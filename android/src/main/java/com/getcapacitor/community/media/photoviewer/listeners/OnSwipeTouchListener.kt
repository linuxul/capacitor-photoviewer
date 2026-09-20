package com.getcapacitor.community.media.photoviewer.listeners

import android.content.Context
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View

internal open class OnSwipeTouchListener(c: Context?) : View.OnTouchListener {
    private val gestureDetector: GestureDetector

    override fun onTouch(view: View, motionEvent: MotionEvent): Boolean = gestureDetector.onTouchEvent(motionEvent)
    private inner class GestureListener : GestureDetector.SimpleOnGestureListener() {
        private val swipeThreshold: Int = 100
        private val swipeVelocityThreshold: Int = 200
        override fun onFling(downEvent: MotionEvent?, moveEvent: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
            var diffX = moveEvent.x.minus(downEvent!!.x)
            var diffY = moveEvent.y.minus(downEvent.y)

            return if (Math.abs(diffX) > Math.abs(diffY)) {
                // this is a left or right swipe
                if (Math.abs(diffX) > swipeThreshold && Math.abs(velocityX) > swipeVelocityThreshold) {
                    if (diffX > 0) {
                        onSwipeRight()
                    } else {
                        onSwipeLeft()
                    }
                    true
                } else {
                    super.onFling(downEvent, moveEvent, velocityX, velocityY)
                }
            } else {
                // this is a up or down swipe
                if (Math.abs(diffY) > swipeThreshold && Math.abs(velocityY) > swipeVelocityThreshold) {
                    if (diffY > 0) {
                        onSwipeDown()
                    } else {
                        onSwipeUp()
                    }
                    true
                } else {
                    super.onFling(downEvent, moveEvent, velocityX, velocityY)
                }
            }
        }
    }
    open fun onSwipeRight() {}
    open fun onSwipeLeft() {}
    open fun onSwipeUp() {}
    open fun onSwipeDown() {}
    init {
        gestureDetector = GestureDetector(c, GestureListener())
    }
}
