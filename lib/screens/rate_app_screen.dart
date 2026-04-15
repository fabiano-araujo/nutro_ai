import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/rate_app_bottom_sheet.dart';

class RateAppScreen extends StatefulWidget {
  const RateAppScreen({Key? key}) : super(key: key);

  @override
  State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> {
  bool _openedSheet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_openedSheet) {
      return;
    }

    _openedSheet = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await RateAppBottomSheet.show(context);

      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkBackgroundColor
          : Colors.white,
    );
  }
}
