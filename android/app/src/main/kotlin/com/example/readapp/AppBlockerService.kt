package com.example.readapp

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Receives app-window changes only; never retrieves or transmits screen content. */
class AppBlockerService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var store: ProtectionStore
    private var foreground: String? = null
    private var lastUsageCheck = System.currentTimeMillis() - 60_000L
    private var shield: View? = null
    private val tick = object : Runnable {
        override fun run() { refreshForeground(); enforce(); handler.postDelayed(this, 500) }
    }

    override fun onServiceConnected() {
        store = ProtectionStore(this)
        handler.post(tick)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || !::store.isInitialized) return
        // Accessibility tells us when to check, but transient keyboard/notification
        // windows must not replace the application beneath them.
        refreshForeground()
        enforce()
    }

    private fun refreshForeground() {
        if (!::store.isInitialized || !store.hasUsageAccess()) return
        val now = System.currentTimeMillis()
        if (now < lastUsageCheck) lastUsageCheck = now - 60_000L
        val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val events = manager.queryEvents(lastUsageCheck, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // ACTIVITY_RESUMED has the same value as MOVE_TO_FOREGROUND (API 21+).
            // IMEs and the notification shade do not resume an Activity.
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                val app = event.packageName ?: continue
                if (app != "com.android.systemui") foreground = app
            }
        }
        lastUsageCheck = now
    }

    private fun enforce() {
        if (!::store.isInitialized) return
        val app = foreground ?: return
        if (!store.shouldBlock(app)) { removeShield(); return }
        if (shield != null) return
        val purple = Color.rgb(119, 60, 255)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(50, 50, 50, 50); setBackgroundColor(Color.rgb(249, 245, 255))
        }
        val brand = TextView(this).apply {
            text = "littlewins"; textSize = 30f; setTextColor(purple)
            typeface = Typeface.create("sans-serif-rounded", Typeface.BOLD); gravity = Gravity.CENTER
        }
        val title = TextView(this).apply {
            text = getString(R.string.reading_first); textSize = 27f
            setTextColor(Color.rgb(33, 9, 79)); gravity = Gravity.CENTER; setPadding(0, 40, 0, 24)
        }
        val body = TextView(this).apply {
            text = getString(R.string.earn_time); textSize = 18f; gravity = Gravity.CENTER
            setTextColor(Color.rgb(121, 106, 159)); setPadding(0, 0, 0, 40)
        }
        val read = Button(this).apply {
            text = getString(R.string.open_reading)
            setOnClickListener {
                foreground = packageName
                removeShield()
                startActivity(Intent(this@AppBlockerService, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP))
            }
        }
        layout.addView(brand); layout.addView(title); layout.addView(body); layout.addView(read)
        val params = WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE)
        shield = layout
        try { (getSystemService(WINDOW_SERVICE) as WindowManager).addView(layout, params) }
        catch (_: Exception) { shield = null; performGlobalAction(GLOBAL_ACTION_HOME) }
    }

    private fun removeShield() {
        shield?.let { view ->
            try { (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(view) } catch (_: Exception) { }
        }
        shield = null
    }
    override fun onInterrupt() { removeShield() }
    override fun onDestroy() { handler.removeCallbacks(tick); removeShield(); super.onDestroy() }
}
