// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Terrain G-Buffer Vertex Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/surface/vegetation.glsl"

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vViewNormal;
varying float vMatId;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vColor    = gl_Color;
    vMatId    = mc_Entity.x;
    int matId = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    #if WAVING_FOLIAGE == 1
        if (matId >= MAT_FOLIAGE_LOW && matId <= MAT_UNDERWATER_PLANT) {
            vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
            vec3 worldPos  = playerPos + cameraPosition;
            vec3 wind = computeVegetationWindOffset(worldPos, matId, vTexCoord, mc_midTexCoord, vLightmap.y);
            playerPos += wind;
            viewPos = gbufferModelView * vec4(playerPos, 1.0);
        }
    #endif

    vec3 n = normalize(gl_NormalMatrix * gl_Normal);
    if (matId == MAT_FOLIAGE_LOW || matId == MAT_FOLIAGE_TALL || matId == MAT_CROPS) {
        vec3 upView = normalize(upPosition);
        n = normalize(mix(n, upView, 0.72));
    }
    vViewNormal = n;

    vec4 clipPos = gl_ProjectionMatrix * viewPos;
    #if TAA_ENABLED == 1
        clipPos.xy += getTaaJitter(frameCounter, vec2(viewWidth, viewHeight)) * clipPos.w;
    #endif

    gl_Position = clipPos;
}
