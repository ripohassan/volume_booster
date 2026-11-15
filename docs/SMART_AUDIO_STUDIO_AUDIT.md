# Flutter Smart Audio Enhancement Studio: source audit and implementation plan

Audit date: 11 November 2026 (Asia/Dhaka).

This is the requested audit-first deliverable. Product implementation has not started. Findings distinguish code inspection, executed checks, and proposed work. Device playback, audible enhancement, sharing, purchase validity, and physical-device performance have not been verified. Existing functionality must be regression-tested rather than assumed correct from its presence in source.

## 1. Existing project architecture

### Application structure

- Flutter package: `untitled`; version `1.1.5+17`; Dart constraint `^3.9.2`.
- Installed tooling: Flutter 3.44.4, Dart 3.12.2, Xcode 27.2, OpenJDK 21.0.10.
- Nineteen application Dart files. The application uses StatefulWidgets and screen-local `setState`, singleton services, and ChangeNotifier. There is no feature-wide project controller or repository layer.
- Provider supplies `ThemeProvider` at the root. `AudioService` is also a ChangeNotifier, but screens obtain its singleton directly; only Voice Booster subscribes to its changes.
- GetX is declared but not used in application code. There is no reason to migrate to it or introduce a different state-management framework.
- SharedPreferences stores premium flags, rewarded-premium expiry, interaction counters, and daily export counts. It is not a durable audio-project database.

### Entry point and navigation

`main.dart` initializes Flutter, requests iOS tracking authorization, awaits AppLovin initialization, creates the theme provider, and launches `MyApp`.

`MyApp → SplashScreen → HomeScreen` uses imperative `Navigator` routes. Home contains an IndexedStack with Boost, Equalizer, Voice, and Export tabs. Settings is a separate route; locked actions open PurchaseScreen. PurchaseScreen also contains the policy and terms screens.

The IndexedStack creates all four tab states, so their services and animations are initialized even while tabs are hidden. The app has several independent purchase-stream listeners in Splash, Home, Purchase, and Settings. `AllSongStoreScreen` exists but is not referenced by active navigation. Its `stored_songs` preference has no writer in current application code.

### Direct dependency inventory

Versions below are resolved from the current lockfile/package configuration, not suggested upgrades.

| Dependency | Resolved version | Current role / observation |
| --- | --- | --- |
| flutter | SDK | UI, framework, platform integration |
| cupertino_icons | 1.0.8 | Icon assets |
| audioplayers | 6.5.1 | Declared; no application import or player use found |
| file_picker | 10.3.3 | Audio/video selection through file paths |
| applovin_max | 4.6.0 | Banners, rewarded ads, interstitials |
| shared_preferences | 2.5.3 | Settings, entitlement flags, counters |
| flutter_screenutil | 5.9.3 | Scaling from a 390 × 844 design |
| get | 4.7.2 | Declared; no GetX architecture in application code |
| url_launcher | 6.3.2 | Policy, support, rating, external links |
| device_preview | 1.3.1 | Declared; not used in application code |
| package_info_plus | 8.3.1 | Settings version information |
| flutter_soloud | 3.4.9 | Actual playback and bass filter |
| app_tracking_transparency | 2.0.6+1 | Startup iOS ATT request |
| provider | 6.1.5+1 | Theme ChangeNotifier injection |
| ffmpeg_kit_flutter_new | 4.3.2 | Offline gain, voice DSP, video audio export, EQ export service |
| path_provider | 2.1.5 | Documents export directory |
| permission_handler | 11.4.0 | Declared; no application permission calls found |
| flutter_launcher_icons | 0.14.4 | Icon generation; currently in runtime dependencies |
| share_plus | 10.1.4 | OS share sheet for exported files |
| in_app_purchase | 3.2.3 | Store products, purchase updates and restoration; unconstrained in pubspec |
| flutter_test | SDK | One starter widget test |
| flutter_lints | 5.0.0 | Analyzer rules |
| flutter_native_splash | 2.4.7 | Splash generation |

Keep working dependencies and the lockfile initially. Unused declarations are cleanup candidates only after platform/build verification; removing them is not part of this audit.

### Native implementation and platforms

**iOS:** `ios/Runner/AppDelegate.swift` uses Flutter's implicit-engine registration; SceneDelegate is a FlutterSceneDelegate. There is no app-owned AVAudioEngine, AVAudioFile, vDSP, EQ, or dynamics implementation. No app-owned MethodChannel, EventChannel, or FFI binding was found. Native processing comes from the existing packages. The Podfile targets iOS 15.0, while Runner configurations target 15.6. Both iPhone and iPad are declared. `ios_backup` is an older separate runner with a different Podfile; it is not the active iOS target and should not be copied over the current runner.

