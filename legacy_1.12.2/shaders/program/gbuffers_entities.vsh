// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Entities & Block Entities Vertex
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
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

    vec4 clipPos = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    #if TAA_ENABLED == 1
        clipPos.xy += getTaaJitter(frameCounter, vec2(viewWidth, viewHeight)) * clipPos.w;
    #endif
    gl_Position = clipPos;
}
