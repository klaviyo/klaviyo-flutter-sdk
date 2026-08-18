package com.klaviyo.flutterexample

import io.flutter.embedding.android.FlutterActivity

// No manual push-open handling is needed here — the Klaviyo Flutter plugin tracks notification
// opens automatically via Flutter's Activity lifecycle hooks. See README.md's Android Setup
// section for the com.klaviyo.push.automatic_push_open_tracking opt-out.
class MainActivity : FlutterActivity()
