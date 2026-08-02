import 'package:flutter/material.dart';

import '../i18n/app_localizations_extension.dart';
import '../services/app_debug_log_service.dart';

class AppDebugLogOverlay extends StatefulWidget {
  const AppDebugLogOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  State<AppDebugLogOverlay> createState() => _AppDebugLogOverlayState();
}

class _AppDebugLogOverlayState extends State<AppDebugLogOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!AppDebugLogService.isEnabled) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 8,
          child: ValueListenableBuilder<List<AppDebugLogEntry>>(
            valueListenable: AppDebugLogService.entries,
            builder: (context, logs, _) {
              if (!_expanded) {
                return FloatingActionButton.small(
                  heroTag: 'app_debug_logs_fab',
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(
                    logs.length.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              final size = MediaQuery.sizeOf(context);
              final width = size.width < 520 ? size.width - 16 : 500.0;
              final height = size.height < 700 ? size.height * 0.48 : 340.0;
              return Material(
                color: Colors.transparent,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 38,
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr.translate('app_logs'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.tr.translate('clear'),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: AppDebugLogService.clear,
                            ),
                            IconButton(
                              tooltip: context.tr.translate('close'),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () =>
                                  setState(() => _expanded = false),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white24),
                      Expanded(
                        child: logs.isEmpty
                            ? Center(
                                child: Text(
                                  context.tr.translate('no_logs_yet'),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.all(8),
                                itemCount: logs.length,
                                itemBuilder: (context, index) {
                                  final log = logs[logs.length - 1 - index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: SelectableText(
                                      _format(log),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        height: 1.25,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _format(AppDebugLogEntry log) {
    final time = log.timestamp.toIso8601String().substring(11, 23);
    return '$time ${log.message}';
  }
}
