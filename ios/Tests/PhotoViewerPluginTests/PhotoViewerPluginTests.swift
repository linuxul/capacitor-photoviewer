import XCTest
import UIKit
import WebKit
import Capacitor
@testable import PhotoViewerPlugin

final class PhotoViewerTests: XCTestCase {
    private let twoImages: [[String: String]] = [["url": "https://example.com/a.jpg"], ["url": "https://example.com/b.jpg"]]

    func testEcho() {
        // This is an example of a functional test case for a plugin.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        let implementation = PhotoViewer(config: PhotoViewerConfig())
        let value = "Hello, World!"
        let result = implementation.echo(value)

        XCTAssertEqual(value, result)
    }

    @MainActor
    func testShowRejectsAMissingOrEmptyImageList() async {
        let missing = await thrownError { _ = try await PhotoViewerPlugin().show(self.makeCall("show", [:])) }
        XCTAssertEqual(missing?.message, "Show : Must provide an image list")
        XCTAssertNil(missing?.code)

        let empty = await thrownError { _ = try await PhotoViewerPlugin().show(self.makeCall("show", ["images": []])) }
        XCTAssertEqual(empty?.message, "Show : Must provide a non-empty image list")
    }

    @MainActor
    func testShowRejectsASingleImageForTheGalleryAndTheSlider() async {
        for mode in ["gallery", "slider"] {
            let options: JSObject = ["images": [["url": "https://example.com/a.jpg"]], "mode": mode]
            let error = await thrownError { _ = try await PhotoViewerPlugin().show(self.makeCall("show", options)) }
            XCTAssertEqual(error?.message, "Show : imageList must be greater that one for Mode \(mode)")
        }
    }

    @MainActor
    func testShowRejectsAnUnknownMode() async {
        let options: JSObject = ["images": twoImages, "mode": "carousel"]
        let error = await thrownError { _ = try await PhotoViewerPlugin().show(self.makeCall("show", options)) }
        XCTAssertEqual(error?.message, "Show : Mode carousel not implemented")
    }

    @MainActor
    func testShowRejectsWhenThereIsNothingToPresentFrom() async {
        // The call used to stay pending when the bridge had no view controller.
        let plugin = PhotoViewerPlugin()
        plugin.load()
        let error = await thrownError { _ = try await plugin.show(self.makeCall("show", ["images": self.twoImages])) }
        XCTAssertEqual(error?.message, "Show : Unable to show the OneImageViewController")
    }

    @MainActor
    func testShowReturnsOnceTheViewerIsPresented() async throws {
        let harness = Harness()
        let result = try await harness.plugin.show(makeCall("show", ["images": twoImages, "mode": "gallery"]))
        XCTAssertEqual(result["result"] as? Bool, true)
        let presented = try XCTUnwrap(harness.root.fakePresented as? CollectionViewController)
        XCTAssertEqual(presented.modalPresentationStyle, .fullScreen)
    }

    @MainActor
    func testARefusedPresentationRejects() async {
        // UIKit logs and does nothing when the presenter already presents a controller or is not in a window; the call
        // used to hang.
        let harness = Harness()
        harness.root.refusesPresentations = true
        let error = await thrownError { _ = try await harness.plugin.show(self.makeCall("show", ["images": self.twoImages, "mode": "slider"])) }
        XCTAssertEqual(error?.message, "Show : Unable to show the SliderViewController")
    }

    func testGetInternalImagePathsRejectsWithoutAnImageLocation() {
        XCTAssertThrowsError(try PhotoViewerPlugin().getInternalImagePaths(makeCall("getInternalImagePaths", [:]))) { error in
            XCTAssertEqual((error as? CAPPluginError)?.message, "GetInternalImagePaths : no image path list")
        }

        let plugin = PhotoViewerPlugin()
        plugin.load()
        XCTAssertThrowsError(try plugin.getInternalImagePaths(makeCall("getInternalImagePaths", [:]))) { error in
            XCTAssertEqual((error as? CAPPluginError)?.message,
                           "GetInternalImagePaths : You must have 'iosImageLocation' defined in the capacitor.config.ts file")
        }
    }

    func testSaveImageFromHttpToInternalRejectsMissingOptions() {
        let plugin = PhotoViewerPlugin()
        XCTAssertThrowsError(try plugin.saveImageFromHttpToInternal(makeCall("saveImageFromHttpToInternal", ["filename": "a"]))) { error in
            XCTAssertEqual((error as? CAPPluginError)?.message, "SaveImageFromHttpToInternal : Must provide an image url")
        }
        XCTAssertThrowsError(try plugin.saveImageFromHttpToInternal(makeCall("saveImageFromHttpToInternal", ["url": "https://example.com/a.jpg"]))) { error in
            XCTAssertEqual((error as? CAPPluginError)?.message, "SaveImageFromHttpToInternal : Must provide an image filename")
        }
    }

