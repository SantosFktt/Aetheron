#ifndef AETHERON_AO_GLSL
#define AETHERON_AO_GLSL

// ==============================================================================
// AETHERON SHADERS — GTAO-Inspired Multi-Horizon Screen-Space Ambient Occlusion
// Clean crevice grounding with depth-aware falloff & zero haloing
// ==============================================================================

float computeGTAO(vec2 uv, vec3 viewPos, vec3 viewNormal, float dither) {
    #if AO_QUALITY == 0
        return 1.0;
    #endif

    float viewDist = -viewPos.z;
    if (viewDist > 110.0) return 1.0;

    #if AO_QUALITY == 3
        const int DIRECTIONS = 6;
        const int STEPS_PER_DIR = 2;
    #elif AO_QUALITY == 2
        const int DIRECTIONS = 4;
        const int STEPS_PER_DIR = 2;
    #else
        const int DIRECTIONS = 4;
        const int STEPS_PER_DIR = 1;
    #endif

    // World-space sample radius projected to screen space
    float worldRadius = mix(0.65, 1.35, clamp(viewDist / 40.0, 0.0, 1.0));
    vec2 screenRadius = (vec2(gbufferProjection[0][0], gbufferProjection[1][1]) * worldRadius) / max(viewDist, 0.5);
    screenRadius = clamp(screenRadius, vec2(0.002), vec2(0.065));

    float angleOffset = dither * TAU;
    float radialJitter = fract(dither * 1.6180339);

    float occlusion = 0.0;
    float totalWeight = 0.0;

    for (int d = 0; d < DIRECTIONS; d++) {
        float angle = angleOffset + (float(d) / float(DIRECTIONS)) * TAU;
        vec2 dir = vec2(cos(angle), sin(angle));

        float maxHorizon = 0.0;
        for (int s = 1; s <= STEPS_PER_DIR; s++) {
            float frac = (float(s) - 0.35 + radialJitter * 0.55) / float(STEPS_PER_DIR);
            vec2 sampleUV = uv + dir * screenRadius * frac;
            if (sampleUV.x < 0.001 || sampleUV.x > 0.999 || sampleUV.y < 0.001 || sampleUV.y > 0.999) {
                continue;
            }

            float sampleDepth = texture(depthtex0, sampleUV).r;
            if (sampleDepth >= 0.99999) continue;

            vec3 sampleViewPos = screenToViewPos(sampleUV, sampleDepth);
            vec3 diff = sampleViewPos - viewPos;
            float distSq = dot(diff, diff);
            float dist = sqrt(max(distSq, 1e-6));

            // Range check prevents foreground objects from haloing background walls
            float rangeAtten = smoothstep(worldRadius * 1.65, worldRadius * 0.25, dist);
            float horizon = max(dot(viewNormal, diff / dist) - 0.06, 0.0) * rangeAtten;
            maxHorizon = max(maxHorizon, horizon);
        }

        occlusion += maxHorizon;
        totalWeight += 1.0;
    }

    float rawAO = 1.0 - (occlusion / max(totalWeight, 1.0));
    float distFade = 1.0 - smoothstep(70.0, 110.0, viewDist);
    float finalAO = mix(1.0, pow(clamp(rawAO, 0.0, 1.0), 1.45 * AO_STRENGTH), distFade);
    return clamp(finalAO, 0.12, 1.0);
}

#endif // AETHERON_AO_GLSL
