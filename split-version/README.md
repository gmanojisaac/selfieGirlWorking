# Split Selfie Girl shader

This folder is a self-contained split of the parent `selfie_modifyAndStudy.glsl`.
The initial split relocated whole definitions without changing shader behavior.
The camera-ray and soft-shadow bounds, interactive quality settings, tailored
ivory blazer and warm studio background have since been updated as described
below. The character animation is retained.

## File map and declaration order

| Order | Editable file | Contents |
| --- | --- | --- |
| 1 | `common.glsl` | Original shared SDF primitives, noise, math and camera helpers, followed by the study's quality settings (`INTERACTIVE`, `AA`, raymarch steps and hit threshold), detail, exposure and orbit constants, `moveHead`, animation globals and helpers (`animEye`, `animTurn`, `animBlink`), and `portraitCamera`. Also retains the original attribution and copyright notice. |
| 2 | `hair_sdf.glsl` | `sdHair` and `sdRearBraids`. |
| 3 | `body_clothing_sdf.glsl` | Suit geometry helpers (`suitBox`, `suitCross`, `suitEdge`, `suitTriangle`, `suitButton`, `suitHand`) and `mapSuit`: blazer, blouse, hands, trousers and shoes. |
| 4 | `face_sdf.glsl` | `map`: facial features, eyes, teeth, neck/shoulders, and final scene distance/material/UVW selection. |
| 5 | `raymarching.glsl` | `intersect`: bounding-volume clipping and camera-ray marching. |
| 6 | `lighting_shading.glsl` | `suitBrocade`, `suitStitches`, detail SDF `mapD`, `calcNormal`, `calcSoftshadow`, `calcOcclusion`, `renderGirl`, and `portraitTonemap`. |
| 7 | `studio_background.glsl` | Analytic room, wood grain, shelves, window, garden highlights, plants, leather chair and `portraitBackground(ro, rd)`. |
| 8 | `main_image.glsl` | `mainImage`: animation setup, camera, spatial supersampling, background/composition, vignette and final output. |

`map` remains one intact function because its face, eyes, hair/scalp and outfit
comparisons share transformed coordinates and update material and UVW outputs in
a specific order. Its calls to the separate hair and clothing SDF functions are
unchanged. This preserves the original calculations and comparison order.

Every function is defined before use. The runtime source order is `common.glsl`
followed by the seven Image modules above. There are no `#include` directives or
forward-declaration stubs.

## Regenerate

Requires Node.js; no npm packages or installation step are needed.

```powershell
cd D:\Projects\webgl\selfie-girl-shader\selfie-girl-shader\split-version
node bundle.mjs
node bundle.mjs --check
```

`bundle.mjs` concatenates the seven Image modules in the listed dependency order
into **`selfie_modifyAndStudy.glsl`**. It adds file-boundary comments and
normalizes line endings to LF; it does not transform shader expressions. Edit the
split files, then regenerate and refresh the preview. Do not edit the generated
shader. Paths are resolved relative to the script, so it also works when invoked
from another directory. `--check` verifies freshness without writing files and
returns a nonzero exit code if regeneration is needed. No build logs are saved.

`common.glsl` stays separate and is prepended once by the runtime. Changes to it
are picked up on preview reload without being duplicated inside the bundle.

## Shader Studio

Open this folder's **`selfie_modifyAndStudy.glsl`** and run **Shader Studio:
New Panel** (`shader-studio.view`). Its neighboring
`selfie_modifyAndStudy.sha.json` is the copied configuration and keeps the
original 1920 x 1080 resolution, textures, filters and wrapping.

The installed Shader Studio 1.0.2 selects the Image pass from the active GLSL
file and locates its config by matching the filename stem. Its schema does not
allow `passes.Image.path`, and its loader has no `#include` expansion. The
generated shader intentionally uses the original filename so the copied config
selects the bundle through that supported filename association. The existing
`passes.common.path` points to this folder's `common.glsl`.

## Interactive and high-quality modes

Set `#define INTERACTIVE` in `common.glsl` to `1` for a faster preview (currently
selected) or `0` for high-quality rendering. The switch lives in common because
it must be defined before both `intersect` and `mainImage` are compiled.

| Setting | Interactive (`1`) | High quality (`0`) |
| --- | --- | --- |
| `AA` | 1: one ray per pixel | 2: four rays per pixel |
| `RAYMARCH_STEPS` | 160 | 320 |
| `RAYMARCH_EPSILON` | 0.001 | 0.00035 |

Interactive mode trades fine geometry and edge quality for less rendering work.
It retains the full-character bounds, conservative 0.8 distance-step multiplier,
four normal probes per hit, and existing shadow/material calculations. High
quality retains the previous sampling and raymarch settings. The mode switch
does not change the configured resolution or guarantee a particular frame rate.

After changing the flag or shader modules, run from the workspace root:

```powershell
node selfie-girl-shader/split-version/bundle.mjs
```

Keep Shader Studio pinned to this folder's `selfie_modifyAndStudy.glsl`.
Use **Shader Studio: Manual Compile** if the preview has not refreshed.

Validation at the quality-switch update: both modes compiled and linked using the installed Shader Studio
1.0.2 wrapper and rendered without WebGL errors at 320 x 180, at 0, 9, 18 and
27 seconds in WebGL2/ANGLE SwiftShader. Every high-quality RGBA byte matched
the pre-change shader at those four times. Interactive front/back captures
were visually checked. These checks do not establish 1080p hardware frame rate.

