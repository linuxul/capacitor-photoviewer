package com.getcapacitor.community.media.photoviewer

import android.util.Log
import com.getcapacitor.JSObject
import com.getcapacitor.PluginCall

public class RetHandler {
    /**
     * Resolves the call with `result`, or rejects it when there is a message.
     */
    public fun retResult(call: PluginCall, res: Boolean?, message: String?) {
        if (message != null) {
            Log.v(TAG, "*** ERROR $message")
            call.reject(message)
            return
        }
        if (res != null) {
            val ret = JSObject()
            ret.put("result", res)
            call.resolve(ret)
        } else {
            Log.v(TAG, "*** ERROR Show: res must be defined")
            call.reject(null)
        }
    }

    private companion object {
        private val TAG = RetHandler::class.java.name
    }
}
