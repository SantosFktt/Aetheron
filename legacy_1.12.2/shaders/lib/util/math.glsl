#ifndef AETHERON_MATH_GLSL
#define AETHERON_MATH_GLSL

// ==============================================================================
// AETHERON SHADERS — Core Math Utilities (Strictly GLSL 120 Compatible)
// No bitwise operators, no integer modulo, no uint
// ==============================================================================

const float PI      = 3.14159265359;
const float TAU     = 6.28318530718;
const float INV_PI  = 0.31830988618;
const float HALF_PI = 1.57079632679;
const float GOLDEN_ANGLE = 2.39996322973;

float sqr(float x) { return x * x; }
vec2  sqr(vec2 x)  { return x * x; }
vec3  sqr(vec3 x)  { return x * x; }

float pow5(float x) { float x2 = x * x; return x2 * x2 * x; }

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2  saturate(vec2 x)  { return clamp(x, 0.0, 1.0); }
vec3  saturate(vec3 x)  { return clamp(x, 0.0, 1.0); }

float maxOf(vec3 v) { return max(v.x, max(v.y, v.z)); }
float minOf(vec3 v) { return min(v.x, min(v.y, v.z)); }

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 srgbToLinear(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 linearToSrgb(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

vec3 blackbodyColor(float kelvin) {
    float t = clamp(kelvin, 1500.0, 12000.0) * 0.01;
    float r = 1.0;
    float g = 1.0;
    float b = 1.0;
    if (t <= 66.0) {
        r = 1.0;
        g = clamp(0.390081578769 * log(t) - 0.631841443788, 0.0, 1.0);
        b = (t <= 19.0) ? 0.0 : clamp(0.543206789110 * log(t - 10.0) - 1.19625408914, 0.0, 1.0);
    } else {
        r = clamp(1.292936186062 * pow(t - 60.0, -0.1332047592), 0.0, 1.0);
        g = clamp(1.129890860895 * pow(t - 60.0, -0.0755148492), 0.0, 1.0);
        b = 1.0;
    }
    vec3 col = srgbToLinear(vec3(r, g, b));
    return col / max(luminance(col), 0.0001);
}

float interleavedGradientNoise(vec2 pixelCoord) {
    return fract(52.9829189 * fract(dot(pixelCoord, vec2(0.06711056, 0.00583715))));
}

// GLSL 120 safe temporal IGN using float mod() instead of bitwise &
float temporalIGN(vec2 pixelCoord, int frame) {
    float fMod = mod(float(frame), 64.0);
    float shift = fract(fMod * 0.61803398875);
    return fract(interleavedGradientNoise(pixelCoord + vec2(shift * 47.0, shift * 17.0)) + shift);
}

float triangularDither(vec2 pixelCoord, int frame) {
    float n1 = temporalIGN(pixelCoord, frame);
    float n2 = temporalIGN(pixelCoord + vec2(11.3, 29.7), frame + 7);
    return n1 - n2;
}

// GLSL 120 safe Halton sequence using float floor/mod
float halton120(float index, float base) {
    float f = 1.0;
    float r = 0.0;
    float i = index;
    for (int step = 0; step < 5; step++) {
        if (i <= 0.5) break;
        f /= base;
        r += f * mod(i, base);
        i = floor(i / base);
    }
    return r;
}

vec2 getTaaJitter(int frame, vec2 resolution) {
    float idx = mod(float(frame), 16.0) + 1.0;
    vec2 j = vec2(halton120(idx, 2.0), halton120(idx, 3.0)) - 0.5;
    return (j * 2.0) / max(resolution, vec2(1.0));
}

vec2 vogelDiskSample(int index, int count, float phi) {
    float r = sqrt((float(index) + 0.5) / float(count));
    float theta = float(index) * GOLDEN_ANGLE + phi;
    return vec2(cos(theta), sin(theta)) * r;
}

#endif
