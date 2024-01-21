package com.lklima.video.manager.merger.options

import android.annotation.TargetApi
import android.content.Context
import android.os.Build
import com.facebook.react.bridge.ReadableMap
import com.lklima.video.manager.merger.MergeOptions

class MergedVideoOptionsFactory(private val context: Context) {
    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    fun newInstance(options: ReadableMap): MergeOptions = MergeOptions(
        fileName = options.getString(KEY_FILE_NAME) ?: DEFAULT_FILE_NAME,
        outputPath = options.getString(KEY_WRITE_DIRECTION)
            ?: context.noBackupFilesDir.absolutePath,
        noAudio = options.getBoolean(KEY_IGNORE_SOUND)
    )

    private companion object {
        const val KEY_FILE_NAME = "fileName"
        const val KEY_WRITE_DIRECTION = "writeDirectory"
        const val KEY_IGNORE_SOUND = "ignoreSound"
        const val DEFAULT_FILE_NAME = "merged_video"
    }
}