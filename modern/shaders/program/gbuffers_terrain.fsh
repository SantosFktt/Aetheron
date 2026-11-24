// ==============================================================================
// AETHERON SHADERS — Terrain G-Buffer Fragment Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmap;
in vec4 vColor;
in vec3 vViewNormal;
flat in int vMatId;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalMat;
layout(location = 2) out vec4 outLightMeta;

void main() {
    vec4 tex = texture(gtexture, vTexCoord);
    if (tex.a < max(alphaTestRef, 0.004)) discard;

    // With separateAo = true, vColor.rgb is biome tint and vColor.a is vanilla smooth AO
    vec3 albedo = tex.rgb * vColor.rgb;
    float vanillaAO = clamp(vColor.a, 0.0, 1.0);

    // Derive SSS and Emissive mask from block material ID
    float sss = 0.0;
    float emissive = 0.0;

    if (vMatId == MAT_LEAVES) {
        sss = 0.85;
    } else if (vMatId == MAT_FOLIAGE_LOW || vMatId == MAT_FOLIAGE_TALL || vMatId == MAT_CROPS || vMatId == MAT_HANGING) {
        sss = 0.95;
    } else if (vMatId == MAT_SNOW) {
        sss = 0.25;
    } else if (vMatId == MAT_EMISSIVE_WARM || vMatId == MAT_EMISSIVE_COOL) {
        // Modulate emissive by texture luminance so lamp frames stay dark while glass/flame glows
        float lum = luminance(tex.rgb);
        emissive = smoothstep(0.28, 0.72, lum);
    } else if (vMatId == MAT_EMISSIVE_ACCENT) {
        float lum = luminance(tex.rgb);
        emissive = smoothstep(0.22, 0.65, lum) * 0.85;
    }

    vec3 normal = normalize(vViewNormal);
    if (!gl_FrontFacing && (vMatId >= MAT_FOLIAGE_LOW && vMatId <= MAT_UNDERWATER_PLANT)) {
        normal = -normal;
    }

    outAlbedo    = vec4(albedo, tex.a);
    outNormalMat = vec4(encodeOctNormal(normal), packMaterialId(vMatId), 1.0);
    outLightMeta = vec4(vLightmap.x, vLightmap.y, vanillaAO, packSssEmissive(sss, emissive));
}
