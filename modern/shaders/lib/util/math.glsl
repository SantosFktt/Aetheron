#ifndef AETHERON_MATH_GLSL
#define AETHERON_MATH_GLSL

// ==============================================================================
// AETHERON SHADERS — Core Mathematical Utilities & Color Space Helpers
// ==============================================================================

const float PI      = 3.14159265359;
const float TAU     = 6.28318530718;
const float INV_PI  = 0.31830988618;
const float HALF_PI = 1.57079632679;
const float GOLDEN_ANGLE = 2.39996322973;

float sqr(float x) { return x * x; }
vec2  sqr(vec2 x)  { return x * x; }
vec3  sqr(vec3 x)  { return x * x; }

float cube(float x) { return x * x * x; }
float pow4(float x) { float x2 = x * x; return x2 * x2; }
float pow5(float x) { float x2 = x * x; return x2 * x2 * x; }

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2  saturate(vec2 x)  { return clamp(x, 0.0, 1.0); }
vec3  saturate(vec3 x)  { return clamp(x, 0.0, 1.0); }
vec4  saturate(vec4 x)  { return clamp(x, 0.0, 1.0); }

float maxOf(vec3 v) { return max(v.x, max(v.y, v.z)); }
float minOf(vec3 v) { return min(v.x, min(v.y, v.z)); }

// Rec.709 relative luminance
float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Fast accurate sRGB <-> Linear conversions
vec3 srgbToLinear(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 linearToSrgb(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

// Color temperature (Kelvin) to linear RGB approximation (Tanner Helland / Planckian fit)
vec3 blackbodyColor(float kelvin) {
    float t = clamp(kelvin, 1500.0, 12000.0) * 0.01;
    float r, g, b;
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
    return col / max(luminance(col), 1e-4);
}

// Interleaved Gradient Noise (Jorge Jimenez) — ideal blue-noise-like screen dither
float interleavedGradientNoise(vec2 pixelCoord) {
    return fract(52.9829189 * fract(dot(pixelCoord, vec2(0.06711056, 0.00583715))));
}

// Temporally animated IGN using golden ratio R1 sequence
float temporalIGN(vec2 pixelCoord, int frame) {
    float shift = fract(float(frame & 63) * 0.61803398875);
    return fract(interleavedGradientNoise(pixelCoord + vec2(shift * 47.0, shift * 17.0)) + shift);
}

// Triangular-PDF dither in [-1, 1] for banding-free 8-bit output
float triangularDither(vec2 pixelCoord, int frame) {
    float n1 = temporalIGN(pixelCoord, frame);
    float n2 = temporalIGN(pixelCoord + vec2(11.3, 29.7), frame + 7);
    return n1 - n2;
}

// Build an orthonormal basis from unit normal n (Duff et al. 2017)
mat3 buildOrthonormalBasis(vec3 n) {
    float s = (n.z >= 0.0) ? 1.0 : -1.0;
    float a = -1.0 / (s + n.z);
    float b = n.x * n.y * a;
    vec3 t = vec3(1.0 + s * n.x * n.x * a, s * b, -s * n.x);
    vec3 bt = vec3(b, s + n.y * n.y * a, -n.y);
    return mat3(t, bt, n);
}

// Halton sequence for TAA subpixel jitter
float halton(int index, int base) {
    float f = 1.0;
    float r = 0.0;
    int i = index;
    while (i > 0) {
        f /= float(base);
        r += f * float(i % base);
        i /= base;
    }
    return r;
}

vec2 getTaaJitter(int frame, vec2 resolution) {
    int idx = (frame % 16) + 1;
    vec2 j = vec2(halton(idx, 2), halton(idx, 3)) - 0.5;
    return (j * 2.0) / max(resolution, vec2(1.0));
}

// Vogel disk sampling pattern for shadows & AO
vec2 vogelDiskSample(int index, int count, float phi) {
    float r = sqrt((float(index) + 0.5) / float(count));
    float theta = float(index) * GOLDEN_ANGLE + phi;
    return vec2(cos(theta), sin(theta)) * r;
}

#endif // AETHERON_MATH_GLSL