    func testOnceContinuationResumesOnlyWithTheFirstValue() async {
        let value = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            let once = OnceContinuation(continuation, fallback: 0)
            XCTAssertTrue(once.resume(returning: 1))
            XCTAssertFalse(once.resume(returning: 2))
        }
        XCTAssertEqual(value, 1)
    }

    func testOnceContinuationReleasedWithoutAnswerResumesWithTheFallback() async {
        let value = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            _ = OnceContinuation(continuation, fallback: 7)
        }
        XCTAssertEqual(value, 7)
    }

    /// The CAPPluginError `body` throws, which the bridge rejects the call with; nil when it returns.
    @MainActor
    private func thrownError(_ body: () async throws -> Void) async -> CAPPluginError? {
        do {
            try await body()
            XCTFail("the method must throw")
            return nil
        } catch let error as CAPPluginError {
            return error
        } catch {
            XCTFail("unexpected error \(error)")
            return nil
        }
    }

    private func makeCall(_ method: String, _ options: JSObject) -> CAPPluginCall {
        return CAPPluginCall(callbackId: "test", methodName: method, options: options, success: { _, _ in
            XCTFail("\(method) answers by returning or throwing")
        }, error: { _ in
            XCTFail("\(method) answers by returning or throwing")
        })
    }
}

/// A loaded plugin whose bridge shows `root`. The plugin's bridge is weak: the harness keeps it.
private struct Harness {
    let plugin = PhotoViewerPlugin()
    let root = FakePresentingController()
    let bridge = FakeBridge()

    init() {
        // Loaded before it has a bridge: the fake bridge has no configuration to read.
        plugin.load()
        bridge.viewController = root
        plugin.bridge = bridge
    }
}

/// A controller whose presentation state the test sets, since real presentation needs a window and an app. It keeps
/// what it is asked to present, the way UIKit does while a controller is on screen, unless it refuses presentations.
private final class FakePresentingController: UIViewController {
    var fakePresented: UIViewController?
    var refusesPresentations = false

    override var presentedViewController: UIViewController? {
        return fakePresented
    }

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        guard !refusesPresentations else {
            return
        }
        fakePresented = viewControllerToPresent
        completion?()
    }
}

/// A bridge with just enough behaviour for the plugin to find its view controller. Members it never uses trap.
private final class FakeBridge: CAPBridgeProtocol {
    var viewController: UIViewController?
    var webView: WKWebView?
    var isSimEnvironment = true
    var isDevEnvironment = true
    var userInterfaceStyle = UIUserInterfaceStyle.unspecified
    var autoRegisterPlugins = false
    var statusBarVisible = true
    var statusBarStyle = UIStatusBarStyle.default
    var statusBarAnimation = UIStatusBarAnimation.fade
    var config: InstanceConfiguration { fatalError("unused") }
    var notificationRouter: NotificationRouter { fatalError("unused") }

    func plugin(withName: String) -> CAPPlugin? { nil }
    func saveCall(_ call: CAPPluginCall) {}
    func savedCall(withID: String) -> CAPPluginCall? { nil }
    func releaseCall(_ call: CAPPluginCall) {}
    func releaseCall(withID: String) {}
    // swiftlint:disable identifier_name
    func evalWithPlugin(_ plugin: CAPPlugin, js: String) {}
    func eval(js: String) {}
    // swiftlint:enable identifier_name
    func triggerJSEvent(eventName: String, target: String) {}
    func triggerJSEvent(eventName: String, target: String, data: String) {}
    func triggerWindowJSEvent(eventName: String) {}
    func triggerWindowJSEvent(eventName: String, data: String) {}
    func triggerDocumentJSEvent(eventName: String) {}
    func triggerDocumentJSEvent(eventName: String, data: String) {}
    func localURL(fromWebURL webURL: URL?) -> URL? { webURL }
    func portablePath(fromLocalURL localURL: URL?) -> URL? { localURL }
    func setServerBasePath(_ path: String) {}
    func registerPluginType(_ pluginType: CAPPlugin.Type) {}
    func registerPluginInstance(_ pluginInstance: CAPPlugin) {}
    func showAlertWith(title: String, message: String, buttonTitle: String) {}
}
