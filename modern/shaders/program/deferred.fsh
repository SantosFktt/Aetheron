// ==============================================================================
// AETHERON SHADERS — Deferred Pass 0 (Modern Iris)
// Computes GTAO, Screen-Space Contact Shadows, and Volumetric Clouds
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

in vec2 vTexCoord;

/* RENDERTARGETS: 4,5 */
layout(location = 0) out vec4 outOcclusion;
layout(location = 1) out vec4 outClouds;

void main() {
    float depth = texture(depthtex0, vTexCoord).r;
    bool isSky  = (depth >= 0.99999);
    float dither = temporalIGN(gl_FragCoord.xy, frameCounter);

    vec3 viewPos = screenToViewPos(vTexCoord, isSky ? 1.0 : depth);
    vec3 playerPos = viewToPlayerPos(viewPos);
    vec3 rayDirWorld = normalize(playerPos);

    // 1. GTAO + Screen-Space Contact Shadows (for opaque terrain only)
    float ao = 1.0;
    float contactShadow = 1.0;
    if (!isSky) {
        vec3 viewNormal = decodeOctNormal(texture(colortex1, vTexCoord).rg);
        ao = computeGTAO(vTexCoord, viewPos, viewNormal, dither);

        #ifdef DIMENSION_OVERWORLD
            vec3 lightDirView = getShadowLightDirView();
            contactShadow = computeContactShadow(viewPos, viewNormal, lightDirView, dither);
        #endif
    }
    outOcclusion = vec4(ao, contactShadow, 0.0, 1.0);

    // 2. Volumetric Clouds (Overworld sky & distant terrain intersection)
    vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
    #ifdef DIMENSION_OVERWORLD
        vec3 sunDir  = getSunDirWorld();
        vec3 moonDir = getMoonDirWorld();
        float maxDist = isSky ? 1e6 : length(playerPos);
        // Only evaluate clouds for sky or when terrain is far/high enough to intersect cloud deck
        if (isSky || maxDist > 60.0 || cameraPosition.y > CLOUD_ALTITUDE - 40.0) {
            clouds = renderVolumetricClouds(rayDirWorld, sunDir, moonDir, dither, maxDist);
        }
    #endif
    outClouds = clouds;
}