**Android:** Kotlin MainActivity initializes a temporary WebView for ads and enables WebView debugging unconditionally. It contains no app-owned audio DSP or channels. Gradle uses AGP 8.9.1, Kotlin 2.1.0, Gradle 8.12, Java/Kotlin target 11, and Flutter-provided SDK versions. The installed Flutter resolves its default Android minimum to API 24; the installed FFmpeg plugin also requires API 24 and uses Java 17 internally. Release currently uses the debug signing configuration.

**Other platforms:** macOS, Windows, Linux and web runner folders exist. This is not evidence that their full workflows are supported. FFmpeg's installed plugin declares Android/iOS/macOS/Windows, not Linux/web. In-app purchase declares Android/iOS/macOS. App code uses `dart:io`, `Platform`, and path-based file picking without a web adapter. macOS sandbox entitlements do not declare user-selected file access. Preserve the runner folders and establish capabilities explicitly; do not silently promise or remove desktop/web support. No non-mobile builds were run in this audit.

## 2. Existing feature inventory and traced workflows

| Feature | Actual workflow | Preservation requirement / limitation |
| --- | --- | --- |
| Volume Booster | BoostScreen → pickAndLoadFile → SoLoud source → applyBoost or applySuperBoost → play | Retain import, gain slider, Light/Medium/Max Safe/Ultra controls, one-tap boost, playback and premium actions. Live limiting is not implemented. |
| Bass Booster | Super Boost changes low EQ values; AudioService activates the global bassBoostFilter; Bass Boost EQ preset exists | Bass is integrated into boost/EQ, not a separate screen or independent bass-amount workflow. Preserve it and make its interaction with gain predictable. |
| Equalizer | EqualizerScreen → six stored presets or ten sliders → AudioService EQ state → bass average and overall volume | Ten independent frequency filters are not implemented in live playback. Premium gates most adjustments. |
| Import / Export | Boost imports audio and exports AAC; ExportScreen independently imports audio/video and calls FFmpeg → documents directory → share sheet | Retain audio/video input, AAC/M4A, WAV, MP4 selection and quality options. ExportScreen does not share the playback project's configuration. |
| Voice Enhancement | VoiceBoosterScreen imports → four parameters → FFmpeg voice filter chain → enhanced file → shared SoLoud playback → Original/Enhanced switch → share | Genuine conventional DSP is present. Comparison reloads from the beginning, settings can become stale relative to rendered audio, and other tabs can replace the shared playback source. |

Additional existing behavior: settings, support/policy links, subscription paywall/restore, rewarded one-hour premium access, banner ads and conditional interstitial handling. Preserve valid entitlements and reachable settings while repairing incorrect behavior.

EQ preset inventory: Flat, Bass Boost, Vocal Boost, Rock, Pop, Night Mode. Super Boost is an additional service-applied curve.

## 3. Existing audio processing implementation

### Real-time playback: AudioService

`lib/core/service/audio_service.dart` owns a SoLoud source and sound handle, initialization state, current file metadata, gain, ten EQ values and a preset name.

- `loadFile` stops/disposes the previous source, then loads the chosen file. No disk-streaming mode is supplied; the installed package defaults to fully decoded PCM in memory.
- `play` starts a new handle and sets volume. There is no exposed duration, position, seek, pause/resume, completion subscription or interruption handling.
- `togglePlayback` stops or starts. The pause icon therefore means stop/restart in practice.
- Boost is linear amplitude (`percent / 100`) clamped to 0–3. The service activates a bass filter when boost changes.
- `_updateEQFilters` averages bands 0–2 into nonnegative bass gain; bands 3–9 become a scalar volume offset. Bass cuts are discarded, and mid/treble bands do not filter their advertised frequencies.
- Comments promise compression/limiting, but no limiter or compressor is activated.

The installed SoLoud package already exposes `setPause`, `seek`, `getPosition`, `getLength`, source events, visualization data, limiter and compressor filters. Its built-in equalizer has **eight** bands, so it cannot honestly be substituted for the existing ten labeled frequency bands without a deliberate implementation strategy.

### Offline processing: FFmpegService

`lib/core/service/ffmpeg_service.dart` writes timestamped files to `Documents/VolumeBooster_Exports`.

