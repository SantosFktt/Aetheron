// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Composite Pass 1
// Volumetric Fog, Crepuscular God Rays, Height Valley Mist & Aerial Perspective
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/atmosphere/scattering.glsl"
#include "/lib/atmosphere/sky.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

#include "/lib/atmosphere/fog.glsl"

varying vec2 vTexCoord;

void main() {
    vec3 sceneColor = texture2D(colortex0, vTexCoord).rgb;

    if (isEyeInWater == 1) {
        /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(sceneColor, 1.0);
        return;
    }

    float depth = texture2D(depthtex0, vTexCoord).r;
    bool isSky  = (depth >= 0.99999);
    float dither = temporalIGN(gl_FragCoord.xy, frameCounter);

    vec3 viewPos = screenToViewPos(vTexCoord, isSky ? 1.0 : depth);
    vec3 playerPos = viewToPlayerPos(viewPos);
    vec3 viewDirWorld = normalize(playerPos);
    float viewDist = isSky ? min(far, shadowDistance) : length(playerPos);

    #ifdef DIMENSION_OVERWORLD
        vec3 sunDir  = getSunDirWorld();
        vec3 moonDir = getMoonDirWorld();
        sceneColor = applyOverworldFog(sceneColor, viewDirWorld, viewDist, sunDir, moonDir, isSky);
        sceneColor += computeVolumetricFogAndGodRays(playerPos, viewDirWorld, viewDist, sunDir, moonDir, dither);
    #elif defined(DIMENSION_NETHER)
        sceneColor = applyNetherFog(sceneColor, viewDirWorld, viewDist, isSky);
    #else
        sceneColor = applyEndFog(sceneColor, viewDirWorld, viewDist, isSky);
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(max(sceneColor, vec3(0.0)), 1.0);
}
