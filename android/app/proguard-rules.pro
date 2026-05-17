# ProGuard / R8 rules for Kathmandu Hiker release builds.
#
# Per ULTIMATE.md §11.1 / §4.4 — minify + shrink are enabled in
# app/build.gradle.kts. The Flutter Gradle plugin and our dependencies
# (Firebase, Google Maps, Google Sign-In, flutter_local_notifications,
# flutter_background_service, etc.) all ship consumer ProGuard rules,
# so this file deliberately contains very little.
#
# Only add `-keep` rules here for classes that R8 strips at release but
# your code still references via reflection (typical symptom: a release
# crash with `ClassNotFoundException` or `NoSuchMethodException` for
# something that works fine in debug). When you add a rule, write a
# comment explaining WHY — otherwise it'll rot.

# Keep model classes that Firestore deserializes via reflection. Without
# this rule, `Trail.fromDoc(d)` and friends would still work (we map
# manually), but if we ever switch to `doc.toObject(Trail.class)` the
# release build would silently return objects with all-null fields.
-keepclassmembers class com.rahul.kathmanduhiker.** {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}

# Keep our own model classes' default constructors and fields — Firestore
# uses them to instantiate via reflection.
-keepclassmembers class com.rahul.kathmanduhiker.** {
    public <init>();
    *;
}

# Crashlytics — keep crash-report line numbers usable.
-keepattributes SourceFile,LineNumberTable
# Per ULTIMATE.md §3.3, upload the mapping file (mapping.txt) to
# Crashlytics in CI so stack traces are deobfuscated. The Crashlytics
# Gradle plugin handles this automatically when present, but be sure
# the mapping file is preserved as a CI build artifact too.
