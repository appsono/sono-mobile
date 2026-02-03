package wtf.sono.app.nightly

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ApkInstaller(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "wtf.sono.app/apk_installer"
    }

    private lateinit var channel: MethodChannel

    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installApk" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_ARGUMENT", "filePath is required", null)
                    return
                }
                installApk(filePath, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun installApk(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "APK file not found: $filePath", null)
                return
            }

            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                FileProvider.getUriForFile(
                    activity,
                    "${activity.packageName}.fileprovider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }

            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            activity.startActivity(intent)
            result.success(mapOf("type" to "done", "message" to "Installation started"))

        } catch (e: Exception) {
            result.error("INSTALL_ERROR", e.message, e.stackTraceToString())
        }
    }
}