- Audio boost: `volume` in dB followed by `alimiter`; gain clamped to −20…20 dB.
- Voice: `afftdn`, high-pass, treble, 1500 Hz EQ, then either `loudnorm` or limiter.
- Video: copies video and re-encodes boosted/limited audio into MP4. Not every imported MOV codec is necessarily compatible with the destination container.
- EQ export: ten actual FFmpeg frequency EQ filters plus gain and limiter. `applyEQToFile` has no UI call site, so this real ten-band implementation is currently unreachable from the EQ screen.
- AAC/M4A and MP4 use AAC; WAV relies on FFmpeg's default WAV audio encoder instead of explicitly using the helper's `pcm_s16le` selection. Standard/high choose 44.1/48 kHz; bitrate labels do not describe lossless WAV output.
- Duration probing invokes FFmpeg with a shell-style `2>&1` token and parses diagnostic text. This is not a shell invocation and should become a structured FFprobe call.
- Progress is process-global via FFmpegKitConfig. EQ export only reports completion. Cancellation cancels every FFmpeg session; a singleton boolean is shared by all tasks.
- Return-code success is treated as sufficient output validation. There is no decoded-output measurement, durable history, atomic finalization, or partial-file cleanup policy.

### Confirmed defects and concrete risks

| Priority | Evidence | Consequence / required correction |
| --- | --- | --- |
| High | FFmpegService line 140 emits `afftdn=nf=-$nrValue`; default slider 0.5 produces `nf=-15.0` | `nf` controls noise floor, not reduction amount. Upstream defines −80…−20 dB for `nf`; default input is outside that range. Verify against the bundled native build and use validated `nr`/noise-floor controls. Likely failure is identified from source, not an executed device DSP test. |
| High | AudioService lines 153 and 250 raise gain/bass with no active limiter | Clipping prevention and “Max Safe” are not substantiated. Add measured headroom and a real limiter; avoid any claim of hearing safety based only on digital limiting. |
| High | AudioService `_updateEQFilters` | Advertised frequency controls do not perform ten-band EQ. Use the existing true offline chain for faithful preview/export, then decide whether continuous live ten-band DSP is needed. |
| High | Settings `_handleRemoveSubscription` | Reachable action clears local premium after a delay and reports success, without changing store billing. Replace with store subscription management and truthful status handling. |
| High | Purchase handlers persist `is_premium_user=true` permanently | No receipt/transaction verification, expiry or revocation handling was found. Monthly/weekly/yearly subscriptions become a permanent local entitlement. Consolidate purchase lifecycle and migrate existing flags carefully. |
| Medium | Voice comparison and all screens share one AudioService source | Boost/EQ gains and global bass effects can affect original/enhanced listening; another tab can change which file Voice plays. Add explicit ownership and neutral comparison routing. |
| Medium | BoostScreen save calculates `(_boostPercent - 100) / 10` and clamps negative results to zero | 150% playback is about +3.52 dB but export uses +5 dB; attenuation cannot be exported. Super Boost EQ/bass is also omitted from saved output. Use one explicit configuration and logarithmic gain conversion, with mute handled separately. |
| Medium | SoLoud loadFile defaults to decoded memory | Large files can exhaust memory. Use suitable streaming mode and chunked offline decode/analysis with bounded caches. |
| Medium | Global FFmpeg callback and cancel | Tab operations can overwrite progress or cancel unrelated jobs. Introduce immutable job IDs and session-specific cancellation; serialize initially. |
| Medium | Limiter uses `limit=0.95` without specifying `level` | Upstream auto-level defaults on; 0.95 is not necessarily the final output ceiling. Explicitly configure makeup behavior and measure decoded output, including lossy overshoot. |
| Medium | Voice controls remain editable after render | Enhanced output can reflect old settings without clear indication. Invalidate previews by configuration hash and provide explicit Reprocess. |
| Medium | AudioService play/load/dispose | Repeated play can create extra voices; load failure can leave old filename/playing state; async shutdown may notify after ChangeNotifier disposal. Serialize lifecycle, reset state on failure, and await teardown before notifier disposal. |
| Medium | Shared playback changes are observed only in Voice screen | Boost/EQ can display stale file, preset or playback state after changes elsewhere. Use consistent listeners/controllers. |
| Medium | Multiple screens subscribe to purchase updates; async UI calls often lack mounted checks | Duplicate completion/navigation and disposed-state errors are possible; Home also uses late preferences during concurrent startup. Centralize purchase state and guard asynchronous transitions. |
| Medium | FFmpeg command strings interpolate paths in double quotes | Valid filenames containing quotation marks can break argument parsing. Use argument-list APIs, explicit audio stream mapping and validated inputs. |
| Medium | Export/Voice exceptions are not consistently handled in try/finally | A thrown plugin/filesystem error can leave processing indicators stuck. Add typed errors and guaranteed state/resource cleanup. |
| Medium | SharedPreferences `canExport` allows three free daily exports, but active screens gate all exports on premium | Monetization rules disagree. Preserve current reachable policy until an explicit product rule is selected; do not silently change gates. |
| Low | Boost/EQ visualizers use sine waves / slider values | They are decorative animations, not a waveform, spectrum or measured audio level. Replace with real sample-derived views before analyzer claims. |
| Low | Theme picker entry is commented out; selection compares AppTheme to ThemeData | Light theme is not an accessible consistent experience. Most main surfaces hardcode dark colors; theme choice is not persisted. |
| Low | AllSongStoreScreen and PremiumManager have no active references | Legacy code is not evidence of a functioning library/history workflow. Keep it until migration is verified. |

