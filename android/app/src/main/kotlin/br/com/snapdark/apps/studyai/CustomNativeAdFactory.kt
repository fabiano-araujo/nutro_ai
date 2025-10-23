package br.com.snapdark.apps.studyai
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.widget.AppCompatButton
import androidx.core.content.ContextCompat
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class CustomNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        // Infla o layout como View normal
        val rootView = LayoutInflater.from(context).inflate(R.layout.custom_native_ad, null)
        // Obtém a referência para o NativeAdView pelo ID
        val nativeAdView = rootView.findViewById<NativeAdView>(R.id.native_ad_view)
        
        // Garante que a view não tenha um parent antes de usá-la
        val parent = nativeAdView.parent as? ViewGroup
        parent?.removeView(nativeAdView)

        // Verifica se o dispositivo está em modo escuro ou claro
        val isDarkMode = (context.resources.configuration.uiMode and 
                Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        
        // Define as cores de texto e fundo com base no modo
        val textColor = if (isDarkMode) Color.WHITE else Color.BLACK
        val attributionBgColor = if (isDarkMode) Color.parseColor("#444444") else Color.parseColor("#F2F2F2")
        val attributionTextColor = if (isDarkMode) Color.parseColor("#AAAAAA") else Color.parseColor("#666666")
        
        // Personaliza as cores dos elementos do anúncio
        nativeAdView.findViewById<TextView>(R.id.ad_headline).setTextColor(textColor)
        nativeAdView.findViewById<TextView>(R.id.ad_advertiser).setTextColor(textColor)
        
        // Personaliza o label "Ad"
        val adAttribution = nativeAdView.findViewById<TextView>(R.id.ad_attribution)
        adAttribution?.apply {
            setBackgroundColor(attributionBgColor)
            setTextColor(attributionTextColor)
        }
        
        // Personaliza o botão CTA programaticamente para garantir cor e bordas arredondadas
        val ctaButton = nativeAdView.findViewById<AppCompatButton>(R.id.ad_call_to_action)
        val buttonColor = Color.parseColor("#6E81F2")
        
        // Aplica drawable programaticamente com bordas arredondadas
        val drawable = GradientDrawable()
        drawable.shape = GradientDrawable.RECTANGLE
        drawable.cornerRadius = 18 * context.resources.displayMetrics.density // 18dp em pixels
        drawable.setColor(buttonColor)
        ctaButton.background = drawable

        // Set the media view
        val mediaView = nativeAdView.findViewById<MediaView>(R.id.ad_media)
        nativeAdView.mediaView = mediaView

        // Set other ad assets
        nativeAdView.headlineView = nativeAdView.findViewById(R.id.ad_headline)
        nativeAdView.callToActionView = nativeAdView.findViewById(R.id.ad_call_to_action)
        nativeAdView.iconView = nativeAdView.findViewById(R.id.ad_app_icon)
        nativeAdView.advertiserView = nativeAdView.findViewById(R.id.ad_advertiser)

        // The headline and mediaContent are guaranteed to be in every NativeAd.
        (nativeAdView.headlineView as TextView).text = nativeAd.headline
        nativeAd.mediaContent?.let { mediaView.setMediaContent(it) }

        // These assets aren't guaranteed to be in every NativeAd, so it's important to
        // check before trying to display them.

        if (nativeAd.callToAction == null) {
            nativeAdView.callToActionView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.callToActionView?.visibility = View.VISIBLE
            (nativeAdView.callToActionView as AppCompatButton).text = nativeAd.callToAction
        }

        if (nativeAd.icon == null) {
            nativeAdView.iconView?.visibility = View.GONE
        } else {
            (nativeAdView.iconView as ImageView).setImageDrawable(nativeAd.icon?.drawable)
            nativeAdView.iconView?.visibility = View.VISIBLE
        }

        if (nativeAd.advertiser == null) {
            nativeAdView.advertiserView?.visibility = View.INVISIBLE
        } else {
            (nativeAdView.advertiserView as TextView).text = nativeAd.advertiser
            nativeAdView.advertiserView?.visibility = View.VISIBLE
        }

        // This registers the NativeAdView with the asset names used above.
        nativeAdView.setNativeAd(nativeAd)

        return nativeAdView
    }
} 