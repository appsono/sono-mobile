package wtf.sono.app.nightly

import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.InputStream

class ContentUriHandler(private val context: Context) : MethodCallHandler {
    companion object {
        private const val CHANNEL = "sono_content_uri"
    }

    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "readContentUri" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    readContentUri(uriString, result)
                } else {
                    result.error("INVALID_ARGUMENT", "URI cannot be null", null)
                }
            }
            "getContentLength" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    getContentLength(uriString, result)
                } else {
                    result.error("INVALID_ARGUMENT", "URI cannot be null", null)
                }
            }
            "getMimeType" -> {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    getMimeType(uriString, result)
                } else {
                    result.error("INVALID_ARGUMENT", "URI cannot be null", null)
                }
            }
            "readContentChunk" -> {
                val uriString = call.argument<String>("uri")
                val start = call.argument<Int>("start") ?: 0
                val length = call.argument<Int>("length") ?: 65536
                if (uriString != null) {
                    readContentChunk(uriString, start, length, result)
                } else {
                    result.error("INVALID_ARGUMENT", "URI cannot be null", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun readContentUri(uriString: String, result: Result) {
        //use coroutine to avoid blocking the main thread
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val uri = Uri.parse(uriString)
                val contentResolver = context.contentResolver
                
                contentResolver.openInputStream(uri)?.use { inputStream ->
                    val outputStream = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        outputStream.write(buffer, 0, bytesRead)
                    }
                    
                    val audioData = outputStream.toByteArray()
                    
                    withContext(Dispatchers.Main) {
                        result.success(audioData)
                    }
                } ?: run {
                    withContext(Dispatchers.Main) {
                        result.error("FILE_NOT_FOUND", "Cannot open input stream for URI: $uriString", null)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("READ_ERROR", "Failed to read content URI: ${e.message}", e.toString())
                }
            }
        }
    }

    private fun getContentLength(uriString: String, result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val uri = Uri.parse(uriString)
                val contentResolver = context.contentResolver
                
                //try to get size from MediaStore first
                var size: Long? = null
                
                contentResolver.query(
                    uri,
                    arrayOf(MediaStore.Audio.Media.SIZE),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val sizeColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
                        if (sizeColumnIndex != -1) {
                            size = cursor.getLong(sizeColumnIndex)
                        }
                    }
                }
                
                //if MediaStore query didnt work => try alternative methods
                if (size == null || size == 0L) {
                    try {
                        contentResolver.openFileDescriptor(uri, "r")?.use { fileDescriptor ->
                            size = fileDescriptor.statSize
                        }
                    } catch (e: Exception) {
                        //last resort: open stream and count bytes (expensive!)
                        contentResolver.openInputStream(uri)?.use { inputStream ->
                            size = inputStream.available().toLong()
                        }
                    }
                }
                
                withContext(Dispatchers.Main) {
                    result.success(size?.toInt() ?: 0)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("SIZE_ERROR", "Failed to get content length: ${e.message}", e.toString())
                }
            }
        }
    }

    private fun getMimeType(uriString: String, result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val uri = Uri.parse(uriString)
                val contentResolver = context.contentResolver
                
                //get MIME type from ContentResolver
                var mimeType = contentResolver.getType(uri)
                
                //fallback to MediaStore query if ContentResolver doesnt return MIME type
                if (mimeType.isNullOrEmpty()) {
                    contentResolver.query(
                        uri,
                        arrayOf(MediaStore.Audio.Media.MIME_TYPE),
                        null,
                        null,
                        null
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val mimeColumnIndex = cursor.getColumnIndex(MediaStore.Audio.Media.MIME_TYPE)
                            if (mimeColumnIndex != -1) {
                                mimeType = cursor.getString(mimeColumnIndex)
                            }
                        }
                    }
                }
                
                //final fallback => use common audio MIME type
                if (mimeType.isNullOrEmpty()) {
                    mimeType = "audio/mpeg"
                }
                
                withContext(Dispatchers.Main) {
                    result.success(mimeType)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    //return fallback MIME type on error
                    result.success("audio/mpeg")
                }
            }
        }
    }

    //read a specific chunk from content URI for streaming
    private fun readContentChunk(uriString: String, start: Int, length: Int, result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val uri = Uri.parse(uriString)
                val contentResolver = context.contentResolver
                
                contentResolver.openInputStream(uri)?.use { inputStream ->
                    //skip to start position
                    if (start > 0) {
                        var skipped = 0L
                        var toSkip = start.toLong()
                        
                        while (toSkip > 0) {
                            val actuallySkipped = inputStream.skip(toSkip)
                            if (actuallySkipped <= 0) {
                                //if skip fails => try reading and discarding bytes
                                val discardBuffer = ByteArray(minOf(toSkip.toInt(), 8192))
                                val bytesRead = inputStream.read(discardBuffer, 0, minOf(toSkip.toInt(), 8192))
                                if (bytesRead <= 0) break
                                toSkip -= bytesRead
                            } else {
                                toSkip -= actuallySkipped
                            }
                            skipped += if (actuallySkipped > 0) actuallySkipped else 0
                        }
                    }
                    
                    //read requested chunk
                    val buffer = ByteArray(length)
                    var totalBytesRead = 0
                    var bytesRead: Int
                    
                    while (totalBytesRead < length) {
                        bytesRead = inputStream.read(buffer, totalBytesRead, length - totalBytesRead)
                        if (bytesRead <= 0) break
                        totalBytesRead += bytesRead
                    }
                    
                    if (totalBytesRead <= 0) {
                        withContext(Dispatchers.Main) {
                            result.success(null)
                        }
                        return@use
                    }
                    
                    //return only bytes actually read
                    val chunk = if (totalBytesRead == length) {
                        buffer
                    } else {
                        ByteArray(totalBytesRead).apply {
                            System.arraycopy(buffer, 0, this, 0, totalBytesRead)
                        }
                    }
                    
                    withContext(Dispatchers.Main) {
                        result.success(chunk)
                    }
                } ?: run {
                    withContext(Dispatchers.Main) {
                        result.error("STREAM_ERROR", "Cannot open input stream for URI: $uriString", null)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("STREAM_ERROR", "Failed to read chunk: ${e.message}", e.toString())
                }
            }
        }
    }
}