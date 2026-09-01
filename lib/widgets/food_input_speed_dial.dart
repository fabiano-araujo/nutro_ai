import 'package:flutter/material.dart';

import '../i18n/app_localizations_extension.dart';

enum FoodInputAction { audio, camera, gallery, barcode }

class FoodInputSpeedDial extends StatefulWidget {
  const FoodInputSpeedDial({
    super.key,
    required this.onSelected,
    this.isBusy = false,
    this.showCamera = true,
    this.showBarcode = true,
  });

  final ValueChanged<FoodInputAction> onSelected;
  final bool isBusy;
  final bool showCamera;
  final bool showBarcode;

  @override
  State<FoodInputSpeedDial> createState() => _FoodInputSpeedDialState();
}

class _FoodInputSpeedDialState extends State<FoodInputSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant FoodInputSpeedDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy && _isOpen) {
      _close();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.isBusy) return;
    if (_isOpen) {
      await _close();
      return;
    }
    setState(() => _isOpen = true);
    await _controller.forward();
  }

  Future<void> _close() async {
    if (!_isOpen) return;
    await _controller.reverse();
    if (mounted) setState(() => _isOpen = false);
  }

  Future<void> _select(FoodInputAction action) async {
    await _close();
    if (!mounted) return;
    widget.onSelected(action);
  }

  List<_FoodInputDialOption> _options() {
    return [
      const _FoodInputDialOption(
        action: FoodInputAction.audio,
        icon: Icons.mic_rounded,
        titleKey: 'food_input_audio_title',
        subtitleKey: 'food_input_audio_subtitle',
      ),
      if (widget.showCamera)
        const _FoodInputDialOption(
          action: FoodInputAction.camera,
          icon: Icons.photo_camera_rounded,
          titleKey: 'take_photo',
          subtitleKey: 'food_input_camera_subtitle',
        ),
      const _FoodInputDialOption(
        action: FoodInputAction.gallery,
        icon: Icons.photo_library_rounded,
        titleKey: 'photo_library',
        subtitleKey: 'food_input_gallery_subtitle',
      ),
      if (widget.showBarcode)
        const _FoodInputDialOption(
          action: FoodInputAction.barcode,
          icon: Icons.qr_code_scanner_rounded,
          titleKey: 'barcode_scanner_title',
          subtitleKey: 'food_input_barcode_subtitle',
          featured: true,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = _options();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen || !_controller.isDismissed)
          SizeTransition(
            sizeFactor: _expandAnimation,
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IgnorePointer(
                  ignoring: !_isOpen,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < options.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _FoodInputDialAction(
                              option: options[i],
                              onTap: () => _select(options[i].action),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Tooltip(
          message: context.tr.translate(
            _isOpen ? 'close' : 'food_input_fab_label',
          ),
          child: FloatingActionButton.extended(
            key: const Key('food_input_speed_dial'),
            heroTag: 'food_input_speed_dial',
            onPressed: widget.isBusy ? null : _toggle,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            icon: widget.isBusy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : AnimatedRotation(
                    turns: _isOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      _isOpen ? Icons.close_rounded : Icons.add_rounded,
                    ),
                  ),
            label: Text(
              context.tr.translate(
                _isOpen ? 'close' : 'food_input_fab_label',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodInputDialOption {
  const _FoodInputDialOption({
    required this.action,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    this.featured = false,
  });

  final FoodInputAction action;
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final bool featured;
}

class _FoodInputDialAction extends StatelessWidget {
  const _FoodInputDialAction({
    required this.option,
    required this.onTap,
  });

  final _FoodInputDialOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = context.tr.translate(option.titleKey);
    final subtitle = context.tr.translate(option.subtitleKey);
    final isFeatured = option.featured;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Material(
                  color: isFeatured
                      ? colorScheme.primaryContainer
                      : colorScheme.surface,
                  elevation: isFeatured ? 4 : 2,
                  shadowColor: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isFeatured ? 10 : 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isFeatured
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                  ),
                        ),
                        if (isFeatured) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer
                                          .withValues(alpha: 0.78),
                                      height: 1.25,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: isFeatured ? 56 : 40,
                height: isFeatured ? 56 : 40,
                decoration: BoxDecoration(
                  color: isFeatured
                      ? colorScheme.primary
                      : colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: isFeatured ? 10 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  option.icon,
                  color: isFeatured
                      ? colorScheme.onPrimary
                      : colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
