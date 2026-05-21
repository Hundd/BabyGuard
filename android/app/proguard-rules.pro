# Keep rules for BabyGuard release builds.
#
# Most Flutter plugins reach across the JNI boundary with reflection or
# native-callback registration. R8 doesn't see those references, so without
# explicit -keep rules it strips classes that look unused and the app crashes
# at runtime with ClassNotFoundException / NoSuchMethodException.
#
# If you hit a crash after enabling R8, run `make logs` while reproducing,
# find the missing class, and add a -keep for its package here.

# ---- Flutter engine ----
-keep class io.flutter.embedding.engine.dart.DartExecutor { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---- Firebase BoM (auth, firestore, messaging, app) ----
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- AwesomeNotifications: reflective channel + action handling ----
-keep class me.carda.awesome_notifications.** { *; }
-keepclassmembers class * extends me.carda.awesome_notifications.core.broadcasters.receivers.AwesomeBroadcastReceiver { *; }
-dontwarn me.carda.awesome_notifications.**

# ---- flutter_foreground_task: service entry points the OS launches by name ----
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**

# ---- mobile_scanner: ML Kit barcode detection uses reflection ----
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_** { *; }
-dontwarn com.google.mlkit.**

# ---- noise_meter / audio_streamer: native MethodChannel handlers ----
-keep class com.dooboolab.** { *; }
-keep class it.davidetrentin.** { *; }
-dontwarn com.dooboolab.**
-dontwarn it.davidetrentin.**

# ---- General Flutter plugin registrant ----
-keep class * extends io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }

# ---- Anything annotated @Keep ----
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * { @androidx.annotation.Keep *; }
