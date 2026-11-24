// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Hand Fragment Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vViewNormal;

void main() {
    vec4 tex = texture2D(texture, vTexCoord) * vColor;
    if (tex.a < 0.05) discard;

    float emissive = 0.0;
    if (heldBlockLightValue > 0 && luminance(tex.rgb) > 0.45) {
        emissive = 0.55;
    }

    vec3 normal = normalize(vViewNormal);

    /* DRAWBUFFERS:012 */
    gl_FragData[0] = vec4(tex.rgb, tex.a);
    gl_FragData[1] = vec4(encodeOctNormal(normal), packMaterialId(MAT_HAND), 1.0);
    gl_FragData[2] = vec4(vLightmap.x, vLightmap.y, 1.0, packSssEmissive(0.0, emissive));
}
