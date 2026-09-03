# Selfie Girl — GLSL Shader Project (Shader Studio)

A real-time, multi-pass **GLSL fragment shader** that raymarches a portrait of a girl
posing in front of a snowy mountain landscape. The scene animates by itself (head
turns, blinking, hair and water movement) — no mouse or keyboard input needed.

This project is a port of the Shadertoy shader
**["Selfie Girl" (WsSBzh) by Xor](https://www.shadertoy.com/view/WsSBzh)** into a
[Shader Studio](https://marketplace.visualstudio.com/items?itemName=teaqu.shader-studio)
project for VS Code. Everything runs live in your editor: edit the code and the
preview updates immediately.

---

## 1. What you need

| Requirement | Notes |
|---|---|
| **VS Code** | Free: <https://code.visualstudio.com> |
| **Shader Studio extension** | Search "Shader Studio" (publisher `teaqu`) in the Extensions panel, or install from the link above |
| **A GPU with WebGL2** | The preview renders in a WebGL2 canvas inside VS Code (integrated GPUs work, but a discrete GPU is smoother) |

That's it — no compilers, no Node, no packages.

---

## 2. Quick start (2 minutes)

1. **Unzip** the project folder (e.g. `selfie-girl-shader.zip`).
2. In VS Code: **File → Open Folder…** and select the unzipped `selfie-girl-shader` folder.
3. Open **`selfie.glsl`** (the "Image" pass — the final output).
4. The Shader Studio preview opens automatically (look for the Shader Studio toolbar).
   After a moment the girl and the snowy landscape appear, animating in real time.
5. Click the **Config** button in the toolbar to see the multi-pass pipeline
   (`BufferA → BufferB → Image`) and the input channels.

> If you don't see a preview, click the Shader Studio icon in the activity bar
> or run the command `Shader Studio: Toggle Preview`.

---

## 3. What this project is

A **raymarched scene** written in GLSL ES 3.00, split into four cooperating shaders:

| Pass | File | What it does |
|---|---|---|
| Common | `common.glsl` | Shared math: SDF primitives, noise functions, camera, animation helpers. Prepend-ed to every pass. |
| Buffer A | `bufferA.glsl` | Renders the **background landscape** (mountains, snow, forest, sky, water) and writes the scene **depth into the alpha channel**. Also stores the camera matrix for temporal antialiasing (TAA). |
| Buffer B | `bufferB.glsl` | Reads Buffer A and performs a **depth-of-field gather** (blur depending on distance), passing the depth along. |
| Image | `selfie.glsl` | The main output: **raymarches the girl** (skin, hair, eyes, hoodie), composites her over the landscape using the depth from Buffer B, then applies tone mapping, vignette and color grade. |

### Input channels

| Channel | Bound to | Used for |
|---|---|---|
| `iChannel0` | `texture0.png` | 32³ **value-noise volume** (stored as a 2D slice atlas) — landscape displacement, girl's pores, hoodie knit. |
| `iChannel1` (Buffer A) | itself (feedback) | Previous frame for temporal antialiasing. |
| `iChannel1` (Buffer B) | Buffer A | Landscape color + depth for depth of field. |
| `iChannel1` (Image) | Buffer B | Scene color + depth so the girl is placed correctly over the background. |
| `iChannel2` | `texture2.png` | 64×64 noise tile — snow/terrain detail, water ripples, iris detail. |
| `iChannel3` | `texture3.png` | 256×256 random speckle — fine stochastic detail. |

The pass wiring, channel bindings and resolution are all defined in
**`selfie.sha.json`** (Shader Studio's config format).

---

## 4. How to change things

- **Tweak the look** — edit any `.glsl` file; the preview hot-reloads. Good starting points:
  - `selfie.glsl`: color grade near the bottom (`// grade` section), animation speeds (`animTurn`, `animHead`, `animBlink`).
  - `bufferA.glsl`: mountain shape and sky colors in `renderBackground`.
  - `common.glsl`: `fbm1` octaves (density of the noise), `smin`/`smax` (blending of shapes).
- **Change the pipeline** — open the **Config** panel; you can add/remove channels,
  point a channel at a different texture, or change the output resolution.
- **Replace textures** — put a PNG in the folder and update its `path` in `selfie.sha.json`.
  Keep the sizes/format the noise functions expect (see the channels table above).
- **Resolution** — set in `selfie.sha.json` → `passes.Image.resolution`
  (currently 1280×720).

> ⚠️ **Important (why this port is special):** Shader Studio binds every texture
> channel as a **`sampler2D`** — it does not support `sampler3D` volume textures.
> The original shader sampled a true 3D noise texture, so in this port the 32³ volume
> is stored as a **2D slice atlas** (`texture0.png`, 33×1056: 32 slices of 33×33,
> with duplicated edge row/column for seamless filtering). The noise functions in
> `common.glsl` (`noise1`, `fbm1`) reconstruct the trilinear interpolation manually.
> Keep that in mind if you add new code that samples `iChannel0` — call
> `noise1(iChannel0, …)` or `fbm1(iChannel0, …)` with a `vec3` lattice coordinate.

---

## 5. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Invalid shader configuration: Config must have a valid version string / Config must have an Image pass / Invalid pass name: …` | The `selfie.sha.json` file doesn't match Shader Studio's expected format. It must start with `"version": "1.0"` and contain a `"passes"` *object* with an `"Image"` key (not an array). See the included `selfie.sha.json` as the reference. |
| Preview is black / very slow | WebGL2 not available or software rendering. Close other GPU-heavy apps, update drivers, or lower the resolution in `selfie.sha.json` (e.g. 640×360). |
| Texture missing / purple preview | The PNG files must sit next to the `.glsl` files (paths in `selfie.sha.json` are relative to the config file). |
| Preview doesn't open | Run the command `Shader Studio: Toggle Preview`, or make sure the file you have open is `selfie.glsl` (the Image pass drives the output). |

---

## 6. Project layout

```
selfie-girl-shader/
├── README.md            ← this file
├── selfie.glsl          ← Image pass (girl + final composite) — open this file
├── bufferA.glsl         ← landscape pass + depth/TAA
├── bufferB.glsl         ← depth-of-field pass
├── common.glsl          ← shared code (noise, SDF helpers, camera)
├── selfie.sha.json      ← Shader Studio config: passes, channels, resolution
├── texture0.png         ← 33×1056 noise-volume atlas (iChannel0)
├── texture2.png         ← 64×64 noise tile (iChannel2)
└── texture3.png         ← 256×256 speckle (iChannel3)
```

---

## 7. Sharing

Hand this whole folder (or the ZIP) to a colleague. They only need VS Code + the
Shader Studio extension — everything else is inside the folder. To create a fresh
ZIP yourself: select the files above, right-click → **Compress to ZIP**, and send it.

---

## 8. Credits & license

- **Original shader:** "Selfie Girl" by **Xor** — <https://www.shadertoy.com/view/WsSBzh>
- This port re-generates the noise textures procedurally, so fine snow/hair detail
  differs slightly from the original — the composition and math are the same.
- Shadertoy shaders default to **Creative Commons BY-NC-SA 3.0** (attribute the
  author; non-commercial; share alike). Check the shader page for the exact license
  if you plan to use it beyond personal/educational previewing.