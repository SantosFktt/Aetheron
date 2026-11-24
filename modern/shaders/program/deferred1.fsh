// ==============================================================================
// AETHERON SHADERS — Deferred Pass 1 (Modern Iris)
// Evaluates Full Sky + Volumetric Clouds + Deferred PBR Opaque Shading + SSIL
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

in vec2 vTexCoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outSceneHDR;

void main() {
    float depth = texture(depthtex0, vTexCoord).r;
    bool isSky  = (depth >= 0.99999);
    float dither = temporalIGN(gl_FragCoord.xy, frameCounter);

    vec3 viewPos = screenToViewPos(vTexCoord, isSky ? 1.0 : depth);
    vec3 playerPos = viewToPlayerPos(viewPos);
    vec3 viewDirWorld = normalize(playerPos);

    vec4 cloudData = texture(colortex5, vTexCoord);

    // Sky pixels: render physically-inspired atmosphere + celestials + volumetric clouds
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

        outSceneHDR = vec4(max(skyCol, vec3(0.0)), 1.0);
        return;
    }

    // Unpack G-Buffer
    vec4 albedoSample = texture(colortex0, vTexCoord);
    vec4 normalMat    = texture(colortex1, vTexCoord);
    vec4 lightMeta    = texture(colortex2, vTexCoord);
    vec4 occData      = texture(colortex4, vTexCoord);

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

    // Screen-Space Indirect Lighting (colored diffuse bounce from temporal HDR buffer)
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

    // Composite clouds that pass in front of tall mountains/towers
    #ifdef DIMENSION_OVERWORLD
        if (cloudData.a < 0.998) {
            litColor = litColor * cloudData.a + cloudData.rgb;
        }
    #endif

    outSceneHDR = vec4(max(litColor, vec3(0.0)), 1.0);
}
