# Aetheron Performance Profiles & GPU Budget Analysis

Aetheron is engineered for modern NVIDIA hardware—specifically targeting **NVIDIA GeForce RTX 5070** paired with **AMD Ryzen 7 9800X3D** at **1440p** and **4K**—while providing scalable **Low**, **Medium**, and **Ultra** presets that retain the shader's Photon × Bliss visual identity across all tiers.

Every individual option remains independently customizable in the in-game Shader Pack Settings menu after selecting a profile.

---

## Preset Comparison Matrix

| Subsystem | LOW (Performance) | MEDIUM (Balanced) | ULTRA (RTX Next-Gen) |
| :--- | :--- | :--- | :--- |
| **Shadow Resolution** | `1024 × 1024` | `2048 × 2048` | `4096 × 4096` |
| **Shadow Distance** | `128 blocks` | `192 blocks` | `256 blocks` |
| **Shadow Filtering** | 5-tap Vogel PCF | 9-tap Vogel PCF + Colored Glass | 2-stage Variable-Penumbra PCSS (6 blocker + 14 PCF) |
| **Contact Shadows** | Off | On (8-step screen-space) | On (8-step screen-space) |
| **Volumetric Clouds** | Analytic 2D Layer + Cirrus | 3D Volumetric (16 steps, 2 sun taps) + Cirrus | 3D Perlin-Worley Volumetric (28 steps, 4 sun taps, Beer-Powder) + Cirrus |
| **Volumetric Fog / God Rays** | Low (7 steps) | Medium (12 steps + 3D mist noise) | Ultra (20 steps + 3D mist noise) |
| **Water Shading** | 2-octave Waves + Absorption | 3-octave Waves + Refraction + Caustics | 5-octave Multi-Scale Waves + Refraction + Caustics + Rain Ripples |
| **Water Reflections (SSR)** | Fast SSR (12 steps, 2 binary) | Refined SSR (22 steps, 4 binary) | High-Precision SSR (36 steps, 5 binary) + Cloud Fallback |
| **Ambient Occlusion (GTAO)** | 4-tap Fast Horizon | 8-tap Balanced Horizon | 12-tap Multi-Horizon |
| **Indirect Lighting (SSIL)** | Off | 4-tap Single-Bounce GI | 8-tap High-Precision GI |
| **Rain Puddles & Wetness** | Off | On | On |
| **Bloom** | Fast Single-Scale Karis | Dual-Scale Karis Bloom | Dual-Scale Karis Bloom |
| **Anti-Aliasing & Sharpening** | Off | TAA (YCoCg Variance Clamp) + CAS | TAA (YCoCg Variance Clamp) + CAS |

---

## Target Hardware Pass Breakdown (RTX 5070 + Ryzen 7 9800X3D @ 2560×1440)

Because Aetheron uses a lean 8-buffer (`colortex0`..`colortex7`) deferred pipeline with early transmittance raymarch termination (`ADAPTIVE_RAYMARCHING`), zero redundant skybox passes, and disabled shadow maps in the Nether and End, GPU frame times stay low and predictable:

| Pass | Primary Workload | LOW (Est. ms) | MEDIUM (Est. ms) | ULTRA (Est. ms) |
| :--- | :--- | :---: | :---: | :---: |
| `shadow` | Directional shadow map + cutout foliage wind | ~0.35 ms | ~0.65 ms | ~1.35 ms |
| `gbuffers_*` | Opaque + translucent G-buffer packing (Sodium-accelerated) | ~0.40 ms | ~0.45 ms | ~0.55 ms |
| `deferred` | GTAO + Contact Shadows + Volumetric Clouds | ~0.45 ms | ~1.35 ms | ~2.75 ms |
| `deferred1` | Sky + Cloud composite + Deferred PBR + PCSS + SSIL | ~0.45 ms | ~0.95 ms | ~1.85 ms |
| `composite` | Water waves, Beer-Lambert absorption, caustics, binary SSR | ~0.30 ms | ~0.60 ms | ~1.05 ms |
| `composite1` | Volumetric fog & god rays + height/distance fog | ~0.25 ms | ~0.55 ms | ~0.95 ms |
| `composite2–4` | Dual-scale Karis bloom + YCoCg TAA resolve | ~0.25 ms | ~0.45 ms | ~0.50 ms |
| `final` | Exposure, ACES/AgX tonemap, color grading, CAS, dither | ~0.15 ms | ~0.20 ms | ~0.20 ms |
| **Total GPU Frame Time** | **2560×1440 (16–20 Render Distance)** | **~2.6 ms (~380 FPS)** | **~5.2 ms (~190 FPS)** | **~9.2 ms (~108 FPS)** |

> **Note on CPU Bottlenecks (1.12.2 vs 1.20.x+):**
> On Modern Minecraft (Iris + Sodium) with a Ryzen 7 9800X3D, chunk meshing and draw-call overhead are minimal, keeping the RTX 5070 well-fed. On Legacy Minecraft 1.12.2 (OptiFine), single-threaded OpenGL display-list/VBO submission is CPU-bound at very high render distances (`>20 chunks`), regardless of GPU headroom—for 1.12.2 Ultra, a render distance of 14–18 chunks is recommended for optimal frametime pacing.
