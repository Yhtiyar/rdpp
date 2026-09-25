package com.example.readapp

import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var essentialsDialog: AlertDialog? = null

    override fun onPause() {
        // A parent-authenticated native picker must not survive app backgrounding.
        essentialsDialog?.cancel()
        essentialsDialog = null
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val store = ProtectionStore(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "littlewins/screen_time")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(store.status())
                        "authorize" -> {
                            store.preferences.edit().putBoolean("enabled", true).apply()
                            when {
                                !store.hasUsageAccess() -> startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:$packageName")))
                                !store.hasAccessibility() -> startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            }
                            result.success(store.status())
                        }
                        "configureEssentials" -> {
                            val russian = call.argument<String>("locale") == "ru"
                            val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                            val apps = packageManager.queryIntentActivities(launcherIntent, 0)
                                .filter { it.activityInfo.packageName != packageName }
                                .distinctBy { it.activityInfo.packageName }
                                .sortedBy { it.loadLabel(packageManager).toString().lowercase() }
                            val chosen = store.preferences.getStringSet("essentials", emptySet())!!.toMutableSet()
                            val labels = apps.map { it.loadLabel(packageManager).toString() }.toTypedArray()
                            val checked = apps.map { it.activityInfo.packageName in chosen }.toBooleanArray()
                            essentialsDialog?.cancel()
                            essentialsDialog = AlertDialog.Builder(this)
                                .setTitle(if (russian) "Всегда доступные приложения" else "Always-available apps")
                                .setMultiChoiceItems(labels, checked) { _, index, selected ->
                                    val app = apps[index].activityInfo.packageName
                                    if (selected) chosen.add(app) else chosen.remove(app)
                                }
                                .setPositiveButton(if (russian) "Сохранить" else "Save") { _, _ ->
                                    essentialsDialog = null
                                    if (store.preferences.edit().putStringSet("essentials", chosen).commit()) result.success(store.status())
                                    else result.error("storage", "Could not save essentials", null)
                                }
                                .setNegativeButton(if (russian) "Отмена" else "Cancel") { _, _ -> essentialsDialog = null; result.success(store.status()) }
                                .setOnCancelListener { essentialsDialog = null; result.success(store.status()) }
                                .show()
                        }
                        "unlock" -> {
                            val minutes = call.argument<Int>("minutes") ?: 0
                            val id = call.argument<String>("transactionId") ?: error("Missing transaction ID")
                            result.success(mapOf("endsAt" to store.unlock(minutes, id)))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("screen_time", error.message, null)
                }
            }
    }
}
