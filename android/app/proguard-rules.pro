# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.** { *; }

# SharedPreferences and Kotlin Coroutines (prevents NoSuchMethodError in SharedPreferencesApiRegistrar.getAll)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep interface io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep interface kotlin.coroutines.** { *; }
-keepclassmembers class kotlin.coroutines.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Google Play Services & Sign In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
