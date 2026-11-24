// ==============================================================================
// AETHERON SHADERS — Block Entities Fragment Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"

uniform sampler2D gtexture;
uniform int blockEntityId;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmap;
in vec4 vColor;
in vec3 vViewNormal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalMat;
layout(location = 2) out vec4 outLightMeta;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < max(alphaTestRef, 0.004)) discard;

    int matId = (blockEntityId > 0) ? blockEntityId : MAT_SOLID;
    float emissive = 0.0;
    if (matId == MAT_PORTAL || matId == MAT_EMISSIVE_COOL) {
        emissive = 0.90;
    } else if (matId == MAT_EMISSIVE_WARM) {
        emissive = 0.75;
    }

    vec3 normal = normalize(vViewNormal);
    outAlbedo    = vec4(tex.rgb, tex.a);
    outNormalMat = vec4(encodeOctNormal(normal), packMaterialId(matId), 1.0);
    outLightMeta = vec4(vLightmap.x, vLightmap.y, 1.0, packSssEmissive(0.0, emissive));
}
