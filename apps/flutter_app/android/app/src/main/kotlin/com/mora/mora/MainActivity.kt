package com.mora.mora

import com.mora.mora.camera.MoraCameraPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the native camera plugin alongside Flutter's generated
        // plugin list. Kept in-app (not a separate package) since this is
        // the only consumer.
        MoraCameraPlugin().register(flutterEngine)
    }
}
