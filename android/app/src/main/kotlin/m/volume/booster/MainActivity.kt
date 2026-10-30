package m.volume.booster

import android.os.Bundle
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize WebView with comprehensive crash prevention
        try {
            // Enable debugging
            WebView.setWebContentsDebuggingEnabled(true)

            // Create a temporary WebView to initialize the WebView engine
            // This prevents crashes when rendering web content and ads
            val webView = WebView(this)
            webView.settings.javaScriptEnabled = true
            webView.destroy()

            println("✅ WebView initialized successfully")
        } catch (e: Exception) {
            println("❌ WebView initialization error: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up WebView resources
        try {
            System.gc()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
