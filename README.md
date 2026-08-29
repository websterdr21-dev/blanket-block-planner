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

A new APK is only needed if a native plugin is added or removed, or the icon
changes. When that happens the bundle must not run on the old APK, so bump
`versionCode` in `android/app/build.gradle`, rebuild, and publish with a
matching floor:

```bash
powershell -File publish-update.ps1 -MinVersionCode 2
```

That writes `minVersionCode` into the manifest. On launch the app compares it
against its own `versionCode`: if the installed APK is older it shows a notice
linking to the download page and **skips staging the bundle entirely**, since a
bundle expecting native code the app does not have would crash it. The floor is
carried forward by later publishes, so a routine update never silently lowers
it. If the manifest has no floor, or the version cannot be read, the app never
nags.

**Always publish a bundle straight after building an APK.** The app has no way
to tell whether the manifest is older or newer than the code baked into the
APK, so it applies whatever the manifest names. If the manifest still points at
an older bundle, a fresh install downgrades itself on first launch.

## Notes

- **Photos are re-encoded through a canvas on the way in.** Phones save
  pictures in formats their own WebView cannot draw - HEIC on recent Samsungs
  above all - and the gallery hands them over untouched. Tracing failed, the
  code fell back to showing the original, and the original was the one thing
  guaranteed not to render: every block came out as a broken-image icon with no
  explanation. Decoding into an Image and redrawing yields a JPEG that always
  displays, and shrinks a 4MB phone photo to ~240KB. A file the phone genuinely
  cannot read is now reported on the row and skipped rather than added, and a
  block already saved with unusable art says so on its card.
- **No `aspect-ratio`.** Square cells use the padding-top trick instead.
  `aspect-ratio` needs Android WebView 88; on anything older every square
  collapses to no height, which looks exactly like the pictures failing to
  load. Settings carries a diagnostics readout that probes the technique
  directly, so this is answerable from her phone rather than by guesswork.
- **Four tabs.** Blocks, Layout, Guide, Settings. The page used to be one long
  scroll; the joining guide needed somewhere to live that was not below the
  layout she is trying to follow it against.
- **The guide shows photographs, everywhere else shows drawings.** In the guide
  she is holding the real block against the screen, so the photo is what helps;
  in a grid square at 18px the flat drawing is the only thing still readable.
  A separate 360px JPEG is kept per block for this, ~34KB, rather than the
  900px working copy at ~240KB which a dozen of would not fit in the save.
  Blocks added before this have no photo kept and fall back to the drawing.
- **Joining guide.** Walks her through assembling the blanket one seam at a
  time, the way blankets actually go together: every side seam row by row, then
  one seam per pair of rows. A 4x5 blanket is 4x4 + 3 = 19 steps. Each step
  shows the two pieces, which edge, how many seams remain, and a swatch of the
  colour to sew in - taken from a ring set in from the edge of the flattened
  image, since the outermost pixels are the crop padding rather than the yarn.
- **Editing by hand.** Tap one square then another to swap them. Dragging is
  fiddly on a phone; two taps are hard to get wrong. An edited layout says so
  rather than keeping a claim about a pattern it no longer follows.
- **Sharing.** Draws the layout to a PNG and hands it to the phone's share
  sheet, falling back to saving the picture where that is unavailable.
- **Pattern styles.** Six layouts to choose from: Scattered (the original, no
  two of the same touching), Stripes, Diagonals, Checkerboard, Framed and
  Rings. Each of the five geometric styles is expressed as an *ideal* - given a
  row and column it says which block it would like there - and a single fitting
  routine reconciles that with her actual quantities: it places what it can,
  then fills the gaps with what is left, preferring a block that does not match
  its neighbours. Hand-made blocks never divide neatly, so a style that
  demanded exact counts would be useless. The note under the grid reports how
  much of the pattern the stock covered; counting "conflicts" only makes sense
  for Scattered, since in every other style matching blocks touching is the
  entire point.
- **Icon.** Nine squares in the app's own palette on ink navy, arranged so no
  two of the same colour touch - the rule the app exists to apply. Replaces the
  default Capacitor logo. Legacy PNGs at all five densities plus the adaptive
  foreground and a navy adaptive background. Icons are native, so this is one
  of the few changes that cannot be shipped as a live update.
- **Saved work.** Blocks, the grid size and the generated layout are kept in
  `localStorage`, so Android killing the app in the background does not cost a
  morning of photographing. Only the traced SVG is stored, never the original
  photo: a phone photo is ~430 KB as a data URL and a dozen would blow the ~5 MB
  budget alone, while the SVGs are ~30-60 KB - four blocks plus their layout
  come to ~164 KB. On the way back in the SVG stands in for the photo, which is
  what the app draws anyway. If the write fails, or storage is blocked, the app
  says so rather than letting her believe it saved. "Start a new blanket"
  clears it.
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

  Nothing leaves the phone: no service is called, no model is downloaded, and
  the project has no AI API anywhere in it. That is not the same as "no AI" -
  step 3 is k-means, which is a machine-learning algorithm, and the layout
  engine in the next section is a constraint solver, which is classical AI.
  Both run entirely on the device. ~16-50 KB per block
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
