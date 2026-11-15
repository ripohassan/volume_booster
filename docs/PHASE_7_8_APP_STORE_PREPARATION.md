# Phase 7–8 release preparation

## Implemented navigation and UI

The primary journey is now **Audio Studio → Voice Lab → Audio Analyzer → Sound Control**. Compact layouts use a Material bottom navigation bar; widths of 700 logical pixels or more use a navigation rail. Sound Control retains Boost, Equalizer, and Video Export. Settings remains reachable on large layouts; compact users can reach existing Settings from the legacy UI only and should receive a dedicated settings action before submission.

Theme choice and Light/Dark/System mode are persisted with SharedPreferences. Existing hard-coded legacy screens remain an incremental visual-consistency limitation.

## Verified build checks

Run after UI changes:

* `flutter analyze` (no compile errors)
* `flutter test`
* `flutter build apk --release`

No signed iOS archive, device purchase test, share-sheet test, Bluetooth test, interruption test, low-storage test, or App Store sandbox test was performed by this repository automation. These must not be represented as completed.

## Privacy and permissions findings

* AppLovin MAX, ATT, and the iOS tracking description are present.
* `Info.plist` also declares Photo Library, Camera, and Location usage descriptions. Confirm each is necessary for shipped functionality; remove unused permissions and align purpose strings with the privacy nutrition label.
* Android declares Internet, ad ID, external/media storage, audio settings, and wake-lock permissions. Scoped-storage behavior and all SDK data practices require device/store-console review.
* Privacy Policy and Terms actions currently include placeholder/TODO copy and must be replaced with hosted, accurate URLs before submission.
* The repository does not contain sufficient evidence to complete Apple privacy-manifest/third-party-SDK disclosure review. Review every XCFramework/package privacy manifest and AppLovin’s current disclosure before upload.

## Subscription verification findings

Products in code: `v.booster.weekly`, `v.booster.monthly`, `v.booster.yearly`.

Apple entitlement checks are native-store based. Android deliberately remains `verificationRequired` until a trusted verifier is configured. Local booleans do not establish premium entitlement. Localized price, trial eligibility, expiry/revocation, restore, and reviewer access require a Sandbox/TestFlight pass with products configured in App Store Connect.

## App Store metadata draft

**Title:** Smart Audio Studio

**Subtitle:** Enhance, compare and export audio

**Promotional text:** Import audio, trim it precisely, compare original and enhanced playback, and export your result.

**Keywords:** audio editor, equalizer, voice enhancement, waveform, trim, spectrum

**Description:**

Smart Audio Studio is a local audio workflow for importing a recording, reviewing its waveform, trimming a selection, applying volume, bass, equalizer or voice processing, and comparing the original with the processed result before export. Audio Analyzer displays sample-based RMS, peak, clipping indicators, and a measured frequency spectrum. Export history keeps completed outputs available for playback and sharing.

Processing options include gain, bass, a ten-band rendered equalizer, noise reduction, speech clarity, vocal enhancement, loudness normalization, and peak limiting. Results depend on the source material; no hearing or restoration claims are made.

## Screenshot checklist

Capture real screenshots from a release-mode device or simulator, with a genuine imported audio file:

1. Audio Studio import/empty state.
2. Waveform with a selected trim range.
3. Voice Lab controls and processed preview selected.
4. Audio Analyzer measured RMS/peak/spectrum result.
5. Sound Control Boost and Equalizer controls.
6. Export History with a completed output.

Do not use mockups, decorative analyzers, or screenshots containing placeholder pricing.

## Reviewer notes draft

1. Open **Audio Studio** and choose **Import audio**.
2. Select an audio file, tap the waveform to seek, and long-press/drag a trim handle.
3. Adjust a processing control and choose **Process preview**.
4. Switch **Original** and **Enhanced** to compare aligned playback.
5. Tap the Analyzer icon to inspect sample-based RMS, peak, clipping indicators, and spectrum.
6. Return to Studio and choose **Export**; open Export History from the history icon.
7. Premium actions show the purchase flow. Use the supplied sandbox reviewer account for subscription verification and Restore Purchases.

## Guideline 4.3 response draft

Smart Audio Studio is not limited to volume adjustment. Its primary user journey is Import → Analyze → Trim → Enhance → A/B Compare → Export → History. It provides non-destructive project management, decoded-sample waveforms, trim-aware rendering, voice-specific DSP, a sample-based analyzer, original/enhanced comparison, validated exports, and durable export history. The app preserves source files while allowing users to inspect and process their own audio locally.

This is a functional-differentiation statement only; it does not guarantee App Review approval.
