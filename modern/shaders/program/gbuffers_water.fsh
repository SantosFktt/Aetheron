// ==============================================================================
// AETHERON SHADERS — Water & Translucent Terrain Fragment Shader (Modern Iris)
// Writes to colortex3 (translucent albedo), colortex1 (normal/mat), colortex2 (lightmap)
// leaving colortex0 intact with the deferred-lit opaque scene behind the water!
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

/* RENDERTARGETS: 3,1,2 */
layout(location = 0) out vec4 outTranslucentAlbedo;
layout(location = 1) out vec4 outNormalMat;
layout(location = 2) out vec4 outLightMeta;

void main() {
    vec4 tex = texture(gtexture, vTexCoord);
    if (tex.a < max(alphaTestRef, 0.004)) discard;

    int matId = (vMatId == 0) ? MAT_TRANSLUCENT : vMatId;
    vec3 albedo = tex.rgb * vColor.rgb;
    float alpha = tex.a;

    float emissive = 0.0;
    if (matId == MAT_PORTAL) {
        emissive = 0.95;
    }

    vec3 normal = normalize(vViewNormal);
    outTranslucentAlbedo = vec4(albedo, alpha);
    outNormalMat         = vec4(encodeOctNormal(normal), packMaterialId(matId), 1.0);
    outLightMeta         = vec4(vLightmap.x, vLightmap.y, 1.0, packSssEmissive(0.0, emissive));
}
