import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/credit_provider.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/reward_ad_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreditIndicator extends StatelessWidget {
  final VoidCallback? onTap;
  const CreditIndicator({Key? key, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CreditProvider>(
      builder: (context, creditProvider, child) {
        final hasLowCredits = creditProvider.creditsRemaining <= 4;
        final creditColor =
            _getCreditColor(context, creditProvider.creditsRemaining);
        final creditForegroundColor = _getCreditForegroundColor(creditColor);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onTap ??
                  () {
                    if (creditProvider.creditsRemaining <= 0) {
                      _showWatchAdDialog(context);
                    } else {
                      Navigator.of(context).pushNamed('/subscription');
                    }
                  },
              child: Tooltip(
                message: context.tr.translate('tap_for_premium'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: creditColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: creditColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 14,
                        color: creditForegroundColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${creditProvider.creditsRemaining}',
                        style: TextStyle(
                          color: creditForegroundColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                  ),
                ),
              ),
            ),

            // Badge para indicar premium
            if (hasLowCredits)
              Positioned(
                top: -6,
                right: -10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '+ ',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _getCreditColor(BuildContext context, int credits) {
    if (credits <= 4) {
      return Colors.red;
    } else if (credits <= 10) {
      return Colors.orange;
    } else {
      return Theme.of(context).primaryColor;
    }
  }

  Color _getCreditForegroundColor(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  void _showWatchAdDialog(BuildContext context) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Esta funcionalidade não está disponível na versão web.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    RewardAdDialog.show(context);
  }
}
