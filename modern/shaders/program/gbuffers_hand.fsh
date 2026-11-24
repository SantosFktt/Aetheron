// ==============================================================================
// AETHERON SHADERS — First-Person Hand Fragment Shader (Modern Iris)
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/packing.glsl"

uniform sampler2D gtexture;
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

    float emissive = 0.0;
    if (heldBlockLightValue > 0 && luminance(tex.rgb) > 0.45) {
        emissive = 0.55;
    }

    vec3 normal = normalize(vViewNormal);
    outAlbedo    = vec4(tex.rgb, tex.a);
    outNormalMat = vec4(encodeOctNormal(normal), packMaterialId(MAT_HAND), 1.0);
    outLightMeta = vec4(vLightmap.x, vLightmap.y, 1.0, packSssEmissive(0.0, emissive));
}
