// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Weather Vertex Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/packing.glsl"

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vColor    = gl_Color;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
    float windTilt = sin(frameTimeCounter * 0.8 + playerPos.z * 0.1) * 0.18 + 0.25;
    playerPos.x += playerPos.y * windTilt * 0.06 * WIND_STRENGTH;
    viewPos = gbufferModelView * vec4(playerPos, 1.0);

    gl_Position = gl_ProjectionMatrix * viewPos;
}
