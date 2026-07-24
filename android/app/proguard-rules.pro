# Room instantiates generated `*_Impl` databases via Class.forName + newInstance;
# R8 full mode strips the reflective constructor, killing the process at startup
# (androidx.work.WorkDatabase, pulled in by google_mobile_ads).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
