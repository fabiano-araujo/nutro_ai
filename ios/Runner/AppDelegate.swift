import Flutter
import UIKit
import GoogleMobileAds
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configurar Firebase
    FirebaseApp.configure()
    Messaging.messaging().delegate = self

    // Configurar notificações push
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    
    // Registrar a factory de anúncios nativos personalizada
    let controller = window?.rootViewController as! FlutterViewController
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      controller,
      factoryId: "customNativeAd",
      nativeAdFactory: CustomNativeAdFactory()
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    // Desregistrar a factory quando o aplicativo for encerrado
    let controller = window?.rootViewController as! FlutterViewController
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(
      controller,
      factoryId: "customNativeAd"
    )
  }
}
