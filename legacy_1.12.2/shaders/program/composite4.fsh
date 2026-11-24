// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Composite Pass 4
// Temporal Anti-Aliasing (YCoCg 3x3 Variance Clamping) & History Persistence
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/post/taa_sharpen.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

varying vec2 vTexCoord;

void main() {
    vec2 texelSize = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec3 resolved = computeTAA(colortex0, colortex6, depthtex0, vTexCoord, texelSize);

    /* DRAWBUFFERS:06 */
    gl_FragData[0] = vec4(resolved, 1.0);
    gl_FragData[1] = vec4(resolved, 1.0);
}
