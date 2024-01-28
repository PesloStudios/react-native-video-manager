package com.lklima.video.manager.metadata

import android.content.Context
import android.media.MediaMetadataRetriever
import android.media.MediaMetadataRetriever.METADATA_KEY_DURATION
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.time.Duration.Companion.milliseconds

class VideoMetadataExtractor(
    private val context: Context
) {
    suspend fun getVideoMetadataFor(
        files: List<String>
    ): Result<Map<String, Long>> = withContext(Dispatchers.IO) {
        runCatching {
            files.map { file: String ->
                val durationMs = MediaMetadataRetriever().apply {
                    setDataSource(
                        context,
                        Uri.parse(file)
                    )
                }.extractMetadata(METADATA_KEY_DURATION)?.toLong() ?: -1000L
                file to durationMs.milliseconds.inWholeSeconds
            }.associate { (fileName, durationSeconds) ->
                fileName to durationSeconds
            }.toMap()
        }
    }
}