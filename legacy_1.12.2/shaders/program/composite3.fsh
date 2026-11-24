// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Composite Pass 3
// Bloom Wide Atmospheric Blur (written to colortex5)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/post/bloom.glsl"

uniform sampler2D colortex4;

varying vec2 vTexCoord;

void main() {
    vec2 texelSize = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec3 bloomWide = computeBloomPass2(colortex4, vTexCoord, texelSize);

    /* DRAWBUFFERS:5 */
    gl_FragData[0] = vec4(max(bloomWide, vec3(0.0)), 1.0);
}
