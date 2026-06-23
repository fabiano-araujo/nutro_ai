import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

class PlayStoreUpdateService {
  static bool _checkedThisSession = false;

  Future<void> checkForUpdateOnLaunch() async {
    if (_checkedThisSession ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _checkedThisSession = true;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }

      if (updateInfo.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress &&
          updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (updateInfo.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } on PlatformException catch (e) {
      debugPrint('[PlayStoreUpdate] In-app update unavailable: ${e.code}');
    } catch (e) {
      debugPrint('[PlayStoreUpdate] Failed to check app update: $e');
    }
  }
}
