# ML Kit, Google Play e os plugins Flutter fornecem regras consumer ProGuard.
# Evite regras amplas de keep aqui, pois impedem o R8 de remover código não usado.

# O Flutter referencia suporte opcional a deferred components mesmo quando o
# app não os utiliza. O plugin de OCR também referencia modelos de idiomas que
# não são empacotados; o Nutro usa somente o reconhecedor latino.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Regras para reduzir o tamanho do bundle
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose

# Remover logs e debugs
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Manter atributos necessários
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
