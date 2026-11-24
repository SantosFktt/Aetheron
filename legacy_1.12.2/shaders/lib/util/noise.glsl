#ifndef AETHERON_NOISE_GLSL
#define AETHERON_NOISE_GLSL

// ==============================================================================
// AETHERON SHADERS — Procedural Noise (Strictly GLSL 120 Compatible)
// ==============================================================================

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float valueNoise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash12(i + vec2(0.0, 0.0));
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float valueNoise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);

    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);

    return mix(nxy0, nxy1, u.z);
}

float worleyBillow2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float minDist = 1.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 pt = hash22(i + neighbor);
            vec2 diff = neighbor + pt - f;
            minDist = min(minDist, dot(diff, diff));
        }
    }
    return 1.0 - clamp(sqrt(minDist), 0.0, 1.0);
}

float worleyBillow3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    float minDist = 1.0;
    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 pt = hash33(i + neighbor);
                vec3 diff = neighbor + pt - f;
                minDist = min(minDist, dot(diff, diff));
            }
        }
    }
    return 1.0 - clamp(sqrt(minDist), 0.0, 1.0);
}

float fbm2D(vec2 p, int octaves) {
    mat2 rot2 = mat2(0.80, -0.60, 0.60, 0.80);
    float val = 0.0;
    float amp = 0.5;
    float norm = 0.0;
    for (int i = 0; i < 5; i++) {
        if (i >= octaves) break;
        val += amp * valueNoise2D(p);
        norm += amp;
        p = rot2 * p * 2.03 + vec2(17.1, 31.7);
        amp *= 0.5;
    }
    return val / max(norm, 0.0001);
}

float fbm3D(vec3 p, int octaves) {
    float val = 0.0;
    float amp = 0.5;
    float norm = 0.0;
    for (int i = 0; i < 4; i++) {
        if (i >= octaves) break;
        val += amp * valueNoise3D(p);
        norm += amp;
        p = p * 2.02 + vec3(13.7, 29.3, 41.1);
        amp *= 0.5;
    }
    return val / max(norm, 0.0001);
}

float remap(float value, float origMin, float origMax, float newMin, float newMax) {
    return newMin + ((value - origMin) / max(origMax - origMin, 0.00001)) * (newMax - newMin);
}

float remapClamped(float value, float origMin, float origMax, float newMin, float newMax) {
    return clamp(remap(value, origMin, origMax, newMin, newMax), min(newMin, newMax), max(newMin, newMax));
}

#endif
