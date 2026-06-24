# TensorFlow Lite rules
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.examples.** { *; }
-keep class org.tensorflow.lite.nativeio.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn org.checkerframework.**

# Specific delegates if used
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }

# Gson rules (used by flutter_local_notifications)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.dexterous.** { *; }

# Glide rules (used by photo_manager)
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep public class * extends com.bumptech.glide.module.AppGlideModule
-keep public enum com.bumptech.glide.load.resource.bitmap.ImageHeaderParser$** {
  **[] $VALUES;
  public *;
}
-dontwarn com.bumptech.glide.**

