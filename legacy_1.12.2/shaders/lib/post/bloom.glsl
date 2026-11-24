#ifndef AETHERON_BLOOM_GLSL
#define AETHERON_BLOOM_GLSL

// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Firefly-Free Karis-Weighted Soft Bloom
// Two-scale cinematic bloom (tight glow + wide atmospheric halo)
// ==============================================================================

// Soft knee luminance threshold (avoids hard bloom popping on bright specular edges)
vec3 extractBloomBright(vec3 hdrColor, float threshold, float knee) {
    float br = maxOf(hdrColor);
    float soft = clamp(br - threshold + knee, 0.0, 2.0 * knee);
    soft = (soft * soft) / max(4.0 * knee, 1e-4);
    float contrib = max(br - threshold, soft) / max(br, 1e-4);
    // Clamp extreme fireflies while keeping sun/lava radiant
    vec3 res = hdrColor * contrib;
    return min(res, vec3(12.0));
}

// Karis inverse-luminance weight prevents single bright pixels from flickering
float karisWeight(vec3 col) {
    return 1.0 / (1.0 + luminance(col));
}

// Pass 1: Bright extraction + 9-tap Karis-weighted tight blur (written to colortex4)
vec3 computeBloomPass1(sampler2D sceneTex, vec2 uv, vec2 texelSize) {
    #if BLOOM_QUALITY == 0
        return vec3(0.0);
    #endif

    const float threshold = 0.88;
    const float knee      = 0.45;
    vec2 stepUV = texelSize * 2.2;

    vec3 sum = vec3(0.0);
    float wSum = 0.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = vec2(float(x), float(y)) * stepUV;
            vec3 c = extractBloomBright(texture2D(sceneTex, clamp(uv + off, vec2(0.001), vec2(0.999))).rgb, threshold, knee);
            float spatialW = (x == 0 && y == 0) ? 4.0 : ((x == 0 || y == 0) ? 2.0 : 1.0);
            float w = spatialW * karisWeight(c);
            sum += c * w;
            wSum += w;
        }
    }

    return sum / max(wSum, 1e-4);
}

// Pass 2: Dual-radius wide Gaussian/tent blur (written to colortex5)
vec3 computeBloomPass2(sampler2D tightBloomTex, vec2 uv, vec2 texelSize) {
    #if BLOOM_QUALITY < 2
        return vec3(0.0);
    #endif

    vec3 sum = vec3(0.0);
    float wSum = 0.0;

    // 13-tap multi-ring atmospheric spread
    vec3 c0 = texture2D(tightBloomTex, uv).rgb;
    sum += c0 * 0.16;
    wSum += 0.16;

    float r1 = 5.5;
    float r2 = 13.5;

    for (int i = 0; i < 6; i++) {
        float ang = float(i) * (TAU / 6.0);
        vec2 dir = vec2(cos(ang), sin(ang)) * texelSize;
        sum += texture2D(tightBloomTex, clamp(uv + dir * r1, vec2(0.001), vec2(0.999))).rgb * 0.09;
        wSum += 0.09;
    }

    for (int i = 0; i < 6; i++) {
        float ang = (float(i) + 0.5) * (TAU / 6.0);
        vec2 dir = vec2(cos(ang), sin(ang)) * texelSize;
        sum += texture2D(tightBloomTex, clamp(uv + dir * r2, vec2(0.001), vec2(0.999))).rgb * 0.05;
        wSum += 0.05;
    }

    return sum / max(wSum, 1e-4);
}

#endif // AETHERON_BLOOM_GLSL
