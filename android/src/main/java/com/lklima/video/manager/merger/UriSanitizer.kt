package com.lklima.video.manager.merger

import android.net.Uri
import java.io.File

class UriSanitizer {
    fun sanitize(path: String): Uri {
        return if (path.contains("://")) {
            Uri.parse(path)
        } else {
            Uri.fromFile(File(path))
        }
    }
}