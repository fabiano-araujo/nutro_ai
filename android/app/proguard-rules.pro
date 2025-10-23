# Keep classes referenced by the ML Kit libraries
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Rules for text recognition models - mantendo apenas o modelo básico
-keep class com.google.mlkit.vision.text.** { *; }
# Comentado modelos de idiomas específicos que não estamos usando mais
# -keep class com.google.mlkit.vision.text.chinese.** { *; }
# -keep class com.google.mlkit.vision.text.devanagari.** { *; }
# -keep class com.google.mlkit.vision.text.japanese.** { *; }
# -keep class com.google.mlkit.vision.text.korean.** { *; }

# Novas bibliotecas do Play
-keep class com.google.android.play.feature.** { *; }
-keep class com.google.android.play.asset.** { *; }
-keep class com.google.android.play.review.** { *; }
-keep class com.google.android.play.update.** { *; }

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