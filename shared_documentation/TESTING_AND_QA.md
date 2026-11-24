# Testing, Compilation Validation & Quality Control

Aetheron includes an automated GLSL compilation and static verification suite (`tools/validate_shaders.py`) powered by Khronos `glslangValidator` to ensure zero syntax, type, preprocessor, or version-compatibility errors across every preset, dimension, and feature toggle.

---

## 1. Automated GLSL Compilation Audit

Run the complete validation matrix from the repository root:

```bash
python3 tools/validate_shaders.py --edition all
```

### What Is Validated Automatically
1. **Recursive `#include` Resolution**: Expands Iris/OptiFine root-relative includes (`/lib/...`, `/program/...`) identically to the game loaders and detects missing or circular includes.
2. **All 3 Performance Presets + Feature Stress Configs**:
   - `LOW`
   - `MEDIUM`
   - `ULTRA`
   - `ULTRA_EXTRAS_AGX_DOF_MB` (Ultra + AgX Tonemapping + Depth of Field + Motion Blur)
   - `MINIMAL_TOGGLES_AETHERON_TM` (Aetheron Filmic + Clouds Off + Volumetrics Off + AO Off + SSR Off + Bloom Off)
3. **All 3 Dimensions per Edition**:
   - `world0` (Overworld — 52 shaders: shadow, 17 gbuffers, 2 deferred, 5 composite, final × vert/frag)
   - `world-1` (Nether — 48 shaders)
   - `world1` (The End — 48 shaders)
4. **Total Compilations Verified Per Run**:
   - **Modern Edition (`#version 330 compatibility`)**: `148 shaders × 5 configs = 740` Khronos GLSL compilations.
   - **Legacy Edition (`#version 120`)**: `148 shaders × 5 configs = 740` Khronos GLSL compilations + static enforcement of OptiFine 1.12.2 hard limits (no `colortex8+`, no `DRAWBUFFERS > 7`, no `thunderStrength`, `#version 120` header check).
   - **Grand Total**: **1,480 shader compilations validated per run**.

---

## 2. In-Game Visual Quality Control Checklist

When testing both packaged shaderpacks (`Aetheron-Modern-Iris-1.20+.zip` on Iris 1.20.x+ and `Aetheron-Legacy-OptiFine-1.12.2.zip` on OptiFine 1.12.2), verify each of the following scenes across **Low**, **Medium**, and **Ultra**:

- [ ] **Shader Load & Reload**: Zero `[Shaders] Error: Invalid program` chat messages when switching presets or toggling individual options.
- [ ] **Shadow Stability**: Slowly rotate the camera and walk across flat stone, stairs, and leaf canopies; verify zero shadow acne, zero detached peter-panning, smooth penumbra transition at `shadowDistance`, and colored light behind stained glass.
- [ ] **Day / Sunset / Night Transitions**: Run `/time set 0`, `6000`, `12500`, `13500`, `18000`, `23000`. Verify smooth sky transitions, golden-coral horizon + cobalt twilight zenith, limb-darkened sun, phase-shaded moon (`moonPhase`), and clean non-flickering starfield.
- [ ] **Weather Transitions**: Toggle `/weather clear`, `/weather rain`, `/weather thunder`. Verify cloud thickening, overcast light softening, rain ripples on water, and wet reflective puddles on exposed outdoor stone.
- [ ] **Volumetric Clouds**: Fly above, inside, and below `CLOUD_ALTITUDE` (`240m`); verify clean terrain-cloud depth intersection, silver-lining forward scattering near the sun, and smooth cirrus deck above cumulus.
- [ ] **Water & Underwater Rendering**: Inspect shallow riverbeds (caustics, shore foam, clear Beer-Lambert turquoise gradient), deep oceans (SSR reflection stability at screen edges, Fresnel grazing reflection of clouds), waterfalls, and submerged underwater view (underwater fog + surface light).
- [ ] **Caves & Underground Lighting**: Enter a sealed deep cave (`Y < 0` in Modern, `Y < 30` in 1.12.2). Verify zero sunlight leaking through terrain, natural cool cave ambient, warm torchlight glow, and dynamic handheld torch/soul-lantern illumination.
- [ ] **Foliage & Vegetation**: Inspect oak/spruce/cherry forests, wheat farms, tall grass, and underwater kelp. Verify synchronized shadow sway, warm back-lit leaf SSS, and crisp TAA edge stability.
- [ ] **Translucent Blocks**: Verify ice, stained glass panes, slime blocks, honey blocks, and Nether portals render with proper depth ordering and Fresnel reflections without corrupting underwater opaque terrain.
- [ ] **Nether Dimension**: Verify deep volcanic crimson-amber atmospheric depth fog, glowing lava/magma/shroomlight/soul fire, and smooth framerate with shadow map disabled.
- [ ] **End Dimension**: Verify obsidian-violet cosmic sky, swirling nebula ring & zenith vortex, glowing End crystals / End rods, and smooth island depth fog.
