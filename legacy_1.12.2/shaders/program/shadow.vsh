// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Shadow Pass Vertex Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/surface/vegetation.glsl"

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

varying vec2 vTexCoord;
varying vec4 vColor;
varying float vMatId;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor    = gl_Color;
    vMatId    = mc_Entity.x;
    int matId = int(mc_Entity.x + 0.5);

    vec4 shadowViewPos = gl_ModelViewMatrix * gl_Vertex;

    #if WAVING_FOLIAGE == 1
        if (matId >= MAT_FOLIAGE_LOW && matId <= MAT_UNDERWATER_PLANT) {
            vec3 playerPos = (shadowModelViewInverse * shadowViewPos).xyz;
            vec3 worldPos  = playerPos + cameraPosition;
            vec2 lm = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
            vec3 wind = computeVegetationWindOffset(worldPos, matId, vTexCoord, mc_midTexCoord, lm.y);
            playerPos += wind;
            shadowViewPos = shadowModelView * vec4(playerPos, 1.0);
        }
    #endif

    vec4 clipPos = gl_ProjectionMatrix * shadowViewPos;
    clipPos.xyz /= clipPos.w;
    clipPos.xyz = distortShadowClip(clipPos.xyz);
    gl_Position = vec4(clipPos.xyz, 1.0);
}
