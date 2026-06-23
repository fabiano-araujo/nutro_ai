import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/credit_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/profile_shape_preview_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reward_ad_dialog.dart';

class ProfileShapePreviewScreen extends StatefulWidget {
  final VoidCallback? onOpenSocialHub;

  const ProfileShapePreviewScreen({
    super.key,
    this.onOpenSocialHub,
  });

  @override
  State<ProfileShapePreviewScreen> createState() =>
      _ProfileShapePreviewScreenState();
}

class _ProfileShapePreviewScreenState extends State<ProfileShapePreviewScreen> {
  static const String _exampleImageAsset =
      'assets/images/profile_shape_example.png';

  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _sourceImageBytes;
  String? _generatedImageUrl;
  bool _isPicking = false;
  bool _isGenerating = false;
  bool _isApplying = false;
  bool _isPostingToSocial = false;
  bool _showInfoChip = false;
  ProfileShapePreviewProvider? _shapeProvider;

  @override
  void initState() {
    super.initState();
    _loadLastGeneratedPreview();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<ProfileShapePreviewProvider>();
    if (_shapeProvider == provider) return;

    _shapeProvider?.removeListener(_handleShapeProviderChanged);
    _shapeProvider = provider;
    provider.addListener(_handleShapeProviderChanged);
    _handleShapeProviderChanged();
  }

  @override
  void dispose() {
    _shapeProvider?.removeListener(_handleShapeProviderChanged);
    super.dispose();
  }

  void _handleShapeProviderChanged() {
    final provider = _shapeProvider;
    if (!mounted || provider == null) return;

    final credits = provider.takePendingCredits();
    if (credits != null) {
      unawaited(context.read<CreditProvider>().applyServerCredits(credits));
    }

    final nextImageUrl = provider.generatedImageUrl ?? _generatedImageUrl;
    final nextIsGenerating = provider.isGenerating;
    if (nextImageUrl != null && _sourceImageBytes == null) {
      unawaited(_loadStoredSourceImage());
    }

    if (_generatedImageUrl == nextImageUrl &&
        _isGenerating == nextIsGenerating) {
      return;
    }

    setState(() {
      _generatedImageUrl = nextImageUrl;
      _isGenerating = nextIsGenerating;
    });
  }

  Future<void> _loadLastGeneratedPreview() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final providerUrl =
        context.read<ProfileShapePreviewProvider>().generatedImageUrl;
    final lastUrl = providerUrl ??
        prefs.getString(ProfileShapePreviewProvider.storageKey(userId));
    final sourceBytes = _decodeStoredSourceImage(
      prefs.getString(_sourceImageStorageKey(userId)),
    );
    if (!mounted) return;

    final hasGeneratedUrl = lastUrl != null && lastUrl.trim().isNotEmpty;
    if (!hasGeneratedUrl && sourceBytes == null) return;

