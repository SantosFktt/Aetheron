#ifndef AETHERON_SETTINGS_GLSL
#define AETHERON_SETTINGS_GLSL

// ==============================================================================
// AETHERON SHADERS — Modern Configuration & Pipeline Constants
// Default profile matches MEDIUM; selectable presets: LOW / MEDIUM / ULTRA
// ==============================================================================

// --- Pipeline Constants (Recognized by Iris & OptiFine) ---
const int   shadowMapResolution = 2048;   // [1024 2048 3072 4096]
const float shadowDistance      = 192.0;  // [64.0 96.0 128.0 160.0 192.0 224.0 256.0 320.0]
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize  = 2.0;
const float sunPathRotation     = -32.0;
const float ambientOcclusionLevel = 0.75;
const float wetnessHalflife     = 140.0;
const float drynessHalflife     = 220.0;
const float eyeBrightnessHalflife = 6.0;
const float centerDepthHalflife = 1.2;
const int   noiseTextureResolution = 256;

// --- Material ID Constants (Must match block.properties) ---
#define MAT_SOLID           0
#define MAT_WATER           10
#define MAT_ICE             11
#define MAT_TRANSLUCENT     12
#define MAT_PORTAL          13
#define MAT_FOLIAGE_LOW     20
#define MAT_FOLIAGE_TALL    21
#define MAT_LEAVES          22
#define MAT_CROPS           23
#define MAT_HANGING         24
#define MAT_UNDERWATER_PLANT 25
#define MAT_EMISSIVE_WARM   30
#define MAT_EMISSIVE_COOL   31
#define MAT_EMISSIVE_ACCENT 32
#define MAT_METALLIC        40
#define MAT_SNOW            41
#define MAT_ENTITY          50
#define MAT_HAND            52
#define MAT_PARTICLE        54

// --- Lighting Options ---
#define SUN_INTENSITY        1.00 // [0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.35 1.50]
#define MOON_INTENSITY       1.00 // [0.40 0.60 0.80 1.00 1.20 1.40 1.60]
#define AMBIENT_INTENSITY    1.00 // [0.60 0.75 0.90 1.00 1.15 1.30 1.50]
#define BLOCKLIGHT_INTENSITY 1.05 // [0.50 0.75 0.90 1.05 1.20 1.40 1.60]
#define BLOCKLIGHT_TEMP      2800 // [2000 2400 2800 3200 3600 4200]
#define EMISSIVE_INTENSITY   1.15 // [0.50 0.75 1.00 1.15 1.35 1.60 2.00]
#define CAVE_BRIGHTNESS      0.06 // [0.02 0.04 0.06 0.08 0.12 0.16 0.22]
#define SSIL_QUALITY         1    // [0 1 2]
#define BIOME_LIGHTING            // Subtle biome-aware light & atmosphere grading
#define WEATHER_PUDDLES      1    // [0 1]

// --- Shadow Options ---
#define SHADOW_QUALITY       2    // [1 2 3]
#define SHADOW_SOFTNESS      1.00 // [0.50 0.75 1.00 1.25 1.50 2.00]
#define CONTACT_SHADOWS      1    // [0 1]
#define COLORED_SHADOWS           // Stained glass colored light transmission
#define FOLIAGE_SSS               // Warm sunlight subsurface scattering through foliage

// --- Atmosphere & Fog Options ---
#define ATMOSPHERE_DENSITY     1.00 // [0.50 0.75 1.00 1.25 1.50]
#define VOLUMETRIC_FOG_QUALITY 2    // [0 1 2 3]
#define VOLUMETRIC_FOG_DENSITY 0.85 // [0.25 0.50 0.70 0.85 1.00 1.25 1.50 2.00]
#define HEIGHT_FOG_DENSITY     0.75 // [0.00 0.25 0.50 0.75 1.00 1.35 1.75]
#define DISTANCE_FOG_DENSITY   0.85 // [0.00 0.30 0.55 0.85 1.15 1.50]
#define GOD_RAYS               1    // [0 1]
#define GOD_RAY_STRENGTH       0.95 // [0.30 0.60 0.80 0.95 1.20 1.50 1.80]
#define STAR_BRIGHTNESS        1.00 // [0.00 0.40 0.75 1.00 1.35 1.75]
#define MOON_SIZE              1.00 // [0.60 0.80 1.00 1.25 1.50]

