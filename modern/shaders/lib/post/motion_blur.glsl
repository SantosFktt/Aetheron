#ifndef AETHERON_MOTION_BLUR_GLSL
#define AETHERON_MOTION_BLUR_GLSL

// ==============================================================================
// AETHERON SHADERS — Optional Camera Velocity Motion Blur
// ==============================================================================

vec3 applyMotionBlur(sampler2D colorTex, sampler2D depthTex, vec2 uv, float dither) {
    #if MOTION_BLUR_ENABLED == 0
        return texture(colorTex, uv).rgb;
    #endif

    float depth = texture(depthTex, uv).r;
    // Exclude player hand from camera motion blur
    if (depth < 0.56) {
        return texture(colorTex, uv).rgb;
    }

    vec3 prevScreen = reprojectToPreviousScreen(uv, depth);
    vec2 velocity = (uv - prevScreen.xy) * MOTION_BLUR_STRENGTH * 0.55;

    // Clamp max velocity so rapid mouse turns remain clean and artifact-free
    float speed = length(velocity);
    if (speed < 0.0008) {
        return texture(colorTex, uv).rgb;
    }
    velocity *= min(speed, 0.032) / speed;

    const int MB_TAPS = 6;
    vec3 sum = vec3(0.0);
    float wSum = 0.0;

    for (int i = 0; i < MB_TAPS; i++) {
        float t = (float(i) + dither) / float(MB_TAPS) - 0.5;
        vec2 sampleUV = clamp(uv + velocity * t, vec2(0.001), vec2(0.999));
        float sampleDepth = texture(depthTex, sampleUV).r;
        if (sampleDepth < 0.56) continue;

        sum += texture(colorTex, sampleUV).rgb;
        wSum += 1.0;
    }

    return (wSum > 0.5) ? (sum / wSum) : texture(colorTex, uv).rgb;
}

#endif // AETHERON_MOTION_BLUR_GLSL
