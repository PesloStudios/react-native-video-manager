package com.lklima.video.manager.merger.mp4parser

import android.content.Context
import android.net.Uri
import android.util.Log
import org.mp4parser.muxer.RandomAccessSource
import org.mp4parser.tools.CastUtils.l2i
import java.io.FileInputStream
import java.nio.ByteBuffer

class RandomAccessSourceFromUri(context: Context, uri: Uri) : RandomAccessSource {
    private val fileDescriptor = requireNotNull(
        context.contentResolver.openFileDescriptor(uri, FD_MODE_READ)
    )
    private val fileInputStream = FileInputStream(fileDescriptor.fileDescriptor)

    override fun close() {
        fileDescriptor.close()
        fileInputStream.close()
    }

    override fun get(offset: Long, size: Long): ByteBuffer? {
        try {
            val channel = fileInputStream.channel
            channel.position(offset)
            Log.d(TAG, "getting $size bytes")
            val byteArray = ByteArray(l2i(size))
            val byteBuffer = ByteBuffer.wrap(byteArray)
            val bytesRead = channel.read(byteBuffer)
            Log.d(TAG, "read $bytesRead bytes")
            return byteBuffer
        } catch (e: Exception) {
            Log.e(TAG, "failed to read file", e)
        }
        return null
    }

    private companion object {
        const val TAG: String = "RandomAccessSourceFromU"
        const val FD_MODE_READ = "r"
    }
}