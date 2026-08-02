import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/activity_tracking_provider.dart';
import '../services/tracking_app_launcher.dart';
import '../theme/app_theme.dart';

class ActivityTrackingAppsScreen extends StatefulWidget {
  const ActivityTrackingAppsScreen({super.key});

  @override
  State<ActivityTrackingAppsScreen> createState() =>
      _ActivityTrackingAppsScreenState();
}

class _ActivityTrackingAppsScreenState extends State<ActivityTrackingAppsScreen>
    with WidgetsBindingObserver {
  final Map<String, bool> _installedApps = {};
  final Set<String> _appsBeingOpened = {};
  bool _isOpeningHealthConnect = false;
  bool _isLoadingApps = true;
  int? _androidSdkInt;

  static const List<_TrackingAppInfo> _trackingApps = [
    _TrackingAppInfo(
      name: 'Google Health (Fitbit)',
      packageName: 'com.fitbit.FitbitMobile',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF00A9B5),
      descriptionKey: 'tracking_desc_fitbit_health_connect',
    ),
    _TrackingAppInfo(
      name: 'Garmin Connect',
      packageName: 'com.garmin.android.apps.connectmobile',
      icon: Icons.watch_rounded,
      color: Color(0xFF1778B8),
      descriptionKey: 'tracking_desc_garmin_health_connect',
      minAndroidSdk: 34,
    ),
    _TrackingAppInfo(
      name: 'Polar Flow',
      packageName: 'fi.polar.polarflow',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFD71937),
      descriptionKey: 'tracking_desc_polar_health_connect',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadInstalledApps());
      unawaited(_refreshHealthData());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    unawaited(_loadInstalledApps());
    unawaited(_refreshHealthData());
  }

  Future<void> _loadInstalledApps() async {
    final provider = context.read<ActivityTrackingProvider>();
    final androidSdkInt = await provider.getAndroidSdkInt();
    final supportedApps = _trackingApps.where(
      (app) => _isSupportedOnAndroid(app, androidSdkInt),
    );
    final entries = await Future.wait(
      supportedApps.map((app) async {
        final installed =
            await provider.isTrackingAppInstalled(app.packageName);
        return MapEntry(app.packageName, installed);
      }),
    );

    if (!mounted) return;
    setState(() {
      _installedApps
        ..clear()
        ..addEntries(entries);
      _androidSdkInt = androidSdkInt;
      _isLoadingApps = false;
    });
  }

  Future<void> _refreshHealthData({
    bool showFeedback = false,
    bool force = true,
  }) async {
    final provider = context.read<ActivityTrackingProvider>();
    if (provider.isRequestingPermissions) return;

    await provider.loadForDate(DateTime.now(), force: force);
    if (!mounted || !showFeedback) return;

    _showMessage(
      provider.errorMessage == null
          ? _healthSummaryMessage(provider)
          : _syncErrorMessage(),
    );
  }

  Future<void> _configureHealthConnect(
    ActivityTrackingProvider provider,
  ) async {
    final status = await provider.requestPermissionsAndLoad(DateTime.now());
    if (!mounted) return;

    if (status.hasAllPermissions) {
      _showMessage(context.tr.translate('tracking_permission_granted'));
      return;
    }
    if (status.hasAnyPermission) {
      _showMessage(context.tr.translate('tracking_permission_partial'));
      return;
    }
    if (status.needsProviderUpdate || !status.isAvailable) {
      _showMessage(context.tr.translate('tracking_health_update_required'));
      await _openHealthConnect(provider);
      return;
    }

    _showMessage(context.tr.translate('tracking_permission_denied'));
  }

  Future<void> _openHealthConnect(
    ActivityTrackingProvider provider,
  ) async {
    if (_isOpeningHealthConnect) return;

    setState(() {
      _isOpeningHealthConnect = true;
    });

    try {
      final result = await provider.openHealthConnect();
      if (!mounted) return;

      switch (result) {
        case TrackingAppLaunchResult.openedApp:
          break;
        case TrackingAppLaunchResult.openedStore:
          _showMessage(
            context.tr.translate('tracking_health_update_required'),
          );
          break;
        case TrackingAppLaunchResult.unsupported:
          _showMessage(context.tr.translate('tracking_not_available'));
          break;
        case TrackingAppLaunchResult.failed:
          _showMessage(_syncErrorMessage());
          break;
      }
    } catch (_) {
      if (mounted) _showMessage(_syncErrorMessage());
    } finally {
      if (mounted) {
        setState(() => _isOpeningHealthConnect = false);
      }
    }
  }

  Future<void> _handlePrimaryAction(
    ActivityTrackingProvider provider,
  ) async {
    if (provider.isLoading ||
        provider.isRequestingPermissions ||
        _isOpeningHealthConnect) {
      return;
    }

    if (!provider.isHealthConnectAvailable || provider.needsProviderUpdate) {
      await _openHealthConnect(provider);
      return;
    }

    if (!provider.hasAllPermissions) {
      await _configureHealthConnect(provider);
      return;
    }

    await _refreshHealthData(showFeedback: true);
  }

  Future<void> _openTrackingApp(
    _TrackingAppInfo app,
    ActivityTrackingProvider provider,
  ) async {
    if (_appsBeingOpened.isNotEmpty ||
        provider.isLoading ||
        provider.isRequestingPermissions) {
      return;
    }

    setState(() => _appsBeingOpened.add(app.packageName));

    try {
      final installed = _installedApps[app.packageName] ?? false;
      if (installed && !provider.hasAnyPermission) {
        final status = await provider.requestPermissionsAndLoad(DateTime.now());
        if (!mounted) return;
        if (!status.hasAnyPermission) {
          _showMessage(
            context.tr.translate('tracking_permission_needed'),
          );
          return;
        }
      }

      if (!mounted) return;

      final result = await provider.openTrackingApp(app.packageName);
      if (!mounted) return;

      setState(() {
        if (result == TrackingAppLaunchResult.openedStore) {
          _installedApps[app.packageName] = false;
        }
      });

      final key = switch (result) {
        TrackingAppLaunchResult.openedApp => 'tracking_app_opened',
        TrackingAppLaunchResult.openedStore => 'tracking_app_store_opened',
        TrackingAppLaunchResult.unsupported => 'tracking_not_available',
        TrackingAppLaunchResult.failed => 'tracking_app_open_error',
      };
      _showMessage(
        context.tr.translate(key).replaceAll('{app}', app.name),
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          context.tr
              .translate('tracking_app_open_error')
              .replaceAll('{app}', app.name),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _appsBeingOpened.remove(app.packageName));
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: _refreshHealthData,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _buildConnectionCard(
                        theme,
                        isDarkMode,
                        trackingProvider,
                      ),
                      if (trackingProvider.hasAnyPermission) ...[
                        const SizedBox(height: 14),
                        _buildTodaySummary(
                          theme,
                          isDarkMode,
                          trackingProvider,
                        ),
                      ],
                      if (!trackingProvider.isHealthConnectUnsupported) ...[
                        const SizedBox(height: 22),
                        _buildTrackingAppsSection(
                          theme,
                          isDarkMode,
                          trackingProvider,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionCard(
    ThemeData theme,
    bool isDarkMode,
    ActivityTrackingProvider provider,
  ) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(isDarkMode, cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(
                    alpha: isDarkMode ? 0.2 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: isDarkMode
                      ? AppTheme.primaryColorDarkMode
                      : AppTheme.primaryDarkColor,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  context.tr.translate('tracking_health_connect_name'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _buildStatusBanner(theme, isDarkMode, provider),
          if (!provider.isHealthConnectUnsupported) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: provider.isLoading ||
                        provider.isRequestingPermissions ||
                        _isOpeningHealthConnect
                    ? null
                    : () => _handlePrimaryAction(provider),
                icon: _buildPrimaryActionIcon(provider),
                label: Text(
                  _primaryActionLabel(provider),
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: _isOpeningHealthConnect
                    ? null
                    : () => _openHealthConnect(provider),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  context.tr.translate('tracking_open_health_connect'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner(
    ThemeData theme,
    bool isDarkMode,
    ActivityTrackingProvider provider,
  ) {
    final loading = !provider.hasLoadedStatus ||
        provider.isLoading ||
        provider.isRequestingPermissions;
    final Color color;
    final IconData icon;

    if (loading) {
      color = theme.colorScheme.primary;
      icon = Icons.sync_rounded;
    } else if (provider.isHealthConnectUnsupported ||
        !provider.isHealthConnectAvailable ||
        provider.errorMessage != null) {
      color = theme.colorScheme.error;
      icon = Icons.error_outline_rounded;
    } else if (provider.hasAllPermissions) {
      color = const Color(0xFF168B62);
      icon = Icons.check_circle_outline_rounded;
    } else if (provider.hasAnyPermission) {
      color = const Color(0xFFB7791F);
      icon = Icons.warning_amber_rounded;
    } else {
      color = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      icon = Icons.link_off_rounded;
    }

    return Semantics(
      liveRegion: true,
      label: _healthStatusMessage(provider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDarkMode ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, color: color, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _healthStatusMessage(provider),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActionIcon(ActivityTrackingProvider provider) {
    if (provider.isLoading ||
        provider.isRequestingPermissions ||
        _isOpeningHealthConnect) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (!provider.isHealthConnectAvailable || provider.needsProviderUpdate) {
      return const Icon(Icons.system_update_alt_rounded, size: 20);
    }
    if (provider.hasAllPermissions) {
      return const Icon(Icons.sync_rounded, size: 20);
    }
    return const Icon(Icons.link_rounded, size: 20);
  }

  String _primaryActionLabel(ActivityTrackingProvider provider) {
    if (provider.isLoading ||
        provider.isRequestingPermissions ||
        _isOpeningHealthConnect) {
      return context.tr.translate('tracking_syncing');
    }
    if (provider.hasAllPermissions) {
      return context.tr.translate('tracking_refresh');
    }
    return context.tr.translate('configure_health_connect');
  }

  Widget _buildTodaySummary(
    ThemeData theme,
    bool isDarkMode,
    ActivityTrackingProvider provider,
  ) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final syncedAt = provider.errorMessage == null
        ? _formattedSyncTime(provider.summary?.syncedAt)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(isDarkMode, cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.translate('tracking_synced_today'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (syncedAt != null)
                Text(
                  syncedAt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final columns = constraints.maxWidth < 280 ? 2 : 3;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _buildMetric(
                    metricKey: const ValueKey('tracking-metric-calories'),
                    width: width,
                    icon: Icons.local_fire_department_rounded,
                    label: context.tr
                        .translate('tracking_permission_active_calories'),
                    value: _metricValue(
                      provider,
                      canRead:
                          provider.canReadCalories && provider.hasCaloriesData,
                      value: provider.caloriesBurned,
                      suffix: 'kcal',
                    ),
                    color: const Color(0xFFE76F51),
                    isDarkMode: isDarkMode,
                  ),
                  _buildMetric(
                    metricKey: const ValueKey('tracking-metric-steps'),
                    width: width,
                    icon: Icons.directions_walk_rounded,
                    label: context.tr.translate('tracking_permission_steps'),
                    value: _metricValue(
                      provider,
                      canRead: provider.canReadSteps,
                      value: provider.steps,
                    ),
                    color: const Color(0xFF2F80ED),
                    isDarkMode: isDarkMode,
                  ),
                  _buildMetric(
                    metricKey: const ValueKey('tracking-metric-exercises'),
                    width: width,
                    icon: Icons.fitness_center_rounded,
                    label:
                        context.tr.translate('tracking_permission_exercises'),
                    value: _metricValue(
                      provider,
                      canRead: provider.canReadExercise,
                      value: provider.exerciseMinutes,
                      suffix: 'min',
                    ),
                    color: const Color(0xFF8B5CF6),
                    isDarkMode: isDarkMode,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required Key metricKey,
    required double width,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    final foregroundColor =
        isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return Semantics(
      key: metricKey,
      label: '$label: $value',
      child: Container(
        width: width,
        height: 112,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDarkMode ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor.withValues(alpha: 0.72),
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingAppsSection(
    ThemeData theme,
    bool isDarkMode,
    ActivityTrackingProvider provider,
  ) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate('popular_tracking_apps'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ..._trackingApps
            .where(
              (app) => _isSupportedOnAndroid(app, _androidSdkInt),
            )
            .map(
              (app) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTrackingAppTile(
                  app,
                  theme,
                  isDarkMode,
                  provider,
                ),
              ),
            ),
      ],
    );
  }

  bool _isSupportedOnAndroid(_TrackingAppInfo app, int? sdkInt) {
    final minAndroidSdk = app.minAndroidSdk;
    return minAndroidSdk == null || (sdkInt != null && sdkInt >= minAndroidSdk);
  }

  Widget _buildTrackingAppTile(
    _TrackingAppInfo app,
    ThemeData theme,
    bool isDarkMode,
    ActivityTrackingProvider provider,
  ) {
    final installed = _installedApps[app.packageName] ?? false;
    final detected = _hasDataFromApp(app, provider);
    final isOpening = _appsBeingOpened.contains(app.packageName);
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final actionColor = detected
        ? const Color(0xFF168B62)
        : isDarkMode
            ? AppTheme.primaryColorDarkMode
            : AppTheme.primaryDarkColor;
    final statusColor = detected
        ? const Color(0xFF168B62)
        : installed
            ? const Color(0xFF2F80ED)
            : const Color(0xFF64748B);
    final statusKey = detected
        ? 'tracking_source_data_detected'
        : installed
            ? 'tracking_installed'
            : 'tracking_store';
    final actionKey = _isLoadingApps
        ? 'tracking_syncing'
        : !installed
            ? 'tracking_action_install'
            : detected
                ? 'tracking_action_open'
                : 'tracking_action_connect';

    return Semantics(
      button: true,
      label: '${app.name}. ${context.tr.translate(statusKey)}. '
          '${context.tr.translate(actionKey)}',
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: _isLoadingApps ||
                  _appsBeingOpened.isNotEmpty ||
                  provider.isLoading ||
                  provider.isRequestingPermissions
              ? null
              : () => _openTrackingApp(app, provider),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 13, 10, 13),
            decoration: _cardDecoration(isDarkMode, Colors.transparent),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: app.color.withValues(
                      alpha: isDarkMode ? 0.2 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(app.icon, color: app.color, size: 28),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr.translate(app.descriptionKey),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedTextColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(
                                alpha: isDarkMode ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              context.tr.translate(statusKey),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            context.tr.translate(actionKey),
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (isOpening)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: actionColor,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: mutedTextColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasDataFromApp(
    _TrackingAppInfo app,
    ActivityTrackingProvider provider,
  ) {
    final packageName = app.packageName.toLowerCase();
    return provider.summary?.dataOrigins.any(
          (origin) => origin.toLowerCase() == packageName,
        ) ??
        false;
  }

  BoxDecoration _cardDecoration(bool isDarkMode, Color cardColor) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
      ),
    );
  }

  String _healthStatusMessage(ActivityTrackingProvider provider) {
    if (!provider.hasLoadedStatus ||
        provider.isLoading ||
        provider.isRequestingPermissions) {
      return context.tr.translate('tracking_syncing_health_connect');
    }
    if (provider.isHealthConnectUnsupported) {
      return context.tr.translate('tracking_not_available');
    }
    if (!provider.isHealthConnectAvailable || provider.needsProviderUpdate) {
      return context.tr.translate('tracking_health_update_required');
    }
    if (provider.errorMessage != null) return _syncErrorMessage();
    if (provider.hasAllPermissions) {
      return context.tr.translate('tracking_permission_granted');
    }
    if (provider.hasAnyPermission) {
      return context.tr.translate('tracking_permission_partial');
    }
    return context.tr.translate('tracking_permission_needed');
  }

  String _healthSummaryMessage(ActivityTrackingProvider provider) {
    if (provider.isLoading) {
      return context.tr.translate('tracking_syncing_health_connect');
    }
    if (provider.errorMessage != null) return _syncErrorMessage();
    if (!provider.hasActivityData) {
      return context.tr.translate('tracking_no_activity_data');
    }
    return context.tr
        .translate('tracking_activity_synced_message')
        .replaceAll('{steps}', _formatNumber(provider.steps))
        .replaceAll('{minutes}', _formatNumber(provider.exerciseMinutes));
  }

  String _syncErrorMessage() {
    return '${context.tr.translate('error_occurred')}. '
        '${context.tr.translate('try_again_later')}';
  }

  String _metricValue(
    ActivityTrackingProvider provider, {
    required bool canRead,
    required int value,
    String? suffix,
  }) {
    if (!canRead || provider.summary == null || provider.errorMessage != null) {
      return '—';
    }

    final formatted = _formatNumber(value);
    return suffix == null ? formatted : '$formatted $suffix';
  }

  String _formatNumber(int value) {
    return NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(value);
  }

  String? _formattedSyncTime(DateTime? dateTime) {
    if (dateTime == null) return null;
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
}

class _TrackingAppInfo {
  final String name;
  final String packageName;
  final IconData icon;
  final Color color;
  final String descriptionKey;
  final int? minAndroidSdk;

  const _TrackingAppInfo({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.color,
    required this.descriptionKey,
    this.minAndroidSdk,
  });
}
