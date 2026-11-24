// ==============================================================================
// AETHERON SHADERS — Textured / Particles Fragment Shader (Modern Iris)
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

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalMat;
layout(location = 2) out vec4 outLightMeta;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < max(alphaTestRef, 0.004)) discard;

    outAlbedo    = tex;
    outNormalMat = vec4(encodeOctNormal(normalize(vViewNormal)), packMaterialId(MAT_PARTICLE), 1.0);
    outLightMeta = vec4(vLightmap.x, vLightmap.y, 1.0, 0.0);
}
