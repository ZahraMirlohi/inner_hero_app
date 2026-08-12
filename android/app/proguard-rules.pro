# proguard-rules.pro

# ✅ اضافه کنید - برای رفع خطای Missing classes
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ✅ نگه داشتن کلاس‌های Play Core
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep all classes that extend android.app.Application
-keep public class * extends android.app.Application

# Keep all classes that extend android.app.Activity
-keep public class * extends android.app.Activity

# Keep all classes that extend android.app.Service
-keep public class * extends android.app.Service

# Keep all classes that extend android.content.BroadcastReceiver
-keep public class * extends android.content.BroadcastReceiver

# Keep all classes that extend android.content.ContentProvider
-keep public class * extends android.content.ContentProvider

# Keep all classes that implement android.os.Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep all classes that are Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep all classes that are used in reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep all classes in your app package
-keep class com.example.inner_hero_app.** { *; }

# Keep all classes that are used in Gson
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep all classes that are used in Supabase
-keep class com.supabase.** { *; }

# Keep all classes that are used in Hive
-keep class com.hive.** { *; }

# Keep all classes that are used in Just Audio
-keep class com.ryanheise.just_audio.** { *; }

# Keep all classes that are used in Path Provider
-keep class com.path_provider.** { *; }

# Keep all classes that are used in File Picker
-keep class com.file_picker.** { *; }

# Keep all classes that are used in Open File
-keep class com.open_file.** { *; }

# Keep all classes that are used in Share Plus
-keep class com.share_plus.** { *; }

# Keep all classes that are used in Permission Handler
-keep class com.permission_handler.** { *; }

# Keep all classes that are used in Image Picker
-keep class com.image_picker.** { *; }

# Keep all classes that are used in Geolocator
-keep class com.geolocator.** { *; }

# Keep all classes that are used in Flutter Map
-keep class com.flutter_map.** { *; }

# Keep all classes that are used in Lottie
-keep class com.lottie.** { *; }

# Keep all classes that are used in Provider
-keep class com.provider.** { *; }

# Keep all classes that are used in Carousel Slider
-keep class com.carousel_slider.** { *; }

# Keep all classes that are used in Font Awesome
-keep class com.font_awesome.** { *; }

# Keep all classes that are used in Material Symbols
-keep class com.material_symbols.** { *; }

# Keep all classes that are used in Shamsi Date
-keep class com.shamsi_date.** { *; }

# Keep all classes that are used in Shared Preferences
-keep class com.shared_preferences.** { *; }

# Keep all classes that are used in Flutter Dotenv
-keep class com.flutter_dotenv.** { *; }

# Keep all classes that are used in HTTP
-keep class com.http.** { *; }

# Keep all classes that are used in Mime
-keep class com.mime.** { *; }

# Keep all classes that are used in Internet Connection Checker
-keep class com.internet_connection_checker.** { *; }

# Keep all classes that are used in Linkify
-keep class com.linkify.** { *; }

# Keep all classes that are used in URL Launcher
-keep class com.url_launcher.** { *; }

# Keep all classes that are used in Flutter Contacts
-keep class com.flutter_contacts.** { *; }