package com.lklima.video.manager.merger

import android.annotation.TargetApi
import android.content.Context
import android.os.Build
import com.facebook.react.bridge.NativeMap
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableNativeMap

data class MergedVideoResults (
    val uri: String,
    val duration: Int
)

class MergedVideoResultsMapFactory() {
    fun newInstance(results: MergedVideoResults): NativeMap {
        val map = WritableNativeMap()
        map.putString(KEY_URI, results.uri)
        map.putInt(KEY_DURATION, results.duration)

        return map
    }

    private companion object {
        const val KEY_URI = "uri"
        const val KEY_DURATION = "duration"
    }
}