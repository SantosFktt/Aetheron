// ==============================================================================
// AETHERON SHADERS — Terrain G-Buffer Vertex Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/surface/vegetation.glsl"

in vec4 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 vTexCoord;
out vec2 vLightmap;
out vec4 vColor;
out vec3 vViewNormal;
flat out int vMatId;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vColor    = gl_Color;
    vMatId    = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    #if WAVING_FOLIAGE == 1
        if (vMatId >= MAT_FOLIAGE_LOW && vMatId <= MAT_UNDERWATER_PLANT) {
            vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
            vec3 worldPos  = playerPos + cameraPosition;
            vec3 wind = computeVegetationWindOffset(worldPos, vMatId, vTexCoord, mc_midTexCoord, vLightmap.y);
            playerPos += wind;
            viewPos = gbufferModelView * vec4(playerPos, 1.0);
        }
    #endif

    // Smooth foliage upward normal bias prevents harsh black leaf back-faces
    vec3 n = normalize(gl_NormalMatrix * gl_Normal);
    if (vMatId == MAT_FOLIAGE_LOW || vMatId == MAT_FOLIAGE_TALL || vMatId == MAT_CROPS) {
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