FFmpeg parameter facts above are supported by the primary sources for [afftdn](https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/af_afftdn.c) and [alimiter](https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/af_alimiter.c). Upstream source is a reference; shipped binary behavior remains a required device test.

## 4. Missing functionality

| Requested section | Already reusable | Missing / incomplete |
| --- | --- | --- |
| Audio Studio | Picking, basic playback, gain processing, file export/share | Shared project, real waveform, duration/position, pause/resume/seek, trim, faithful processing preview, aligned A/B, complete progress/cancel, persistent export history |
| Voice Lab | Clarity, denoise, vocal EQ, loudnorm chain, basic file comparison and share | Correct denoise parameters, bounded intensity, stale-render invalidation, cancellation UI, waveform comparison, aligned neutral A/B, shared project/export configuration |
| Audio Analyzer | SoLoud data APIs available but unused | Screen, full-file decoded sample analysis, frequency spectrum, calibrated RMS/peak dBFS, clipping sample counts, waveform envelope, band energy, actual codec/channel/rate/duration information |
| Sound Control | Boost, bass effect, six EQ presets, ten stored controls | Real limiter, ten-band behavior, source/completion state, consistent units, honest safe-gain labels and exported preview parity |
| Cross-cutting | Provider, ScreenUtil, theme definitions, preferences | Responsive phone/tablet composition, functional light theme, accessible controls/semantics, durable files/history, errors/cleanup, meaningful tests and verified builds |

No speech model or AI inference exists. The current voice DSP should be described as signal processing. Do not invent an overall audio-quality score, estimated bitrate for PCM, recovered clipping, or speech intelligibility measurements without a defined and validated calculation.

## 5. Proposed architecture and new files

Retain Flutter, current Navigator, Provider/ChangeNotifier, SoLoud and FFmpeg. Add a small domain/controller layer alongside existing files. Proposed paths below do not exist yet.

| New files / group | Responsibility |
| --- | --- |
| `lib/features/models/audio_project.dart` | Source identity, owned paths, metadata, trim, revision; serialization version |
| `lib/features/models/processing_config.dart` | Validated immutable gain, ten EQ bands, voice controls, normalization, limiter and output settings |
| `lib/features/models/audio_analysis.dart` | Channel-aware measured metrics, waveform envelope, spectrum and measurement scope |
| `lib/features/models/export_record.dart` | Project/config revision, output metadata, created time, result path |
| `lib/core/service/audio_project_repository.dart` | Copy imported files into managed storage; atomic project/history JSON; missing-file recovery |
| `lib/core/service/audio_processing_backend.dart` | Backend interface, capabilities, typed job/progress/error/cancel contract |
| `lib/core/service/audio_analysis_service.dart` | Bounded PCM reading, envelope/statistics/FFT; isolate work and cancellation |
| `lib/core/service/processing_filter_builder.dart` | One validated FFmpeg filter configuration shared by preview and final export |
| `lib/features/UI/controller/audio_project_controller.dart` | Shared import/edit/render/export state and immutable jobs |
| `lib/features/UI/controller/audio_analyzer_controller.dart` | Analysis scheduling, cache, progress and source/config revisions |
| `lib/features/UI/controller/purchase_controller.dart` | Single purchase-stream subscription and verified entitlement lifecycle |
| `lib/features/UI/screen/audio_studio_screen.dart` | Main import → trim → adjust → preview → compare → export journey |
| `lib/features/UI/screen/audio_analyzer_screen.dart` | Measured waveform/spectrum, RMS/peak/clipping and file properties |
| `lib/features/UI/screen/sound_control_screen.dart` | Preserve Boost and Equalizer as reachable tools within Sound Control |
| `lib/features/UI/screen/export_history_screen.dart` | Real saved exports, reopen/share/delete and missing-file state |
| `lib/features/UI/screen/widgets/audio_waveform.dart` | Cached sample envelope, scrub/trim controls, semantics |
| `lib/features/UI/screen/widgets/audio_transport.dart` | Accessible play/pause/seek and original/enhanced comparison |
| `lib/features/UI/screen/widgets/audio_spectrum.dart` | Calibrated spectrum from actual PCM analysis |
| `lib/features/UI/screen/utils/studio_theme.dart` | Shared light/dark colors, type, spacing and adaptive surfaces |
| `test/audio/` and `test/features/` | DSP configuration/measurement, job lifecycle and workflow tests |
| `integration_test/studio_workflow_test.dart` | Import, trim, preview, comparison, export, history and regression flows |
| `docs/APP_STORE_REVIEW_NOTES.md` | Final verified reviewer steps and actual differences |
| `docs/RELEASE_VALIDATION.md` | Per-phase changed files, commands, platform results and device evidence |

