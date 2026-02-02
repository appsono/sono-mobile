-keep class com.ryanheise.just_audio.** { *; }
-keep interface com.ryanheise.just_audio.** { *; }

-keep class com.ryanheise.audioservice.** { *; }
-keep interface com.ryanheise.audioservice.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

-keep class com.google.firebase.** { *; }
-keep class wtf.sono.** { *; }
-keep class wtf.sono.app.nightly.** { *; }
-keep class wtf.sono.app.beta.** { *; }

-keep class com.ryanheise.audioservice.AudioServiceActivity { *; }

-keep class com.lucasjosino.on_audio_query.** { *; }
-dontwarn com.lucasjosino.on_audio_query.**
-keepattributes Signature, InnerClasses

-keep class canta.ran.OpenFilex.** { *; }
-keep class androidx.core.content.FileProvider { *; }

-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**
-dontwarn android.support.v4.media.**