// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Deferred Pass 1
// Sky + Volumetric Clouds + Deferred PBR Opaque Shading + SSIL
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/atmosphere/scattering.glsl"
#include "/lib/atmosphere/sky.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

#include "/lib/lighting/shadows.glsl"
#include "/lib/lighting/ssil.glsl"
#include "/lib/lighting/shading.glsl"

varying vec2 vTexCoord;

void main() {
    float depth = texture2D(depthtex0, vTexCoord).r;
    bool isSky  = (depth >= 0.99999);
    float dither = temporalIGN(gl_FragCoord.xy, frameCounter);

    vec3 viewPos = screenToViewPos(vTexCoord, isSky ? 1.0 : depth);
    vec3 playerPos = viewToPlayerPos(viewPos);
    vec3 viewDirWorld = normalize(playerPos);

    vec4 cloudData = texture2D(colortex5, vTexCoord);

    if (isSky) {
        vec3 skyCol;
        #ifdef DIMENSION_OVERWORLD
            vec3 sunDir  = getSunDirWorld();
            vec3 moonDir = getMoonDirWorld();
            skyCol = computeOverworldSky(viewDirWorld, sunDir, moonDir, true);
            skyCol = skyCol * cloudData.a + cloudData.rgb;
        #elif defined(DIMENSION_NETHER)
            skyCol = computeNetherSky(viewDirWorld);
        #else
            skyCol = computeEndSky(viewDirWorld);
        #endif

        /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(max(skyCol, vec3(0.0)), 1.0);
        return;
    }

    vec4 albedoSample = texture2D(colortex0, vTexCoord);
    vec4 normalMat    = texture2D(colortex1, vTexCoord);
    vec4 lightMeta    = texture2D(colortex2, vTexCoord);
    vec4 occData      = texture2D(colortex4, vTexCoord);

    vec3 albedoLinear = srgbToLinear(albedoSample.rgb);
    vec3 viewNormal   = decodeOctNormal(normalMat.rg);
    vec3 worldNormal  = normalize((gbufferModelViewInverse * vec4(viewNormal, 0.0)).xyz);
    int  matId        = unpackMaterialId(normalMat.b);

    vec2  lightmap     = lightMeta.rg;
    float vanillaAO    = lightMeta.b;
    float sssStrength  = unpackSss(lightMeta.a);
    float emissiveMask = unpackEmissive(lightMeta.a);

    float ssao          = occData.r;
    float contactShadow = occData.g;

    vec3 ssilBounce = computeSSIL(vTexCoord, viewPos, viewNormal, dither, colortex6);

    vec3 litColor = shadeOpaqueSurface(
        albedoLinear,
        viewPos,
        playerPos,
        worldNormal,
        viewNormal,
        lightmap,
        vanillaAO,
        ssao,
        contactShadow,
        matId,
        sssStrength,
        emissiveMask,
        dither,
        ssilBounce
    );

    #ifdef DIMENSION_OVERWORLD
        if (cloudData.a < 0.998) {
            litColor = litColor * cloudData.a + cloudData.rgb;
        }
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(max(litColor, vec3(0.0)), 1.0);
}
