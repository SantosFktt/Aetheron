#ifndef AETHERON_SHADOWS_GLSL
#define AETHERON_SHADOWS_GLSL

// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Directional Shadow Mapping, PCSS/PCF & Contact Shadows
// Stable distorted projection, normal-offset bias, colored glass, foliage SSS
// ==============================================================================

// Screen-Space Contact Shadows: short-range raymarch in view space to ground
// grass blades, small details, and overhangs beyond shadow map texel resolution
float computeContactShadow(vec3 viewPos, vec3 viewNormal, vec3 lightDirView, float dither) {
    #if CONTACT_SHADOWS == 0
        return 1.0;
    #endif

    float viewDist = length(viewPos);
    if (viewDist > 42.0) return 1.0;

    float ndotl = dot(viewNormal, lightDirView);
    if (ndotl <= 0.02) return 1.0;

    const int CONTACT_STEPS = 8;
    float rayLen = mix(0.45, 1.35, clamp(viewDist / 32.0, 0.0, 1.0));
    float stepLen = rayLen / float(CONTACT_STEPS);

    vec3 rayStart = viewPos + viewNormal * (0.015 + viewDist * 0.0015);
    float occlusion = 0.0;

    for (int i = 0; i < CONTACT_STEPS; i++) {
        float dist = (float(i) + 0.35 + dither * 0.65) * stepLen;
        vec3 sampleView = rayStart + lightDirView * dist;
        vec3 sampleScreen = viewToScreenPos(sampleView);

        if (sampleScreen.x < 0.0 || sampleScreen.x > 1.0 || sampleScreen.y < 0.0 || sampleScreen.y > 1.0) {
            break;
        }

        float sceneDepth = texture2D(depthtex0, sampleScreen.xy).r;
        if (sceneDepth >= 0.99999) continue;

        float linearScene  = linearizeDepth(sceneDepth);
        float linearSample = -sampleView.z;
        float diff = linearSample - linearScene;

        // Thin depth shell test prevents false self-shadowing from distant foreground objects
        float thickness = 0.08 + dist * 0.35;
        if (diff > 0.025 && diff < thickness) {
            float fade = 1.0 - float(i) / float(CONTACT_STEPS);
            occlusion = max(occlusion, fade);
        }
    }

    float distFade = 1.0 - smoothstep(26.0, 42.0, viewDist);
    return 1.0 - occlusion * 0.78 * distFade;
}

// Compute filtered directional shadow visibility (returns RGB to support colored stained glass!)
vec3 computeDirectionalShadow(
    vec3 playerPos,
    vec3 worldNormal,
    vec3 lightDirWorld,
    float sssStrength,
    float dither,
    out float sssTransmission
) {
    sssTransmission = 0.0;

    // Fade shadows smoothly near the configured shadowDistance boundary
    float radialDist = length(playerPos.xz);
    float edgeFade = 1.0 - smoothstep(shadowDistance * 0.80, shadowDistance * 0.98, radialDist);
    if (edgeFade <= 0.001) {
        return vec3(1.0);
    }

    // Normal-offset bias eliminates shadow acne on grazing angles without peter-panning
    float ndotl = dot(worldNormal, lightDirWorld);
    float slopeFactor = sqrt(max(1.0 - ndotl * ndotl, 0.0));

    float texelWorld = (shadowDistance * 2.0) / float(shadowMapResolution);
    vec3 biasedPlayerPos = playerPos + worldNormal * (texelWorld * (0.45 + 1.15 * slopeFactor));
    if (sssStrength > 0.1) {
        // Slightly gentler normal push for thin foliage cards so leaves self-shadow organically
        biasedPlayerPos = playerPos + worldNormal * (texelWorld * 0.25) + lightDirWorld * (texelWorld * 0.20);
    }

    float distortFactor;
    vec3 shadowPos = playerToShadowScreenPos(biasedPlayerPos, distortFactor);

    if (shadowPos.x < 0.002 || shadowPos.x > 0.998 || shadowPos.y < 0.002 || shadowPos.y > 0.998 || shadowPos.z >= 1.0) {
        return vec3(1.0);
    }

    // Slope-scaled depth bias adjusted for shadow map non-linear distortion
    float depthBias = (0.00028 + 0.00055 * slopeFactor) * (distortFactor * distortFactor) * (2048.0 / float(shadowMapResolution));
    if (sssStrength > 0.1) {
        depthBias *= 0.65;
    }

    float receiverDepth = shadowPos.z - depthBias;
    float phi = dither * TAU;

    // Filter radius in shadow-map UV space
    float invRes = 1.0 / float(shadowMapResolution);
    float filterRadius = (1.65 * SHADOW_SOFTNESS) * invRes / max(distortFactor, 0.25);

    // ULTRA (SHADOW_QUALITY == 3): Variable-Penumbra PCSS Blocker Search
    #if SHADOW_QUALITY == 3
        const int BLOCKER_TAPS = 6;
        float blockerSum = 0.0;
        float blockerCount = 0.0;
        float searchRadius = (5.5 * SHADOW_SOFTNESS) * invRes / max(distortFactor, 0.25);

        for (int b = 0; b < BLOCKER_TAPS; b++) {
            vec2 off = vogelDiskSample(b, BLOCKER_TAPS, phi + 0.5) * searchRadius;
            float d = texture2D(shadowtex0, shadowPos.xy + off).r;
            if (d < receiverDepth) {
                blockerSum += d;
                blockerCount += 1.0;
            }
        }

        if (blockerCount > 0.5) {
            float avgBlocker = blockerSum / blockerCount;
            float penumbra = clamp((receiverDepth - avgBlocker) * 42.0, 0.65, 4.2);
            filterRadius *= penumbra;
        } else {
            filterRadius *= 0.75;
        }
        const int PCF_TAPS = 14;
    #elif SHADOW_QUALITY == 2
        const int PCF_TAPS = 9;
    #else
        const int PCF_TAPS = 5;
    #endif

    // Foliage Subsurface Scattering thickness estimation via shadowtex1
    #ifdef FOLIAGE_SSS
        if (sssStrength > 0.05) {
            float sssDepth = texture2D(shadowtex1, shadowPos.xy).r;
            float thickness = max(receiverDepth - sssDepth, 0.0) * 140.0;
            sssTransmission = exp(-thickness * 1.45) * sssStrength * edgeFade;
        }
    #endif

    // Soft Vogel-Disk PCF with optional stained-glass colored shadows
    vec3 shadowAccum = vec3(0.0);
    for (int i = 0; i < PCF_TAPS; i++) {
        vec2 offset = vogelDiskSample(i, PCF_TAPS, phi) * filterRadius;
        vec2 uv = shadowPos.xy + offset;

        float dAll = texture2D(shadowtex0, uv).r;
        if (receiverDepth <= dAll) {
            shadowAccum += vec3(1.0);
        } else {
            #ifdef COLORED_SHADOWS
                float dOpaque = texture2D(shadowtex1, uv).r;
                if (receiverDepth <= dOpaque) {
                    // Ray passed through translucent stained glass or water!
                    vec4 sc = texture2D(shadowcolor0, uv);
                    vec3 tint = mix(vec3(1.0), srgbToLinear(sc.rgb) * 1.25, sc.a);
                    shadowAccum += tint;
                }
            #endif
        }
    }

    vec3 filteredShadow = shadowAccum / float(PCF_TAPS);
    return mix(vec3(1.0), filteredShadow, edgeFade);
}

#endif // AETHERON_SHADOWS_GLSL
