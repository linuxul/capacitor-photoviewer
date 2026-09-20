// The package keeps the name the Java sources used.
@file:Suppress("ktlint:standard:package-name")

package com.getcapacitor.community.media.photoviewer.Notifications

public class NotificationCenter private constructor() {
    private val registeredObjects = HashMap<String, ArrayList<MyRunnable>>()

    @Synchronized
    public fun addMethodForNotification(notificationName: String, r: MyRunnable) {
        registeredObjects.getOrPut(notificationName) { ArrayList() }.add(r)
    }

    @Synchronized
    public fun removeMethodForNotification(notificationName: String, r: MyRunnable) {
        registeredObjects[notificationName]?.remove(r)
    }

    @Synchronized
    public fun removeAllNotifications() {
        val entries = registeredObjects.entries.iterator()
        while (entries.hasNext()) {
            val entry = entries.next()
            removeMethodForNotification(entry.key, entry.value[0])
            entries.remove()
        }
    }

    @Synchronized
    public fun postNotification(notificationName: String, info: Map<String, Any>?) {
        registeredObjects[notificationName]?.forEach { r ->
            r.info = info
            r.run()
        }
    }

    public companion object {
        private var instance: NotificationCenter? = null

        @JvmStatic
        @Synchronized
        public fun defaultCenter(): NotificationCenter = instance ?: NotificationCenter().also { instance = it }
    }
}
