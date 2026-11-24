// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Final Output Pass
// Bloom, Adaptive Exposure, Tonemapping, Color Grading, CAS, Vignette & Dither
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

varying vec2 vTexCoord;

void main() {
    vec2 texelSize = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec3 hdr = texture2D(colortex0, vTexCoord).rgb;

    #if BLOOM_QUALITY == 2
        vec3 bloomTight = texture2D(colortex4, vTexCoord).rgb;
        vec3 bloomWide  = texture2D(colortex5, vTexCoord).rgb;
        vec3 bloom = bloomTight * 0.42 + bloomWide * 0.58;
        hdr += bloom * BLOOM_STRENGTH;
    #elif BLOOM_QUALITY == 1
        vec3 bloomTight = texture2D(colortex4, vTexCoord).rgb;
        hdr += bloomTight * BLOOM_STRENGTH * 0.85;
    #endif

    hdr *= computeAdaptiveExposure();

    vec3 mappedLinear = applyTonemap(max(hdr, vec3(0.0)));
    vec3 srgb = linearToSrgb(mappedLinear);
    srgb = applyColorGrading(srgb);
    srgb = applyCASSharpening(colortex0, vTexCoord, texelSize, srgb);
    srgb = applyVignette(srgb, vTexCoord);

    #ifdef DITHERING_ENABLED
        srgb += vec3(triangularDither(gl_FragCoord.xy, frameCounter) / 255.0);
    #endif

    gl_FragColor = vec4(clamp(srgb, 0.0, 1.0), 1.0);
}
