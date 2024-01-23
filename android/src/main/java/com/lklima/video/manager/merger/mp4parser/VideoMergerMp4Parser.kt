package com.lklima.video.manager.merger.mp4parser

import android.content.Context
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import com.lklima.video.manager.merger.MergeOptions
import com.lklima.video.manager.merger.MergedVideoResults
import com.lklima.video.manager.merger.VideoMerger
import org.mp4parser.Container
import org.mp4parser.muxer.Movie
import org.mp4parser.muxer.Track
import org.mp4parser.muxer.builder.DefaultMp4Builder
import org.mp4parser.muxer.container.mp4.MovieCreator
import org.mp4parser.muxer.tracks.AppendTrack
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.channels.FileChannel
import kotlin.time.Duration.Companion.milliseconds


class VideoMergerMp4Parser(private val context: Context) : VideoMerger {

    override suspend fun mergeVideos(videoFiles: List<Uri>, options: MergeOptions): Result<MergedVideoResults> {
        return runCatching {
            Log.d(TAG, "videoFiles=$videoFiles")
            val inMovies = videoFiles.map { uri ->
                uri.toMovie() ?: throw IllegalStateException("Movie is null")
            }

            val videoTracks = inMovies.flatMap {
                it.tracks
            }.filter {
                it.handler == TRACK_VIDEO
            }.onEach {
                val duration = it.duration.milliseconds.inWholeSeconds
                val width = it.trackMetaData.width
                val height = it.trackMetaData.height
                Log.i(TAG, "track ${it.name} ${width}x${height} $duration secs")
            }

            val audioTracks = if (options.noAudio) {
                emptyList<Track>()
            } else {
                inMovies.flatMap {
                    it.tracks
                }.filter {
                    it.handler == TRACK_AUDIO
                }.onEach {
                    val duration = it.duration.milliseconds.inWholeSeconds
                    Log.i(TAG, "track ${it.name} ${it.trackMetaData.language} $duration secs")
                }
            }

            val result = Movie().apply {
                tracks = buildList {
                    if (videoTracks.isNotEmpty()) {
                        add(AppendTrack(*videoTracks.toTypedArray()))
                    }
                    if (audioTracks.isNotEmpty()) {
                        add(AppendTrack(*audioTracks.toTypedArray()))
                    }
                }
            }

            val destination = getOutputFile(options)
            DefaultMp4Builder()
                .build(result)
                .storeVideo(destination)

            val uri = Uri.fromFile(destination).also {
                Log.d(TAG, "file written => $it")
            }

            // TODO: Surface the video duration here.
            MergedVideoResults(uri.toString(), result.timescale.toInt())
        }
    }

    private fun Uri.toMovie() = context.contentResolver
        .openFileDescriptor(this, FD_MODE_READ)
        .use { descriptor: ParcelFileDescriptor? ->
            descriptor
                ?.fileDescriptor
                ?.let(::FileInputStream)
                ?.channel
                ?.use { channel: FileChannel ->
                    MovieCreator.build(
                        channel,
                        RandomAccessSourceFromUri(context = context, uri = this),
                        "inMemory"
                    )
                }
        }

    private fun getOutputFile(options: MergeOptions): File {
        val dir = File(options.outputPath).apply {
            mkdirs()
        }
        return File(dir, "${options.fileName}.mp4")
    }

    private fun Container.storeVideo(destination: File) {
        Log.d(TAG, "storing file in ${destination.absolutePath}")
        FileOutputStream(destination).channel.use { channel ->
            writeContainer(channel)
        }
    }

    private companion object {
        const val TAG: String = "VideoMergerMp4Parser"
        const val FD_MODE_READ = "r"
        const val TRACK_AUDIO = "soun"
        const val TRACK_VIDEO = "vide"
    }
}