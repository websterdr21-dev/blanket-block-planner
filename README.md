# Blanket Block Planner

Offline Android app for planning crochet/knit blanket layouts. Upload photos of
your blocks, name them, say how many of each you have, and it arranges them so
no two of the same pattern touch.

The whole app is `www/index.html` — plain HTML, CSS and vanilla JS, no backend,
no build step, no framework. Capacitor wraps it as an APK.

## Layout

```
www/index.html        the app
www/vtracer.js        vtracer WebAssembly glue (photo -> flat-colour SVG)
www/vtracer.wasm
android/              Capacitor's native Android project
docs/live/            published live-update bundles, served by GitHub Pages
publish-update.ps1    ship a new version to her phone
```

## Building the APK

Needs **JDK 21** and the **Android SDK (API 36)**.

```bash
npx cap sync android
```

```bash
cd android && ./gradlew assembleDebug
```

The APK lands at `android/app/build/outputs/apk/debug/app-debug.apk`. Sideload
it once; after that, updates go over the air.

## Shipping an update

Edit `www/index.html`, commit, then:

```bash
powershell -File publish-update.ps1
```

That zips `www/`, drops it in `docs/live/`, points `docs/live/manifest.json` at
it, and pushes. GitHub Pages serves it. Her app reads the manifest on its next
launch, downloads the bundle in the background, and starts on the new version
the launch after that. No new APK, no new link.

Requires GitHub Pages to be enabled on this repo (source: `main` branch,
`/docs` folder), which requires the repo to be public.

A new APK is only needed if a native plugin is added or removed.

**Always publish a bundle straight after building an APK.** The app has no way
to tell whether the manifest is older or newer than the code baked into the
APK, so it applies whatever the manifest names. If the manifest still points at
an older bundle, a fresh install downgrades itself on first launch.

## Notes

- **Photos.** Two sources: *Take a photo* uses `capture="environment"`, which
  Capacitor sends straight to the Android camera app, and *Choose from gallery*
  opens the picker for as many photos as she likes. Neither needs a runtime
  permission - the camera app and the system picker handle that themselves.
- **Vector tracing.** Each uploaded photo is traced on-device to a flat-colour
  SVG with [vtracer](https://github.com/visioncortex/vtracer), at 160px with a 1px
  blur so yarn texture is not mistaken for detail. Nothing is uploaded anywhere
  and no AI is involved. Measured on a real 1528px photo: the SVG is ~4x
  smaller than the JPEG and a 168-cell grid paints in 86 ms against 352 ms for
  the photos, without holding 36 MB of decoded bitmaps. If the wasm can't load, blocks fall
  back to their original photos and everything else still works.
- **Fonts.** The page pulls Fraunces/Inter/Caveat from Google Fonts, so offline
  it falls back to system fonts. Embedding them would add roughly 200 KB.
