// ==============================================================================
// AETHERON SHADERS — Entities G-Buffer Fragment Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"

uniform sampler2D gtexture;
uniform vec4 entityColor;
uniform int entityId;
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

    // Apply damage flash / creeper fuse overlay cleanly
    vec3 albedo = mix(tex.rgb, entityColor.rgb, entityColor.a);

    int matId = MAT_ENTITY;
    float emissive = 0.0;
    if (entityId == 101) {
        matId = MAT_EMISSIVE_WARM;
        emissive = 0.80;
    } else if (entityId == 102) {
        matId = MAT_EMISSIVE_COOL;
        emissive = 0.85;
    }

    vec3 normal = normalize(vViewNormal);
    outAlbedo    = vec4(albedo, tex.a);
    outNormalMat = vec4(encodeOctNormal(normal), packMaterialId(matId), 1.0);
    outLightMeta = vec4(vLightmap.x, vLightmap.y, 1.0, packSssEmissive(0.0, emissive));
}
