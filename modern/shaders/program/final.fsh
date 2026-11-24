// ==============================================================================
// AETHERON SHADERS — Final Output Pass (Modern Iris)
// Multi-Scale Bloom, Adaptive Exposure, Filmic Tonemapping, Natural Color Grading,
// Contrast Adaptive Sharpening (CAS), Vignette & Anti-Banding Dithering
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/post/tonemap.glsl"
#include "/lib/post/taa_sharpen.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

in vec2 vTexCoord;

layout(location = 0) out vec4 outFinalColor;

void main() {
    vec2 texelSize = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec3 hdr = texture(colortex0, vTexCoord).rgb;

    // 1. Multi-Scale Cinematic Bloom (subtle, natural highlight glow)
    #if BLOOM_QUALITY == 2
        vec3 bloomTight = texture(colortex4, vTexCoord).rgb;
        vec3 bloomWide  = texture(colortex5, vTexCoord).rgb;
        vec3 bloom = bloomTight * 0.42 + bloomWide * 0.58;
        hdr += bloom * BLOOM_STRENGTH;
    #elif BLOOM_QUALITY == 1
        vec3 bloomTight = texture(colortex4, vTexCoord).rgb;
        hdr += bloomTight * BLOOM_STRENGTH * 0.85;
    #endif

    // 2. Adaptive & Manual Exposure Control
    hdr *= computeAdaptiveExposure();

    // 3. Filmic Display Tonemapping (ACES / AgX / Aetheron / Uncharted 2)
    vec3 mappedLinear = applyTonemap(max(hdr, vec3(0.0)));

    // 4. Linear -> sRGB Display Encoding
    vec3 srgb = linearToSrgb(mappedLinear);

    // 5. Natural Color Grading (Balance, Subtle Split-Tone, Vibrance, Saturation, Contrast)
    srgb = applyColorGrading(srgb);

    // 6. Optional Contrast Adaptive Sharpening (restores fine texture detail after TAA)
    srgb = applyCASSharpening(colortex0, vTexCoord, texelSize, srgb);

    // 7. Subtle Cinematic Vignette
    srgb = applyVignette(srgb, vTexCoord);

    // 8. Triangular-PDF Dithering (eliminates 8-bit sky & fog banding)
    #ifdef DITHERING_ENABLED
        srgb += vec3(triangularDither(gl_FragCoord.xy, frameCounter) / 255.0);
    #endif

    outFinalColor = vec4(clamp(srgb, 0.0, 1.0), 1.0);
}
