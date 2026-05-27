package br.com.snapdark.apps.nutreai

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val trackingAppsChannel = "br.com.snapdark.apps.nutro_ia/tracking_apps"
    private val healthPermissionRequestCode = 8317
    private val healthPermissionContract =
        PermissionController.createRequestPermissionResultContract()
    private val healthScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingHealthPermissionResult: MethodChannel.Result? = null

    private val healthPermissions: Set<String> by lazy {
        setOf(
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(WeightRecord::class),
            HealthPermission.getReadPermission(BodyFatRecord::class)
        )
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
                    if (packageName.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        result.success(isPackageInstalled(packageName))
                    }
                }
                "openAppOrStore" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.success("failed")
                    } else {
                        result.success(openAppOrStore(packageName))
                    }
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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)

        // Desregistrar a fábrica quando não for mais necessária
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "customNativeAd")
        healthScope.cancel()
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

        return if (openPlayStore(packageName)) {
            "opened_store"
        } else {
            "failed"
        }
    }

    private fun openHealthConnect(): String {
        val sdkStatus = HealthConnectClient.getSdkStatus(this)
        val permissionIntent = Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
            .putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (startExternalActivity(permissionIntent)) {
            return "opened_app"
        }

        val settingsIntents = listOf(
            Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            Intent("android.settings.HEALTH_CONNECT_SETTINGS")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )

        for (intent in settingsIntents) {
            if (startExternalActivity(intent)) {
                return "opened_app"
            }
        }

        if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
            if (openHealthConnectStore()) {
                return "opened_store"
            }
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
        var totalCalories: Double? = null
        var steps: Long? = null
        var exerciseCount = 0
        var exerciseMinutes = 0L
        var weightKg: Double? = null
        var bodyFatPercentage: Double? = null

        val metrics = mutableSetOf<androidx.health.connect.client.aggregate.AggregateMetric<*>>()
        if (granted.contains(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))) {
            metrics.add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
        }
        if (granted.contains(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))) {
            metrics.add(TotalCaloriesBurnedRecord.ENERGY_TOTAL)
        }
        if (granted.contains(HealthPermission.getReadPermission(StepsRecord::class))) {
            metrics.add(StepsRecord.COUNT_TOTAL)
        }
        if (granted.contains(HealthPermission.getReadPermission(WeightRecord::class))) {
            metrics.add(WeightRecord.WEIGHT_AVG)
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
            totalCalories = aggregate[TotalCaloriesBurnedRecord.ENERGY_TOTAL]
                ?.inKilocalories
            steps = aggregate[StepsRecord.COUNT_TOTAL]
            weightKg = aggregate[WeightRecord.WEIGHT_AVG]?.inKilograms
            dataOrigins.addAll(aggregate.dataOrigins.map { it.packageName })
        }

        if (granted.contains(HealthPermission.getReadPermission(ExerciseSessionRecord::class))) {
            val response = client.readRecords(
                ReadRecordsRequest<ExerciseSessionRecord>(
                    timeRangeFilter = timeRangeFilter,
                    ascendingOrder = true,
                    pageSize = 200
                )
            )
            exerciseCount = response.records.size
            exerciseMinutes = response.records.sumOf { record ->
                val clippedStart = if (record.startTime.isBefore(start)) {
                    start
                } else {
                    record.startTime
                }
                val clippedEnd = if (record.endTime.isAfter(end)) {
                    end
                } else {
                    record.endTime
                }
                if (clippedEnd.isAfter(clippedStart)) {
                    Duration.between(clippedStart, clippedEnd).toMinutes()
                } else {
                    0L
                }
            }
            dataOrigins.addAll(response.records.map { it.metadata.dataOrigin.packageName })
        }

        if (granted.contains(HealthPermission.getReadPermission(BodyFatRecord::class))) {
            val historyStart = end.minus(Duration.ofDays(30))
            val response = client.readRecords(
                ReadRecordsRequest<BodyFatRecord>(
                    timeRangeFilter = TimeRangeFilter.between(historyStart, end),
                    ascendingOrder = false,
                    pageSize = 1
                )
            )
            val latestBodyFat = response.records.firstOrNull()
            bodyFatPercentage = latestBodyFat?.percentage?.value
            latestBodyFat?.metadata?.dataOrigin?.packageName?.let { dataOrigins.add(it) }
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
            "totalCalories" to totalCalories,
            "steps" to steps,
            "exerciseCount" to exerciseCount,
            "exerciseMinutes" to exerciseMinutes,
            "weightKg" to weightKg,
            "bodyFatPercentage" to bodyFatPercentage,
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
            "totalCalories" to null,
            "steps" to null,
            "exerciseCount" to 0,
            "exerciseMinutes" to 0,
            "weightKg" to null,
            "bodyFatPercentage" to null,
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
}
