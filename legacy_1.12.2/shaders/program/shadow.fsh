// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Shadow Pass Fragment Shader
// ==============================================================================

#include "/lib/settings.glsl"

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec4 vColor;
varying float vMatId;

void main() {
    int matId = int(vMatId + 0.5);
    if (matId == MAT_WATER) {
        discard;
    }

    vec4 tex = texture2D(texture, vTexCoord) * vec4(vColor.rgb, 1.0);
    if (tex.a < 0.05) {
        discard;
    }

    gl_FragData[0] = vec4(tex.rgb, tex.a);
}