// --- Cloud Options ---
#define CLOUD_QUALITY        2     // [0 1 2 3]
#define CLOUD_COVERAGE       0.48  // [0.15 0.30 0.40 0.48 0.58 0.70 0.85]
#define CLOUD_ALTITUDE       240.0 // [140.0 180.0 210.0 240.0 280.0 340.0]
#define CLOUD_THICKNESS      110.0 // [60.0 85.0 110.0 140.0 180.0]
#define CLOUD_SPEED          1.00  // [0.00 0.50 1.00 1.50 2.00 3.00]
#define CIRRUS_CLOUDS              // High-altitude wispy cirrus clouds

// --- Water & Reflection Options ---
#define WATER_QUALITY          2    // [1 2 3]
#define REFLECTION_QUALITY     2    // [0 1 2 3]
#define WATER_WAVE_HEIGHT      1.00 // [0.30 0.60 0.80 1.00 1.25 1.50]
#define WATER_CLARITY          1.00 // [0.40 0.70 1.00 1.30 1.65 2.00]
#define WATER_CAUSTICS              // Animated sunlight caustics on underwater terrain
#define RAIN_RIPPLES                // Animated raindrop rings on water surfaces
#define UNDERWATER_FOG_DENSITY 1.00 // [0.35 0.65 1.00 1.35 1.75]

// --- Vegetation Options ---
#define WAVING_FOLIAGE       1    // [0 1]
#define WIND_STRENGTH        1.00 // [0.25 0.50 0.75 1.00 1.35 1.75]
#define WAVING_LEAVES             // Enable canopy leaf wind flutter
#define WAVING_GRASS              // Enable grass and flower wind sway
#define WAVING_CROPS              // Enable crop, vine, and kelp animation

// --- Post-Processing Options ---
#define TONEMAP_OPERATOR     0    // [0 1 2 3]
#define EXPOSURE             1.05 // [0.60 0.75 0.90 1.05 1.20 1.35 1.55]
#define AUTO_EXPOSURE             // Smooth luminance-adaptive exposure
#define BLOOM_QUALITY        2    // [0 1 2]
#define BLOOM_STRENGTH       0.14 // [0.00 0.06 0.10 0.14 0.20 0.28 0.40]
#define CONTRAST             1.04 // [0.85 0.92 1.00 1.04 1.10 1.18 1.25]
#define SATURATION           1.03 // [0.75 0.88 0.96 1.03 1.10 1.18 1.28]
#define VIBRANCE             0.08 // [-0.20 -0.10 0.00 0.08 0.16 0.25]
#define COLOR_TEMP           0.00 // [-0.30 -0.20 -0.10 0.00 0.10 0.20 0.30]
#define VIGNETTE_STRENGTH    0.16 // [0.00 0.08 0.16 0.26 0.38 0.50]
#define DOF_ENABLED          0    // [0 1]
#define DOF_STRENGTH         0.50 // [0.15 0.30 0.50 0.75 1.00]
#define MOTION_BLUR_ENABLED  0    // [0 1]
#define MOTION_BLUR_STRENGTH 0.45 // [0.15 0.30 0.45 0.70 1.00]
#define CAS_SHARPENING       1    // [0 1]
#define CAS_STRENGTH         0.35 // [0.10 0.20 0.35 0.50 0.70 0.90]

// --- Performance & Stability Options ---
#define AO_QUALITY           2    // [0 1 2 3]
#define AO_STRENGTH          0.72 // [0.25 0.50 0.72 0.95 1.20]
#define TAA_ENABLED          1    // [0 1]
#define ADAPTIVE_RAYMARCHING      // Early transmittance exit & dynamic step scaling
#define DITHERING_ENABLED         // Triangular-PDF anti-banding dithering

#endif // AETHERON_SETTINGS_GLSL
