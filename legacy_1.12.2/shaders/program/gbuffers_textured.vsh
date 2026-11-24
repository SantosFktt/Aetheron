// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Hand & Textured Vertex Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/util/packing.glsl"

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vViewNormal;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap   = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vColor      = gl_Color;
    vViewNormal = (length(gl_Normal) > 0.001) ? normalize(gl_NormalMatrix * gl_Normal) : vec3(0.0, 1.0, 0.0);
    gl_Position = ftransform();
}
