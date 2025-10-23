import Foundation
import GoogleMobileAds

class CustomNativeAdFactory: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: GADNativeAd, customOptions: [AnyHashable : Any]? = nil) -> GADNativeAdView {
        let nibView = Bundle.main.loadNibNamed("CustomNativeAdView", owner: nil, options: nil)?.first
        let nativeAdView = nibView as! GADNativeAdView

        // Set the media view
        let mediaView = nativeAdView.mediaView
        mediaView?.mediaContent = nativeAd.mediaContent

        // Set the headline
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline

        // Aplicar cor personalizada ao botão se especificado
        if let options = customOptions, let buttonColor = options["buttonColor"] as? NSNumber {
            let color = UIColor(
                red: CGFloat((buttonColor.intValue >> 16) & 0xff) / 255.0,
                green: CGFloat((buttonColor.intValue >> 8) & 0xff) / 255.0,
                blue: CGFloat(buttonColor.intValue & 0xff) / 255.0,
                alpha: CGFloat((buttonColor.intValue >> 24) & 0xff) / 255.0
            )
            (nativeAdView.callToActionView as? UIButton)?.backgroundColor = color
        }

        // Opcionalmente configurar outras visualizações se presentes
        if let body = nativeAd.body {
            (nativeAdView.bodyView as? UILabel)?.text = body
        } else {
            nativeAdView.bodyView?.isHidden = true
        }

        if let callToAction = nativeAd.callToAction {
            (nativeAdView.callToActionView as? UIButton)?.setTitle(callToAction, for: .normal)
        } else {
            nativeAdView.callToActionView?.isHidden = true
        }

        if let icon = nativeAd.icon?.image {
            (nativeAdView.iconView as? UIImageView)?.image = icon
        } else {
            nativeAdView.iconView?.isHidden = true
        }

        if let advertiser = nativeAd.advertiser {
            (nativeAdView.advertiserView as? UILabel)?.text = advertiser
        } else {
            nativeAdView.advertiserView?.isHidden = true
        }

        // Associar o anúncio nativo à visualização
        nativeAdView.nativeAd = nativeAd

        return nativeAdView
    }
} 