#include "/lib/settings.glsl"
#include "/lib/util/packing.glsl"

in vec4 vColor;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormalMat;
layout(location = 2) out vec4 outLightMeta;

void main() {
    if (vColor.a < 0.004) discard;
    outAlbedo    = vColor;
    outNormalMat = vec4(encodeOctNormal(vec3(0.0, 1.0, 0.0)), packMaterialId(MAT_SOLID), 1.0);
    outLightMeta = vec4(0.0, 1.0, 1.0, 0.0);
}
