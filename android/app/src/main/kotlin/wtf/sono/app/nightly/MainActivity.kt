package wtf.sono.app.nightly

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    private lateinit var contentUriHandler: ContentUriHandler
    private lateinit var apkInstaller: ApkInstaller
    private lateinit var visualizerPlugin: VisualizerPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        contentUriHandler = ContentUriHandler(this)
        contentUriHandler.configureFlutterEngine(flutterEngine)

        apkInstaller = ApkInstaller(this)
        apkInstaller.configureFlutterEngine(flutterEngine)

        visualizerPlugin = VisualizerPlugin()
        visualizerPlugin.configureFlutterEngine(flutterEngine)
    }
}
