package ir.ryzerdns.ryzer_dns_android

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.Bundle
import android.os.IBinder
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.mservices.market.InAppBillingService
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ir.ryzerdns/vpn"
    private val MYKET_CHANNEL = "ir.ryzerdns/myket_billing"
    private val VPN_REQUEST_CODE = 2026
    private var pendingResult: MethodChannel.Result? = null
    private var targetPrimaryDns = "87.248.145.40"
    private var targetSecondaryDns = "46.8.102.223"

    private val MYKET_RSA_KEY = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCSFZFMD07zzp9eOG95m3Swifaa9unu21AJqjNVKKc/EuGHa7OWlCymw4ngTIQI4gYN3Je7UNavxl7bM+yUJrQpELAQvvUdEoLjR6Prja3Lk9BMvibgbYEGRHiM9avLSt3kRSIruJntUh3/CeNL9DhL/pZzwxeOURv92zmqenoQMwIDAQAB"

    private var mBillingService: InAppBillingService? = null
    private var isBillingBound = false

    private val mServiceConn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            mBillingService = InAppBillingService.Stub.asInterface(service)
            isBillingBound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            mBillingService = null
            isBillingBound = false
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bindMyketService()

        // 1. VPN Channel
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
                    targetSecondaryDns = call.argument<String>("secondary_dns") ?: "46.8.102.223"
                    
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

        // 2. Myket In-App Billing Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MYKET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "purchaseSku" -> {
                    val sku = call.argument<String>("sku") ?: ""
                    val payload = call.argument<String>("payload") ?: ""
                    
                    if (mBillingService == null) {
                        bindMyketService()
                        result.error("MYKET_NOT_CONNECTED", "سرویس پرداخت مایکت در حال اتصال است، مجدداً تلاش کنید.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val buyIntentBundle = mBillingService?.getBuyIntent(3, packageName, sku, "inapp", payload)
                        val responseCode = buyIntentBundle?.getInt("RESPONSE_CODE") ?: -1
                        if (responseCode == 0) {
                            val pendingIntent = buyIntentBundle?.getParcelable<android.app.PendingIntent>("BUY_INTENT")
                            if (pendingIntent != null) {
                                pendingMyketResult = result
                                startIntentSenderForResult(pendingIntent.intentSender, 2027, Intent(), 0, 0, 0)
                            } else {
                                result.error("FLOW_FAILED", "خطا در دریافت درگاه مایکت", null)
                            }
                        } else {
                            result.error("FLOW_FAILED", "خطای ارتباط با مایکت: کد $responseCode", null)
                        }
                    } catch (e: Exception) {
                        result.error("FLOW_FAILED", e.message ?: "خطا در فرآیند خرید مایکت", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private var pendingMyketResult: MethodChannel.Result? = null

    private fun bindMyketService() {
        if (!isBillingBound) {
            val serviceIntent = Intent("ir.mservices.market.InAppBillingService.BIND").apply {
                `package` = "ir.mservices.market"
            }
            try {
                bindService(serviceIntent, mServiceConn, Context.BIND_AUTO_CREATE)
            } catch (e: Exception) {
                // ignore
            }
        }
    }

    private fun startVpnServiceInternal() {
        val startIntent = Intent(this, RyzerDnsVpnService::class.java).apply {
            action = RyzerDnsVpnService.ACTION_START
            putExtra("primary_dns", targetPrimaryDns)
            putExtra("secondary_dns", targetSecondaryDns)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(startIntent)
        } else {
            startService(startIntent)
        }
    }

    override fun onDestroy() {
        if (isBillingBound) {
            unbindService(mServiceConn)
            isBillingBound = false
        }
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                startVpnServiceInternal()
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        } else if (requestCode == 2027) {
            if (resultCode == RESULT_OK && data != null) {
                val purchaseData = data.getStringExtra("INAPP_PURCHASE_DATA")
                val dataSignature = data.getStringExtra("INAPP_DATA_SIGNATURE")
                if (purchaseData != null) {
                    try {
                        val jsonObj = JSONObject(purchaseData)
                        val purchaseToken = jsonObj.optString("purchaseToken", "")
                        val orderId = jsonObj.optString("orderId", "")
                        val productId = jsonObj.optString("productId", "")
                        
                        // Consume purchase in background thread so it can be bought again
                        Thread {
                            try {
                                mBillingService?.consumePurchase(3, packageName, purchaseToken)
                            } catch (e: Exception) {}
                        }.start()

                        val resultMap = mapOf(
                            "status" to "success",
                            "orderId" to orderId,
                            "purchaseToken" to purchaseToken,
                            "productId" to productId,
                            "signature" to (dataSignature ?: "")
                        )
                        pendingMyketResult?.success(resultMap)
                    } catch (e: Exception) {
                        pendingMyketResult?.error("PARSING_ERROR", "خطا در خواندن نتیجه خرید", null)
                    }
                } else {
                    pendingMyketResult?.error("EMPTY_DATA", "داده‌های خرید دریافت نشد.", null)
                }
            } else {
                pendingMyketResult?.error("USER_CANCELED", "پرداخت توسط کاربر لغو شد.", null)
            }
            pendingMyketResult = null
        }
    }
}
