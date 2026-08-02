package br.com.snapdark.apps.nutreai

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).toInt()

        val scrollView = ScrollView(this).apply {
            setBackgroundColor(0xFFFFFFFF.toInt())
        }
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.START
            setPadding(dp(24), dp(36), dp(24), dp(36))
        }

        val title = TextView(this).apply {
            text = getString(R.string.health_permissions_privacy_title)
            textSize = 24f
            setTextColor(0xFF1F2937.toInt())
        }

        val body = TextView(this).apply {
            text = getString(R.string.health_permissions_privacy_body)
            textSize = 16f
            setTextColor(0xFF4B5563.toInt())
            setPadding(0, dp(16), 0, 0)
            setLineSpacing(dp(4).toFloat(), 1.0f)
        }

        container.addView(
            title,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
        container.addView(
            body,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        scrollView.addView(container)
        setContentView(scrollView)
    }
}
