package com.lklima.video.manager.merger.native

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMetadataRetriever.METADATA_KEY_DURATION
import android.media.MediaMuxer
import android.media.MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
import android.net.Uri
import android.util.Log
import com.lklima.video.manager.merger.MergeOptions
import com.lklima.video.manager.merger.MergedVideoResults
import com.lklima.video.manager.merger.VideoMerger
import java.io.File
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.nio.ByteBuffer

class VideoMergerNative(private val context: Context) : VideoMerger {

    private val File.fileDescriptor: FileDescriptor
        get() = FileOutputStream(this).fd

    override suspend fun mergeVideos(
        videoFiles: List<Uri>,
        options: MergeOptions
    ): Result<MergedVideoResults> {
        Log.d(TAG, "videoFiles=$videoFiles")
        return runCatching {
            val outputFile = getOutputFile(options)
            concatenateFiles(
                sources = videoFiles,
                output = outputFile.fileDescriptor,
                noAudio = options.noAudio
            )
            val uri = Uri.fromFile(outputFile).also {
                Log.d(TAG, "file written => $it")
            }
            // TODO: Surface the video duration here.
            MergedVideoResults(uri = uri.toString(), duration = 0)
        }.onFailure {
            Log.w(TAG, it)
        }
    }

    private fun concatenateFiles(output: FileDescriptor, sources: List<Uri>, noAudio: Boolean) {
        if (sources.isEmpty()) throw IllegalArgumentException("")
        val muxer = MediaMuxer(output, MUXER_OUTPUT_MPEG_4)
        val result = runCatching {
            var videoFormat: MediaFormat? = null
            var audioFormat: MediaFormat? = null
            var idx = 0
            var muxerStarted = false
            var videoTrackIndex = -1
            var audioTrackIndex = -1
            var totalDuration = 0
            for (file in sources) {
                val metadataRetriever = MediaMetadataRetriever().apply {
                    setDataSource(context, file)
                }
                val trackDuration =
                    metadataRetriever.extractMetadata(METADATA_KEY_DURATION)!!.toInt()
                val extractorVideo = MediaExtractor().apply {
                    setDataSource(context, file, null)
                }
                val tracks = extractorVideo.trackCount
                Log.d(TAG, "file=$file\n\t tracks = $tracks")
                for (i in 0 until tracks) {
                    val mediaFormat = extractorVideo.getTrackFormat(i)
                    val mime = mediaFormat.getString(MediaFormat.KEY_MIME)
                    Log.d(TAG, "\ttrack[$i]=>$mime")
                    if (mime?.startsWith("video/") == true) {
                        extractorVideo.selectTrack(i)
                        videoFormat = extractorVideo.getTrackFormat(i)
                        break
                    }
                }
                val extractorAudio = MediaExtractor().apply {
                    setDataSource(context, file, null)
                }
                for (i in 0 until tracks) {
                    val mf = extractorAudio.getTrackFormat(i)
                    val mime = mf.getString(MediaFormat.KEY_MIME)
                    Log.d(TAG, "\ttrack[$i]=>$mime")
                    if (!noAudio && mime?.startsWith("audio/") == true) {
                        extractorAudio.selectTrack(i)
                        audioFormat = extractorAudio.getTrackFormat(i)
                        break
                    }
                }
                if (videoTrackIndex == -1 && videoFormat != null) {
                    videoTrackIndex = muxer.addTrack(videoFormat)
                }
                if (audioTrackIndex == -1 && audioFormat != null) {
                    audioTrackIndex = muxer.addTrack(audioFormat)
                }
                var sawEOS = false
                var sawAudioEOS = false
                val bufferSize = MAX_SAMPLE_SIZE
                val dstBuf = ByteBuffer.allocate(bufferSize)
                val offset = 0
                val bufferInfo = MediaCodec.BufferInfo()
                if (!muxerStarted) {
                    muxer.start()
                    muxerStarted = true
                }
                while (!sawEOS) {
                    bufferInfo.offset = offset
                    bufferInfo.size = extractorVideo.readSampleData(dstBuf, offset)
                    if (bufferInfo.size < 0) {
                        sawEOS = true
                        bufferInfo.size = 0
                    } else {
                        bufferInfo.presentationTimeUs = extractorVideo.sampleTime + totalDuration
                        bufferInfo.flags = MediaCodec.BUFFER_FLAG_KEY_FRAME
                        muxer.writeSampleData(videoTrackIndex, dstBuf, bufferInfo)
                        extractorVideo.advance()
                    }
                }
                val audioBuf = ByteBuffer.allocate(bufferSize)
                while (!sawAudioEOS) {
                    bufferInfo.offset = offset
                    bufferInfo.size = extractorAudio.readSampleData(audioBuf, offset)
                    if (bufferInfo.size < 0) {
                        sawAudioEOS = true
                        bufferInfo.size = 0
                    } else {
                        bufferInfo.presentationTimeUs = extractorAudio.sampleTime + totalDuration
                        bufferInfo.flags = MediaCodec.BUFFER_FLAG_KEY_FRAME
                        muxer.writeSampleData(audioTrackIndex, audioBuf, bufferInfo)
                        extractorAudio.advance()
                    }
                }
                extractorVideo.release()
                extractorAudio.release()

                totalDuration += (trackDuration * 1_000)

                Log.d(TAG, "PresentationTimeUs: + ${bufferInfo.presentationTimeUs}")
                Log.d(TAG, "totalDuration: + $totalDuration")

                idx += 1
            }
        }
        runCatching {
            muxer.stop()
            muxer.release()
        }
        return result.getOrThrow()
    }

    private fun getOutputFile(options: MergeOptions): File {
        val dir = File(options.outputPath).apply {
            mkdirs()
        }
        return File(dir, "${options.fileName}.mp4")
    }

    private companion object {
        const val TAG: String = "VideoMergerMp4Parser"
        private const val MAX_SAMPLE_SIZE = 256 * 1024
    }
}