package ir.ryzerdns.ryzer_dns_android

import android.content.Intent
import android.net.VpnService
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.cafebazaar.poolakey.Connection
import ir.cafebazaar.poolakey.ConnectionState
import ir.cafebazaar.poolakey.Payment
import ir.cafebazaar.poolakey.config.PaymentConfiguration
import ir.cafebazaar.poolakey.config.SecurityCheck
import ir.cafebazaar.poolakey.request.PurchaseRequest

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "ir.ryzerdns/vpn"
    private val BAZAAR_CHANNEL = "ir.ryzerdns/bazaar_billing"
    private val VPN_REQUEST_CODE = 2026
    private var pendingResult: MethodChannel.Result? = null
    private var targetPrimaryDns = "87.248.145.40"
    private var targetSecondaryDns = "46.8.102.223"

    private val BAZAAR_RSA_KEY = "MIHNMA0GCSqGSIb3DQEBAQUAA4G7ADCBtwKBrwDaqDiT9Ig0Q8MZwYGbI/fMzX6aHkryDl1fw65Xw8LTt0L0J/5w7fvuKs77c2sHZMOcHa0qMP2Xt6KsbajPSQ1lqtFPY6iwSl6XFwGOl31ErOILqvK3Bh0Hb3I7dqfbzucMuo9X6PtGJ8BIbn/5M84dPJve2hETHeXriDF1glL1+lCbl08QJglp5G3whVVLFUQxVJpcqzc2eFX3y/EypD2REK6h64nrov8/6DowvmECAwEAAQ=="

    private val paymentConfig by lazy {
        PaymentConfiguration(
            localSecurityCheck = SecurityCheck.Enable(rsaPublicKey = BAZAAR_RSA_KEY)
        )
    }

    private val payment by lazy(LazyThreadSafetyMode.NONE) {
        Payment(context = this, config = paymentConfig)
    }

    private var paymentConnection: Connection? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // 2. Cafe Bazaar In-App Billing Channel (Poolakey)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BAZAAR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectBazaar" -> {
                    paymentConnection = payment.connect {
                        connectionSucceed {
                            result.success(true)
                        }
                        connectionFailed {
                            result.success(false)
                        }
                        disconnected {
                            // disconnected callback
                        }
                    }
                }
                "purchaseSku" -> {
                    val sku = call.argument<String>("sku") ?: ""
                    val payload = call.argument<String>("payload") ?: ""

                    if (paymentConnection?.getState() != ConnectionState.Connected) {
                        // Attempt reconnect
                        paymentConnection = payment.connect {
                            connectionSucceed {
                                launchPurchaseFlow(sku, payload, result)
                            }
                            connectionFailed {
                                result.error("BAZAAR_NOT_CONNECTED", "عدم اتصال به سرویس پرداخت کافه‌بازار", null)
                            }
                        }
                    } else {
                        launchPurchaseFlow(sku, payload, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchPurchaseFlow(sku: String, payload: String, result: MethodChannel.Result) {
        payment.purchaseProduct(
            registry = activityResultRegistry,
            request = PurchaseRequest(
                productId = sku,
                payload = payload
            )
        ) {
            purchaseFlowBegan {
                // Flow started
            }
            failedToBeginFlow { throwable ->
                result.error("FLOW_FAILED", throwable.message ?: "خطا در شروع پرداخت", null)
            }
            purchaseSucceed { purchaseEntity ->
                val resultMap = mapOf(
                    "status" to "success",
                    "orderId" to purchaseEntity.orderId,
                    "purchaseToken" to purchaseEntity.purchaseToken,
                    "payload" to purchaseEntity.payload,
                    "packageName" to purchaseEntity.packageName,
                    "purchaseTime" to purchaseEntity.purchaseTime,
                    "productId" to purchaseEntity.productId
                )
                result.success(resultMap)
            }
            purchaseCanceled {
                result.error("USER_CANCELED", "پرداخت توسط کاربر لغو شد.", null)
            }
            purchaseFailed { throwable ->
                result.error("PURCHASE_FAILED", throwable.message ?: "پرداخت با خطا مواجه شد.", null)
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
        paymentConnection?.disconnect()
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
        }
    }
}
