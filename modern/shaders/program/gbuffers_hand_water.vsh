// ==============================================================================
// AETHERON SHADERS — Translucent Hand Items Vertex Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/packing.glsl"

out vec2 vTexCoord;
out vec2 vLightmap;
out vec4 vColor;
out vec3 vViewNormal;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap   = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vColor      = gl_Color;
    vViewNormal = normalize(gl_NormalMatrix * gl_Normal);
    gl_Position = ftransform();
}
