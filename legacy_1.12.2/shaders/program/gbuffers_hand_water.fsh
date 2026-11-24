// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Translucent Hand Fragment Shader
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
    if (tex.a < 0.004) discard;

    vec3 normal = normalize(vViewNormal);

    /* DRAWBUFFERS:312 */
    gl_FragData[0] = vec4(tex.rgb, tex.a);
    gl_FragData[1] = vec4(encodeOctNormal(normal), packMaterialId(MAT_TRANSLUCENT), 1.0);
    gl_FragData[2] = vec4(vLightmap.x, vLightmap.y, 1.0, 0.0);
}
