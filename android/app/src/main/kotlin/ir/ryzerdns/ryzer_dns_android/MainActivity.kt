package ir.ryzerdns.ryzer_dns_android

import android.app.Activity
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.annotation.NonNull
import com.android.vending.billing.IInAppBillingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ir.ryzerdns/vpn"
    private val MYKET_CHANNEL = "ir.ryzerdns/myket_billing"
    private val VPN_REQUEST_CODE = 2026
    private val MYKET_PURCHASE_REQUEST_CODE = 2027

    private var pendingResult: MethodChannel.Result? = null
    private var pendingMyketResult: MethodChannel.Result? = null
    private var targetPrimaryDns = "87.248.145.40"
    private var targetSecondaryDns = "46.8.102.223"

    @Volatile
    private var mBillingService: IInAppBillingService? = null
    @Volatile
    private var isBillingBound = false
    private var connectionLatch = CountDownLatch(1)

    private val mServiceConn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            try {
                mBillingService = IInAppBillingService.Stub.asInterface(service)
                isBillingBound = true
                connectionLatch.countDown()
            } catch (e: Exception) {
                // Ignore
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            mBillingService = null
            isBillingBound = false
            connectionLatch = CountDownLatch(1)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Proactively bind Myket Billing Service on app startup
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

                    Thread {
                        // If not yet bound, bind and wait up to 3.5 seconds
                        if (mBillingService == null) {
                            bindMyketService()
                            try {
                                connectionLatch.await(3500, TimeUnit.MILLISECONDS)
                            } catch (e: Exception) {
                                // proceed
                            }
                        }

                        val service = mBillingService
                        if (service == null) {
                            runOnUiThread {
                                result.error("MYKET_NOT_CONNECTED", "سرویس پرداخت مایکت در دسترس نیست. لطفاً از نصب و به‌روز بودن برنامه مایکت اطمینان حاصل فرمایید.", null)
                            }
                            return@Thread
                        }

                        try {
                            // Check if billing is supported
                            val supported = service.isBillingSupported(3, packageName, "inapp")
                            if (supported != 0) {
                                runOnUiThread {
                                    result.error("NOT_SUPPORTED", "پرداخت درون‌برنامه‌ای در این نسخه از مایکت پشتیبانی نمی‌شود.", null)
                                }
                                return@Thread
                            }

                            val buyIntentBundle = service.getBuyIntent(3, packageName, sku, "inapp", payload)
                            val responseCode = buyIntentBundle?.getInt("RESPONSE_CODE") ?: -1

                            if (responseCode == 0) {
                                val pendingIntent: PendingIntent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    buyIntentBundle?.getParcelable("BUY_INTENT", PendingIntent::class.java)
                                } else {
                                    @Suppress("DEPRECATION")
                                    buyIntentBundle?.getParcelable("BUY_INTENT")
                                }

                                if (pendingIntent != null) {
                                    runOnUiThread {
                                        pendingMyketResult = result
                                        try {
                                            startIntentSenderForResult(
                                                pendingIntent.intentSender,
                                                MYKET_PURCHASE_REQUEST_CODE,
                                                Intent(),
                                                0,
                                                0,
                                                0
                                            )
                                        } catch (e: Exception) {
                                            pendingMyketResult = null
                                            result.error("FLOW_FAILED", "خطا در باز کردن درگاه پرداخت مایکت: ${e.message}", null)
                                        }
                                    }
                                } else {
                                    runOnUiThread {
                                        result.error("FLOW_FAILED", "درگاه پرداخت از سوی مایکت دریافت نشد.", null)
                                    }
                                }
                            } else if (responseCode == 7) {
                                // Item already owned (BILLING_RESPONSE_RESULT_ITEM_ALREADY_OWNED)
                                try {
                                    val purchases = service.getPurchases(3, packageName, "inapp", null)
                                    val tokens = purchases?.getStringArrayList("INAPP_PURCHASE_TOKEN_LIST")
                                    if (tokens != null) {
                                        for (tok in tokens) {
                                            service.consumePurchase(3, packageName, tok)
                                        }
                                    }
                                } catch (e: Exception) {}
                                runOnUiThread {
                                    result.error("ALREADY_OWNED", "اشتراک قبلی فعال‌سازی شد. لطفاً مجدداً دکمه پرداخت را لمس کنید.", null)
                                }
                            } else {
                                runOnUiThread {
                                    result.error("FLOW_FAILED", "خطای مایکت (کد $responseCode)", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("FLOW_FAILED", e.message ?: "خطا در ارتباط با مایکت", null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bindMyketService() {
        if (!isBillingBound) {
            try {
                connectionLatch = CountDownLatch(1)
                val serviceIntent = Intent("ir.mservices.market.InAppBillingService.BIND").apply {
                    setPackage("ir.mservices.market")
                }
                val bound = bindService(serviceIntent, mServiceConn, Context.BIND_AUTO_CREATE)
                if (!bound) {
                    serviceIntent.component = ComponentName("ir.mservices.market", "ir.mservices.market.InAppBillingService")
                    bindService(serviceIntent, mServiceConn, Context.BIND_AUTO_CREATE)
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    private fun startVpnServiceInternal() {
        val startIntent = Intent(this, RyzerDnsVpnService::class.java).apply {
            action = RyzerDnsVpnService.ACTION_START
            putExtra("primary_dns", targetPrimaryDns)
            putExtra("secondary_dns", targetSecondaryDns)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(startIntent)
        } else {
            startService(startIntent)
        }
    }

    override fun onDestroy() {
        if (isBillingBound) {
            try {
                unbindService(mServiceConn)
            } catch (e: Exception) {}
            isBillingBound = false
        }
        super.onDestroy()
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
        } else if (requestCode == MYKET_PURCHASE_REQUEST_CODE) {
            val resCallback = pendingMyketResult
            pendingMyketResult = null

            if (resultCode == Activity.RESULT_OK && data != null) {
                val purchaseData = data.getStringExtra("INAPP_PURCHASE_DATA")
                val dataSignature = data.getStringExtra("INAPP_DATA_SIGNATURE")
                if (purchaseData != null) {
                    try {
                        val jsonObj = JSONObject(purchaseData)
                        val purchaseToken = jsonObj.optString("purchaseToken", "")
                        val orderId = jsonObj.optString("orderId", "")
                        val productId = jsonObj.optString("productId", "")

                        // Consume purchase in background thread so it can be re-purchased in future
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
                        resCallback?.success(resultMap)
                    } catch (e: Exception) {
                        resCallback?.error("PARSING_ERROR", "خطا در پردازش اطلاعات پرداخت مایکت", null)
                    }
                } else {
                    resCallback?.error("EMPTY_DATA", "اطلاعات خرید دریافت نشد.", null)
                }
            } else {
                resCallback?.error("USER_CANCELED", "پرداخت توسط کاربر لغو شد.", null)
            }
        }
    }
}
