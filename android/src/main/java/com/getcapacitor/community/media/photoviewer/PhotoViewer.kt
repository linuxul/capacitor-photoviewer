package com.getcapacitor.community.media.photoviewer

import android.content.Context
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import com.getcapacitor.Bridge
import com.getcapacitor.BridgeActivity
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.community.media.photoviewer.adapter.Image
import com.getcapacitor.community.media.photoviewer.fragments.GalleryFullscreenFragment
import com.getcapacitor.community.media.photoviewer.fragments.ImageFragment
import com.getcapacitor.community.media.photoviewer.fragments.MainFragment
import org.json.JSONException
import org.json.JSONObject

public class PhotoViewer internal constructor(private val context: Context, private val pluginBridge: Bridge) : BridgeActivity() {
    private val frameLayoutViewId = 8256

    public fun echo(value: String?): String? = value

    @Throws(Exception::class)
    public fun show(images: JSArray, mode: String?, startFrom: Int?, options: JSObject) {
        try {
            val imageList = convertJSArrayToImageList(images)
            // A missing startFrom or mode threw a NullPointerException here in Java, which the plugin
            // turns into `result: false`.
            val stFrom = if (startFrom!! > imageList.size - 1) imageList.size - 1 else startFrom
            if (imageList.size > 1 && mode!! == "gallery") {
                createMainFragment(imageList, options)
            } else if (mode!! == "one") {
                createImageFragment(imageList, stFrom, options)
            } else if (mode == "slider") {
                createSliderFragment(imageList, stFrom, options)
            }
        } catch (e: JSONException) {
            throw Exception(e.message)
        }
    }

    @Throws(Exception::class)
    private fun createMainFragment(imageList: ArrayList<Image>, options: JSObject) {
        try {
            addFrameLayout()
            val mainFragment = MainFragment()
            mainFragment.setImageList(imageList)
            mainFragment.setOptions(options)
            replaceFragment(mainFragment, "mainfragment")
        } catch (e: Exception) {
            throw Exception(e.message)
        }
    }

    @Throws(Exception::class)
    private fun createImageFragment(imageList: ArrayList<Image>, startFrom: Int, options: JSObject) {
        try {
            addFrameLayout()
            val imageFragment = ImageFragment()
            imageFragment.setImage(imageList[startFrom])
            imageFragment.setOptions(options)
            imageFragment.setStartFrom(startFrom)
            replaceFragment(imageFragment, "imagefragment")
        } catch (e: Exception) {
            throw Exception(e.message)
        }
    }

    @Throws(Exception::class)
    private fun createSliderFragment(imageList: ArrayList<Image>, startFrom: Int, options: JSObject) {
        try {
            addFrameLayout()
            val galleryFragment = GalleryFullscreenFragment()
            galleryFragment.setImageList(imageList)
            galleryFragment.setStartFrom(startFrom)
            galleryFragment.setMode("slider")
            galleryFragment.setOptions(options)
            galleryFragment.setStartFrom(startFrom)
            replaceFragment(galleryFragment, "gallery")
        } catch (e: Exception) {
            throw Exception(e.message)
        }
    }

    /** Adds the FrameLayout that hosts the fragment next to the WebView. */
    private fun addFrameLayout() {
        val frameLayoutView = FrameLayout(context)
        frameLayoutView.id = frameLayoutViewId
        frameLayoutView.layoutParams =
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        (pluginBridge.webView.parent as ViewGroup).addView(frameLayoutView)
    }

    private fun replaceFragment(fragment: Fragment, tag: String) {
        pluginBridge.activity.supportFragmentManager
            .beginTransaction()
            .replace(frameLayoutViewId, fragment, tag)
            .commit()
    }

    @Throws(JSONException::class)
    private fun convertJSArrayToImageList(jsArray: JSArray): ArrayList<Image> {
        val list = ArrayList<Image?>()
        for (i in 0 until jsArray.length()) {
            if (jsArray.isNull(i)) {
                list.add(null)
            } else {
                val obj = jsArray.get(i) as JSONObject
                val url = obj.getString("url")
                val title: String? = obj.optString("title", null)
                list.add(Image(url, title))
            }
        }
        // Java put null entries into this list as well and the fragments take a list of non-null images.
        @Suppress("UNCHECKED_CAST")
        return list as ArrayList<Image>
    }
}
