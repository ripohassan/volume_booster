# Phase 2A — Existing Flutter build stabilization

Date: 11 November 2026 (Asia/Dhaka).

Scope: existing release builds and their validation only. No application feature, audio algorithm, screen, navigation, bundle ID, package ID, signing policy, or supported Runner deployment minimum is intentionally changed.

## Root causes

### iOS

Runner already targets iOS **15.6** in Debug, Profile and Release. The Podfile declared 15.0, and its post-install hook did not consistently raise individual library and privacy-resource targets to the app baseline. Several Pod specifications therefore retained minimums of 9.0, 12.0, 13.0 or 14.0. Installed Xcode 27.2 rejects targets below 15.0 before compiling the application.

The complete before/after per-target, per-configuration inventory is in `phase2a_logs/pods_before.json` and `phase2a_logs/pods_after.json`. These are the 26 targets with an explicit unsupported minimum before the fix; each had the same minimum in Debug, Profile and Release:

| Original minimum | Exact affected Pod targets |
| --- | --- |
| 9.0 | `app_tracking_transparency-app_tracking_transparency_privacy`; `DKImagePickerController`; `DKImagePickerController-DKImagePickerController`; `DKPhotoGallery`; `DKPhotoGallery-DKPhotoGallery`; `flutter_native_splash-flutter_native_splash_privacy`; `permission_handler_apple-permission_handler_apple_privacy`; `SDWebImage`; `SDWebImage-SDWebImage`; `SwiftyGif`; `SwiftyGif-SwiftyGif` |
| 12.0 | `AppLovinSDK`; `file_picker-file_picker_ios_privacy`; `package_info_plus-package_info_plus_privacy`; `share_plus-share_plus_privacy` |
| 13.0 | `Flutter`; `flutter_soloud`; `in_app_purchase_storekit`; `in_app_purchase_storekit-in_app_purchase_storekit_privacy`; `path_provider_foundation`; `path_provider_foundation-path_provider_foundation_privacy`; `shared_preferences_foundation`; `shared_preferences_foundation-shared_preferences_foundation_privacy`; `url_launcher_ios`; `url_launcher_ios-url_launcher_ios_privacy` |
| 14.0 | `ffmpeg_kit_flutter_new` |

Other targets either inherited a minimum or already used the Podfile's aggregate minimum. The fix aligns the Podfile with Runner's existing 15.6 support and applies a version-aware minimum in `post_install` to **every generated Pod target/configuration**, including privacy resource bundles. A dependency's higher minimum is preserved rather than lowered. Generated Pods project files are not the source of this fix; a fresh installation reapplies the Podfile rule.

No settings were copied from `ios_backup`. Pod versions did not change. `ios/Podfile.lock` changes only its Podfile checksum.

### Android

`flutter_native_splash` resolves correctly at **2.4.7**. The plugin's Java class exists in the package cache, and Flutter metadata correctly marks it as a dev dependency. There is no evidence of a missing/corrupt dependency or an application Gradle classpath declaration that needs to be added.

Flutter 3.44.4's Gradle integration excludes dev-only plugins from release dependencies. The stale GeneratedPluginRegistrant.java still referenced `net.jonhanson.flutter_native_splash.FlutterNativeSplashPlugin`, so javac attempted to compile a reference to a class intentionally absent from that release classpath.

The original audit build used `--no-pub`. Inspection of the installed Flutter tooling shows that `FlutterCommand.regeneratePlatformSpecificToolingIfApplicable` returns early when `shouldRunPub` is false, so that command reused registration from a non-release generation. The normal release path filters dev plugins in `injectPlugins`, matching Gradle's release dependency selection.

Resolution: `flutter clean`, `flutter pub get`, then the requested **`flutter build apk --release`** with its normal dependency/tooling generation enabled. Flutter, not a hand edit, regenerates the release registrant. Dev-only splash native registration is omitted; runtime plugins remain registered, and the existing generated native splash resources remain in place. No Android application source, Gradle override, plugin deletion, package move, or dependency upgrade is required for this registration failure.

Run validation commands sequentially: debug/test tooling and release tooling use shared generated registrants. Do not run another Flutter command that regenerates them while a native build is compiling.

### Android: additional R8 blocker exposed after registration was fixed

The next build passed Java registration compilation but failed at `:app:minifyReleaseWithR8`: Tika 3.2.0 references `javax.xml.stream.XMLStreamException`, which Android does not provide. The installed `file_picker` 10.3.3 Android Gradle dependency brings in Tika; its consumer rules already handle related StAX classes but omit this exception.

