#ifndef AETHERON_VEGETATION_GLSL
#define AETHERON_VEGETATION_GLSL

// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Efficient Organic Vertex Wind Simulation
// Natural travelling gusts + rain storm intensification with minimal vertex cost
// ==============================================================================

vec3 computeVegetationWindOffset(vec3 worldPos, int matId, vec2 texCoord, vec2 midTexCoord, float skyLight) {
    #if WAVING_FOLIAGE == 0
        return vec3(0.0);
    #endif

    // Quickly skip non-waving blocks
    if (matId < MAT_FOLIAGE_LOW || matId > MAT_UNDERWATER_PLANT) {
        return vec3(0.0);
    }

    // Determine whether this vertex is top or bottom of a quad using mc_midTexCoord
    // In Minecraft block atlas, smaller V = top of texture
    float isTop = (texCoord.y < midTexCoord.y) ? 1.0 : 0.0;

    // Storm & rain amplify wind frequency and gust strength organically
    float rain = getRainMix();
    float speed = (1.65 + rain * 1.15);
    float amp   = 0.048 * WIND_STRENGTH * (1.0 + rain * 0.85);
    float t = frameTimeCounter * speed;

    // Travelling macro wind gust wave across the landscape
    float gustPhase = worldPos.x * 0.14 + worldPos.z * 0.11 - t * 0.55;
    float gust = 0.65 + 0.55 * sin(gustPhase) + 0.25 * sin(gustPhase * 2.3 + 1.4);

    // Sky exposure dampens wind inside enclosed greenhouses / caves
    float outdoorWind = mix(0.22, 1.0, smoothstep(0.25, 0.85, skyLight));
    amp *= gust * outdoorWind;

    vec3 offset = vec3(0.0);

    if (matId == MAT_FOLIAGE_LOW) {
        #ifdef WAVING_GRASS
            float phase = worldPos.x * 1.3 + worldPos.z * 1.1 + worldPos.y * 0.5;
            offset.x = sin(t * 1.4 + phase) * amp * 1.15 * isTop;
            offset.z = cos(t * 1.1 + phase * 0.85) * amp * 0.80 * isTop;
        #endif
    } else if (matId == MAT_FOLIAGE_TALL) {
        #ifdef WAVING_GRASS
            float phase = worldPos.x * 1.1 + worldPos.z * 0.95 + worldPos.y * 0.7;
            // Tall plants sway subtly even near middle joints
            float weight = mix(0.45, 1.25, isTop);
            offset.x = sin(t * 1.25 + phase) * amp * weight;
            offset.z = cos(t * 1.05 + phase * 0.9) * amp * 0.75 * weight;
        #endif
    } else if (matId == MAT_LEAVES) {
        #ifdef WAVING_LEAVES
            float p1 = worldPos.x * 0.9 + worldPos.y * 1.2 + worldPos.z * 0.8;
            float p2 = worldPos.x * 2.1 - worldPos.z * 1.9 + worldPos.y * 1.6;
            offset.x = (sin(t * 1.1 + p1) * 0.65 + sin(t * 2.4 + p2) * 0.35) * amp * 0.65;
            offset.y = cos(t * 1.6 + p2) * amp * 0.28;
            offset.z = (cos(t * 0.95 + p1) * 0.65 + cos(t * 2.1 + p2) * 0.35) * amp * 0.65;
        #endif
    } else if (matId == MAT_CROPS) {
        #ifdef WAVING_CROPS
            float phase = worldPos.x * 1.5 + worldPos.z * 1.4;
            offset.x = sin(t * 1.55 + phase) * amp * 0.95 * isTop;
            offset.z = cos(t * 1.25 + phase) * amp * 0.65 * isTop;
        #endif
    } else if (matId == MAT_HANGING) {
        #ifdef WAVING_CROPS
            float phase = worldPos.x * 1.2 + worldPos.y * 0.9 + worldPos.z * 1.2;
            offset.x = sin(t * 1.0 + phase) * amp * 0.60;
            offset.z = cos(t * 0.85 + phase) * amp * 0.60;
        #endif
    } else if (matId == MAT_UNDERWATER_PLANT) {
        #ifdef WAVING_CROPS
            // Gentle slow underwater current sway (independent of surface rain)
            float ut = frameTimeCounter * 1.2;
            float phase = worldPos.x * 0.8 + worldPos.y * 0.7 + worldPos.z * 0.8;
            float uAmp = 0.055 * WIND_STRENGTH;
            offset.x = sin(ut + phase) * uAmp * mix(0.35, 1.0, isTop);
            offset.z = cos(ut * 0.85 + phase * 1.1) * uAmp * 0.8 * mix(0.35, 1.0, isTop);
        #endif
    }

    return offset;
}

#endif // AETHERON_VEGETATION_GLSL
