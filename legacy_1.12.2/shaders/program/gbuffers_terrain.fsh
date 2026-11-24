// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Terrain G-Buffer Fragment Shader
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
    if (tex.a < 0.1) discard;

    int matId = int(vMatId + 0.5);
    vec3 albedo = tex.rgb * vColor.rgb;
    float vanillaAO = clamp(vColor.a, 0.0, 1.0);

    float sss = 0.0;
    float emissive = 0.0;

    if (matId == MAT_LEAVES) {
        sss = 0.85;
    } else if (matId == MAT_FOLIAGE_LOW || matId == MAT_FOLIAGE_TALL || matId == MAT_CROPS || matId == MAT_HANGING) {
        sss = 0.95;
    } else if (matId == MAT_SNOW) {
        sss = 0.25;
    } else if (matId == MAT_EMISSIVE_WARM || matId == MAT_EMISSIVE_COOL) {
        float lum = luminance(tex.rgb);
        emissive = smoothstep(0.28, 0.72, lum);
    } else if (matId == MAT_EMISSIVE_ACCENT) {
        float lum = luminance(tex.rgb);
        emissive = smoothstep(0.22, 0.65, lum) * 0.85;
    }

    vec3 normal = normalize(vViewNormal);
    if (!gl_FrontFacing && (matId >= MAT_FOLIAGE_LOW && matId <= MAT_UNDERWATER_PLANT)) {
        normal = -normal;
    }

    /* DRAWBUFFERS:012 */
    gl_FragData[0] = vec4(albedo, tex.a);
    gl_FragData[1] = vec4(encodeOctNormal(normal), packMaterialId(matId), 1.0);
    gl_FragData[2] = vec4(vLightmap.x, vLightmap.y, vanillaAO, packSssEmissive(sss, emissive));
}
