package wtf.sono.app.nightly

import android.media.audiofx.Visualizer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.sqrt

class VisualizerPlugin : MethodChannel.MethodCallHandler {
    companion object { const val CHANNEL = "sono_visualizer" }

    private var visualizer: Visualizer? = null

    @Volatile private var fftBins: FloatArray = FloatArray(0)

    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                init(call.argument<Int>("sessionId") ?: 0)
                result.success(null)
            }
            "getSpectrum" -> result.success(fftBins.map { it.toDouble() })
            "release" -> { release(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun init(sessionId: Int) {
        release()
        try {
            val range   = Visualizer.getCaptureSizeRange()
            val capSize = maxOf(range[0], minOf(128, range[1]))
            val bins    = FloatArray(capSize / 2)

            visualizer = Visualizer(sessionId).apply {
                captureSize = capSize
                setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(v: Visualizer, w: ByteArray, r: Int) {}
                    override fun onFftDataCapture(v: Visualizer, fft: ByteArray, r: Int) {
                        val n = bins.size
                        bins[0] = abs(fft[0].toFloat()) / 128f
                        for (i in 1 until n) {
                            val re = if (2 * i < fft.size) fft[2 * i].toFloat()     else 0f
                            val im = if (2 * i + 1 < fft.size) fft[2 * i + 1].toFloat() else 0f
                            bins[i] = minOf(sqrt(re * re + im * im) / 128f, 1f)
                        }
                        fftBins = bins
                    }
                }, Visualizer.getMaxCaptureRate() / 2, false, true)
                enabled = true
            }
        } catch (_: Exception) {
            fftBins = FloatArray(0)
        }
    }

    private fun release() {
        try { visualizer?.enabled = false; visualizer?.release() } catch (_: Exception) {}
        visualizer = null
        fftBins = FloatArray(0)
    }
}
