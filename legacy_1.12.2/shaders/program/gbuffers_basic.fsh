// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Basic Fragment Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/util/packing.glsl"

varying vec4 vColor;

void main() {
    if (vColor.a < 0.004) discard;

    /* DRAWBUFFERS:012 */
    gl_FragData[0] = vColor;
    gl_FragData[1] = vec4(encodeOctNormal(vec3(0.0, 1.0, 0.0)), packMaterialId(MAT_SOLID), 1.0);
    gl_FragData[2] = vec4(0.0, 1.0, 1.0, 0.0);
}
