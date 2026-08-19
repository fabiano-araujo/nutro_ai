package br.com.snapdark.apps.nutreai

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val trackingAppsChannel = "br.com.snapdark.apps.nutro_ia/tracking_apps"
    private val rateAppChannel = "br.com.snapdark.apps.nutro_ia/rate_app"
    private val streakWidgetChannelName = "br.com.snapdark.apps.nutro_ia/streak_widget"
    private val healthPermissionRequestCode = 8317
    private val healthPermissionContract =
        PermissionController.createRequestPermissionResultContract()
    private val healthScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingHealthPermissionResult: MethodChannel.Result? = null
    private var streakWidgetChannel: MethodChannel? = null
    private var pendingOpenStreak = false
    private var openStreakDispatchGeneration = 0L

    private val healthPermissions: Set<String> by lazy {
        setOf(
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingOpenStreak =
            savedInstanceState?.getBoolean(pendingOpenStreakStateKey, false) == true ||
                isOpenStreakIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registrar a fábrica de anúncios nativos personalizada
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "customNativeAd",
            CustomNativeAdFactory(context)
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            trackingAppsChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    result.success(
                        !packageName.isNullOrBlank() && isPackageInstalled(packageName)
                    )
                }
                "getAndroidSdkInt" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                "openAppOrStore" -> {
                    val packageName = call.argument<String>("packageName")
                    result.success(
                        if (packageName.isNullOrBlank()) {
                            "failed"
                        } else {
                            openAppOrStore(packageName)
                        }
                    )
                }
                "openHealthConnect" -> {
                    result.success(openHealthConnect())
                }
                "getHealthConnectStatus" -> {
                    getHealthConnectStatus(result)
                }
                "requestHealthPermissions" -> {
                    requestHealthPermissions(result)
                }
                "readHealthSummary" -> {
                    val startMillis = call.argument<Number>("startMillis")?.toLong()
                    val endMillis = call.argument<Number>("endMillis")?.toLong()
                    if (startMillis == null || endMillis == null) {
                        result.error(
                            "invalid_args",
                            "startMillis and endMillis are required",
                            null
                        )
                    } else {
                        readHealthSummary(startMillis, endMillis, result)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            rateAppChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openGooglePlayListing" -> {
                    result.success(openPlayStore(packageName))
                }
                else -> result.notImplemented()
            }
        }

        streakWidgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            streakWidgetChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val calories = call.argument<Number>("calories")?.toInt()
                        val calorieGoal = call.argument<Number>("calorieGoal")?.toInt()
                        val streak = call.argument<Number>("streak")?.toInt()
                        val date = call.argument<String>("date")?.trim()

                        if (calories == null || calorieGoal == null ||
                            streak == null || date.isNullOrEmpty()
                        ) {
                            result.error(
                                "invalid_widget_snapshot",
                                "calories, calorieGoal, streak and date are required",
                                null
                            )
                        } else {
                            NutritionStreakWidgetProvider.persistSnapshotAndUpdate(
                                applicationContext,
                                calories = calories.coerceAtLeast(0),
                                calorieGoal = calorieGoal.coerceAtLeast(0),
                                streak = streak.coerceAtLeast(0),
                                date = date
                            )
                            result.success(true)
                        }
                    }
                    "isPinSupported" -> {
                        result.success(
                            AppWidgetManager.getInstance(this)
                                .isRequestPinAppWidgetSupported
                        )
                    }
                    "isWidgetAdded" -> {
                        result.success(
                            NutritionStreakWidgetProvider.isWidgetAdded(this)
                        )
                    }
                    "requestPin" -> {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        if (NutritionStreakWidgetProvider.isWidgetAdded(this)) {
                            result.success("already_added")
                        } else if (!appWidgetManager.isRequestPinAppWidgetSupported) {
                            result.success("unsupported")
                        } else {
                            try {
                                val provider = ComponentName(
                                    this,
                                    NutritionStreakWidgetProvider::class.java
                                )
                                val requested =
                                    appWidgetManager.requestPinAppWidget(
                                        provider,
                                        null,
                                        null
                                    )
                                result.success(if (requested) "requested" else "failed")
                            } catch (error: IllegalStateException) {
                                result.error(
                                    "widget_pin_unavailable",
                                    error.message ?: "Widget pin request requires a foreground activity",
                                    null
                                )
                            }
                        }
                    }
                    "consumeOpenStreak" -> {
                        val shouldOpen = pendingOpenStreak || isOpenStreakIntent(intent)
                        pendingOpenStreak = false
                        openStreakDispatchGeneration++
                        clearOpenStreakIntent()
                        result.success(shouldOpen)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        dispatchPendingOpenStreak()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isOpenStreakIntent(intent)) {
            pendingOpenStreak = true
            dispatchPendingOpenStreak()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean(
            pendingOpenStreakStateKey,
            pendingOpenStreak || isOpenStreakIntent(intent)
        )
        super.onSaveInstanceState(outState)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)

        // Desregistrar a fábrica quando não for mais necessária
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "customNativeAd")
        streakWidgetChannel?.setMethodCallHandler(null)
        streakWidgetChannel = null
        openStreakDispatchGeneration++
        healthScope.cancel()
    }

    private fun dispatchPendingOpenStreak() {
        if (!pendingOpenStreak) return
        val channel = streakWidgetChannel ?: return
        val dispatchGeneration = ++openStreakDispatchGeneration

        channel.invokeMethod("openStreak", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (dispatchGeneration != openStreakDispatchGeneration) return
                pendingOpenStreak = false
                clearOpenStreakIntent()
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                // Keep the request pending so Dart can recover it with consumeOpenStreak.
            }

            override fun notImplemented() {
                // Dart may still be starting during a cold launch. Keep it pending.
            }
        })
    }

    private fun isOpenStreakIntent(candidate: Intent?): Boolean {
        return candidate?.action == NutritionStreakWidgetProvider.ACTION_OPEN_STREAK
    }

    private fun clearOpenStreakIntent() {
        if (isOpenStreakIntent(intent)) {
            intent?.action = null
            intent?.removeExtra(AppWidgetManager.EXTRA_APPWIDGET_ID)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == healthPermissionRequestCode) {
            val pendingResult = pendingHealthPermissionResult
            pendingHealthPermissionResult = null

            if (pendingResult != null) {
                healthScope.launch {
                    try {
                        val contractGranted =
                            healthPermissionContract.parseResult(resultCode, data)
                        val status = withContext(Dispatchers.IO) {
                            buildHealthConnectStatus(contractGranted)
                        }
                        pendingResult.success(status)
                    } catch (e: Exception) {
                        pendingResult.error(
                            "health_permission_error",
                            e.message ?: "Unable to request Health Connect permissions",
                            null
                        )
                    }
                }
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == healthPermissionRequestCode) {
            val pendingResult = pendingHealthPermissionResult
            pendingHealthPermissionResult = null

            if (pendingResult != null) {
                healthScope.launch {
                    try {
                        val status = withContext(Dispatchers.IO) {
                            buildHealthConnectStatus()
                        }
                        pendingResult.success(status)
                    } catch (e: Exception) {
                        pendingResult.error(
                            "health_permission_error",
                            e.message ?: "Unable to request Health Connect permissions",
                            null
                        )
                    }
                }
                return
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun openAppOrStore(packageName: String): String {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null && startExternalActivity(launchIntent)) {
            return "opened_app"
        }

        return if (openPlayStore(packageName)) "opened_store" else "failed"
    }

    private fun openHealthConnect(): String {
        val sdkStatus = HealthConnectClient.getSdkStatus(this)

        if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE) {
            return "unsupported"
        }

        if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
            return if (openHealthConnectStore()) "opened_store" else "failed"
        }

        val permissionIntent = Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
            .putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (startExternalActivity(permissionIntent)) {
            return "opened_app"
        }

        val settingsIntent = Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (startExternalActivity(settingsIntent)) {
            return "opened_app"
        }

        val healthConnectPackage = "com.google.android.apps.healthdata"
        val healthConnectIntent =
            packageManager.getLaunchIntentForPackage(healthConnectPackage)
        if (healthConnectIntent != null && startExternalActivity(healthConnectIntent)) {
            return "opened_app"
        }

        return if (openPlayStore(healthConnectPackage)) {
            "opened_store"
        } else {
            "failed"
        }
    }

    private fun getHealthConnectStatus(result: MethodChannel.Result) {
        healthScope.launch {
            try {
                val status = withContext(Dispatchers.IO) {
                    buildHealthConnectStatus()
                }
                result.success(status)
            } catch (e: Exception) {
                result.error(
                    "health_status_error",
                    e.message ?: "Unable to read Health Connect status",
                    null
                )
            }
        }
    }

    private fun requestHealthPermissions(result: MethodChannel.Result) {
        if (pendingHealthPermissionResult != null) {
            result.error(
                "health_permission_pending",
                "A Health Connect permission request is already pending",
                null
            )
            return
        }

        pendingHealthPermissionResult = result
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                requestPermissions(
                    healthPermissions.toTypedArray(),
                    healthPermissionRequestCode
                )
            } else {
                val intent = healthPermissionContract.createIntent(this, healthPermissions)
                startActivityForResult(intent, healthPermissionRequestCode)
            }
        } catch (e: Exception) {
            pendingHealthPermissionResult = null
            result.error(
                "health_permission_error",
                e.message ?: "Unable to open Health Connect permissions",
                null
            )
        }
    }

    private fun readHealthSummary(
        startMillis: Long,
        endMillis: Long,
        result: MethodChannel.Result
    ) {
        healthScope.launch {
            try {
                val summary = withContext(Dispatchers.IO) {
                    buildHealthSummary(startMillis, endMillis)
                }
                result.success(summary)
            } catch (e: SecurityException) {
                result.success(
                    buildBaseHealthSummary(
                        startMillis,
                        endMillis,
                        status = "missing_permissions",
                        errorMessage = e.message
                    )
                )
            } catch (e: Exception) {
                result.success(
                    buildBaseHealthSummary(
                        startMillis,
                        endMillis,
                        status = "error",
                        errorMessage = e.message
                    )
                )
            }
        }
    }

    private suspend fun buildHealthConnectStatus(
        contractGrantedPermissions: Set<String>? = null
    ): Map<String, Any?> {
        val sdkStatus = HealthConnectClient.getSdkStatus(this)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            return buildUnavailableHealthStatus(sdkStatus)
        }

        val client = HealthConnectClient.getOrCreate(this)
        val grantedPermissions = client.permissionController.getGrantedPermissions()
        val granted = if (contractGrantedPermissions == null) {
            grantedPermissions
        } else {
            grantedPermissions + contractGrantedPermissions
        }
        val missing = healthPermissions - granted

        return mapOf(
            "sdkStatus" to sdkStatusName(sdkStatus),
            "isAvailable" to true,
            "hasAllPermissions" to missing.isEmpty(),
            "hasAnyPermission" to granted.any { it in healthPermissions },
            "grantedPermissions" to granted.toList(),
            "missingPermissions" to missing.toList()
        )
    }

    private fun buildUnavailableHealthStatus(sdkStatus: Int): Map<String, Any?> {
        return mapOf(
            "sdkStatus" to sdkStatusName(sdkStatus),
            "isAvailable" to false,
            "hasAllPermissions" to false,
            "hasAnyPermission" to false,
            "grantedPermissions" to emptyList<String>(),
            "missingPermissions" to healthPermissions.toList()
        )
    }

    private suspend fun buildHealthSummary(
        startMillis: Long,
        endMillis: Long
    ): Map<String, Any?> {
        val sdkStatus = HealthConnectClient.getSdkStatus(this)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            return buildBaseHealthSummary(
                startMillis,
                endMillis,
                status = sdkStatusName(sdkStatus)
            )
        }

        val client = HealthConnectClient.getOrCreate(this)
        val granted = client.permissionController.getGrantedPermissions()
        val start = Instant.ofEpochMilli(startMillis)
        val end = Instant.ofEpochMilli(endMillis)
        val timeRangeFilter = TimeRangeFilter.between(start, end)
        val dataOrigins = mutableSetOf<String>()

        var activeCalories: Double? = null
        var steps: Long? = null
        var exerciseMinutes = 0L

        val metrics = mutableSetOf<androidx.health.connect.client.aggregate.AggregateMetric<*>>()
        if (granted.contains(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))) {
            metrics.add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
        }
        if (granted.contains(HealthPermission.getReadPermission(StepsRecord::class))) {
            metrics.add(StepsRecord.COUNT_TOTAL)
        }
        if (granted.contains(HealthPermission.getReadPermission(ExerciseSessionRecord::class))) {
            metrics.add(ExerciseSessionRecord.EXERCISE_DURATION_TOTAL)
        }

        if (metrics.isNotEmpty()) {
            val aggregate = client.aggregate(
                AggregateRequest(
                    metrics = metrics,
                    timeRangeFilter = timeRangeFilter
                )
            )
            activeCalories = aggregate[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]
                ?.inKilocalories
            steps = aggregate[StepsRecord.COUNT_TOTAL]
            exerciseMinutes = aggregate[ExerciseSessionRecord.EXERCISE_DURATION_TOTAL]
                ?.toMinutes() ?: 0L
            dataOrigins.addAll(aggregate.dataOrigins.map { it.packageName })
        }

        val missing = healthPermissions - granted

        return mapOf(
            "status" to "ok",
            "sdkStatus" to sdkStatusName(sdkStatus),
            "hasAllPermissions" to missing.isEmpty(),
            "hasAnyPermission" to granted.any { it in healthPermissions },
            "missingPermissions" to missing.toList(),
            "startMillis" to startMillis,
            "endMillis" to endMillis,
            "syncedAtMillis" to System.currentTimeMillis(),
            "activeCalories" to activeCalories,
            "steps" to steps,
            "exerciseMinutes" to exerciseMinutes,
            "dataOrigins" to dataOrigins.toList().sorted()
        )
    }

    private fun buildBaseHealthSummary(
        startMillis: Long,
        endMillis: Long,
        status: String,
        errorMessage: String? = null
    ): Map<String, Any?> {
        return mapOf(
            "status" to status,
            "sdkStatus" to status,
            "hasAllPermissions" to false,
            "hasAnyPermission" to false,
            "missingPermissions" to healthPermissions.toList(),
            "startMillis" to startMillis,
            "endMillis" to endMillis,
            "syncedAtMillis" to System.currentTimeMillis(),
            "activeCalories" to null,
            "steps" to null,
            "exerciseMinutes" to 0,
            "dataOrigins" to emptyList<String>(),
            "errorMessage" to errorMessage
        )
    }

    private fun sdkStatusName(sdkStatus: Int): String {
        return when (sdkStatus) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED ->
                "provider_update_required"
            HealthConnectClient.SDK_UNAVAILABLE -> "unavailable"
            else -> "unknown"
        }
    }

    private fun openPlayStore(packageName: String): Boolean {
        val marketIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$packageName")
        )
            .setPackage("com.android.vending")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (startExternalActivity(marketIntent)) {
            return true
        }

        val webIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        return startExternalActivity(webIntent)
    }

    private fun openHealthConnectStore(): Boolean {
        val healthConnectPackage = "com.google.android.apps.healthdata"
        val marketIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse(
                "market://details?id=$healthConnectPackage&url=healthconnect%3A%2F%2Fonboarding"
            )
        )
            .setPackage("com.android.vending")
            .putExtra("overlay", true)
            .putExtra("callerId", packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (startExternalActivity(marketIntent)) {
            return true
        }

        return openPlayStore(healthConnectPackage)
    }

    private fun startExternalActivity(intent: Intent): Boolean {
        val safeIntent = intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            val activity = safeIntent.resolveActivity(packageManager)
            if (activity == null) {
                false
            } else {
                startActivity(safeIntent)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        const val pendingOpenStreakStateKey = "pending_open_streak"
    }
}
