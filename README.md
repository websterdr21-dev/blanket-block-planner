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
- **Vector tracing.** Each uploaded photo becomes a flat-colour SVG on-device
  in four stages, ~120-260 ms per photo end to end:
  1. **Find the block.** Photos are taken on a table or on the blanket, so much
     of the frame is background; left in, it takes palette slots the yarn
     colours need and gets drawn into the SVG. The background is flooded
     inwards from the frame edge and whatever the flood never reaches is the
     block. Two details make it hold up: seeds come only from the dominant
     edge colours, so a block running off the side of the photo does not seed
     the flood from its own pixels; and the box comes from row/column density
     rather than the outermost block pixel, because a loose yarn tail is the
     same colour as the block and would drag the box to the frame edge. The
     crop is re-sampled from the full-resolution original, so it costs no
     detail. Measured: background inside the box fell from 33/35/22/12% of the
     frame to 7/8/8/6%. Anything suspicious falls back to the whole photo.
  2. **Kuwahara filter** at 256px - each pixel takes the mean of whichever of
     four overlapping quadrants is flattest. Inside a region that erases yarn
     texture; at a boundary the quadrant avoiding the edge wins, so edges stay
     sharp rather than blurring. Summed-area tables make it O(1) per quadrant.
  3. **k-means in CIELab, luminance weighted to 0.4**, over the distinct
     colours rather than all 65k pixels. Weighting L down is what keeps the
     palette on the yarn: in RGB a lit navy and a shadowed navy are far apart
     and burn two slots. Seeding is k-means++, not by lightness - seeded by
     lightness a small sage-green centre surrounded by navy and cream never won
     a cluster and came out cream. Each cluster is painted with its modal
     colour, since the mean of a lit and a shadowed pink is a washed-out mauve.
  4. **[vtracer](https://github.com/visioncortex/vtracer)** on the flat image,
     so it only follows region boundaries.

  Nothing is uploaded anywhere and no AI is involved. ~16-50 KB per block
  against ~320-430 KB for the JPEG, and a 168-cell grid paints in 86 ms against
  352 ms for photos, without holding 36 MB of decoded bitmaps. If the wasm
  can't load, blocks fall back to their original photos and the rest still works.

  Two things were tried and rejected. Folding the image over the 8 symmetries
  of a square would give a perfectly symmetric motif, but the blocks are not
  centred or rotationally aligned in the photos, so it smeared them into a
  blob. Raising vtracer's colorPrecision above 2 on the already-flat image
  collapsed the green centres into the surrounding pink.
- **Fonts.** The page pulls Fraunces/Inter/Caveat from Google Fonts, so offline
  it falls back to system fonts. Embedding them would add roughly 200 KB.
