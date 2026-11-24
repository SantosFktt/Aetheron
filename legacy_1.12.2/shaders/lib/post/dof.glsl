#ifndef AETHERON_DOF_GLSL
#define AETHERON_DOF_GLSL

// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Optional Cinematic Bokeh Depth of Field
// Uses smooth crosshair focus (centerDepthSmooth) with foreground protection
// ==============================================================================

vec3 applyDepthOfField(sampler2D colorTex, sampler2D depthTex, vec2 uv, vec2 texelSize, float dither) {
    #if DOF_ENABLED == 0
        return texture2D(colorTex, uv).rgb;
    #endif

    float centerDepth = texture2D(depthTex, uv).r;
    // Do not blur first-person hand
    if (centerDepth < 0.56) {
        return texture2D(colorTex, uv).rgb;
    }

    float focusDist = linearizeDepth(centerDepthSmooth);
    float pixelDist = linearizeDepth(centerDepth);

    // Circle of Confusion (CoC) proportional to distance from focal plane
    float coc = abs(pixelDist - focusDist) / max(pixelDist * focusDist * 0.06 + focusDist, 1.0);
    coc = clamp(coc * 14.0 * DOF_STRENGTH, 0.0, 1.0);

    if (coc < 0.03) {
        return texture2D(colorTex, uv).rgb;
    }

    const int DOF_TAPS = 12;
    float maxPixelRadius = 9.0 * coc;
    float phi = dither * TAU;

    vec3 accum = texture2D(colorTex, uv).rgb;
    float weightSum = 1.0;

    for (int i = 0; i < DOF_TAPS; i++) {
        vec2 disk = vogelDiskSample(i, DOF_TAPS, phi);
        vec2 sampleUV = clamp(uv + disk * texelSize * maxPixelRadius, vec2(0.001), vec2(0.999));

        float sampleDepth = texture2D(depthTex, sampleUV).r;
        if (sampleDepth < 0.56) continue; // Protect player hand silhouette

        vec3 sampleCol = texture2D(colorTex, sampleUV).rgb;
        float sampleDist = linearizeDepth(sampleDepth);
        // Prevent crisp foreground objects from bleeding over background blur inappropriately
        float depthWeight = (sampleDist >= pixelDist - 0.5) ? 1.0 : clamp(coc, 0.2, 1.0);
        // Subtle bokeh highlight boost
        float bokehWeight = depthWeight * (1.0 + clamp(luminance(sampleCol) - 1.2, 0.0, 1.5) * 0.35);

        accum += sampleCol * bokehWeight;
        weightSum += bokehWeight;
    }

    return accum / max(weightSum, 1e-4);
}

#endif // AETHERON_DOF_GLSL
