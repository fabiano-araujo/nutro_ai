import 'package:flutter/foundation.dart';

/// Controlador global das abas principais do aplicativo.
class NavigationController {
  NavigationController._internal();

  static final NavigationController _instance =
      NavigationController._internal();

  factory NavigationController() => _instance;

  ValueChanged<int>? tabChangeCallback;
  final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(0);

  void updateSelectedIndex(int index) {
    if (selectedIndexNotifier.value != index) {
      selectedIndexNotifier.value = index;
    }
  }

  void changeTab(int index) {
    tabChangeCallback?.call(index);
  }
}

final navigationController = NavigationController();
