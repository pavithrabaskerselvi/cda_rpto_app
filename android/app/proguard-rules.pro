# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep annotations used by reflection-based libraries
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Flutter's Play Store "deferred components" support references Play Core
# classes that only exist if you use dynamic feature delivery. This app
# doesn't, so tell R8 to stop looking for them instead of failing the build.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }