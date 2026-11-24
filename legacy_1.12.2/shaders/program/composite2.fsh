// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Composite Pass 2
// Optional Motion Blur / DoF + Bloom Bright-Pass & Tight Blur (colortex4)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/post/dof.glsl"
#include "/lib/post/motion_blur.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

varying vec2 vTexCoord;

void main() {
    vec2 texelSize = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    float dither = temporalIGN(gl_FragCoord.xy, frameCounter);

    vec3 sceneCol = texture2D(colortex0, vTexCoord).rgb;

    #if MOTION_BLUR_ENABLED == 1
        sceneCol = applyMotionBlur(colortex0, depthtex0, vTexCoord, dither);
    #endif

    #if DOF_ENABLED == 1
        sceneCol = applyDepthOfField(colortex0, depthtex0, vTexCoord, texelSize, dither);
    #endif

    vec3 bloomTight = computeBloomPass1(colortex0, vTexCoord, texelSize);

    /* DRAWBUFFERS:04 */
    gl_FragData[0] = vec4(max(sceneCol, vec3(0.0)), 1.0);
    gl_FragData[1] = vec4(max(bloomTight, vec3(0.0)), 1.0);
}
