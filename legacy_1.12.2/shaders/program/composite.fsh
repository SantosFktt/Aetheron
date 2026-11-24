// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Composite Pass 0
// Water Waves, Refraction, Beer-Lambert Absorption, Caustics, SSR & Underwater Fog
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/atmosphere/scattering.glsl"
#include "/lib/atmosphere/sky.glsl"
#include "/lib/atmosphere/clouds.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

#include "/lib/lighting/shadows.glsl"
#include "/lib/lighting/shading.glsl"
#include "/lib/surface/water.glsl"
#include "/lib/surface/reflections.glsl"
#include "/lib/atmosphere/fog.glsl"

varying vec2 vTexCoord;

void main() {
    float depth0 = texture2D(depthtex0, vTexCoord).r;
    float depth1 = texture2D(depthtex1, vTexCoord).r;
    vec3 sceneColor = texture2D(colortex0, vTexCoord).rgb;

    float dither = temporalIGN(gl_FragCoord.xy, frameCounter);

    vec4 transAlbedoSample = texture2D(colortex3, vTexCoord);
    bool hasTranslucent = (depth0 < depth1 - 0.000001) && (transAlbedoSample.a > 0.004);

    if (hasTranslucent) {
        vec4 normalMat = texture2D(colortex1, vTexCoord);
        vec4 lightMeta = texture2D(colortex2, vTexCoord);

        vec3 viewPos0   = screenToViewPos(vTexCoord, depth0);
        vec3 playerPos0 = viewToPlayerPos(viewPos0);
        vec3 worldPos0  = cameraPosition + playerPos0;

        vec3 viewPos1   = screenToViewPos(vTexCoord, (depth1 >= 0.99999) ? 1.0 : depth1);
        vec3 playerPos1 = viewToPlayerPos(viewPos1);
        vec3 worldPos1  = cameraPosition + playerPos1;

        vec3 geoViewNormal  = decodeOctNormal(normalMat.rg);
        vec3 geoWorldNormal = normalize((gbufferModelViewInverse * vec4(geoViewNormal, 0.0)).xyz);
        int  matId          = unpackMaterialId(normalMat.b);
        vec2 lightmap       = lightMeta.rg;
        float emissiveMask  = unpackEmissive(lightMeta.a);

        vec3 Vworld = normalize(-playerPos0);
        float distToCam = length(playerPos0);

        #ifdef DIMENSION_OVERWORLD
            vec3 sunDir    = getSunDirWorld();
            vec3 moonDir   = getMoonDirWorld();
            vec3 lightDir  = getShadowLightDirWorld();
            vec3 directCol = getActiveCelestialColor(sunDir, moonDir);
            vec3 skyAmb    = getSkyAmbientIrradiance(sunDir, moonDir);
        #elif defined(DIMENSION_NETHER)
            vec3 lightDir  = normalize(vec3(0.0, 1.0, 0.0));
            vec3 directCol = vec3(0.28, 0.09, 0.04);
            vec3 skyAmb    = vec3(0.22, 0.08, 0.04);
        #else
            vec3 lightDir  = normalize(vec3(0.38, 0.82, 0.42));
            vec3 directCol = vec3(0.55, 0.46, 0.80);
            vec3 skyAmb    = vec3(0.14, 0.10, 0.24);
        #endif

        if (matId == MAT_WATER) {
            vec3 waterNormalWorld = computeWaterNormal(worldPos0, geoWorldNormal, lightmap.y, distToCam);
            vec3 waterNormalView  = worldToViewDir(waterNormalWorld);
            float waterThickness  = (depth1 >= 0.99999) ? 28.0 : max(length(playerPos1 - playerPos0), 0.05);

            vec2 refractUV = vTexCoord;
            #if WATER_QUALITY >= 2
                vec2 waveOffset = (waterNormalView.xy - geoViewNormal.xy) * 0.032 * clamp(waterThickness * 0.45, 0.0, 1.0) / max(distToCam * 0.12 + 0.5, 0.5);
                vec2 candUV = clamp(vTexCoord + waveOffset, vec2(0.002), vec2(0.998));
                float candDepth1 = texture2D(depthtex1, candUV).r;
                if (candDepth1 > depth0) {
                    refractUV = candUV;
                }
            #endif

            vec3 behindColor = texture2D(colortex0, refractUV).rgb;
            vec3 waterTintLinear = srgbToLinear(transAlbedoSample.rgb);

            vec3 transmitted;
            evaluateWaterOpticalDepth(
                waterThickness,
                behindColor,
                waterTintLinear,
                directCol,
                skyAmb,
                worldPos1,
                lightDir,
                lightmap.y,
                transmitted
            );

            vec3 reflDirWorld = reflect(-Vworld, waterNormalWorld);
            vec3 envFallback  = sampleSkyReflectionFallback(reflDirWorld, lightmap.y);
            vec4 ssr = traceScreenSpaceReflection(viewPos0, waterNormalView, 0.03, dither, colortex0, depthtex1);
            vec3 reflectionColor = mix(envFallback, ssr.rgb, ssr.a);

            float ndotv = clamp(dot(waterNormalWorld, Vworld), 0.0, 1.0);
            float fresnel = 0.02 + 0.98 * pow5(1.0 - ndotv);

            vec3 specGlint = vec3(0.0);
            #ifdef DIMENSION_OVERWORLD
                float dummySSS;
                vec3 waterShadow = computeDirectionalShadow(playerPos0, geoWorldNormal, lightDir, 0.0, dither, dummySSS);
                float ndotl = max(dot(waterNormalWorld, lightDir), 0.0);
                specGlint = evalGGXSpecular(waterNormalWorld, Vworld, lightDir, 0.045, vec3(0.025))
                          * directCol * ndotl * waterShadow * smoothstep(0.1, 0.5, lightmap.y) * 1.45;
            #else
                float ndotl = max(dot(waterNormalWorld, lightDir), 0.0);
                specGlint = evalGGXSpecular(waterNormalWorld, Vworld, lightDir, 0.06, vec3(0.025)) * directCol * ndotl;
            #endif

            float foam = smoothstep(0.28, 0.02, waterThickness) * 0.14 * (0.6 + 0.4 * valueNoise2D(worldPos0.xz * 4.5 + frameTimeCounter * 0.5));
            vec3 foamColor = (skyAmb + directCol * 0.25) * 0.85;

            sceneColor = mix(transmitted, reflectionColor, clamp(fresnel, 0.02, 0.96)) + specGlint;
            sceneColor = mix(sceneColor, foamColor, foam);
        } else {
            vec3 tintLinear = srgbToLinear(transAlbedoSample.rgb);
            float alpha = transAlbedoSample.a;
            vec3 transmitted = sceneColor * mix(vec3(1.0), tintLinear * 1.15, clamp(alpha * 1.1, 0.0, 0.95));

            vec3 blockLight = computeBlocklight(lightmap.x, worldPos0);
            vec3 handLight  = computeHandheldLight(playerPos0, geoWorldNormal);
            float ndotl = max(dot(geoWorldNormal, lightDir), 0.0);

            vec3 surfLit = tintLinear * (directCol * ndotl * 0.55 * lightmap.y + skyAmb * lightmap.y + blockLight + handLight + vec3(CAVE_BRIGHTNESS));
            surfLit += computeEmissiveRadiance(tintLinear, matId, emissiveMask);

            float roughness = (matId == MAT_ICE) ? 0.12 : 0.06;
            vec3 reflDirWorld = reflect(-Vworld, geoWorldNormal);
            vec3 envFallback  = sampleSkyReflectionFallback(reflDirWorld, lightmap.y);
            vec4 ssr = traceScreenSpaceReflection(viewPos0, geoViewNormal, roughness, dither, colortex0, depthtex1);
            vec3 reflectionColor = mix(envFallback, ssr.rgb, ssr.a);

            float ndotv = clamp(dot(geoWorldNormal, Vworld), 0.0, 1.0);
            float fresnel = 0.04 + 0.96 * pow5(1.0 - ndotv);
            vec3 spec = evalGGXSpecular(geoWorldNormal, Vworld, lightDir, roughness, vec3(0.04)) * directCol * ndotl * lightmap.y;

            vec3 surfaceComposed = mix(transmitted, surfLit, alpha * 0.72);
            sceneColor = mix(surfaceComposed, reflectionColor, fresnel * 0.75) + spec;
        }
    }

    if (isEyeInWater == 1) {
        bool isSky = (depth0 >= 0.99999);
        vec3 viewPos = screenToViewPos(vTexCoord, isSky ? 1.0 : depth0);
        vec3 playerPos = viewToPlayerPos(viewPos);
        vec3 viewDirWorld = normalize(playerPos);
        float viewDist = length(playerPos);

        #ifdef DIMENSION_OVERWORLD
            sceneColor = applyUnderwaterFog(sceneColor, viewDirWorld, viewDist, getSunDirWorld(), getMoonDirWorld(), isSky);
        #else
            sceneColor = applyUnderwaterFog(sceneColor, viewDirWorld, viewDist, vec3(0.0, 1.0, 0.0), vec3(0.0, -1.0, 0.0), isSky);
        #endif
    }

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(max(sceneColor, vec3(0.0)), 1.0);
}
