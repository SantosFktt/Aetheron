#ifndef AETHERON_PACKING_GLSL
#define AETHERON_PACKING_GLSL

// ==============================================================================
// AETHERON SHADERS — Compact G-Buffer Encoding & Decoding (GLSL 120)
// ==============================================================================

vec2 signNotZero(vec2 v) {
    return vec2((v.x >= 0.0) ? 1.0 : -1.0, (v.y >= 0.0) ? 1.0 : -1.0);
}

vec2 encodeOctNormal(vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z) + 0.000001);
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * signNotZero(n.xy);
    }
    return n.xy * 0.5 + 0.5;
}

vec3 decodeOctNormal(vec2 e) {
    vec2 f = e * 2.0 - 1.0;
    vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float t = clamp(-n.z, 0.0, 1.0);
    n.x += (n.x >= 0.0) ? -t : t;
    n.y += (n.y >= 0.0) ? -t : t;
    return normalize(n);
}

float packMaterialId(int id) {
    return (clamp(float(id), 0.0, 255.0) + 0.5) / 255.0;
}

int unpackMaterialId(float packedVal) {
    return int(floor(clamp(packedVal, 0.0, 1.0) * 255.0));
}

float packSssEmissive(float sss, float emissive) {
    if (emissive > 0.005) {
        return 0.51 + clamp(emissive, 0.0, 1.0) * 0.49;
    }
    return clamp(sss, 0.0, 1.0) * 0.49;
}

float unpackSss(float v) {
    return (v <= 0.50) ? clamp(v / 0.49, 0.0, 1.0) : 0.0;
}

float unpackEmissive(float v) {
    return (v > 0.50) ? clamp((v - 0.51) / 0.49, 0.0, 1.0) : 0.0;
}

vec2 decodeLightmap(vec2 lm) {
    return clamp(lm * (16.0 / 15.0) - (0.5 / 15.0), 0.0, 1.0);
}

#endif
