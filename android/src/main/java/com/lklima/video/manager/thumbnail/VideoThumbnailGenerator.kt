package com.lklima.video.manager.thumbnail

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

class VideoThumbnailGenerator(
    private val context: Context
) {

    suspend fun generateThumbnail(
        video: String,
        writeDirectory: String,
        fileName: String,
        timestamp: Long
    ): Result<Boolean> = withContext(Dispatchers.IO) {
        runCatching {
            val thumbnailBitmap = MediaMetadataRetriever().apply {
                setDataSource(context, Uri.parse(video))
            }.getFrameAtTime(
                timestamp * 1000000L,
                OPTION_CLOSEST_SYNC,
            ).let {
                requireNotNull(it) { "thumbnail failed to be generated" }
            }
            val outputDir = File(writeDirectory).apply {
                mkdirs()
            }
            val outputFile = File(outputDir, "${fileName}.jpg")
            FileOutputStream(outputFile).use { out ->
                thumbnailBitmap.compress(Bitmap.CompressFormat.JPEG, 40, out)
            }
        }
    }
}

