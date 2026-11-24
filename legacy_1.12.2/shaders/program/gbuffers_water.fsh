// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Water & Translucent Fragment Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;
varying vec3 vViewNormal;
varying float vMatId;

void main() {
    vec4 tex = texture2D(texture, vTexCoord);
    if (tex.a < 0.004) discard;

    int rawId = int(vMatId + 0.5);
    int matId = (rawId == 0) ? MAT_TRANSLUCENT : rawId;
    vec3 albedo = tex.rgb * vColor.rgb;
    float alpha = tex.a;

    float emissive = 0.0;
    if (matId == MAT_PORTAL) {
        emissive = 0.95;
    }

    vec3 normal = normalize(vViewNormal);

    /* DRAWBUFFERS:312 */
    gl_FragData[0] = vec4(albedo, alpha);
    gl_FragData[1] = vec4(encodeOctNormal(normal), packMaterialId(matId), 1.0);
    gl_FragData[2] = vec4(vLightmap.x, vLightmap.y, 1.0, packSssEmissive(0.0, emissive));
}