Avoid a database dependency at this size: use app-owned audio files plus versioned atomic JSON unless measured requirements justify another store. History records must point to durable relative paths; Share is not proof that a user saved a copy outside the app.

### Backend and processing contract

Keep SoLoud for low-latency transport and compatible live effects. Adapt the existing FFmpegService behind AudioProcessingBackend for offline processing. Preview renders a bounded region from an immutable processing configuration; final export uses the same chain. Represent source time and trimmed time explicitly so comparison aligns the same samples and compensates filter latency. Bypass enhancement effects on the original comparison path, and offer clearly labeled gain-matched audition if implemented.

Analyze actual decoded PCM in bounded chunks; accumulate per-channel sum of squares, absolute peaks and near-full-scale sample counts. RMS dBFS is `20*log10(sqrt(sum(x²)/N))`; peak dBFS is `20*log10(max(abs(x)))`. Silence is −∞, not an invented floor reading. Define the clipping threshold and report it; near-full-scale samples indicate possible clipping, not proof of the original recording's distortion history. Use windowed FFT with documented scaling and real sample rate; mark segment analysis and full-file analysis separately. Do not use the player's small visualization buffer as full-file diagnostics. Metadata and decoded measurements should identify codec, sample rate, channels, duration, and meaningful bitrate/bit-depth fields.

Import validates readable content through probing, not extension alone; reject unsupported/DRM-protected inputs with an actionable error. Keep originals immutable. Use temporary render files, validate nonempty decodable output/duration/channel layout, then rename and commit history. On error/cancel remove partial output and release streams, sessions, subscriptions and PCM buffers. Enforce one active offline job initially, cancel only its session, and reject stale callbacks by job/config revision. Cache waveform envelopes, not entire PCM files, and bound temporary storage.

For normalization, use measured two-pass loudness normalization for final output when requested; short previews must be labeled as such and cannot imply full-file normalization measurements. Treat sample peak and true peak as different measurements and verify lossy encoded output separately. Do not promise that a digital ceiling prevents all audible distortion or sets safe acoustic loudness.

### Native extensions: conditional, not automatic

No custom Swift/Kotlin backend is initially necessary for the requested offline editing: the existing native FFmpeg package can already provide EQ, trim, decoding, normalization, denoising and limiting. First implement and validate that path to avoid two different DSP engines for the same export.

If profiling, format support or faithful continuous ten-band playback exposes a concrete gap, implement a versioned `smart_audio_studio/processing` MethodChannel plus job-scoped events behind the same backend interface. Candidate files are `ios/Runner/Audio/AudioProcessingPlugin.swift`, `ios/Runner/Audio/AudioProcessingEngine.swift`, and Android equivalents under `android/app/src/main/kotlin/m/volume/booster/audio/`. Register them only when implemented. AVAudioEngine/AVAudioFile/AVAudioUnitEQ/dynamics/Accelerate and suitable Android APIs would then be platform adapters; Flutter remains responsible for UI, state, projects and history. A shared native DSP library is preferable if identical custom processing is required on both platforms. Preserve channel layout/sample-rate semantics and define interruption/resource behavior explicitly.

## 6. Existing files requiring targeted modification