This exact omission has an [upstream maintainer-merged fix, File Picker PR #1968](https://github.com/vicajilau/flutter_file_picker/pull/1968/files). The app now backports its single rule, `-dontwarn javax.xml.stream.XMLStreamException`, in `android/app/proguard-rules.pro`. The installed Flutter Gradle plugin automatically includes that file in the release R8 configuration. No Gradle override or package-cache edit is necessary. R8, resource shrinking, plugin keep rules and all other missing-class diagnostics remain enabled. This is the upstream compatibility rule for the existing package, not a claim that Android supplies StAX or that the app's import/export has been device-tested.

The failed build log is retained as `phase2a_logs/android_before_r8_fix.log`. No new library is added and no Tika/File Picker version is changed.

### Flutter test baseline

The old test was Flutter's starter counter example. It directly constructed MyApp without the ThemeProvider that the real entry point supplies and asserted nonexistent counter controls. This was a test-fixture defect, not a reason to change the app's startup behavior.

The replacement smoke test supplies the existing provider, uses in-memory SharedPreferences, isolates the native billing connection, and verifies the existing splash, app name/logo, and theme propagation. It disposes the splash and drains its navigation timer. It does not claim to test store transactions, native audio, ads, or physical-device behavior. No new test dependency is needed.

## Dependency preservation

- `pubspec.yaml` is unchanged.
- `pubspec.lock` is byte-for-byte identical to the pre-phase file.
- All Dart and native Pod package versions are unchanged, including SoLoud 3.4.9 and FFmpeg Kit 4.3.2.
- No Firebase dependency is declared in this checkout; none was added or removed.
- The Podfile lock checksum changes because the Podfile changed, not because Pods were upgraded.
- The application IDs remain `m.volume.booster`; Runner's Debug/Profile/Release deployment minimum remains 15.6.

## Reproducibility and validation

Logs are in `docs/phase2a_logs/`. Commands are run without warning suppression or manually patched generated registration. `pod install --deployment` is an additional reproducibility check: it verifies the existing lock and recreates the Pod configuration without updating package versions.

| Command | Exit | Final observed result |
| --- | --- | --- |
| `flutter pub get` | 0 | Dependency resolution succeeds; existing versions and lockfile preserved. |
| `flutter analyze` | 1 | 182 pre-existing findings: 0 errors, 25 warnings, 157 informational findings. Exact finding set matches the original audit; no suppressions added. |
| `flutter test` | 0 | One widget smoke test passes, covering the existing splash and provider-driven theme update. |
| `flutter build ios --release --no-codesign` | 0 | `build/ios/iphoneos/Runner.app`, reported size 66.6 MB. Final repeated build succeeds. |
| `flutter build apk --release` | 0 | `build/app/outputs/flutter-apk/app-release.apk`, reported size 238.8 MB; R8 enabled. |
| `pod install --deployment` | 0 | Existing lock verified; all 36 Pod targets × 3 configurations remain at 15.6 after a second installation. |

The built iOS Info.plist confirms `m.volume.booster`, minimum OS 15.6, version 1.1.5, build 17. Android APK badging confirms `m.volume.booster`, minimum SDK 24, target SDK 36, version 1.1.5/build 17, and arm64-v8a/armeabi-v7a/x86_64 libraries. Existing Android SDK settings are unchanged. Arm64 SoLoud, FFmpeg, libavcodec and libavfilter native libraries are present. All twelve expected runtime Java plugin registrations remain in the regenerated release registrant; SoLoud's FFI library is separately verified in the APK. The merged R8 configuration includes the one added upstream compatibility rule.

### Exact retained changes

Application/build/test files:

1. `ios/Podfile` — declares minimum 15.6 and reproducibly raises lower generated Pod targets without reducing higher requirements.
2. `ios/Podfile.lock` — only the Podfile checksum changes; all Pod versions/checksums remain unchanged.
3. `android/app/proguard-rules.pro` — new single-class upstream File Picker/Tika R8 compatibility rule, with its source documented.
4. `test/widget_test.dart` — replaces unrelated counter assertions with a provider-wrapped, native-service-isolated splash/theme smoke test.

Documentation/evidence:

- `docs/PHASE_2A_BUILD_STABILIZATION.md` — this report.
- `docs/phase2a_logs/pub_get.log`
- `docs/phase2a_logs/clean.log`
- `docs/phase2a_logs/analyze.log`
- `docs/phase2a_logs/test.log`
- `docs/phase2a_logs/ios.log`
- `docs/phase2a_logs/android.log`
- `docs/phase2a_logs/android_before_r8_fix.log`
- `docs/phase2a_logs/pod_install_reproducibility.log`
- `docs/phase2a_logs/pods_before.json`
- `docs/phase2a_logs/pods_after.json`
- `docs/phase2a_logs/android_badging.log`
- `docs/phase2a_logs/validation_summary.json`

The repository's existing ignore rules exclude `.log` files from normal Git status, but these logs are present locally. No commit is created by this phase.

Flutter/CocoaPods regenerated local build output and plugin registrants through normal commands. Unrelated Xcode-project serialization and the tracked plugin-metadata timestamp were restored to their pre-phase contents after inspection; no registry or dependency metadata workaround is retained. The release registrant itself was never manually edited. No files under `lib/`, Android Gradle settings, native app source, pubspec.yaml, or pubspec.lock are changed. Pre-existing `.DS_Store` index/worktree changes are untouched.

## Remaining limitations

- Plain `flutter analyze` still reports the pre-existing 182 findings: 0 errors, 25 warnings and 157 informational findings. They concern existing unused declarations/imports, naming, deprecated APIs, logging and asynchronous-context issues. No new findings were introduced. These are not compilation blockers; correcting unrelated application Dart files or suppressing findings is outside this phase.
- Flutter reports future compatibility warnings for the current Gradle/AGP/Kotlin setup and plugins without Swift Package Manager support. They do not by themselves prove a failed current build; dependency upgrades are not introduced speculatively.
- CocoaPods reports the existing custom base-configuration warning. The requested iOS Release build is the validation for the current configuration; Profile compilation is not claimed.
- The requested iOS build disables signing. Android retains its existing release/debug-key signing configuration. This phase does not create App Store/Play distribution credentials or assert store upload readiness.
- No physical-device playback, import/export, audio-quality, purchase or ad-network checks were performed. Application Dart/native behavior is preserved by limiting changes to build configuration and the test harness; successful compilation is not a substitute for those device checks.

Stop point: build stabilization only. Audio Studio, Voice Lab, Audio Analyzer and UI redesign are not started.
