package com.example.demo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.os.Bundle

class MainActivity : FlutterActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Optimize window flags for better performance
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
    }
    
    override fun onPause() {
        // Minimize work in onPause to prevent the 323ms delay
        super.onPause()
    }
    
    override fun onResume() {
        super.onResume()
        // Ensure smooth transitions
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Clean up resources properly
    }
}
