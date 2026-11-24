#ifndef AETHERON_REFLECTIONS_GLSL
#define AETHERON_REFLECTIONS_GLSL

// ==============================================================================
// AETHERON SHADERS — Binary-Refined Screen-Space Reflections (SSR)
// Reflection stability, roughness jitter, edge vignette, sky/cloud fallback
// ==============================================================================

// Evaluate fallback environment reflection (Atmosphere + Clouds or Nether/End sky)
vec3 sampleSkyReflectionFallback(vec3 reflectDirWorld, float skyLight) {
    float skyMask = smoothstep(0.05, 0.55, skyLight);
    #ifdef DIMENSION_OVERWORLD
        vec3 sunDir  = getSunDirWorld();
        vec3 moonDir = getMoonDirWorld();
        vec3 env = evaluateAtmosphere(reflectDirWorld, sunDir, moonDir);
        // Add analytic/cloud reflection tint so water reflects sunlit & sunset clouds!
        #if CLOUD_QUALITY >= 1
            if (reflectDirWorld.y > 0.02) {
                vec4 reflCloud = renderAnalyticClouds(reflectDirWorld, sunDir, moonDir);
                env = env * reflCloud.a + reflCloud.rgb;
            }
        #endif
        vec3 caveRefl = vec3(0.015, 0.020, 0.028) * (0.6 + CAVE_BRIGHTNESS * 6.0);
        return mix(caveRefl, env, skyMask);
    #elif defined(DIMENSION_NETHER)
        return computeNetherSky(reflectDirWorld) * 0.75;
    #else
        return computeEndSky(reflectDirWorld);
    #endif
}

// Trace Screen-Space Reflection in view space against opaque depth buffer (depthtex1)
// Returns vec4(reflectedColor.rgb, hitConfidence [0..1])
vec4 traceScreenSpaceReflection(
    vec3 viewPos,
    vec3 viewNormal,
    float roughness,
    float dither,
    sampler2D sceneColorTex,
    sampler2D depthTex
) {
    #if REFLECTION_QUALITY == 0
        return vec4(0.0);
    #endif

    vec3 viewDir = normalize(viewPos);
    vec3 reflDir = reflect(viewDir, viewNormal);

    // Rays pointing straight back at camera cannot intersect visible screen geometry
    if (reflDir.z > 0.55) {
        return vec4(0.0);
    }

    #if REFLECTION_QUALITY == 3
        const int MAX_STEPS    = 36;
        const int BINARY_STEPS = 5;
        float initStep         = 0.35;
        float stepGrowth       = 1.14;
    #elif REFLECTION_QUALITY == 2
        const int MAX_STEPS    = 22;
        const int BINARY_STEPS = 4;
        float initStep         = 0.50;
        float stepGrowth       = 1.18;
    #else
        const int MAX_STEPS    = 12;
        const int BINARY_STEPS = 2;
        float initStep         = 0.80;
        float stepGrowth       = 1.24;
    #endif

    // Push start slightly off surface along normal to avoid self-intersection noise
    vec3 rayPos = viewPos + viewNormal * (0.04 + length(viewPos) * 0.002);
    float stepSize = initStep * (0.65 + 0.70 * dither);
    vec3 prevPos = rayPos;

    bool hit = false;
    vec2 hitUV = vec2(0.0);

    for (int i = 0; i < MAX_STEPS; i++) {
        prevPos = rayPos;
        rayPos += reflDir * stepSize;
        stepSize *= stepGrowth;

        // Clip behind near plane
        if (rayPos.z >= -near) break;

        vec3 screenPos = viewToScreenPos(rayPos);
        if (screenPos.x < 0.0 || screenPos.x > 1.0 || screenPos.y < 0.0 || screenPos.y > 1.0) {
            break;
        }
        if (screenPos.z >= 1.0 || screenPos.z <= 0.0) {
            break;
        }

        float sampledDepth = texture(depthTex, screenPos.xy).r;
        if (sampledDepth >= 0.99999) continue;

        float linearScene = linearizeDepth(sampledDepth);
        float linearRay   = -rayPos.z;
        float diff = linearRay - linearScene;

        // Adaptive surface thickness threshold prevents reflections stretching across gaps
        float maxThickness = max(0.35, stepSize * 1.45);
        if (diff > 0.01 && diff < maxThickness) {
            // Binary search refinement between prevPos and rayPos for razor-sharp stability
            vec3 lo = prevPos;
            vec3 hi = rayPos;
            for (int b = 0; b < BINARY_STEPS; b++) {
                vec3 mid = 0.5 * (lo + hi);
                vec3 midScr = viewToScreenPos(mid);
                float midScene = linearizeDepth(texture(depthTex, midScr.xy).r);
                if (-mid.z > midScene) {
                    hi = mid;
                } else {
                    lo = mid;
                }
            }
            vec3 refinedScr = viewToScreenPos(hi);
            float refinedScene = linearizeDepth(texture(depthTex, refinedScr.xy).r);
            if (abs(-hi.z - refinedScene) < maxThickness * 1.25) {
                hit = true;
                hitUV = refinedScr.xy;
            }
            break;
        }
    }

    if (!hit) {
        return vec4(0.0);
    }

    // Smooth vignette near viewport edges so reflections never pop abruptly at screen borders
    vec2 edgeDist = min(hitUV, 1.0 - hitUV);
    float edgeFade = smoothstep(0.0, 0.12, min(edgeDist.x, edgeDist.y));

    // Fade rays pointing backward toward camera smoothly
    float dirFade = 1.0 - smoothstep(0.15, 0.55, reflDir.z);

    // Slight roughness attenuation
    float roughFade = 1.0 - smoothstep(0.15, 0.65, roughness);

    float confidence = clamp(edgeFade * dirFade * roughFade, 0.0, 1.0);
    vec3 reflectedColor = texture(sceneColorTex, hitUV).rgb;

    return vec4(max(reflectedColor, vec3(0.0)), confidence);
}

#endif // AETHERON_REFLECTIONS_GLSL
