package com.getcapacitor.community.media.photoviewer.helper

import android.content.Context
import android.util.AttributeSet
import android.widget.RelativeLayout

public class SquareLayout : RelativeLayout {
    public constructor(context: Context) : super(context)

    public constructor(context: Context, attrs: AttributeSet) : super(context, attrs)

    public constructor(context: Context, attrs: AttributeSet, defStyleAttr: Int) : super(context, attrs, defStyleAttr)

    public constructor(context: Context, attrs: AttributeSet, defStyleAttr: Int, defStyleRes: Int) :
        super(context, attrs, defStyleAttr, defStyleRes)

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, widthMeasureSpec)
    }
}
