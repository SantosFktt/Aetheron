// ==============================================================================
// AETHERON SHADERS — Shadow Pass Vertex Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/space.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/surface/vegetation.glsl"

in vec4 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 vTexCoord;
out vec4 vColor;
flat out int vMatId;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vColor    = gl_Color;
    vMatId    = int(mc_Entity.x + 0.5);

    vec4 shadowViewPos = gl_ModelViewMatrix * gl_Vertex;

    // Match vertex wind animation in shadow map so foliage shadows sway in sync!
    #if WAVING_FOLIAGE == 1
        if (vMatId >= MAT_FOLIAGE_LOW && vMatId <= MAT_UNDERWATER_PLANT) {
            vec3 playerPos = (shadowModelViewInverse * shadowViewPos).xyz;
            vec3 worldPos  = playerPos + cameraPosition;
            vec2 lm = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
            vec3 wind = computeVegetationWindOffset(worldPos, vMatId, vTexCoord, mc_midTexCoord, lm.y);
            playerPos += wind;
            shadowViewPos = shadowModelView * vec4(playerPos, 1.0);
        }
    #endif

    vec4 clipPos = gl_ProjectionMatrix * shadowViewPos;
    clipPos.xyz /= clipPos.w;
    clipPos.xyz = distortShadowClip(clipPos.xyz);
    gl_Position = vec4(clipPos.xyz, 1.0);
}
