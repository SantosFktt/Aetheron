#ifndef AETHERON_SSIL_GLSL
#define AETHERON_SSIL_GLSL

// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Screen-Space Indirect Lighting (SSIL)
// One-bounce colored diffuse GI from previous-frame HDR radiance (colortex6)
// ==============================================================================

vec3 computeSSIL(vec2 uv, vec3 viewPos, vec3 viewNormal, float dither, sampler2D historyTex) {
    #if SSIL_QUALITY == 0
        return vec3(0.0);
    #endif

    float viewDist = -viewPos.z;
    if (viewDist > 96.0) return vec3(0.0);

    #if SSIL_QUALITY == 2
        const int GI_TAPS = 8;
        float maxRadius = 0.095;
    #else
        const int GI_TAPS = 4;
        float maxRadius = 0.065;
    #endif

    float phi = dither * TAU;
    vec3 bounceAccum = vec3(0.0);
    float weightSum = 0.0;

    for (int i = 0; i < GI_TAPS; i++) {
        vec2 disk = vogelDiskSample(i, GI_TAPS, phi);
        vec2 sampleUV = uv + disk * maxRadius;
        if (sampleUV.x < 0.005 || sampleUV.x > 0.995 || sampleUV.y < 0.005 || sampleUV.y > 0.995) {
            continue;
        }

        float sampleDepth = texture2D(depthtex0, sampleUV).r;
        if (sampleDepth >= 0.99999) continue;

        vec3 sampleViewPos = screenToViewPos(sampleUV, sampleDepth);
        vec3 delta = sampleViewPos - viewPos;
        float distSq = dot(delta, delta);
        if (distSq < 0.04 || distSq > 64.0) continue;

        float dist = sqrt(distSq);
        vec3 dir = delta / dist;

        // Cosine-weighted hemisphere reception at receiver
        float nDotDir = max(dot(viewNormal, dir), 0.0);
        if (nDotDir <= 0.01) continue;

        // Check emitter normal faces back toward receiver for physical energy conservation
        vec3 sampleNormal = decodeOctNormal(texture2D(colortex1, sampleUV).rg);
        float emitterFacing = max(dot(sampleNormal, -dir), 0.15);

        vec3 prevRadiance = texture2D(historyTex, sampleUV).rgb;
        // Clamp extreme firefly HDR spikes so GI stays temporally clean
        prevRadiance = min(prevRadiance, vec3(6.0));

        float falloff = 1.0 / (1.0 + distSq * 0.45);
        float w = nDotDir * emitterFacing * falloff;

        bounceAccum += prevRadiance * w;
        weightSum += 1.0;
    }

    float distFade = 1.0 - smoothstep(64.0, 96.0, viewDist);
    return (bounceAccum / max(weightSum, 1.0)) * 0.42 * distFade;
}

#endif // AETHERON_SSIL_GLSL