## Ivory blazer and studio

The supplied ivory tailoring reference informs the warmer silk-linen color,
raised floral weave, stitched rolled lapels, shaped pocket flaps, elbow folds,
fitted waist and fuller back. Cloth relief affects the four normal probes;
camera and shadow rays still use the simpler base garment. The jacket retains
`focc = 0.86`, with directional key light, reduced fill and a grazing sheen.
Pattern boundaries fade smoothly to avoid false ridges in the normal calculation.

`studio_background.glsl` supplies a world-space room with walnut panelling,
bookshelves, a tall garden window, warm floor light, plants and a leather chair.
Room intersections are analytic; decorations are softened planar shapes. This
is a stylized procedural interpretation of the reference, with approximate
background lighting and focus, rather than a photographic reconstruction or
a fully modeled interior. It requires no additional textures or npm packages.

Both modes were rendered at 1920 x 1080 using the installed Shader Studio 1.0.2
wrapper in WebGL2/ANGLE SwiftShader. The front, key-lit oblique and rear views
were checked in high quality; interactive checks also cover both side views.
See `../../../shader-review/ivory-studio/` relative to this folder for
the capture script and full-resolution images. These renders do not establish
hardware frame rate or guarantee Shader Studio's driver-specific compile time.

## Browser preview

```powershell
node serve-preview.mjs
```

Open <http://127.0.0.1:8080/blazer-preview.html>. Stop the server with Ctrl+C.
To use another port, run `node serve-preview.mjs 8081`. The server serves only
this folder's preview runtime files and writes no logs.

The copied `blazer-preview.html` is byte-for-byte unchanged and defaults to the
generated `selfie_modifyAndStudy.glsl`. For a deterministic still, use
<http://127.0.0.1:8080/blazer-preview.html?time=0&width=480&height=270>.
Omit `time` to animate the orbit; the existing button/Space key pauses playback.

`texture0.png` and `texture2.png` are used by this Image shader. The unchanged
HTML also loads `texture3.png`, so all three texture files are copied unchanged.
The study renders its background in the Image pass and does not use the older
`bufferA.glsl` or `bufferB.glsl` passes.

## Soft-shadow bounds

`clipCharacterBounds` in `common.glsl` supplies a finite world-space cylinder
with radius **2.2** and Y bounds **[-6.6, 1.6]**, leaving room around the shoes,
body and animated hair. It intersects both the radial cylinder and the interval
between its caps with the caller's `[mint, tmax]` range before sampling `map`.
Misses, intersections behind the ray and empty intervals return `1.0` without
marching. Vertical and horizontal rays avoid division by zero; the starting
distance is at least `0.0001` so `k*h/t` remains finite when `mint` is zero.

The original `iCylinderY` helper is infinite along Y; its radius only bounds XZ.
Both `calcSoftshadow` and `intersect` call the shared clipping helper. The
128-step budget, distance stepping, penumbra formula and caller's maximum shadow
distance are preserved. Regenerate with `node bundle.mjs` after editing.

Validation of the bounds update: the regenerated shader compiled/linked and
rendered at 0, 9, 18 and 27 seconds in the existing WebGL2 preview. All 25 GPU
regression cases passed, covering radial/cap misses, intersections behind the
ray, empty intervals, tangency, vertical/horizontal and nearly parallel rays,
zero `mint`, clear rays, and occluders near the top, shoes and beyond the old
radius. Misses made zero `map` calls; all sampled points stayed inside the
bounding volume and the caller's ray interval. No generated logs are included.

## Camera-ray bounds

`intersect` in `raymarching.glsl` clips `[1.0, tmax]` with the same
`clipCharacterBounds` helper. A miss or empty interval returns `vec2(-1.0)`
before evaluating `map`, with `cma` and `uvw` initialized to zero. The existing
camera near distance of 1.0 and distance stepping are preserved. High-quality
mode retains the 320-step limit and hit threshold; interactive mode uses the
settings above. The loop stops when it reaches the clipped far distance.

The rebuilt shader compiled/linked and rendered four orbit views in the browser
preview. All 21 targeted GPU cases passed, including cap/side entry, parallel
and nearly parallel rays, empty intervals, the near-distance cutoff and hits
beyond the old radius. Hit distances matched analytic sphere intersections
within 0.001; material/UVW outputs and sample bounds were also checked.

## Initial split validation

- At the initial split, all 1,070 lines of the original Image shader were retained
  byte-for-byte in the editable modules. At that point the original `common.glsl`
  was an unchanged prefix of the new common file; it now also contains the shared
  bounds helper. The config, HTML and three textures are byte-for-byte copies.
- The original and copied HTML previews compiled and linked successfully in
  Chromium 151 using WebGL2/ANGLE SwiftShader, with no compiler, linker, page,
  resource-loading or WebGL errors.
- Before the shadow-bounds update, every RGBA byte matched between original and bundled renders at times
  `0`, `0.14`, `9`, `18`, and `27` seconds at 320 x 180, and at `0` and `18`
  seconds at 180 x 320. These are sampled comparisons, not an exhaustive check
  of every animation time or GPU driver.
- `node bundle.mjs --check` passed. No generated validation logs are included.
