package com.cmandili.partner

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Partner App
 *
 * Bridges the native notification tap (built by CmandiliMessagingService when
 * the app is killed) into Dart so the app can deep-link to the tapped order.
 *
 * When the app is terminated, the alarm notification is built natively and its
 * tap PendingIntent launches THIS activity with `order_id` / `notification_type`
 * extras. FirebaseMessaging.getInitialMessage() is NULL on this path (no FCM
 * message object is reconstructed), so Dart must read these intent extras over
 * the MethodChannel below instead.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.cmandili.partner/notifications"
    }

    private var channel: MethodChannel? = null

    // Holds the order_id from the launch intent until Dart asks for it via
    // getInitialNotification(). Consumed once so a hot restart doesn't re-navigate.
    private var pendingOrderId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingOrderId = orderIdFrom(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Cold-start path: Dart calls this after the engine is ready to
                // see if the app was launched by tapping an order notification.
                "getInitialNotification" -> {
                    result.success(pendingOrderId)
                    pendingOrderId = null // consume — only deep-link once
                }
                // Which phone this is, so the app can tell the owner how to keep
                // it alive in the background (see BackgroundGuide in Dart).
                "getManufacturer" -> result.success(android.os.Build.MANUFACTURER ?: "")
                // Opens the maker's "autostart / background" screen for this
                // phone, or the app's own settings page when there is none.
                "openBackgroundSettings" -> result.success(openBackgroundSettings())
                else -> result.notImplemented()
            }
        }
    }

    // Warm path: app already running in background, user taps the notification.
    // Android delivers the tap via onNewIntent (singleTop launch mode), so push
    // the order_id straight to Dart instead of stashing it for a cold start.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val orderId = orderIdFrom(intent)
        if (orderId != null) {
            channel?.invokeMethod("onNotificationTap", orderId)
        }
    }

    private fun orderIdFrom(intent: Intent?): String? {
        if (intent?.getStringExtra("notification_type") != "new_order") return null
        val orderId = intent.getStringExtra("order_id")
        return if (orderId.isNullOrBlank()) null else orderId
    }
    /**
     * Xiaomi, Oppo, Vivo, Huawei, Tecno... add their own switch on top of
     * Android's: unless "Autostart" is on for an app, the phone kills its
     * services once it is closed and never wakes it for a push -- which is
     * exactly when an order alarm has to ring. There is no API to turn that
     * switch on, only to open the screen where the owner can.
     *
     * Each maker hides it under a different activity, and they move between
     * versions, so the known ones are tried in turn. Returns "autostart" when
     * one opened, "app_details" when only the standard app page could be
     * shown, "none" when even that failed.
     */
    private fun openBackgroundSettings(): String {
        val screens = listOf(
            // Xiaomi / Redmi / POCO (MIUI, HyperOS)
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            // Oppo / Realme / OnePlus (ColorOS)
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oplus.safecenter" to "com.oplus.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            // Vivo / iQOO
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            // Huawei / Honor
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            // Tecno / Infinix / itel (Transsion)
            "com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity",
            // Samsung
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
        )
        for ((pkg, cls) in screens) {
            try {
                startActivity(
                    Intent()
                        .setComponent(android.content.ComponentName(pkg, cls))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return "autostart"
            } catch (_: Exception) {
                // Not this maker, or the screen moved: try the next one.
            }
        }
        return try {
            startActivity(
                Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(android.net.Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            "app_details"
        } catch (_: Exception) {
            "none"
        }
    }
}
