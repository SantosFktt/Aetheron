#ifndef AETHERON_BLOCKLIGHT_GLSL
#define AETHERON_BLOCKLIGHT_GLSL

// ==============================================================================
// AETHERON SHADERS — Shared torch/blocklight response
// Used by the deferred shading pass and by forward-lit programs (particles).
// ==============================================================================

vec3 computeBlocklight(float blockLight, vec3 worldPos) {
    if (blockLight <= 0.002) return vec3(0.0);

    float falloff = pow(blockLight, 2.3) * 0.72 + pow(blockLight, 4.8) * 1.40;
    float flicker = 1.0 + 0.022 * sin(frameTimeCounter * 5.2 + worldPos.x * 1.7 + worldPos.z * 2.3);
    vec3 tempCol = blackbodyColor(float(BLOCKLIGHT_TEMP));

    return tempCol * falloff * flicker * 1.75 * BLOCKLIGHT_INTENSITY;
}

#endif // AETHERON_BLOCKLIGHT_GLSL
