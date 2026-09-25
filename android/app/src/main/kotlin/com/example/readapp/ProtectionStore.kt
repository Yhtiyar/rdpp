package com.example.readapp

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import java.util.Calendar

/** Native, process-independent enforcement state. Expiration uses monotonic time. */
class ProtectionStore(private val context: Context) {
    val preferences = context.getSharedPreferences("littlewins_protection", Context.MODE_PRIVATE)

    fun hasUsageAccess(): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED
    }

    fun hasAccessibility(): Boolean {
        val component = ComponentName(context, AppBlockerService::class.java).flattenToString()
        return Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?.split(':')?.any { it.equals(component, ignoreCase = true) } == true
    }

    private fun bootCount(): Int = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)

    fun isUnlocked(): Boolean {
        // Fail closed after reboot. Changing the wall clock cannot extend a window.
        if (preferences.getInt("boot", -2) != bootCount()) return false
        return preferences.getLong("elapsedExpiry", 0) > SystemClock.elapsedRealtime()
    }

    fun unlock(minutes: Int, transactionId: String): Long {
        check(hasUsageAccess() && hasAccessibility()) { "Required permissions are missing" }
        require(minutes in listOf(15, 30, 45)) { "Unsupported duration" }
        if (preferences.getString("transactionId", null) == transactionId) {
            return preferences.getLong("endsAt", 0)
        }
        check(!isUnlocked()) { "An access window is already active" }
        val endsAt = System.currentTimeMillis() + minutes * 60_000L
        val persisted = preferences.edit()
            .putLong("endsAt", endsAt)
            .putLong("elapsedExpiry", SystemClock.elapsedRealtime() + minutes * 60_000L)
            .putInt("boot", bootCount())
            .putString("transactionId", transactionId)
            .putBoolean("enabled", true)
            .commit()
        if (!persisted) {
            // commit() updates process memory even when its disk write fails.
            // Remove the active window before surfacing an error to Flutter.
            preferences.edit().remove("endsAt").remove("elapsedExpiry")
                .remove("boot").remove("transactionId").commit()
            error("Could not persist the native time window")
        }
        return endsAt
    }

    fun essentialPackages(): Set<String> {
        val essentials = preferences.getStringSet("essentials", emptySet())!!.toMutableSet()
        essentials += context.packageName
        essentials += setOf("com.android.systemui", "com.android.settings", "com.android.phone", "com.android.server.telecom", "com.android.emergency")
        for (intent in listOf(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            Intent(Intent.ACTION_DIAL), Intent(Settings.ACTION_SETTINGS)
        )) {
            context.packageManager.resolveActivity(intent, 0)?.activityInfo?.packageName?.let { essentials += it }
        }
        // The active keyboard must always work, including PIN and emergency entry.
        Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            ?.substringBefore('/')?.let { essentials += it }
        return essentials
    }

    fun shouldBlock(packageName: String): Boolean =
        preferences.getBoolean("enabled", false) && hasUsageAccess() && !isUnlocked() && packageName !in essentialPackages()

    fun status(): Map<String, Any?> {
        val authorized = preferences.getBoolean("enabled", false) && hasUsageAccess() && hasAccessibility()
        val midnight = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val usage = if (hasUsageAccess()) {
            val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            manager.queryAndAggregateUsageStats(midnight, System.currentTimeMillis()).values
                .filter { it.packageName !in essentialPackages() }.sumOf { it.totalTimeInForeground } / 60_000L
        } else 0L
        return mapOf("supported" to true, "authorized" to authorized,
            "essentialsCount" to (preferences.getStringSet("essentials", emptySet())?.size ?: 0),
            "endsAt" to preferences.getLong("endsAt", 0),
            "transactionId" to preferences.getString("transactionId", null),
            "usageMinutes" to usage.toInt())
    }
}
