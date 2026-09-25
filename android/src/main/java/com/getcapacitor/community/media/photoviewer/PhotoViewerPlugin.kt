package com.getcapacitor.community.media.photoviewer

import android.Manifest
import com.getcapacitor.JSObject
import com.getcapacitor.PermissionState
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginException
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.getcapacitor.annotation.Permission
import com.getcapacitor.annotation.PermissionCallback
import com.getcapacitor.community.media.photoviewer.Notifications.MyRunnable
import com.getcapacitor.community.media.photoviewer.Notifications.NotificationCenter
import org.json.JSONException

@CapacitorPlugin(
    name = "PhotoViewer",
    permissions = [
        Permission(alias = PhotoViewerPlugin.MEDIAIMAGES, strings = [Manifest.permission.READ_MEDIA_IMAGES]),
        Permission(alias = PhotoViewerPlugin.READ_EXTERNAL_STORAGE, strings = [Manifest.permission.READ_EXTERNAL_STORAGE])
    ]
)
public class PhotoViewerPlugin : Plugin() {
    private lateinit var implementation: PhotoViewer
    private val rHandler = RetHandler()
    private var isPermissions = false

    override fun load() {
        implementation = PhotoViewer(context, bridge)
    }

    @PermissionCallback
    private fun imagesPermissionsCallback(call: PluginCall) {
        if (!isImagesPermissions()) {
            throw PluginException(PERMISSION_DENIED_ERROR)
        }
        isPermissions = true
        show(call)
    }

    private fun isImagesPermissions(): Boolean = getPermissionState(MEDIAIMAGES) == PermissionState.GRANTED

    @PluginMethod
    public fun echo(call: PluginCall) {
        val value = call.getString("value")

        val ret = JSObject()
        ret.put("value", implementation.echo(value))
        call.resolve(ret)
    }

    @PluginMethod
    public fun show(call: PluginCall) {
        if (!call.data.has("images")) {
            throw PluginException("Show: Must provide an image list")
        }
        val images = call.getArray("images")
        if (images == null || images.length() == 0) {
            throw PluginException("Show: Must provide a non-empty list of image")
        }
        val options = (if (call.data.has("options")) call.getObject("options", JSObject()) else null) ?: JSObject()
        val mode = if (call.data.has("mode")) call.getString("mode") else "one"
        val startFrom = if (call.data.has("startFrom")) call.getInt("startFrom") else 0
        // Check if requires permissions
        var isRequired = false
        for (i in 0 until images.length()) {
            try {
                val url = images.getJSONObject(i).getString("url")
                if (url.startsWith("file:") || url.contains("_capacitor_file_")) {
                    isRequired = true
                    break
                }
            } catch (e: JSONException) {
                e.printStackTrace()
            }
        }
        if (isRequired) {
            // Check for permissions to access media image files
            if (!isImagesPermissions()) {
                bridge.saveCall(call)
                requestAllPermissions(call, "imagesPermissionsCallback")
            } else {
                isPermissions = true
            }
        } else {
            isPermissions = true
        }
        if (isPermissions) {
            try {
                addObserversToNotificationCenter()

                bridge.activity.runOnUiThread {
                    try {
                        // A `mode` that is not a string threw a NullPointerException here in Java, which ends up as
                        // `result: false`.
                        if (images.length() <= 1 && (mode!! == "gallery" || mode == "slider")) {
                            rHandler.retResult(call, false, "Show : imageList must be greater that one for Mode $mode")
                            return@runOnUiThread
                        }
                        implementation.show(images, mode, startFrom, options)
                        rHandler.retResult(call, true, null)
                    } catch (e: Exception) {
                        rHandler.retResult(call, false, e.message)
                    }
                }
            } catch (e: Exception) {
                rHandler.retResult(call, false, "Show: " + e.message)
            }
        }
    }

    @PluginMethod
    public fun saveImageFromHttpToInternal(call: PluginCall) {
        call.unimplemented("Not implemented on Android.")
    }

    @PluginMethod
    public fun getInternalImagePaths(call: PluginCall) {
        call.unimplemented("Not implemented on Android.")
    }

    private fun addObserversToNotificationCenter() {
        NotificationCenter.defaultCenter().addMethodForNotification(
            "photoviewerExit",
            object : MyRunnable() {
                override fun run() {
                    val data = JSObject()
                    data.put("result", info?.get("result"))
                    data.put("imageIndex", info?.get("imageIndex"))
                    data.put("message", info?.get("message"))
                    NotificationCenter.defaultCenter().removeAllNotifications()
                    notifyListeners("jeepCapPhotoViewerExit", data)
                }
            }
        )
    }

    internal companion object {
        private const val PERMISSION_DENIED_ERROR = "Unable to access media images, user denied permission request"

        // Permission alias constants
        internal const val MEDIAIMAGES = "images"
        internal const val READ_EXTERNAL_STORAGE = "read_external_storage"
    }
}
