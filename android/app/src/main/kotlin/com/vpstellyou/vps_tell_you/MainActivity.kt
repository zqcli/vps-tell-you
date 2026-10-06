package com.vpstellyou.vps_tell_you

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Protect secret input/reveal and the recent-app preview on Android.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
