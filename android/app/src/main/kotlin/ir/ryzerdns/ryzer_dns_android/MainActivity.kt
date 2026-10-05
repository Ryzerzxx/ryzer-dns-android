package ir.ryzerdns.ryzer_dns_android

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ir.ryzerdns/vpn"
    private val VPN_REQUEST_CODE = 2026

    private var pendingResult: MethodChannel.Result? = null
    private var targetPrimaryDns = "87.248.145.40"
    private var targetSecondaryDns = "143.20.60.94"
    private var targetEnableDoh = false
    private var targetDohUrl = "https://ryzerdns.ir/dns-query"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "measureIcmpPing" -> {
                    val host = call.argument<String>("host") ?: "87.248.145.40"
                    Thread {
                        try {
                            val startTime = System.currentTimeMillis()
                            val process = Runtime.getRuntime().exec("ping -c 1 -W 2 $host")
                            val exitVal = process.waitFor()
                            val elapsed = (System.currentTimeMillis() - startTime).toInt()
                            if (exitVal == 0) {
                                runOnUiThread { result.success(elapsed) }
                            } else {
                                runOnUiThread { result.success(-1) }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(-1) }
                        }
                    }.start()
                }
                "startVpn" -> {
                    targetPrimaryDns = call.argument<String>("primary_dns") ?: "87.248.145.40"
                    targetSecondaryDns = call.argument<String>("secondary_dns") ?: "143.20.60.94"
                    targetEnableDoh = call.argument<Boolean>("enable_doh") ?: false
                    targetDohUrl = call.argument<String>("doh_url") ?: "https://ryzerdns.ir/dns-query"
                    
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        pendingResult = result
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        startVpnServiceInternal()
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    val stopIntent = Intent(this, RyzerDnsVpnService::class.java).apply {
                        action = RyzerDnsVpnService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startVpnServiceInternal() {
        val startIntent = Intent(this, RyzerDnsVpnService::class.java).apply {
            action = RyzerDnsVpnService.ACTION_START
            putExtra("primary_dns", targetPrimaryDns)
            putExtra("secondary_dns", targetSecondaryDns)
            putExtra("enable_doh", targetEnableDoh)
            putExtra("doh_url", targetDohUrl)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(startIntent)
        } else {
            startService(startIntent)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                startVpnServiceInternal()
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }
}
