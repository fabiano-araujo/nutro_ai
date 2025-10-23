import Flutter
import UIKit
import GoogleMobileAds

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
