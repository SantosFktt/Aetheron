// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Emissive Overlay Fragment
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/util/packing.glsl"

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vViewNormal;

void main() {
    vec4 tex = texture2D(texture, vTexCoord) * vColor;
    if (tex.a < 0.01) discard;

    /* DRAWBUFFERS:012 */
    gl_FragData[0] = tex;
    gl_FragData[1] = vec4(encodeOctNormal(normalize(vViewNormal)), packMaterialId(MAT_EMISSIVE_COOL), 1.0);
    gl_FragData[2] = vec4(1.0, 1.0, 1.0, packSssEmissive(0.0, 0.92));
}