| Existing path | Intended change and justification |
| --- | --- |
| `lib/main.dart` | Inject shared controllers, theme mode and entitlements; make ads initialization failure nonfatal and platform-aware |
| `lib/features/UI/screen/home_screen.dart` | Four destinations: Audio Studio, Voice Lab, Audio Analyzer, Sound Control; adaptive rail/bar, preserve Settings/Purchase routes |
| `lib/core/service/audio_service.dart` | Real pause/seek/completion, bounded loading, source ownership, safe filter/lifecycle state and actual limiting |
| `lib/core/service/ffmpeg_service.dart` | Reuse algorithms; add validated argument lists, structured probe, shared filter builder, session-bound jobs/cancel and cleanup |
| `lib/features/UI/screen/boost_screen.dart` | Keep controls; shared state, gain unit parity, limiter, measured visualization and integrated export |
| `lib/features/UI/screen/equalizer_screen.dart` | Keep six presets and ten labels; faithful rendered ten-band audition/export; honest processing state |
| `lib/features/UI/screen/voice_booster_screen.dart` | Expand into Voice Lab without replacing its useful controls; intensity, comparisons, cancellation and cache invalidation |
| `lib/features/UI/screen/export_screen.dart` | Preserve audio/video formats/quality; bind to project config and centralized validated export/history |
| `lib/features/models/eq_presets.dart` | Retain values and names; share frequency constants if needed |
| `lib/features/UI/screen/utils/ThemeProvider.dart` and `app_themes.dart` | Functional persisted light/dark mode and consistent theme tokens |
| `lib/core/service/shared_preferance/Shared_Preferences.dart` | Preserve/migrate settings and valid premium data; reconcile daily export policy |
| `lib/features/UI/screen/PurchaseScreen.dart`, `splash_screen.dart`, `setting_screen.dart` | Single entitlement owner; store-derived price/offer eligibility; true manage-subscription action; accurate policy/support |
| `lib/features/UI/controller/AppLovinAds.dart` and `lib/configs/AppConfigs.dart` | Actual ad configuration, callback ownership, accurate privacy/product text; retain monetization behavior where valid |
| `ios/Podfile`, `ios/Runner.xcodeproj/project.pbxproj` | Resolve supported deployment targets and package integration based on build evidence |
| `ios/Runner/Info.plist` | Purpose descriptions that match implemented imports and any genuinely used capture permissions |
| `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`, `android/app/build.gradle.kts` | Scope permissions, remove release WebView debugging, validate SDK compatibility and configure real release signing |
| `pubspec.yaml` / `pubspec.lock` | Add test support only when needed; constrain reproducibility; change package versions only for demonstrated compatibility reasons |
| `test/widget_test.dart` | Replace unrelated starter assertions with provider-wrapped app/workflow coverage and plugin fakes |
| `README.md` | Real setup, platform support, processing limits and validation instructions |

Keep unrelated screen layout, platform runners and `ios_backup` untouched unless a documented dependency requires a change. No app/bundle ID change is proposed.

## 7. Compatibility and App Store risks

1. **Current iOS build blocker:** installed Xcode supports deployment targets 15.0…27.2, while several Pod targets remain at 9/12/13/14. Align compatible Pod minimums with the app's supported baseline; do not lower Runner's current 15.6 support boundary accidentally. Inspect generated Pod settings rather than blindly copying ios_backup.
2. **Current Android build blocker and dependency integration:** `:app:compileReleaseJavaWithJavac` fails because GeneratedPluginRegistrant.java line 39 references `net.jonhanson.flutter_native_splash.FlutterNativeSplashPlugin`, whose package is absent from the compilation classpath. Reconcile resolved package/plugin metadata and generated registration before attributing this to application Dart code or replacing packages; this baseline used existing resolution with `--no-pub`. The current iOS build also warns that ATT, AppLovin, FFmpeg, SoLoud and permission_handler lack Swift Package Manager support. CocoaPods is still used today; this warning is not proof those plugins fail compilation. Android emits upcoming Gradle/AGP/Kotlin compatibility warnings. Pin a tested toolchain before considering upgrades.
3. **Native artifacts:** installed FFmpeg uses `full-gpl` XCFrameworks and a `ffmpeg-kit-full-gpl` Android artifact. Record exact artifact provenance, notices and distribution requirements before release. No legal conclusion or automatic package replacement is made here. Also verify shipped architectures, binary size and current Android native-library/page-size requirements using the actual release artifacts.
4. **File access:** iCloud/document-provider paths can be temporary; copy into app-owned project storage. Explicitly test revoked/deleted files, Unicode/quotes in names, large imports, low storage and app relaunch. iPad share sheets currently supply no `sharePositionOrigin`; verify and add a proper anchor.
5. **Format parity:** a codec accepted by FFmpeg may not decode in SoLoud; validate a supported matrix. Video copy can fail if the original codec does not fit MP4. Do not silently drop video import/export while introducing Studio.
6. **Privacy:** local audio-processing code has no upload path, but AppLovin and ATT are present. The in-app statement “We do not collect, store, or transmit any personal data” does not account for third-party SDK behavior. Inspect SDK disclosures and built archive privacy manifests; no app-owned PrivacyInfo.xcprivacy exists. Avoid assuming dependency manifests are absent merely because Runner has none.
7. **Permissions:** iOS declares camera, photo library, location and tracking descriptions, but no microphone description; no recording workflow was found. Explain only permissions actually used. Android declares duplicate WRITE_EXTERNAL_STORAGE, legacy storage, READ_MEDIA_VIDEO and unrestricted cleartext traffic. Verify system-picker requirements and merged SDK permissions before narrowing them.
8. **Commerce:** hardcoded prices and universal three-day-trial text can differ from storefront prices and eligibility. Purchase updates currently grant permanent flags and cancellation UI is misleading. Rewarded premium must expire in the visible session as well as after reload. No App Store Connect products, age rating, privacy labels, screenshots or rejection message are available in the repository, so those cannot be certified from source.
9. **Advertising:** Android production IDs and interstitial IDs include placeholders. Some code falls back to demo IDs; invalid interstitial IDs are skipped. Confirm real configuration without changing it during this audit. Do not interrupt trimming, A/B listening or processing with unexpected tab-switch ads.
10. **UI:** ScreenUtil scaling alone is not an iPad layout. Existing fixed rows, icon-only gestures, hardcoded dark colors and hidden theme selection need adaptive layout, semantics, keyboard/focus where relevant, large-text and contrast checks.

