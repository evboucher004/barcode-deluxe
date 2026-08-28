# Barcode Deluxe

Flutter app that turns text into a barcode. Input via textbox or camera (OCR).
The barcode type is auto-detected from the content, with a manual override dropdown.

## Detection rules (in order)

1. 8 digits + valid checksum -> EAN-8
2. 12 digits + valid checksum -> UPC-A
3. 13 digits + valid checksum -> EAN-13 (labeled ISBN for 978/979 prefix)
4. 14 digits + valid checksum -> ITF-14
5. Digits only, even length, 4-30 long -> ITF
6. Printable ASCII up to 48 chars -> Code 128
7. Everything else (URLs, long text, unicode) -> QR code

## Result screen

Top to bottom: the **Barcode type** dropdown, the barcode itself, **Scan new
text**, the editable encoded-text box, and a last row of **Regenerate** and
**Download**. The two share that row evenly, so they are always the same size.
Download writes the rendered barcode to the photo gallery.

Editing the box and pressing Regenerate (or Enter in the box) re-encodes with
the new value: detection runs again, so the symbology can change, and any
manual override from the dropdown is dropped along with the content it
belonged to. Regenerate is disabled whenever the box already matches the
barcode on screen, so it can never redraw what is already there — surrounding
whitespace, and an emptied box, do not count as a change.

The box holds the *encoded* string, so an edit made here is taken literally:
the Advanced Options are not re-applied to it. Regenerating records the new
string in the recent inputs like any other barcode.

Tapping any empty part of the screen dismisses the keyboard.

## Recent inputs

Focusing the text box on the home screen shows the last five strings that were
actually encoded, newest first. Tapping one pastes it into the box, leaving the
field focused. Re-encoding a string moves it back to the front rather than
duplicating it.

What is stored is the *encoded* string, i.e. after the Advanced Options have
been applied, so tapping an entry reproduces exactly the barcode you saw. The
list is saved to `shared_preferences` and reloaded in `main()`, so it survives
a restart.

Everything that becomes a barcode is recorded, including a scan started from
**Scan new text** on the result screen. That path replaces the result route
without returning through the home screen, so the home screen tracks
`RecentInputsStore.listenable` rather than only the entries it records itself.

Like the Advanced Options panel it renders into the app `Overlay`, so showing
it costs no layout space and the buttons beneath never move. It does float
over them while visible; the keyboard's Done key still generates.

## Advanced options

Both the home screen and the scan screen carry an **Advanced Options** button
that drops down a panel of toggles. They are applied to the input (typed or
scanned) before detection runs, so they can change which symbology is chosen.

| Toggle | Default | Effect |
| --- | --- | --- |
| Remove Spaces | **on** | Strips all whitespace, including tabs and newlines |
| Alphanumeric only | **on** | Drops punctuation, symbols and non-ASCII letters; leaves whitespace alone |

The two are independent. `Alphanumeric only` deliberately spares whitespace so
that `Remove Spaces` is the only control over spacing — with it unchecked,
`AB-12 cd/34` encodes as `AB12 cd34`, keeping the space.

Both are on by default, so `HELLO-123 x` encodes as `HELLO123x` out of the
box. The result is trimmed either way.

Both settings are saved to `shared_preferences` on every change and reloaded
in `main()` before the first frame, so they persist between sessions and are
shared by both screens.

The panel is rendered into the app `Overlay`, so opening it does not move any
other element on the screen. `AdvancedOptions` is self-contained and drop-in
(`const AdvancedOptions()`) for reuse on other screens.

On the scan screen the button is pinned to the very bottom, so it opens
upward (`direction: AdvancedOptionsDirection.up`). The panel covers the zoom
row and shutter, and the shutter is additionally disabled while the panel is
open, so a photo cannot be taken mid-change.

## Layout

```
lib/
  main.dart               app shell; loads saved settings before first frame
  barcode_detector.dart   detection heuristics + checksum validation
  models/
    advanced_options_value.dart   toggle values + the input transform
  services/
    advanced_options_store.dart   shared_preferences persistence
    recent_inputs_store.dart      last five encoded strings
  screens/
    home_screen.dart      text input, entry point to both flows
    scan_screen.dart      camera preview, resizable capture box, OCR
    result_screen.dart    barcode render, type override, save to gallery
  widgets/
    advanced_options.dart button + overlay panel, reusable
test/
  barcode_detector_test.dart   detection rules
  widget_test.dart             screens, options, transforms, persistence
```

## Setup

The `android/` and `ios/` platform folders are checked in and already
configured (permissions and deployment targets are set — see below). To run:

```bash
flutter pub get
flutter run
```

### Platform configuration

Already applied in this repo; listed here so it survives a regenerated
platform folder.

**Android** — `android/app/src/main/AndroidManifest.xml` declares:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

`minSdk` inherits Flutter's default, which is already >= 21 (the ML Kit
minimum), so it is not pinned in `build.gradle.kts`.

**iOS** — `ios/Runner/Info.plist` declares:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to photograph text for barcode generation.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Used to save generated barcodes to your photo library.</string>
```

`NSCameraUsageDescription` is mandatory — without it iOS terminates the app
as soon as the scan screen initialises the camera.

The deployment target is 15.5 (required by `google_mlkit_text_recognition`),
set as `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj`.
This project uses Swift Package Manager rather than CocoaPods, so there is no
`Podfile` to set `platform :ios` in.

## Tests

```bash
flutter test
```
