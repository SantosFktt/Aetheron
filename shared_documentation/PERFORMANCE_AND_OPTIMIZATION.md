# GPU Performance & Optimization Engineering

Aetheron is designed to maximize visual fidelity per millisecond on modern NVIDIA GPUs (**GeForce RTX 5070**, Blackwell architecture) paired with high-IPC CPUs (**AMD Ryzen 7 9800X3D**), while scaling gracefully down to mid-range hardware via intelligent algorithmic optimizations rather than merely disabling aesthetics.

---

## Core GPU Optimization Principles Implemented

### 1. Minimized Framebuffer Passes & Buffer Bandwidth
- **Lean 8-Buffer Pipeline**: Even on Modern Iris (which allows 16 buffers), Aetheron packs all deferred attributes into 8 buffers (`colortex0`–`colortex7`) using octahedral normal encoding (`RG16F`) and dual-range SSS/emissive packing (`colortex2.a`).
- **Buffer Reuse Across Stages**: `colortex4` and `colortex5` store GTAO/Contact Shadows and Volumetric Clouds during `deferred`/`deferred1`, then are cleanly repurposed for tight & wide Karis Bloom in `composite2`/`composite3`, saving ~64 MB of high-bandwidth `RGBA16F` VRAM traffic per frame at 1440p.
- **Zero-Cost Disabled Effects**: Every optional pass feature (`SSIL_QUALITY == 0`, `AO_QUALITY == 0`, `DOF_ENABLED == 0`, `MOTION_BLUR_ENABLED == 0`, `CLOUD_QUALITY == 0`, `VOLUMETRIC_FOG_QUALITY == 0`) compiles out via preprocessor guards (`#if`) so the GPU never executes dead branches or wastes texture bandwidth.

### 2. Smarter Raymarching & Early Termination
- **Adaptive Cloud Raymarching**:
  - Elevation-adaptive step scaling reduces steps smoothly at steep zenith angles (where cloud slab traversal distance is short) while concentrating steps near the horizon.
  - Early transmittance termination (`if (transmittance < 0.025) break;`) exits thick cumulus cores immediately without wasting sun-march taps.
  - Analytical per-step integration `L * (1.0 - exp(-sigma * dt))` allows fewer steps without slicing artifacts.
  - Sky/terrain height culling skips cloud raymarching entirely for close opaque ground pixels that cannot intersect the cloud layer.
- **Exponentially Distributed Volumetric Fog**: Quadratic step spacing (`d = maxDist * t * t`) concentrates shadow-map samples near the viewer where crepuscular shafts have the highest visual frequency, delivering crisp god rays in 12–20 steps instead of 64+.
- **Binary-Refined Screen-Space Reflections**: Exponentially expanding march steps quickly cross open space, followed by 2–5 binary search iterations only upon hit detection, avoiding expensive uniform small-step marches.

### 3. Efficient Shadow Filtering
- **No Brute-Force Grid PCF**: Replaces expensive $5\times 5$ (25-tap) or $7\times 7$ (49-tap) square PCF grids with temporally rotated **Vogel Disk sampling** (5 taps on Low, 9 taps on Medium, 6-blocker + 14-tap PCSS on Ultra). Combined with YCoCg TAA, 14 rotated Vogel taps achieve smoother penumbras than 49 static grid taps at a fraction of the texture fetch cost.
- **Dimension-Specific Shadow Culling**: Nether (`world-1`) and End (`world1`) omit `shadow.vsh`/`shadow.fsh` completely, eliminating shadow-map geometry passes where directional sun shadows do not apply.
- **Water Shadow Discard**: `shadow.fsh` discards water fragments early so underwater beds stay sunlit and shadow fill-rate drops over oceans.

### 4. CPU Offloading via Custom Uniforms
- Biome transitions (`biomeDesert`, `biomeCold`, `biomeHumid`, `biomeOcean`) and smooth weather transitions (`smoothRain`, `smoothThunder`) are evaluated once per frame on the CPU via `shaders.properties` custom uniforms rather than branching per-pixel on the GPU.

### 5. NVIDIA RTX 5070 (Blackwell) Architectural Alignment
- High ALU-to-bandwidth ratio on RTX 50-series favors procedural FBM/Worley evaluation in registers over large 3D volume texture fetches (avoiding L2 cache thrashing).
- Compact `RGBA16F` G-buffer writes maximize framebuffer compression (DCC) efficiency.
- Avoiding dynamic non-uniform loops and keeping loop upper bounds compile-time constant allows NVIDIA's shader compiler (`nvglsl`) to optimize register allocation and warp occupancy cleanly.

---

## Profiling Methodology (In-Game & External Tools)

To measure exact per-pass GPU timings on your own system:
1. **Iris Built-In Profiler**: Press `F3` (or `Alt + F3` / `F3 + 2` in 1.20.2+) to inspect frame time graphs and confirm GPU vs CPU bound status.
2. **NVIDIA Nsight Graphics / RenderDoc**: Capture a single frame during a heavy sunset forest+water+cloud vista on `ULTRA` and inspect GPU timestamps for:
   - `shadow` (geometry & alpha-cutout fill rate)
   - `deferred` (cloud raymarching & GTAO ALU cost)
   - `deferred1` (PCSS shadow fetches & SSIL)
   - `composite` (water wave normals & SSR raymarching)
   - `composite1` (volumetric fog shadow fetches)
3. **Tuning Knobs by Bottleneck**:
   - If **`deferred`** is highest: lower `CLOUD_QUALITY` (`3 → 2`) or `AO_QUALITY` (`3 → 2`).
   - If **`deferred1`** is highest: lower `SHADOW_QUALITY` (`3 → 2`), `shadowMapResolution` (`4096 → 2048`), or `SSIL_QUALITY` (`2 → 1`).
   - If **`composite`** is highest: lower `REFLECTION_QUALITY` (`3 → 2`).
   - If **`composite1`** is highest: lower `VOLUMETRIC_FOG_QUALITY` (`3 → 2`).
