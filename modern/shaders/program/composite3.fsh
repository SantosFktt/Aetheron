// ==============================================================================
// AETHERON SHADERS — Composite Pass 3 (Modern Iris)
// Bloom Wide Multi-Ring Atmospheric Blur (written to colortex5)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/post/bloom.glsl"

uniform sampler2D colortex4;

in vec2 vTexCoord;

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 outBloomWide;

void main() {
    vec2 texelSize = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec3 bloomWide = computeBloomPass2(colortex4, vTexCoord, texelSize);
    outBloomWide = vec4(max(bloomWide, vec3(0.0)), 1.0);
}