    setState(() {
      if (hasGeneratedUrl) {
        _generatedImageUrl = lastUrl;
      }
      _sourceImageBytes ??= sourceBytes;
    });
  }

  Future<void> _loadStoredSourceImage() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null || _sourceImageBytes != null) return;

    final prefs = await SharedPreferences.getInstance();
    final sourceBytes = _decodeStoredSourceImage(
      prefs.getString(_sourceImageStorageKey(userId)),
    );
    if (!mounted || sourceBytes == null || _sourceImageBytes != null) return;

    setState(() {
      _sourceImageBytes = sourceBytes;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking || _isGenerating) return;

    setState(() {
      _isPicking = true;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _sourceImageBytes = bytes;
        _generatedImageUrl = null;
      });
      await _persistSourceImage(bytes, clearGeneratedPreview: true);
    } catch (e) {
      _showSnackBar(context.tr.translate('profile_shape_select_image_error'));
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _generatePreview() async {
    if (!_hasPremiumAccess()) {
      await _openSubscriptionScreen();
      return;
    }

    final imageBytes = _sourceImageBytes;
    final authService = context.read<AuthService>();
    final token = authService.token;
    final userId = authService.currentUser?.id;

    if (imageBytes == null ||
        token == null ||
        token.isEmpty ||
        userId == null) {
      _showSnackBar(context.tr.translate('profile_shape_no_image_selected'));
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      await _persistSourceImage(imageBytes);
      final data =
          await context.read<ProfileShapePreviewProvider>().startGeneration(
                userId: userId,
                token: token,
                imageBytes: imageBytes,
                languageCode: _currentLocaleCode(),
              );
      if (data == null) {
        final error = context.read<ProfileShapePreviewProvider>().error;
        throw Exception(
          error ?? context.tr.translate('profile_shape_generation_error'),
        );
      }
      final imageUrl = data['imageUrl']?.toString();
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        throw Exception(context.tr.translate('profile_shape_generation_error'));
      }

      if (!mounted) return;

      setState(() {
        _sourceImageBytes = imageBytes;
        _generatedImageUrl = imageUrl;
      });
      _showSnackBar(context.tr.translate('profile_shape_generate_success'));
    } catch (e) {
      if (!mounted) return;

      final message = _friendlyError(e);
      _showSnackBar(message);

      if (message.toLowerCase().contains('crédit')) {
        await context.read<CreditProvider>().markCreditsExhausted();
        if (mounted) {
          RewardAdDialog.show(
            context,
            onRewardEarned: _refreshCreditsAfterReward,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _applyAsProfilePhoto() async {
    final imageUrl = _generatedImageUrl;
    final authService = context.read<AuthService>();
    final token = authService.token;

    if (imageUrl == null || token == null || token.isEmpty) return;

    setState(() {
      _isApplying = true;
    });

    try {
      final updatedUser = await ApiService.updateOwnProfilePhoto(
        token: token,
        photo: imageUrl,
      );
      await authService.updateUserLocally(updatedUser);
      if (!mounted) return;

      _showSnackBar(context.tr.translate('profile_shape_apply_success'));
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(context.tr.translate('profile_shape_apply_error'));
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  Future<void> _showSocialShareOptions() async {
    if (_isPostingToSocial || _generatedImageUrl == null) return;

    final canPostComparison = _sourceImageBytes != null;
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final primary =
            isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
        final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
        final titleColor =
            isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
        final bodyColor = isDarkMode
            ? Colors.white.withValues(alpha: 0.68)
            : AppTheme.textSecondaryColor;

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr.translate('profile_shape_share_title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr.translate('profile_shape_share_body'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyColor,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  enabled: canPostComparison,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.compare_rounded, color: primary),
                  title: Text(
                    context.tr.translate('profile_shape_share_comparison'),
                  ),
                  subtitle: canPostComparison
                      ? null
                      : Text(
                          context.tr.translate(
                            'profile_shape_share_comparison_unavailable',
                          ),
                        ),
                  onTap: canPostComparison
                      ? () => Navigator.of(context).pop('comparison')
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.image_rounded, color: primary),
                  title: Text(
                    context.tr.translate('profile_shape_share_after_only'),
                  ),
                  onTap: () => Navigator.of(context).pop('after_only'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || mode == null) return;
    await _postToSocial(mode);
  }

  Future<void> _postToSocial(String mode) async {
    final imageUrl = _generatedImageUrl;
    final token = context.read<AuthService>().token;
    if (imageUrl == null || token == null || token.isEmpty) return;

    setState(() {
      _isPostingToSocial = true;
    });

    try {
      final beforeImageBase64 =
          mode == 'comparison' && _sourceImageBytes != null
              ? 'data:image/jpeg;base64,${base64Encode(_sourceImageBytes!)}'
              : null;

      final ok = await context.read<FeedProvider>().publishProfileShapePreview(
            afterImageUrl: imageUrl,
            beforeImageBase64: beforeImageBase64,
            mode: mode,
          );

      if (!mounted) return;
      if (!ok) {
        _showSnackBar(context.tr.translate('profile_shape_share_error'));
        return;
      }

      _showSnackBar(context.tr.translate('profile_shape_share_success'));
      Navigator.of(context).maybePop();
      widget.onOpenSocialHub?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isPostingToSocial = false;
        });
      }
    }
  }

  void _refreshCreditsAfterReward() {
    final authService = context.read<AuthService>();
    final token = authService.token;
    final userId = authService.currentUser?.id;
    if (token == null || userId == null) return;

    context.read<CreditProvider>().refreshCreditsFromServer(
          token: token,
          userId: userId,
        );
  }

  String _currentLocaleCode() {
    final locale = Localizations.localeOf(context);
    final countryCode = locale.countryCode;
    if (countryCode == null || countryCode.isEmpty) {
      return locale.languageCode;
    }
    return '${locale.languageCode}-$countryCode';
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lowerRaw = raw.toLowerCase();
    if (raw.isEmpty) {
      return context.tr.translate('profile_shape_generation_error');
    }
    if (raw.contains('504') ||
        lowerRaw.contains('timeout') ||
        lowerRaw.contains('demorou')) {
      return context.tr.translate('profile_shape_timeout_error');
    }
    if (lowerRaw.contains('formatexception') ||
        lowerRaw.contains('unexpected character')) {
      return context.tr.translate('profile_shape_generation_error');
    }
    return raw;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _sourceImageStorageKey(int userId) =>
      'profile_shape_source_image_user_$userId';

  Future<void> _persistSourceImage(
    Uint8List bytes, {
    bool clearGeneratedPreview = false,
  }) async {
    final authService = context.read<AuthService>();
    final shapeProvider = clearGeneratedPreview
        ? context.read<ProfileShapePreviewProvider>()
        : null;
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _sourceImageStorageKey(userId), base64Encode(bytes));
      if (clearGeneratedPreview) {
        await prefs.remove(ProfileShapePreviewProvider.storageKey(userId));
        await shapeProvider?.clearGeneratedPreview(userId: userId);
      }
    } catch (e) {
      debugPrint('Erro ao salvar foto original do shape: $e');
    }
  }

  Uint8List? _decodeStoredSourceImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final commaIndex = raw.indexOf(',');
      final payload = commaIndex >= 0 ? raw.substring(commaIndex + 1) : raw;
      return base64Decode(payload);
    } catch (e) {
      debugPrint('Erro ao carregar foto original do shape: $e');
      return null;
    }
  }

  void _toggleHowItWorks() {
    setState(() {
      _showInfoChip = !_showInfoChip;
    });
  }

  bool _hasPremiumAccess() {
    final purchaseService = context.read<PurchaseService>();
    final authService = context.read<AuthService>();
    return purchaseService.isPremium ||
        (authService.currentUser?.subscription.isPremium ?? false);
  }

  Future<void> _openSubscriptionScreen() async {
    await Navigator.of(context).pushNamed('/subscription');
  }

  Future<void> _showImageSourcePicker() async {
    if (_isPicking || _isGenerating) return;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primary =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final titleColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr.translate('profile_shape_source_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.photo_camera_outlined, color: primary),
                  title: Text(context.tr.translate('profile_shape_take_photo')),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.photo_library_outlined, color: primary),
                  title: Text(
                      context.tr.translate('profile_shape_choose_gallery')),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || source == null) return;
    await _pickImage(source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final primary =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final background =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        title: Text(
          context.tr.translate('profile_shape_preview_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton(
              onPressed: _toggleHowItWorks,
              icon: Icon(
                Icons.help_outline_rounded,
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              ),
              tooltip: context.tr.translate('profile_shape_help'),
            ),
          ),
        ],
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        children: [
          _buildPageSubtitle(theme, isDarkMode),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _showInfoChip
                ? Padding(
                    key: const ValueKey('profile-shape-info-chip'),
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildInfoChip(theme, primary, isDarkMode),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _buildTransformationPreviewCard(primary, isDarkMode),
          const SizedBox(height: 20),
          if (_sourceImageBytes == null)
            _buildUploadCard(theme, primary, cardColor, isDarkMode)
          else ...[
            _buildSelectedPhotoCard(
              theme,
              colorScheme,
              primary,
              cardColor,
              isDarkMode,
            ),
            const SizedBox(height: 12),
            _buildGenerateButton(primary),
          ],
          if (_isGenerating) ...[
            const SizedBox(height: 16),
            _buildGenerationStatusCard(
              theme,
              primary,
              cardColor,
              isDarkMode,
            ),
          ],
          if (_generatedImageUrl != null) ...[
            const SizedBox(height: 18),
            _buildGeneratedResultCard(
              theme,
              colorScheme,
              primary,
              cardColor,
              isDarkMode,
            ),
          ],
          const SizedBox(height: 18),
          _buildFeatureStrip(theme, primary, cardColor, isDarkMode),
          const SizedBox(height: 18),
          _buildSecureFooter(theme, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildPageSubtitle(ThemeData theme, bool isDarkMode) {
    final color = isDarkMode
        ? Colors.white.withValues(alpha: 0.72)
        : AppTheme.textSecondaryColor;

    return Text(
      context.tr.translate('profile_shape_preview_subtitle'),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, Color primary, bool isDarkMode) {
    final textColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.82)
        : AppTheme.textPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDarkMode ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primary.withValues(alpha: isDarkMode ? 0.24 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr.translate('profile_shape_help_message'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransformationPreviewCard(Color primary, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDarkMode ? 0.16 : 0.2),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1.42,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _exampleImageAsset,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.06),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.42),
                    ],
                    stops: const [0, 0.54, 1],
                  ),
                ),
              ),
              Positioned(
                bottom: 64,
                left: 16,
                child: _buildHeroBadge(
                  context.tr.translate('profile_shape_before'),
                  Colors.black.withValues(alpha: 0.72),
                  Colors.white,
                ),
              ),
              Positioned(
                bottom: 64,
                right: 16,
                child: _buildHeroBadge(
                  context.tr.translate('profile_shape_after'),
                  primary,
                  Colors.white,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 2,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 22,
                        color: Color(0xFF172033),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: Color(0xFF172033),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 18,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.tr
                                .translate('profile_shape_projection_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _buildFeatureStrip(
    ThemeData theme,
    Color primary,
    Color cardColor,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: _cardDecoration(
        cardColor: cardColor,
        isDarkMode: isDarkMode,
        radius: 22,
        blur: 18,
      ),
      child: Column(
        children: [
          _buildFeatureItem(
            theme,
            primary,
            Icons.shield_outlined,
            context.tr.translate('profile_shape_privacy_title'),
            context.tr.translate('profile_shape_privacy_body'),
            isDarkMode,
          ),
          _buildFeatureDivider(isDarkMode),
          _buildFeatureItem(
            theme,
            primary,
            Icons.schedule_rounded,
            context.tr.translate('profile_shape_detail_title'),
            context.tr.translate('profile_shape_detail_body'),
            isDarkMode,
          ),
          _buildFeatureDivider(isDarkMode),
          _buildFeatureItem(
            theme,
            primary,
            Icons.trending_up_rounded,
            context.tr.translate('profile_shape_science_title'),
            context.tr.translate('profile_shape_science_body'),
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme,
    Color primary,
    IconData icon,
    String title,
    String body,
    bool isDarkMode,
  ) {
    final titleColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final bodyColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.62)
        : AppTheme.textSecondaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: isDarkMode ? 0.14 : 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                maxLines: 2,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: bodyColor,
                  fontSize: 11,
                  height: 1.18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
      ),
    );
  }

  Widget _buildUploadCard(
    ThemeData theme,
    Color primary,
    Color cardColor,
    bool isDarkMode,
  ) {
    final titleColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final bodyColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.68)
        : AppTheme.textSecondaryColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        cardColor: cardColor,
        isDarkMode: isDarkMode,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDarkMode ? 0.16 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('profile_shape_send_current_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr.translate('profile_shape_tips_intro'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: bodyColor,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTipRow(theme, primary, isDarkMode),
          const SizedBox(height: 18),
          _buildSourceButton(
            primary: primary,
            isFilled: true,
            icon: Icons.add_photo_alternate_outlined,
            label: context.tr.translate('profile_shape_pick_photo'),
            onPressed:
                _isPicking || _isGenerating ? null : _showImageSourcePicker,
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(ThemeData theme, Color primary, bool isDarkMode) {
    final tips = [
      (
        Icons.center_focus_strong_rounded,
        context.tr.translate('profile_shape_tip_light'),
      ),
      (
        Icons.checkroom_rounded,
        context.tr.translate('profile_shape_tip_clothes'),
      ),
    ];

    return SizedBox(
      height: 72,
      child: Row(
        children: [
          for (var i = 0; i < tips.length; i++) ...[
            Expanded(
              child: _buildTipItem(
                theme,
                primary,
                tips[i].$1,
                tips[i].$2,
                isDarkMode,
              ),
            ),
            if (i != tips.length - 1) _buildVerticalDivider(isDarkMode),
          ],
        ],
      ),
    );
  }

  Widget _buildTipItem(
    ThemeData theme,
    Color primary,
    IconData icon,
    String label,
    bool isDarkMode,
  ) {
    final textColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.72)
        : AppTheme.textSecondaryColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: primary, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor,
            fontSize: 9,
            height: 1.08,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceButton({
    required Color primary,
    required bool isFilled,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );

    if (isFilled) {
      return SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildSelectedPhotoCard(
    ThemeData theme,
    ColorScheme colorScheme,
    Color primary,
    Color cardColor,
    bool isDarkMode,
  ) {
    final titleColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final bodyColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.68)
        : AppTheme.textSecondaryColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(
        cardColor: cardColor,
        isDarkMode: isDarkMode,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 86,
              height: 106,
              child: ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Image.memory(
                  _sourceImageBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.translate('profile_shape_selected_title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr.translate('profile_shape_selected_body'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyColor,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _isPicking || _isGenerating
                      ? null
                      : _showImageSourcePicker,
                  style: TextButton.styleFrom(
                    foregroundColor: primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(
                    context.tr.translate('profile_shape_change_photo'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _isGenerating ? null : _generatePreview,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(
          _isGenerating
              ? context.tr.translate('profile_shape_generating')
              : context.tr.translate('profile_shape_generate'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildGenerationStatusCard(
    ThemeData theme,
    Color primary,
    Color cardColor,
    bool isDarkMode,
  ) {
    final titleColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final bodyColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.68)
        : AppTheme.textSecondaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        cardColor: isDarkMode ? cardColor : const Color(0xFFF6FFFD),
        isDarkMode: isDarkMode,
        radius: 20,
        blur: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    color: primary,
                    backgroundColor: primary.withValues(alpha: 0.12),
                  ),
                ),
                Text(
                  context.tr.translate('profile_shape_analysis_time'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.translate('profile_shape_generation_status_title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr.translate('profile_shape_generation_status_body'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyColor,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    color: primary,
                    backgroundColor: primary.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedResultCard(
    ThemeData theme,
    ColorScheme colorScheme,
    Color primary,
    Color cardColor,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(
        cardColor: cardColor,
        isDarkMode: isDarkMode,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDarkMode ? 0.16 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr.translate('profile_shape_result_label'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGeneratedComparison(colorScheme, primary, isDarkMode),
          const SizedBox(height: 12),
          _buildApplyButton(primary),
          const SizedBox(height: 10),
          _buildSocialShareButton(primary),
        ],
      ),
    );
  }

  Widget _buildGeneratedComparison(
    ColorScheme colorScheme,
    Color primary,
    bool isDarkMode,
  ) {
    final sourceImageBytes = _sourceImageBytes;

    if (sourceImageBytes == null) {
      return _buildGeneratedOnlyImage(colorScheme, primary);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1.12,
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: _buildComparisonPanel(
                  label: context.tr.translate('profile_shape_before'),
                  labelColor: Colors.black.withValues(alpha: 0.72),
                  child: Image.memory(
                    sourceImageBytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              Container(
                width: 2,
                color: Colors.white.withValues(alpha: isDarkMode ? 0.6 : 0.9),
              ),
              Expanded(
                child: _buildComparisonPanel(
                  label: context.tr.translate('profile_shape_after'),
                  labelColor: primary,
                  child: CachedNetworkImage(
                    imageUrl: _generatedImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: primary),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 42,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratedOnlyImage(ColorScheme colorScheme, Color primary) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: CachedNetworkImage(
            imageUrl: _generatedImageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(color: primary),
            ),
            errorWidget: (context, url, error) => Center(
              child: Icon(
                Icons.broken_image_rounded,
                size: 42,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonPanel({
    required String label,
    required Color labelColor,
    required Widget child,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 10,
          bottom: 10,
          child: _buildHeroBadge(label, labelColor, Colors.white),
        ),
      ],
    );
  }

  Widget _buildApplyButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isApplying ? null : _applyAsProfilePhoto,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isApplying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.account_circle_rounded),
        label: Text(
          _isApplying
              ? context.tr.translate('profile_shape_applying')
              : context.tr.translate('profile_shape_apply_profile'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialShareButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isPostingToSocial ? null : _showSocialShareOptions,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isPostingToSocial
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              )
            : const Icon(Icons.groups_rounded),
        label: Text(
          _isPostingToSocial
              ? context.tr.translate('profile_shape_posting_social')
              : context.tr.translate('profile_shape_share_social'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSecureFooter(ThemeData theme, bool isDarkMode) {
    final textColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.58)
        : AppTheme.textSecondaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 15,
          color: textColor,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            context.tr.translate('profile_shape_secure_footer'),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(bool isDarkMode) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    );
  }

  BoxDecoration _cardDecoration({
    required Color cardColor,
    required bool isDarkMode,
    double radius = 24,
    double blur = 22,
  }) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDarkMode ? 0.24 : 0.07),
          blurRadius: blur,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
