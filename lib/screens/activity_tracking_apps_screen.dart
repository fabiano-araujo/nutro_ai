import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/activity_tracking_provider.dart';
import '../services/tracking_app_launcher.dart';
import '../theme/app_theme.dart';

class ActivityTrackingAppsScreen extends StatefulWidget {
  const ActivityTrackingAppsScreen({Key? key}) : super(key: key);

  @override
  State<ActivityTrackingAppsScreen> createState() =>
      _ActivityTrackingAppsScreenState();
}

class _ActivityTrackingAppsScreenState
    extends State<ActivityTrackingAppsScreen> {
  final TrackingAppLauncher _launcher = TrackingAppLauncher();
  final Map<String, bool> _installedApps = {};
  bool _isLoadingApps = true;

  static const List<_TrackingAppInfo> _apps = [
    _TrackingAppInfo(
      name: 'Google Fit',
      packageName: 'com.google.android.apps.fitness',
      icon: Icons.favorite_rounded,
      color: Color(0xFF2DAA57),
      descriptionKey: 'tracking_desc_all_day',
    ),
    _TrackingAppInfo(
      name: 'Samsung Health',
      packageName: 'com.sec.android.app.shealth',
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFF1E88E5),
      descriptionKey: 'tracking_desc_all_day',
    ),
    _TrackingAppInfo(
      name: 'Fitbit',
      packageName: 'com.fitbit.FitbitMobile',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF00B0B9),
      descriptionKey: 'tracking_desc_wearables',
    ),
    _TrackingAppInfo(
      name: 'Garmin Connect',
      packageName: 'com.garmin.android.apps.connectmobile',
      icon: Icons.watch_rounded,
      color: Color(0xFF1F2937),
      descriptionKey: 'tracking_desc_wearables',
    ),
    _TrackingAppInfo(
      name: 'Strava',
      packageName: 'com.strava',
      icon: Icons.terrain_rounded,
      color: Color(0xFFFC4C02),
      descriptionKey: 'tracking_desc_running',
    ),
    _TrackingAppInfo(
      name: 'Huawei Health',
      packageName: 'com.huawei.health',
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFFD32F2F),
      descriptionKey: 'tracking_desc_wearables',
    ),
    _TrackingAppInfo(
      name: 'Mi Fitness',
      packageName: 'com.xiaomi.wearable',
      icon: Icons.directions_walk_rounded,
      color: Color(0xFFFF6900),
      descriptionKey: 'tracking_desc_wearables',
    ),
    _TrackingAppInfo(
      name: 'Zepp',
      packageName: 'com.huami.watch.hmwatchmanager',
      icon: Icons.watch_outlined,
      color: Color(0xFF00A878),
      descriptionKey: 'tracking_desc_wearables',
    ),
    _TrackingAppInfo(
      name: 'Polar Flow',
      packageName: 'fi.polar.polarflow',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFB91C1C),
      descriptionKey: 'tracking_desc_running',
    ),
    _TrackingAppInfo(
      name: 'Withings',
      packageName: 'com.withings.wiscale2',
      icon: Icons.monitor_weight_rounded,
      color: Color(0xFF8E949B),
      descriptionKey: 'tracking_desc_body',
    ),
    _TrackingAppInfo(
      name: 'Nike Run Club',
      packageName: 'com.nike.plusgps',
      icon: Icons.directions_run_rounded,
      color: Color(0xFF111111),
      descriptionKey: 'tracking_desc_running',
    ),
    _TrackingAppInfo(
      name: 'adidas Running',
      packageName: 'com.runtastic.android',
      icon: Icons.speed_rounded,
      color: Color(0xFF111827),
      descriptionKey: 'tracking_desc_running',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActivityTrackingProvider>().loadForDate(DateTime.now());
    });
  }

  Future<void> _loadInstalledApps() async {
    final entries = await Future.wait(
      _apps.map((app) async {
        final installed = await _launcher.isAppInstalled(app.packageName);
        return MapEntry(app.packageName, installed);
      }),
    );

    if (!mounted) return;
    setState(() {
      _installedApps
        ..clear()
        ..addEntries(entries);
      _isLoadingApps = false;
    });
  }

  Future<void> _configureHealthConnect(
    ActivityTrackingProvider provider,
  ) async {
    final status = await provider.requestPermissionsAndLoad(DateTime.now());
    if (!mounted) return;

    String message;
    if (status.hasAllPermissions) {
      message = context.tr.translate('tracking_permission_granted');
    } else if (status.hasAnyPermission) {
      message = context.tr.translate('tracking_permission_partial');
    } else if (status.needsProviderUpdate || !status.isAvailable) {
      message = context.tr.translate('tracking_health_update_required');
      await provider.openHealthConnect();
    } else {
      message = context.tr.translate('tracking_permission_denied');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openApp(_TrackingAppInfo app) async {
    final result = await _launcher.openAppOrStore(app.packageName);
    if (!mounted) return;
    _showLaunchFeedback(result, app.name);

    if (result == TrackingAppLaunchResult.openedStore) {
      setState(() {
        _installedApps[app.packageName] = false;
      });
    }
  }

  void _showLaunchFeedback(TrackingAppLaunchResult result, String appName) {
    final key = switch (result) {
      TrackingAppLaunchResult.openedApp => 'tracking_app_opened',
      TrackingAppLaunchResult.openedStore => 'tracking_app_store_opened',
      TrackingAppLaunchResult.unsupported => 'tracking_not_available',
      TrackingAppLaunchResult.failed => 'tracking_app_open_error',
    };

    final message = context.tr.translate(key).replaceAll('{app}', appName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return Consumer<ActivityTrackingProvider>(
      builder: (context, trackingProvider, child) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(
              context.tr.translate('automatic_tracking_apps_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _buildHealthConnectCard(
                    theme,
                    isDarkMode,
                    trackingProvider,
                  ),
                  const SizedBox(height: 22),
                  _buildSectionHeader(theme, textColor),
                  const SizedBox(height: 10),
                  ..._apps.map(
                    (app) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildTrackingAppTile(app, theme, isDarkMode),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthConnectCard(
    ThemeData theme,
    bool isDarkMode,
    ActivityTrackingProvider trackingProvider,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthConnectGraphic(theme, isDarkMode),
          const SizedBox(height: 22),
          Text(
            context.tr.translate('tracking_health_connect_heading'),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontSize: 23,
              height: 1.18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr.translate('tracking_health_connect_body'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: mutedTextColor,
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildSyncedSummary(theme, trackingProvider, isDarkMode),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDataChip(
                Icons.local_fire_department_rounded,
                context.tr.translate('tracking_permission_active_calories'),
                const Color(0xFFFF6B35),
                isDarkMode,
              ),
              _buildDataChip(
                Icons.directions_walk_rounded,
                context.tr.translate('tracking_permission_steps'),
                const Color(0xFF2F80ED),
                isDarkMode,
              ),
              _buildDataChip(
                Icons.fitness_center_rounded,
                context.tr.translate('tracking_permission_exercises'),
                const Color(0xFF8B5CF6),
                isDarkMode,
              ),
              _buildDataChip(
                Icons.monitor_weight_rounded,
                context.tr.translate('tracking_permission_body_measures'),
                const Color(0xFF059669),
                isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: trackingProvider.isRequestingPermissions
                  ? null
                  : () => _configureHealthConnect(trackingProvider),
              icon: trackingProvider.isRequestingPermissions
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ThemeData.estimateBrightnessForColor(primary) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    )
                  : const Icon(Icons.link_rounded, size: 19),
              label: Text(
                trackingProvider.hasAnyPermission
                    ? context.tr.translate('tracking_refresh')
                    : context.tr.translate('configure_health_connect'),
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor:
                    ThemeData.estimateBrightnessForColor(primary) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedSummary(
    ThemeData theme,
    ActivityTrackingProvider trackingProvider,
    bool isDarkMode,
  ) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('tracking_synced_today'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _healthSummaryMessage(trackingProvider),
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedTextColor,
              height: 1.28,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  context.tr.translate('tracking_metric_calories'),
                  trackingProvider.activeCalories.toString(),
                  const Color(0xFFFF6B35),
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryMetric(
                  context.tr.translate('tracking_metric_steps'),
                  trackingProvider.steps.toString(),
                  const Color(0xFF2F80ED),
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryMetric(
                  context.tr.translate('tracking_metric_minutes'),
                  trackingProvider.exerciseMinutes.toString(),
                  const Color(0xFF8B5CF6),
                  isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _healthSummaryMessage(ActivityTrackingProvider provider) {
    if (provider.isLoading) {
      return context.tr.translate('tracking_syncing_health_connect');
    }
    if (!provider.isHealthConnectAvailable || provider.needsProviderUpdate) {
      return context.tr.translate('tracking_health_update_required');
    }
    if (!provider.hasAnyPermission) {
      return context.tr.translate('tracking_permission_needed');
    }
    if (!provider.hasActivityData) {
      return context.tr.translate('tracking_no_activity_data');
    }
    return context.tr
        .translate('tracking_activity_synced_message')
        .replaceAll('{steps}', provider.steps.toString())
        .replaceAll('{minutes}', provider.exerciseMinutes.toString());
  }

  Widget _buildSummaryMetric(
    String label,
    String value,
    Color color,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectGraphic(ThemeData theme, bool isDarkMode) {
    final lineColor = isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1);
    final bridgeColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return SizedBox(
      height: 162,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TrackingBridgePainter(
                color: lineColor,
                accentColor: const Color(0xFF58C76B),
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 28,
            child: _MiniOrbitBadge(
              icon: Icons.grid_view_rounded,
              color: const Color(0xFF00B0B9),
              isDarkMode: isDarkMode,
            ),
          ),
          Positioned(
            left: 44,
            bottom: 22,
            child: _MiniOrbitBadge(
              icon: Icons.terrain_rounded,
              color: const Color(0xFFFC4C02),
              isDarkMode: isDarkMode,
            ),
          ),
          Positioned(
            top: 4,
            left: 134,
            child: _MiniOrbitBadge(
              icon: Icons.favorite_rounded,
              color: const Color(0xFFFF7043),
              isDarkMode: isDarkMode,
            ),
          ),
          Positioned(
            right: 122,
            top: 18,
            child: _MiniOrbitBadge(
              icon: Icons.directions_run_rounded,
              color: const Color(0xFF14B8A6),
              isDarkMode: isDarkMode,
            ),
          ),
          Positioned(
            right: 70,
            bottom: 28,
            child: _MiniOrbitBadge(
              icon: Icons.watch_rounded,
              color: const Color(0xFF374151),
              isDarkMode: isDarkMode,
            ),
          ),
          Positioned(
            left: 104,
            top: 58,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF222833) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.link_rounded,
                color: bridgeColor,
                size: 34,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 46,
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: const Color(0xFF58C76B).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF58C76B),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Color(0xFF58C76B),
                size: 44,
              ),
            ),
          ),
          Positioned(
            right: 128,
            top: 82,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF58C76B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataChip(
    IconData icon,
    String label,
    Color color,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr.translate('popular_tracking_apps'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_isLoadingApps)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildTrackingAppTile(
    _TrackingAppInfo app,
    ThemeData theme,
    bool isDarkMode,
  ) {
    final installed = _installedApps[app.packageName] ?? false;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openApp(app),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: app.color.withValues(alpha: isDarkMode ? 0.24 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(app.icon, color: app.color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr.translate(app.descriptionKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedTextColor,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(installed, isDarkMode),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      installed
                          ? context.tr.translate('tracking_action_open')
                          : context.tr.translate('tracking_action_install'),
                      style: TextStyle(
                        color: isDarkMode ? Colors.black : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool installed, bool isDarkMode) {
    final color = installed ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr.translate(
          installed ? 'tracking_installed' : 'tracking_store',
        ),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrackingAppInfo {
  final String name;
  final String packageName;
  final IconData icon;
  final Color color;
  final String descriptionKey;

  const _TrackingAppInfo({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.color,
    required this.descriptionKey,
  });
}

class _MiniOrbitBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  const _MiniOrbitBadge({
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF222833) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _TrackingBridgePainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  const _TrackingBridgePainter({
    required this.color,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dottedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final linkCenter = Offset(size.width * 0.34, size.height * 0.55);
    final sources = [
      Offset(size.width * 0.09, size.height * 0.31),
      Offset(size.width * 0.14, size.height * 0.79),
      Offset(size.width * 0.42, size.height * 0.18),
      Offset(size.width * 0.64, size.height * 0.28),
      Offset(size.width * 0.67, size.height * 0.76),
    ];

    for (final source in sources) {
      final path = Path()
        ..moveTo(source.dx, source.dy)
        ..quadraticBezierTo(
          (source.dx + linkCenter.dx) / 2,
          source.dy - 22,
          linkCenter.dx,
          linkCenter.dy,
        );
      _drawDashedPath(canvas, path, dottedPaint);
    }

    final bridgePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final bridgePath = Path()
      ..moveTo(size.width * 0.44, size.height * 0.62)
      ..cubicTo(
        size.width * 0.55,
        size.height * 0.75,
        size.width * 0.73,
        size.height * 0.72,
        size.width * 0.83,
        size.height * 0.57,
      );
    canvas.drawPath(bridgePath, bridgePaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dashLength = 7.0;
      const gapLength = 7.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, math.min(next, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrackingBridgePainter oldDelegate) {
    return color != oldDelegate.color || accentColor != oldDelegate.accentColor;
  }
}