Apple's Guideline 4.3 addresses indistinguishable apps; a coherent measured edit/compare/export workflow is a proposed differentiation, not evidence of approval. The exact rejection rationale is not in this checkout. A cosmetic renaming or tab rearrangement alone would not establish meaningful differentiation. See [Apple's App Review Guidelines, 4.3](https://developer.apple.com/app-store/review/guidelines/#spam).

For release, prepare an accurate description and screenshots from the implemented build; reconcile third-party data disclosures and permission text; verify age-rating/advertising answers and real subscription behavior. Apple requires accurate metadata, complete functionality and reviewer access; see [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/). No guaranteed approval is claimed.

## 8. Step-by-step implementation plan

### Phase 1 — Audit and baseline

Deliver this report and captured analyzer/test/build logs. Record source-controlled state and existing features. Identify build blockers before claiming existing device functionality is preserved. This phase does not repair source or change architecture.

### Phase 2 — Architecture and baseline stabilization

Fix the iOS Pod deployment-target blocker and Android missing native-splash plugin registration/classpath blocker with the current lockfile where possible. Reconcile generated plugin metadata through controlled dependency resolution before selecting any package changes. Replace the starter test. Add validated project/config/analysis/history models and small Provider controllers. Introduce a backend adapter around current FFmpegService, immutable jobs, argument-safe probing, and source-owned transport. Centralize verified entitlements while preserving valid access and settings. Document any package/toolchain change and its necessity.

Exit evidence: known fixtures decode, transport handles play/pause/seek/end/error, old gain/preset/video/voice paths remain reachable, both native builds succeed before broader feature work.

### Phase 3 — Audio Studio

Make Studio the main tab. Copy/validate imports, probe metadata, build chunked waveform envelopes, add transport and accessible trim handles, persist non-destructive trim/config state. Render previews using the final-export chain, align A/B at the same source position, implement progress/cancel and recoverable errors, validate/finalize output and commit history. Retain video audio export through the integrated export flow. Provide genuine empty/loading/success/error states.

Exit evidence: import → trim → preview → compare → export → share/reopen works for supported audio formats; cancel leaves no committed partial export; changing configuration invalidates stale renders.

### Phase 4 — Voice Lab

Reuse existing voice filters with valid denoise controls, speech/vocal adjustments, intensity and measured normalization. Add aligned waveform comparison, neutral original/enhanced playback, explicit reprocessing, cancellation and history-backed export. Label the processing as DSP. Use repeatable speech/noise fixtures and listen for pumping, speech damage and stereo artifacts.

Exit evidence: valid output at zero/default/maximum intensity; predictable controls; original remains unchanged; speech fixture tests and listening checks recorded. Do not imply a model or guaranteed intelligibility improvement.

### Phase 5 — Audio Analyzer

Add actual per-channel/full-file RMS, sample peak, clipping threshold/counts, windowed spectrum, band energy and format properties from decoded data. Use isolates/bounded chunk processing, cache by source identity/revision and expose analysis progress/cancel. Distinguish full-file from selected-region measurements and display silence/unsupported values honestly.

Exit evidence: known sine amplitude gives expected RMS/peak/frequency; silence produces −∞ readings; clipped and stereo fixtures produce correct counts/channel results; waveform coordinates and frequency axes are calibrated.

### Phase 6 — Sound Control

Keep boost, bass, ten EQ controls and all presets reachable under Sound Control. Correct gain conversions, explicitly stage headroom/limiting, remove fake measurement animations, synchronize state and route faithful ten-band processed audition/export through the shared configuration. If continuous live ten-band adjustment is required beyond rendered audition, implement and test the conditional native/shared DSP path before calling the EQ complete; do not map ten labels onto an eight-band filter.

Exit evidence: each frequency control changes its intended band in rendered output; all presets and boost attenuation work; preview/export parity and digital peak limits are verified with controlled fixtures.

### Phase 7 — UI/navigation and release content

Integrate four sections around one active project. Use compact navigation on phones and a rail/two-pane composition on iPad where space permits. Persist light/dark/system mode, add semantics and accessible touch targets, large-text support, responsive waveform/transport controls and complete states. Keep Settings/Purchase reachable. Repair truthful price/trial/subscription management and privacy text. Draft final description and reviewer notes only from the actual verified behavior; capture real screenshots.

Exit evidence: small/large iPhone, iPad portrait/landscape, large text, VoiceOver, light/dark, expired entitlement, denied tracking, missing file and unavailable store flows checked.

### Phase 8 — Full validation and review preparation

Run regression and integration tests across all existing and new workflows. Check output duration/sample rate/channels, trim tolerance, gain/EQ response, sample/true peaks as claimed, decoded codec validity and cancellation cleanup. Exercise long files, low memory/storage, corrupt media, unsupported/DRM content, app backgrounding, route changes, headphone/Bluetooth changes and interruptions. Test genuine purchases/restore/expiry/revocation in store test environments. Validate physical-device export/share and iPad anchors. Build signed/distributable artifacts with the intended release configuration and inspect permissions/manifests.

Reviewer notes must explain exact final navigation and a reproducible import → trim → enhance → A/B → analyze → export/history exercise, plus how paid features are accessible during review. Include a licensed sample recording if needed and disclose actual limitations. Do not submit draft feature claims as if implemented.

### Mandatory gate after each implementation phase

Run `flutter analyze`, relevant `flutter test` suites, `flutter build ios --release --no-codesign` for compilation, and `flutter build apk --release` for supported Android compilation. Use the controlled resolved dependencies; report any dependency resolution changes. No-codesign builds do not replace a signed archive/device validation. Fix compilation errors before advancing; record warnings, tests, output validation, modified files and device checks in RELEASE_VALIDATION. If a gate is blocked externally, record the failure accurately and do not mark the phase complete.

## Executed baseline checks and audit changes

| Check | Observed result |
| --- | --- |
| `flutter analyze --no-pub` | Exit 1: 182 issues = 0 errors, 25 warnings, 157 informational findings. Mostly unused legacy declarations/imports, print calls, naming, deprecated withOpacity and async-context concerns. |
| `flutter test --no-pub` | Exit 1: the single counter test fails. MyApp lacks its required ThemeProvider in the test, and counter assertions do not describe this application. No meaningful audio regression coverage exists. |
| `flutter build ios --release --no-codesign --no-pub` | Exit 1: Xcode target-integrity failures for Pod deployment targets below 15.0. This is a real failed baseline build, not an unsigned-build success. |
| `flutter build apk --release --no-pub` | Exit 1 after approximately six minutes: `:app:compileReleaseJavaWithJavac` fails at GeneratedPluginRegistrant.java:39 because package `net.jonhanson.flutter_native_splash` does not exist on the compile classpath. Native-splash registration/resolution needs investigation; no APK success is claimed. |

Raw logs are copied beside this report under `docs/audit_logs/`. No physical device or audio-output test ran. All five legacy feature workflows were traced in source; their full operational status remains unverified until the baseline builds and meaningful device tests pass.

Flutter automatically migrated the Xcode project during the baseline build. The sole tracked source/configuration change it produced was inspected and reverted to the pre-audit contents. Pre-existing `.DS_Store` index/worktree changes were left intact. Audit deliverables are documentation and logs only; application Dart/native code, dependency constraints and lockfiles were not intentionally changed.
