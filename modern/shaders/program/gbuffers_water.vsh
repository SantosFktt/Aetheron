// ==============================================================================
// AETHERON SHADERS — Water & Translucent Terrain Vertex Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"

in vec4 mc_Entity;

out vec2 vTexCoord;
out vec2 vLightmap;
out vec4 vColor;
out vec3 vViewNormal;
flat out int vMatId;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap   = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vColor      = gl_Color;
    vViewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vMatId      = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec4 clipPos = gl_ProjectionMatrix * viewPos;

    #if TAA_ENABLED == 1
        clipPos.xy += getTaaJitter(frameCounter, vec2(viewWidth, viewHeight)) * clipPos.w;
    #endif

    gl_Position = clipPos;
}
