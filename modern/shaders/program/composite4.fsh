// ==============================================================================
// AETHERON SHADERS — Composite Pass 4 (Modern Iris)
// Temporal Anti-Aliasing (YCoCg 3x3 Variance Clamping) & Temporal History Update
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/post/taa_sharpen.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

in vec2 vTexCoord;

/* RENDERTARGETS: 0,6 */
layout(location = 0) out vec4 outResolvedHDR;
layout(location = 1) out vec4 outHistoryHDR;

void main() {
    vec2 texelSize = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec3 resolved = computeTAA(colortex0, colortex6, depthtex0, vTexCoord, texelSize);

    outResolvedHDR = vec4(resolved, 1.0);
    outHistoryHDR  = vec4(resolved, 1.0);
}
