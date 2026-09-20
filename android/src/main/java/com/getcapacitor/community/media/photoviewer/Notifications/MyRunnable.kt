// The package keeps the name the Java sources used.
@file:Suppress("ktlint:standard:package-name")

package com.getcapacitor.community.media.photoviewer.Notifications

public open class MyRunnable : Runnable {
    public var info: Map<String, Any>? = null

    override fun run() {}

    public open fun run(info: Map<String, Any>?) {}
}
