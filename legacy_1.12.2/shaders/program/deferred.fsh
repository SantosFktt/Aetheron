// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Deferred Pass 0
// Computes GTAO, Screen-Space Contact Shadows & Volumetric Clouds
// ==============================================================================

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16F;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;

const bool colortex3Clear = true;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex6Clear = false;
*/

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/atmosphere/scattering.glsl"
#include "/lib/atmosphere/clouds.glsl"

uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

#include "/lib/lighting/ao.glsl"
#include "/lib/lighting/shadows.glsl"

varying vec2 vTexCoord;

void main() {
    float depth = texture2D(depthtex0, vTexCoord).r;
    bool isSky  = (depth >= 0.99999);
    float dither = temporalIGN(gl_FragCoord.xy, frameCounter);

    vec3 viewPos = screenToViewPos(vTexCoord, isSky ? 1.0 : depth);
    vec3 playerPos = viewToPlayerPos(viewPos);
    vec3 rayDirWorld = normalize(playerPos);

    float ao = 1.0;
    float contactShadow = 1.0;
    if (!isSky) {
        vec3 viewNormal = decodeOctNormal(texture2D(colortex1, vTexCoord).rg);
        ao = computeGTAO(vTexCoord, viewPos, viewNormal, dither);

        #ifdef DIMENSION_OVERWORLD
            vec3 lightDirView = getShadowLightDirView();
            contactShadow = computeContactShadow(viewPos, viewNormal, lightDirView, dither);
        #endif
    }

    vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
    #ifdef DIMENSION_OVERWORLD
        vec3 sunDir  = getSunDirWorld();
        vec3 moonDir = getMoonDirWorld();
        float maxDist = isSky ? 1000000.0 : length(playerPos);
        if (isSky || maxDist > 60.0 || cameraPosition.y > CLOUD_ALTITUDE - 40.0) {
            clouds = renderVolumetricClouds(rayDirWorld, sunDir, moonDir, dither, maxDist);
        }
    #endif

    /* DRAWBUFFERS:45 */
    gl_FragData[0] = vec4(ao, contactShadow, 0.0, 1.0);
    gl_FragData[1] = clouds;
}
