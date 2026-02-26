package com.example.offline_survival_companion

import android.content.Intent
import android.provider.Settings
import android.bluetooth.BluetoothAdapter
import android.net.wifi.WifiManager
import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.offline_survival_companion/hardware"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothOn" -> {
                    try {
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        result.success(adapter?.isEnabled == true)
                    } catch(e: Exception) {
                        result.success(false)
                    }
                }
                "turnOnBluetooth" -> {
                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    startActivityForResult(enableBtIntent, 1001)
                    result.success(null)
                }
                "isWifiOn" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        result.success(wifiManager.isWifiEnabled)
                    } catch(e: Exception) {
                        result.success(false)
                    }
                }
                "openWifiSettings" -> {
                    val intent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        Intent(Settings.Panel.ACTION_WIFI)
                    } else {
                        Intent(Settings.ACTION_WIFI_SETTINGS)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
