// ==============================================================================
// AETHERON SHADERS — Weather (Rain & Snow) Vertex Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/packing.glsl"

out vec2 vTexCoord;
out vec2 vLightmap;
out vec4 vColor;

void main() {
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightmap = decodeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vColor    = gl_Color;

    // Gentle wind tilt for realistic diagonal rainfall
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
    float windTilt = sin(frameTimeCounter * 0.8 + playerPos.z * 0.1) * 0.18 + 0.25;
    playerPos.x += playerPos.y * windTilt * 0.06 * WIND_STRENGTH;
    viewPos = gbufferModelView * vec4(playerPos, 1.0);

    gl_Position = gl_ProjectionMatrix * viewPos;
}
