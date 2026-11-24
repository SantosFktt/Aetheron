# Configuration Menu & Customization Guide

Aetheron organizes all user-facing settings into **8 clean categories** plus a top-level **Profile selector** (`LOW` / `MEDIUM` / `ULTRA`). Changing any individual setting after selecting a profile cleanly overrides just that parameter without locking you into a preset.

---

## Menu Categories

### 1. Lighting & Materials (`[LIGHTING]`)
- **Sunlight / Moonlight / Sky Ambient Intensity**: Independently fine-tune direct solar luminance, phase-modulated nocturnal illumination, and shadow fill brightness.
- **Blocklight Intensity & Warmth (`BLOCKLIGHT_TEMP`)**: Adjusts torch/lantern brightness and Planckian color temperature (`2000K` cozy candlelight → `2800K` default warm tungsten → `4200K` neutral halogen).
- **Emissive Glow (`EMISSIVE_INTENSITY`)**: Controls self-illumination of lava, glowstone, lanterns, soul fire, froglights, and sculk.
- **Natural Cave Ambient (`CAVE_BRIGHTNESS`)**: Sets minimum underground visibility so deep caves feel atmospheric without turning pitch-black.
- **Screen-Space Indirect Lighting (`SSIL_QUALITY`)**: `Off` / `Balanced` (4-tap GI) / `Ultra` (8-tap GI) colored diffuse bounce lighting.
- **Biome-Aware Lighting (`BIOME_LIGHTING`)**: Adapts sunlight warmth and sky haze across deserts, cold peaks, swamps/jungles, and oceans.
- **Rain Wetness & Puddles (`WEATHER_PUDDLES`)**: Enables wet material darkening and reflective sky puddles during rain.

### 2. Shadows (`[SHADOWS]`)
- **Shadow Filtering Quality (`SHADOW_QUALITY`)**: `Low` (5-tap Vogel PCF), `Medium` (9-tap Vogel PCF), `Ultra` (Variable-Penumbra PCSS).
- **Shadow Resolution (`shadowMapResolution`)**: `1024`, `2048`, `3072`, `4096`.
- **Shadow Distance (`shadowDistance`)**: Slider from `64` to `320` blocks.
- **Shadow Softness (`SHADOW_SOFTNESS`)**: Scales PCF/PCSS penumbra radius.
- **Screen-Space Contact Shadows (`CONTACT_SHADOWS`)**: Grounds fine grass blades, flowers, and detailed builds.
- **Colored Translucent Shadows (`COLORED_SHADOWS`)**: Stained glass casts tinted sunlight.
- **Foliage Subsurface Scattering (`FOLIAGE_SSS`)**: Warm back-lit transmission through tree canopies and tall grass.

### 3. Atmosphere & Fog (`[ATMOSPHERE]`)
- **Atmospheric Scattering (`ATMOSPHERE_DENSITY`)**: Scales Rayleigh and Mie sky density.
- **Volumetric Lighting Quality (`VOLUMETRIC_FOG_QUALITY`)**: `Off`, `Low` (7 steps), `Medium` (12 steps), `Ultra` (20 steps).
- **Volumetric Fog Density**, **Height Valley Mist**, **Atmospheric Perspective**: Independent controls for air shafts, valley mist, and distant mountain haze.
- **Crepuscular God Rays & Strength**: Enables and tunes directional sun/moon light shafts.
- **Starfield Brightness & Moon Angular Scale**: Customizes night sky brilliance and shaded moon size.

### 4. Volumetric Clouds (`[CLOUDS]`)
- **Volumetric Cloud Quality (`CLOUD_QUALITY`)**: `Off`, `Low` (analytic 2D), `Medium` (volumetric 16-step), `Ultra` (3D Perlin-Worley 28-step with 4-tap self-shadowing).
- **Cloud Coverage, Altitude, Thickness, Wind Speed**: Full artistic control over sky mood.
- **High-Altitude Cirrus Layer (`CIRRUS_CLOUDS`)**: Toggle upper-troposphere wispy clouds.

### 5. Water & Reflections (`[WATER]`)
- **Water Shading Quality (`WATER_QUALITY`)**: Scales wave octaves (2 / 3 / 5) and refraction.
- **Water Reflection Quality (`REFLECTION_QUALITY`)**: `Sky Only`, `Low`, `Medium`, `Ultra` binary-refined SSR.
- **Wave Amplitude, Water Clarity, Underwater Caustics, Rain Ripples, Underwater Fog Density**: Complete water look customization.

### 6. Vegetation & Wind (`[VEGETATION]`)
- **Vegetation Wind Animation** master toggle, **Wind Strength**, and per-category toggles for **Leaves**, **Grass & Flowers**, and **Crops & Vines**.

### 7. Post-Processing & Color (`[POST_PROCESSING]`)
- **Tonemapping Curve (`TONEMAP_OPERATOR`)**:
  - `0`: **ACES Filmic** (Default — cinematic contrast & natural highlight roll-off)
  - `1`: **AgX Neutral** (Zero sunset hue-shift, crisp pastel skies)
  - `2`: **Aetheron Filmic** (Balanced Photon × Bliss signature curve)
  - `3`: **Uncharted 2 Filmic** (Classic punchy filmic curve)
- **Exposure & Auto-Exposure**, **Bloom Quality & Strength**, **Contrast**, **Saturation**, **Vibrance**, **Color Temperature**, **Vignette**.
- **Optional Cinematic Effects**: Bokeh **Depth of Field**, Camera **Motion Blur**, and **CAS Sharpening** (enabled by default on Medium/Ultra to restore crisp texture edges after TAA).

### 8. Performance & Anti-Aliasing (`[PERFORMANCE]`)
- **Ambient Occlusion Quality & Strength (`AO_QUALITY`)**: `Off`, `Low` (4-tap), `Medium` (8-tap), `Ultra` (12-tap).
- **Temporal Anti-Aliasing (`TAA_ENABLED`)**: Eliminates shimmering on leaves, water, and distant edges.
- **Adaptive Raymarching (`ADAPTIVE_RAYMARCHING`)**: Early transmittance exit + elevation-adaptive cloud step scaling.
- **Anti-Banding Dithering (`DITHERING_ENABLED`)**: Triangular-PDF 8-bit dither for smooth sky gradients.
