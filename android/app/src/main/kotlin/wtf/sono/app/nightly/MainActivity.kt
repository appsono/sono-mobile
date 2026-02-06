package wtf.sono.app.nightly

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    private lateinit var contentUriHandler: ContentUriHandler
    private lateinit var apkInstaller: ApkInstaller

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        //initialize ContentUri handler
        contentUriHandler = ContentUriHandler(this)
        contentUriHandler.configureFlutterEngine(flutterEngine)

        //initialize APK installer for auto-updates
        apkInstaller = ApkInstaller(this)
        apkInstaller.configureFlutterEngine(flutterEngine)
    }
}