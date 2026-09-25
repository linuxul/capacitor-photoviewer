import Foundation
import Capacitor
import UIKit

extension NSNotification.Name {
    static var photoviewerExit: Notification.Name {return .init(rawValue: "photoviewerExit")}
}
/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(PhotoViewerPlugin)
public class PhotoViewerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "PhotoViewerPlugin"
    public let jsName = "PhotoViewer"
    public let pluginMethods: [CAPPluginMethod] = [
        .promise("echo", PhotoViewerPlugin.echo),
        .async("show", PhotoViewerPlugin.show),
        .promise("saveImageFromHttpToInternal", PhotoViewerPlugin.saveImageFromHttpToInternal),
        .promise("getInternalImagePaths", PhotoViewerPlugin.getInternalImagePaths)
    ]
    private var implementation: PhotoViewer?
    var exitObserver: Any?
    var config: PhotoViewerConfig?

    override public func load() {
        let mConfig = photoviewerConfig()
        self.config = mConfig
        self.addObserversToNotificationCenter()
        self.implementation = PhotoViewer(config: mConfig)
    }
    deinit {
        NotificationCenter.default.removeObserver(exitObserver as Any)
    }

    // MARK: echo

    func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        if let retValue: String = implementation?.echo(value) {
            call.resolve([
                "value": retValue
            ])
        }
    }

    // MARK: show

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    /// The viewers are UIKit controllers: the method runs on the main actor and resolves with `{ result: true }` once
    /// the viewer is on screen, as it did from the presentation's completion.
    @MainActor
    func show(_ call: CAPPluginCall) async throws -> JSObject {
        guard let imageList = call.options["images"] as? [[String: String]] else {
            let error: String = "Must provide an image list"
            print(error)
            throw CAPPluginError("Show : \(error)")
        }
        if imageList.count == 0 {
            let error: String = "Must provide a non-empty image list"
            print(error)
            throw CAPPluginError("Show : \(error)")
        }
        let mode: String = call.getString("mode") ?? "one"
        let startFrom: Int = call.getInt("startFrom") ?? 0
        let options: JSObject = call.getObject("options") ?? [:]
        var mOptions: [String: Any] = [:]
        let keys = options.keys
        if keys.count > 0 {
            if keys.contains("spancount") {
                mOptions["spancout"] = options["spancout"] as? Int
            }
            if keys.contains("share") {
                mOptions["share"] = options["share"] as? Bool
            }
            if keys.contains("title") {
                mOptions["title"] = options["title"] as? String
            }

        }

        // Display
        if imageList.count <= 1
            && (mode == "gallery" || mode == "slider") {
            var msg = "Show : imageList must be greater that one "
            msg += "for Mode \(mode)"
            throw CAPPluginError(msg)
        }
        let controller: UIViewController
        let unableToShow: String
        if mode == "gallery" {
            unableToShow = "Show : Unable to show the CollectionViewController"
            guard implementation?.show(imageList, mode: mode, startFrom: startFrom, options: options) != nil,
                  let collectionController = implementation?.collectionController else {
                throw CAPPluginError(unableToShow)
            }
            controller = collectionController
        } else if mode == "one" {
            unableToShow = "Show : Unable to show the OneImageViewController"
            guard implementation?.show(imageList, mode: mode, startFrom: startFrom, options: options) != nil,
                  let oneImageController = implementation?.oneImageController else {
                throw CAPPluginError(unableToShow)
            }
            controller = oneImageController
        } else if mode == "slider" {
            unableToShow = "Show : Unable to show the SliderViewController"
            guard implementation?.show(imageList, mode: mode, startFrom: startFrom, options: options) != nil,
                  let sliderController = implementation?.sliderController else {
                throw CAPPluginError(unableToShow)
            }
            controller = sliderController
        } else {
            throw CAPPluginError("Show : Mode \(mode) not implemented")
        }
        controller.modalPresentationStyle = .fullScreen
        // With no view controller to present from, or a presentation UIKit refuses, the call used to stay pending.
        guard let presenter = bridge?.viewController,
              await Self.present(controller, from: presenter) else {
            throw CAPPluginError(unableToShow)
        }
        return ["result": true]
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    // Stays synchronous: it starts the download on a background queue, and the download answers the call.
    func saveImageFromHttpToInternal(_ call: CAPPluginCall) throws {
        guard let imageUrl = call.options["url"] as? String else {
            let error: String = "Must provide an image url"
            print(error)
            throw CAPPluginError("SaveImageFromHttpToInternal : \(error)")
        }
        guard let fileName = call.options["filename"] as? String else {
            let error: String = "Must provide an image filename"
            print(error)
            throw CAPPluginError("SaveImageFromHttpToInternal : \(error)")
        }
        DispatchQueue.global(qos: .background).async {
            do {
                try self.implementation?
                    .saveImageFromHttpToInternal(call, url: imageUrl,
                                                 fileName: fileName)
            } catch PhotoViewerError.failed(let message) {

                DispatchQueue.main.async {
                    call.reject("SaveImageFromHttpToInternal : \(message)")
                    return
                }
            } catch let error {
                DispatchQueue.main.async {
                    let msg = "SaveImageFromHttpToInternal : " +
                        "\(error.localizedDescription)"
                    call.reject("\(msg)")
                    return
                }
            }
        }
    }
    func getInternalImagePaths(_ call: CAPPluginCall) throws {
        let pathList: [String]?
        do {
            pathList = try self.implementation?.getInternalImagePaths()
        } catch PhotoViewerError.failed(let message) {
            throw CAPPluginError("GetInternalImagePaths : \(message)")
        } catch let error {
            throw CAPPluginError("GetInternalImagePaths : \(error.localizedDescription)")
        }
        guard let pathList else {
            throw CAPPluginError("GetInternalImagePaths : no image path list")
        }
        call.resolve(["pathList": pathList])
    }
    @objc func addObserversToNotificationCenter() {
        // add Observers
        exitObserver = NotificationCenter
            .default.addObserver(forName: .photoviewerExit, object: nil,
                                 queue: nil,
                                 using: photoViewerExit)
    }

    // MARK: - photoViewerExit

    @objc func photoViewerExit(notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.notifyListeners("jeepCapPhotoViewerExit", data: info, retainUntilConsumed: true)
            return
        }
    }

    /// Presents `controller` from `presenter` and returns once the presentation has completed: true, or false right
    /// away when UIKit refuses it (it logs and does nothing when the presenter already presents a controller, is
    /// mid-transition or is not in a window). UIKit sets `presentedViewController` as soon as it accepts a presentation.
    @MainActor
    static func present(_ controller: UIViewController, from presenter: UIViewController) async -> Bool {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            // UIKit calls the completion once; should it drop it instead, releasing it still answers.
            let presented = OnceContinuation(continuation, fallback: true)
            presenter.present(controller, animated: true) {
                presented.resume(returning: true)
            }
            if presenter.presentedViewController !== controller {
                presented.resume(returning: false)
            }
        }
    }

    private func photoviewerConfig() -> PhotoViewerConfig {
        var config = PhotoViewerConfig()
        let configPlugin = getConfig()
        if let iosImageLocation = configPlugin.getString("iosImageLocation") {
            config.iosImageLocation = iosImageLocation
        }
        return config
    }

}
