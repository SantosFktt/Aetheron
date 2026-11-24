#ifndef AETHERON_TAA_SHARPEN_GLSL
#define AETHERON_TAA_SHARPEN_GLSL

// ==============================================================================
// AETHERON SHADERS — Temporal Anti-Aliasing (YCoCg Variance Clamping) & CAS
// ==============================================================================

vec3 rgbToYCoCg(vec3 c) {
    return vec3(
         0.25 * c.r + 0.50 * c.g + 0.25 * c.b,
         0.50 * c.r              - 0.50 * c.b,
        -0.25 * c.r + 0.50 * c.g - 0.25 * c.b
    );
}

vec3 yCoCgToRgb(vec3 c) {
    float tmp = c.x - c.z;
    return max(vec3(tmp + c.y, c.x + c.z, tmp - c.y), vec3(0.0));
}

// Reversible Karis tonemap for flicker-free HDR temporal blending
vec3 taaCompress(vec3 c) {
    return c / (1.0 + luminance(c));
}

vec3 taaExpand(vec3 c) {
    return c / max(1.0 - luminance(c), 1e-4);
}

// YCoCg 3x3 Variance-Clamped TAA Resolve
vec3 computeTAA(sampler2D currentTex, sampler2D historyTex, sampler2D depthTex, vec2 uv, vec2 texelSize) {
    vec3 curr = texture(currentTex, uv).rgb;

    #if TAA_ENABLED == 0
        return curr;
    #endif

    // Find closest depth in 3x3 neighborhood (dilation prevents disocclusion halos on edges)
    float minDepth = 1.0;
    vec2 bestUV = uv;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 sUV = clamp(uv + vec2(float(x), float(y)) * texelSize, vec2(0.001), vec2(0.999));
            float d = texture(depthTex, sUV).r;
            if (d < minDepth) {
                minDepth = d;
                bestUV = sUV;
            }
        }
    }

    // Reproject to previous frame UV
    vec3 prevScr = reprojectToPreviousScreen(bestUV, minDepth);
    vec2 prevUV = prevScr.xy;

    // Reject out-of-bounds history (or first-person hand motion)
    if (prevUV.x < 0.001 || prevUV.x > 0.999 || prevUV.y < 0.001 || prevUV.y > 0.999 || minDepth < 0.56) {
        return curr;
    }

    // Compute 3x3 neighborhood mean & variance in compressed YCoCg space
    vec3 m1 = vec3(0.0);
    vec3 m2 = vec3(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 sUV = clamp(uv + vec2(float(x), float(y)) * texelSize, vec2(0.001), vec2(0.999));
            vec3 c = rgbToYCoCg(taaCompress(texture(currentTex, sUV).rgb));
            m1 += c;
            m2 += c * c;
        }
    }
    m1 /= 9.0;
    m2 /= 9.0;
    vec3 sigma = sqrt(max(m2 - m1 * m1, vec3(0.0)));
    float gamma = 1.15;
    vec3 boxMin = m1 - gamma * sigma;
    vec3 boxMax = m1 + gamma * sigma;

    vec3 currComp = taaCompress(curr);
    vec3 histComp = taaCompress(texture(historyTex, prevUV).rgb);
    vec3 histYCoCg = clamp(rgbToYCoCg(histComp), boxMin, boxMax);
    vec3 clampedHist = yCoCgToRgb(histYCoCg);

    // Velocity-adaptive blend factor (reduces ghosting during rapid camera motion)
    float motionPixels = length((uv - prevUV) / max(texelSize, vec2(1e-5)));
    float blendWeight = mix(0.86, 0.55, clamp(motionPixels * 0.08, 0.0, 1.0));

    vec3 resolved = mix(currComp, clampedHist, blendWeight);
    return max(taaExpand(resolved), vec3(0.0));
}

// AMD FidelityFX-Inspired Contrast Adaptive Sharpening (CAS) in perceptual space
vec3 applyCASSharpening(sampler2D srcTex, vec2 uv, vec2 texelSize, vec3 centerSrgb) {
    #if CAS_SHARPENING == 0
        return centerSrgb;
    #endif

    vec3 n = texture(srcTex, clamp(uv + vec2( 0.0,  texelSize.y), vec2(0.001), vec2(0.999))).rgb;
    vec3 s = texture(srcTex, clamp(uv + vec2( 0.0, -texelSize.y), vec2(0.001), vec2(0.999))).rgb;
    vec3 e = texture(srcTex, clamp(uv + vec2( texelSize.x,  0.0), vec2(0.001), vec2(0.999))).rgb;
    vec3 w = texture(srcTex, clamp(uv + vec2(-texelSize.x,  0.0), vec2(0.001), vec2(0.999))).rgb;

    // Convert neighbor HDR to fast local perceptual proxy for clean contrast estimation
    vec3 nL = n / (1.0 + n);
    vec3 sL = s / (1.0 + s);
    vec3 eL = e / (1.0 + e);
    vec3 wL = w / (1.0 + w);
    vec3 cL = texture(srcTex, uv).rgb;
    cL = cL / (1.0 + cL);

    vec3 minRGB = min(min(min(nL, sL), min(eL, wL)), cL);
    vec3 maxRGB = max(max(max(nL, sL), max(eL, wL)), cL);

    vec3 amp = clamp(min(minRGB, 1.0 - maxRGB) / max(maxRGB, vec3(1e-4)), 0.0, 1.0);
    amp = sqrt(amp);

    float peak = -1.0 / mix(8.0, 5.0, CAS_STRENGTH);
    vec3 weight = amp * peak;

    vec3 highPass = cL - 0.25 * (nL + sL + eL + wL);
    vec3 sharpened = centerSrgb - highPass * weight * 1.45;
    return clamp(sharpened, 0.0, 1.0);
}

#endif // AETHERON_TAA_SHARPEN_GLSL
