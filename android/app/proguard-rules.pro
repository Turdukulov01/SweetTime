# mobile_scanner 6.x / bundled ML Kit uses runtime component discovery.
# Keep nested ML Kit packages in release builds; `com.google.mlkit.*` does not
# match subpackages such as `com.google.mlkit.common.sdkinternal`.
-keep class com.google.mlkit.** { *; }
