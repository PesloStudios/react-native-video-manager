package com.lklima.video.manager.merger.ffmpeg

import android.content.Context
import android.net.Uri
import android.util.Log
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegKitConfig
import com.arthenica.ffmpegkit.LogRedirectionStrategy
import com.lklima.video.manager.merger.MergeOptions
import com.lklima.video.manager.merger.VideoMerger
import java.io.File


class VideoMergerFfmpeg(private val context: Context) : VideoMerger {

    init {
        FFmpegKitConfig.setLogRedirectionStrategy(LogRedirectionStrategy.ALWAYS_PRINT_LOGS)
        FFmpegKitConfig.enableLogCallback { log ->
            Log.d(TAG, "[${log.level.name}] [${log.sessionId}] ${log.message}")
        }
    }

    private fun Uri.safePathForRead(): String = requireNotNull(
        FFmpegKitConfig.getSafParameterForRead(context.applicationContext, this)
    ).also {
        Log.w(TAG, "${this.encodedPath}==>$it")
    }

    private fun Uri.safePathForWrite(): String = requireNotNull(
        FFmpegKitConfig.getSafParameterForWrite(context.applicationContext, this)
    ).also {
        Log.w(TAG, "${this.encodedPath}==>$it")
    }

    override suspend fun mergeVideos(videoFiles: List<Uri>, options: MergeOptions): Result<Uri> {
        return runCatching {
            val command = createCommand(
                videoPaths = videoFiles.map { uri ->
                    uri.safePathForRead()
                },
                output = Uri.fromFile(getOutputFile(options)).safePathForWrite()
            )
            val session = FFmpegKit.execute(command)
            val returnCode = session.returnCode
            if (returnCode.isValueSuccess) {
                Log.v(TAG, "SUCCESS")
            } else if (returnCode.isValueCancel) {
                Log.w(TAG, "Cancelled")
                throw RuntimeException("session cancelled")
            } else {
                Log.e(
                    TAG,
                    "Command failed with state ${session.state} and rc ${session.returnCode}.${session.failStackTrace}"
                )
                throw RuntimeException("session failed ${session.state} and rc ${session.returnCode}.${session.failStackTrace}")
            }
            Uri.fromFile(getOutputFile(options))
        }
    }

    private fun createCommand(videoPaths: List<String>, output: String): String {
        val listFilePath: String = generateVideoFileList(videoPaths)
        Log.d(TAG, "output=${output}")
        return "-f concat -protocol_whitelist saf,file,crypto -safe 0 -i $listFilePath -c copy $output"
    }

    private fun generateVideoFileList(inputs: List<String>): String = run {
        val path: String
        File.createTempFile("ffmpeg-list-${System.currentTimeMillis()}", ".txt")
            .also {
                path = it.absolutePath
            }
            .printWriter()
            .use { out ->
                inputs.forEach { path ->
                    out.println("file '$path'")
                }
                out.println()
            }
        Log.d(TAG, "Wrote list file to $path")
        val content = File(path).inputStream().bufferedReader().use { it.readText() }
        Log.d(TAG, content)
        path
    }

    private fun getOutputFile(options: MergeOptions): File {
        val dir = File(options.outputPath).apply {
            mkdirs()
        }
        return File(dir, "${options.fileName}.mp4")
    }

    private companion object {
        const val TAG: String = "VideoMergerFfmpeg"
    }
}