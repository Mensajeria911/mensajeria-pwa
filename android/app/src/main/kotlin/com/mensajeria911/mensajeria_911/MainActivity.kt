package com.mensajeria911.mensajeria_911

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var phoneResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mensajeros911/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method != "requestPhone") {
                    result.notImplemented()
                } else if (checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else {
                    phoneResult = result
                    requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), PHONE_REQUEST)
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PHONE_REQUEST) {
            phoneResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            phoneResult = null
        }
    }

    private companion object {
        const val PHONE_REQUEST = 9110
    }
}
