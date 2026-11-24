#ifndef AETHERON_PACKING_GLSL
#define AETHERON_PACKING_GLSL

// ==============================================================================
// AETHERON SHADERS — Compact G-Buffer Encoding & Decoding
// Octahedral unit normal packing (high precision in 2x16F channels)
// ==============================================================================

vec2 signNotZero(vec2 v) {
    return vec2((v.x >= 0.0) ? 1.0 : -1.0, (v.y >= 0.0) ? 1.0 : -1.0);
}

// Unit vector -> Octahedral [0, 1]^2
vec2 encodeOctNormal(vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z) + 1e-6);
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * signNotZero(n.xy);
    }
    return n.xy * 0.5 + 0.5;
}

// Octahedral [0, 1]^2 -> Unit vector
vec3 decodeOctNormal(vec2 e) {
    vec2 f = e * 2.0 - 1.0;
    vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float t = clamp(-n.z, 0.0, 1.0);
    n.x += (n.x >= 0.0) ? -t : t;
    n.y += (n.y >= 0.0) ? -t : t;
    return normalize(n);
}

// Material ID packing [0..255] <-> [0..1]
float packMaterialId(int id) {
    return (float(clamp(id, 0, 255)) + 0.5) / 255.0;
}

int unpackMaterialId(float packedVal) {
    return int(floor(clamp(packedVal, 0.0, 1.0) * 255.0));
}

// Pack SSS [0..1] OR Emissive [0..1] into colortex2.a
//   [0.00 .. 0.49] -> SSS strength (0 = none, 0.49 = max foliage SSS)
//   [0.51 .. 1.00] -> Emissive strength (0.51 = weak, 1.00 = full glow)
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

// Decode Minecraft lightmap coords cleanly (removes 1/32 half-texel border offset)
vec2 decodeLightmap(vec2 lm) {
    return clamp(lm * (16.0 / 15.0) - (0.5 / 15.0), 0.0, 1.0);
}

#endif // AETHERON_PACKING_GLSL
