# Compatibility Matrix: Modern Iris (1.20.x+) vs Legacy OptiFine (1.12.2)

Aetheron maintains **two dedicated, independently tested shader implementations** (`modern/` and `legacy_1.12.2/`) that share a unified visual identity and configuration structure while strictly respecting each platform's OpenGL/GLSL specifications and Minecraft engine differences.

---

## Technical Architecture Differences

| Capability / Spec | Modern Edition (`modern/`) | Legacy Edition (`legacy_1.12.2/`) |
| :--- | :--- | :--- |
| **Target Minecraft** | Minecraft 1.20.x, 1.21.x+ | Minecraft 1.12.2 |
| **Target Loader** | Iris Shaders + Sodium (also OptiFine 1.20+) | OptiFine HD U G5 / G6 (1.12.2) |
| **GLSL Profile** | `#version 330 compatibility` | `#version 120` |
| **Fragment Output Syntax** | `layout(location = N) out vec4` + `/* RENDERTARGETS: ... */` | `gl_FragData[N]` + `/* DRAWBUFFERS:... */` |
| **Sampler Syntax** | `texture()`, `uniform sampler2D gtexture` | `texture2D()`, `uniform sampler2D texture` |
| **Varying / Attribute Syntax** | `in` / `out` / `flat out int` | `attribute` / `varying` (float-encoded MatID) |
| **Max Color Attachments** | Up to 16 (uses 8 lean buffers) | Hard limit of 8 (`colortex0`–`colortex7`) |
| **Cutout Alpha Test** | Uses Iris `alphaTestRef` uniform | Explicit alpha threshold (`0.1` / `0.004`) |
| **Block ID Format** | **Post-Flattening** (`short_grass`, `oak_leaves`, `soul_lantern`, `sculk_sensor`, `copper_bulb`, `cherry_leaves`, `pale_oak_leaves`) | **Pre-Flattening** (`tallgrass`, `double_plant`, `leaves`, `leaves2`, `flowing_water`, `stained_glass`, `lit_redstone_lamp`) |
| **Dimension Mapping** | `dimension.properties` (`minecraft:overworld`, `the_nether`, `the_end`, modded `*` fallback) + `world0`/`world-1`/`world1` | OptiFine `world0/`, `world-1/`, `world1/` folders |
| **Translucent Entity Ordering** | `separateEntityDraws = true`, `particles.ordering = mixed` | OptiFine 1.12.2 fixed ordering (translucent entities pre-deferred) |
| **Biome Detection Uniforms** | Iris `biome_category` (`CAT_DESERT`, `CAT_ICY`, `CAT_SWAMP`, etc.) smoothed on CPU | 1.12.2 `biome` IDs (`BIOME_DESERT`, `BIOME_SWAMPLAND`, `BIOME_ICE_PLAINS`, etc.) smoothed on CPU |
| **Weather / Status Uniforms** | `rainStrength`, `wetness`, `thunderStrength`, `blindness`, `darknessFactor` | `rainStrength`, `wetness`, `blindness` (storm derived smoothly from `rainStrength` & `wetness`; `thunderStrength` & `darknessFactor` omitted cleanly) |
| **Entity Classification** | `entity.properties` (`entityId` for glowing mobs, End Crystals, Allays, Glow Squids) | Standard entity shading (`entityId` & `entity.properties` unavailable in 1.12.2) |

---

## Features That Cannot Be Identical Across Both Generations

1. **Modern Blocks & Entities (1.13–1.21+)**:
   - Underwater plants (`kelp`, `seagrass`), soul fire/lanterns, froglights, amethyst clusters, sculk blocks, copper bulbs, cherry/mangrove/pale oak leaves, and Warden `darknessFactor` exist only in Modern Minecraft and are handled exclusively in `modern/shaders/`.
2. **Thunderstorm Dedicated Uniform (`thunderStrength`)**:
   - Iris and modern Minecraft expose `thunderStrength` directly. OptiFine 1.12.2 does not provide a built-in `thunderStrength` uniform, so the Legacy edition derives smooth storm intensity from `rainStrength` and `wetness` to avoid undefined-uniform compilation errors.
3. **Separate Translucent Entity Draws (`separateEntityDraws`)**:
   - Iris allows deferring translucent entities and mixed particles until after the opaque `deferred1` pass (`separateEntityDraws = true`, `particles.ordering = mixed`). In OptiFine 1.12.2, these directives are unsupported and omitted cleanly so the pack loads without warnings.
4. **Modded Dimensions (`dimension.properties`)**:
   - Modern Iris supports `dimension.properties` with a `*` wildcard so modded Overworld-like dimensions automatically receive full Aetheron lighting and shadows. OptiFine 1.12.2 routes custom dimensions using its legacy `world0` fallback behavior.
5. **Sodium Geometry Acceleration**:
   - Modern Edition benefits from Sodium's multi-threaded chunk meshing and low-overhead draw batching alongside Iris, dramatically increasing CPU headroom compared to 1.12.2's legacy OpenGL immediate/display-list pipeline.

---

## Verified Compatibility Matrix

| Feature | Modern (Iris 1.20.x+) | Legacy (OptiFine 1.12.2) |
| :--- | :---: | :---: |
| Physically-Inspired Atmospheric Scattering (Rayleigh + Mie + Ozone) | Full | Full |
| Procedural Volumetric Clouds (Low / Medium / Ultra) + Cirrus | Full | Full |
| Volumetric Fog & Crepuscular God Rays | Full | Full |
| Height-Based Valley Mist & Atmospheric Perspective | Full | Full |
| Variable-Penumbra PCSS (Ultra) & Vogel PCF Shadows | Full | Full |
| Colored Stained-Glass Shadows & Foliage SSS | Full | Full |
| Screen-Space Contact Shadows | Full | Full |
| Multi-Octave Animated Water, Refraction, Beer-Lambert, Caustics, Rain Ripples | Full | Full |
| Binary-Refined SSR Reflections + Sky/Cloud Fallback | Full | Full |
| GTAO Ambient Occlusion & SSIL Indirect Bounce | Full | Full |
| Rain Wetness & Reflective Puddles | Full | Full |
| Vertex Wind Animation (Grass, Leaves, Crops, Vines) | Full | Full |
| Karis Bloom, ACES/AgX/Aetheron/Uncharted2 Tonemapping, Color Grading | Full | Full |
| YCoCg Variance-Clamped TAA + CAS Sharpening + Optional DoF & Motion Blur | Full | Full |
| Dedicated Nether & End Atmospheres | Full | Full |
| Emissive Mobs (`entity.properties`) & `darknessFactor` | Full | N/A (Engine Limit) |
