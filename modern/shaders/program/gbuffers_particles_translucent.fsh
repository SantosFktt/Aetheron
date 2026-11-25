// ==============================================================================
// AETHERON SHADERS — Forward-Lit Translucent Particles (Modern Iris)
// With particles.ordering = mixed, translucent particles (smoke, splashes, crits,
// dust...) are drawn AFTER the deferred lighting pass, directly on top of the HDR
// scene. They therefore need their own lighting, otherwise they show up as
// unlit full-bright sprites at night and inside caves.
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/atmosphere/scattering.glsl"

uniform sampler2D gtexture;
uniform sampler2D shadowtex1;
uniform float alphaTestRef;

#include "/lib/lighting/blocklight.glsl"

in vec2 vTexCoord;
in vec2 vLightmap;
in vec4 vColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

// Single-tap sun visibility so particles under trees / roofs are not sunlit
float sampleParticleShadow(vec3 playerPos) {
    float distort;
    vec3 shadowPos = playerToShadowScreenPos(playerPos, distort);
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 || shadowPos.y < 0.0 || shadowPos.y > 1.0 || shadowPos.z >= 1.0) {
        return 1.0;
    }
    return (shadowPos.z - 0.0015 > texture(shadowtex1, shadowPos.xy).r) ? 0.0 : 1.0;
}

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < max(alphaTestRef, 0.004)) discard;

    vec3 albedo = srgbToLinear(tex.rgb);
    vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec3 playerPos = viewToPlayerPos(screenToViewPos(screenUV, gl_FragCoord.z));
    vec3 worldPos = playerPos + cameraPosition;

    vec3 light = computeBlocklight(vLightmap.x, worldPos);

    #ifdef DIMENSION_OVERWORLD
        vec3 sunDir  = getSunDirWorld();
        vec3 moonDir = getMoonDirWorld();
        vec3 skyAmb    = getSkyAmbientIrradiance(sunDir, moonDir);
        vec3 celestial = getActiveCelestialColor(sunDir, moonDir);
        float skyMask  = pow(vLightmap.y, 1.55);
        float sunVis   = sampleParticleShadow(playerPos) * smoothstep(0.02, 0.14, vLightmap.y);

        light += skyAmb * skyMask * 1.10;
        light += celestial * sunVis * 0.55;
        light += vec3(0.55, 0.66, 0.85) * CAVE_BRIGHTNESS;
    #elif defined(DIMENSION_NETHER)
        light += vec3(0.30, 0.11, 0.06) * (0.42 + CAVE_BRIGHTNESS * 2.5);
    #else
        light += vec3(0.16, 0.13, 0.26) * (0.85 + CAVE_BRIGHTNESS * 2.5) + vec3(0.66, 0.56, 0.92) * 0.30;
    #endif

    light += vec3(0.35, 0.40, 0.48) * nightVision;

    outColor = vec4(albedo * light, tex.a);
}
