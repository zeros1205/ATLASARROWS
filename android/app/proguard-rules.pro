# R8 rules for the release build.
#
# Debug builds are not minified, so anything here only ever fails in release —
# and it fails at process start, before a single frame. Test release builds on
# a device, not just debug.

# WorkManager, pulled in by google_mobile_ads, stores its state in a Room
# database whose implementation class is created by reflection. R8 cannot see
# that reference and strips it, which crashes the app during
# androidx.startup.InitializationProvider with:
#   Failed to create an instance of androidx.work.impl.WorkDatabase
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Room itself resolves DAOs and type converters reflectively.
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-dontwarn androidx.room.paging.**

# Play Billing: in_app_purchase talks to it through generated proxies.
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.**

# Google Mobile Ads keeps its mediation adapters behind reflection.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Play Games / Firebase model classes are deserialized by name.
-keep class com.google.android.gms.games.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
