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
- **Vector tracing.** Each uploaded photo becomes a flat-colour SVG on-device,
  in three stages at 256px, ~250-450 ms per photo:
  1. **Kuwahara filter** - each pixel takes the mean of whichever of four
     overlapping quadrants is flattest. Inside a region that erases yarn
     texture; at a boundary the quadrant that avoids the edge wins, so edges
     stay sharp rather than blurring.
  2. **k-means in CIELab, luminance weighted to 0.4** - this is what keeps the
     six palette slots on the yarn colours. In RGB a shadowed navy and a lit
     navy are far apart and burn two slots; in Lab they differ mostly in L, so
     weighting L down collapses them. Each cluster is painted with its modal
     colour, not its mean, because the mean of a lit and a shadowed pink is a
     washed-out mauve.
  3. **[vtracer](https://github.com/visioncortex/vtracer)** on the already-flat
     image, so it only follows region boundaries: ~50 paths instead of ~585.

  Nothing is uploaded anywhere and no AI is involved. Measured on real photos:
  ~23-43 KB per block against ~320-430 KB for the JPEG, and a 168-cell grid
  paints in 86 ms against 352 ms, without holding 36 MB of decoded bitmaps.
  If the wasm can't load, blocks fall back to their original photos and
  everything else still works.

  Symmetry folding was tried and rejected: a granny square is symmetric under
  the 8 rotations and reflections of a square, but the blocks are not centred
  or rotationally aligned in the photos, so folding smeared the motif.
- **Fonts.** The page pulls Fraunces/Inter/Caveat from Google Fonts, so offline
  it falls back to system fonts. Embedding them would add roughly 200 KB.
