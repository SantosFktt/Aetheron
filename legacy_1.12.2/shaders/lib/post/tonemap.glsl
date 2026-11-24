#ifndef AETHERON_TONEMAP_GLSL
#define AETHERON_TONEMAP_GLSL

// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Filmic Tonemapping, Exposure, Natural Color Grading & Vignette
// ==============================================================================

// 0: ACES Filmic (Stephen Hill RRT+ODT matrix fit — natural highlight desaturation)
vec3 tonemapACES(vec3 x) {
    mat3 ACESInputMat = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777
    );
    mat3 ACESOutputMat = mat3(
         1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602
    );

    x = ACESInputMat * x;
    vec3 a = x * (x + 0.0245786) - 0.000090537;
    vec3 b = x * (0.983729 * x + 0.4329510) + 0.238081;
    x = a / max(b, vec3(1e-5));
    return clamp(ACESOutputMat * x, 0.0, 1.0);
}

// 1: AgX-Inspired Neutral Filmic (preserves crisp sky cyan & golden sunset without hue shift)
vec3 tonemapAgX(vec3 col) {
    mat3 agxInset = mat3(
        0.842479, 0.042328, 0.042375,
        0.078433, 0.878468, 0.078433,
        0.079223, 0.079166, 0.879142
    );
    mat3 agxOutset = mat3(
         1.196879, -0.052896, -0.052971,
        -0.098020,  1.151903, -0.098043,
        -0.099029, -0.098961,  1.151073
    );

    col = max(agxInset * col, vec3(1e-6));
    col = clamp((log2(col) - (-12.47393)) / (4.026069 - (-12.47393)), 0.0, 1.0);
    vec3 x2 = col * col;
    vec3 x4 = x2 * x2;
    col =  15.5     * x4 * x2
         - 40.14    * x4 * col
         + 31.96    * x4
         -  6.868   * x2 * col
         +  0.4298  * x2
         +  0.1191  * col
         -  0.00232;
    col = agxOutset * col;
    return clamp(pow(max(col, vec3(0.0)), vec3(2.2)), 0.0, 1.0);
}

// 2: Aetheron Signature Filmic (Photon clarity + Bliss organic roll-off)
vec3 tonemapAetheron(vec3 x) {
    // Gentle highlight path-to-white desaturation before filmic curve
    float luma = luminance(x);
    vec3 desat = mix(x, vec3(luma), smoothstep(1.2, 6.5, luma) * 0.42);
    const float a = 2.45;
    const float b = 0.03;
    const float c = 2.38;
    const float d = 0.56;
    const float e = 0.13;
    return clamp((desat * (a * desat + b)) / max(desat * (c * desat + d) + e, vec3(1e-5)), 0.0, 1.0);
}

// 3: Uncharted 2 Filmic
vec3 uncharted2Partial(vec3 x) {
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;
    return ((x * (A * x + C * B) + D * E) / max(x * (A * x + B) + D * F, vec3(1e-5))) - E / F;
}

vec3 tonemapUncharted2(vec3 x) {
    vec3 curr = uncharted2Partial(x * 1.85);
    vec3 whiteScale = vec3(1.0) / uncharted2Partial(vec3(11.2));
    return clamp(curr * whiteScale, 0.0, 1.0);
}

// Select configured tonemap operator
vec3 applyTonemap(vec3 hdr) {
    #if TONEMAP_OPERATOR == 0
        return tonemapACES(hdr);
    #elif TONEMAP_OPERATOR == 1
        return tonemapAgX(hdr);
    #elif TONEMAP_OPERATOR == 2
        return tonemapAetheron(hdr);
    #else
        return tonemapUncharted2(hdr);
    #endif
}

// Smooth adaptive exposure factor based on eye skylight & time of day
float computeAdaptiveExposure() {
    float expMult = EXPOSURE;
    #ifdef AUTO_EXPOSURE
        #ifdef DIMENSION_OVERWORLD
            float skyAccess = clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0);
            float dayFrac   = getDayFactor();
            float rain      = getRainMix();
            // Gently boost exposure indoors / at night / in storms without over-brightening caves
            float sceneBright = mix(0.26, 1.0, dayFrac * mix(1.0, 0.58, rain)) * mix(0.32, 1.0, skyAccess);
            float autoMult = clamp(mix(1.38, 0.88, sceneBright), 0.84, 1.45);
            expMult *= autoMult;
        #elif defined(DIMENSION_NETHER)
            expMult *= 1.15;
        #else
            expMult *= 1.25;
        #endif
    #endif
    return expMult;
}

// Natural cinematic color grading (white balance, subtle split-tone, vibrance, saturation, contrast)
vec3 applyColorGrading(vec3 srgb) {
    // Color temperature shift
    vec3 tempShift = vec3(1.0 + COLOR_TEMP * 0.28, 1.0 + COLOR_TEMP * 0.04, 1.0 - COLOR_TEMP * 0.28);
    srgb = clamp(srgb * tempShift, 0.0, 1.0);

    // Subtle filmic S-curve contrast around mid-grey (0.5)
    srgb = clamp((srgb - 0.5) * CONTRAST + 0.5, 0.0, 1.0);

    // Subtle natural split toning: cool-slate shadows, warm-ivory highlights (Photon x Bliss balance)
    float luma = luminance(srgb);
    vec3 shadowTint    = vec3(0.985, 0.995, 1.020);
    vec3 highlightTint = vec3(1.015, 1.004, 0.988);
    srgb *= mix(shadowTint, highlightTint, smoothstep(0.15, 0.85, luma));

    // Vibrance (boosts muted colors selectively without clipping saturated reds/greens)
    float maxC = maxOf(srgb);
    float minC = minOf(srgb);
    float currentSat = maxC - minC;
    float vibranceScale = 1.0 + VIBRANCE * (1.0 - currentSat);
    luma = luminance(srgb);
    srgb = mix(vec3(luma), srgb, vibranceScale * SATURATION);

    return clamp(srgb, 0.0, 1.0);
}

// Cinematic optical vignette
vec3 applyVignette(vec3 col, vec2 uv) {
    if (VIGNETTE_STRENGTH <= 0.001) return col;
    vec2 centered = (uv - 0.5) * vec2(aspectRatio * 0.72, 1.0);
    float distSq = dot(centered, centered);
    float vig = 1.0 - smoothstep(0.28, 1.35, distSq) * VIGNETTE_STRENGTH;
    return col * vig;
}

#endif // AETHERON_TONEMAP_GLSL
