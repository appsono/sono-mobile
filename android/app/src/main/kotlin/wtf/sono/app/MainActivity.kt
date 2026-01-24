package wtf.sono.app
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    private lateinit var contentUriHandler: ContentUriHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        //initialize ContentUri handler
        contentUriHandler = ContentUriHandler(this)
        contentUriHandler.configureFlutterEngine(flutterEngine)
    }
}