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

## Notes

- **Vector tracing.** Each uploaded photo is traced on-device to a flat-colour
  SVG with [vtracer](https://github.com/visioncortex/vtracer). Nothing is
  uploaded anywhere and no AI is involved. If the wasm can't load, blocks fall
  back to their original photos and everything else still works.
- **Fonts.** The page pulls Fraunces/Inter/Caveat from Google Fonts, so offline
  it falls back to system fonts. Embedding them would add roughly 200 KB.
