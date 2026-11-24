// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Weather Fragment Shader
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/atmosphere/scattering.glsl"

uniform sampler2D texture;

varying vec2 vTexCoord;
varying vec2 vLightmap;
varying vec4 vColor;

void main() {
    vec4 tex = texture2D(texture, vTexCoord) * vColor;
    if (tex.a < 0.02) discard;

    vec3 sunDir   = getSunDirWorld();
    vec3 moonDir  = getMoonDirWorld();
    vec3 skyAmb   = getSkyAmbientIrradiance(sunDir, moonDir);
    vec3 blockCol = blackbodyColor(float(BLOCKLIGHT_TEMP)) * pow(vLightmap.x, 2.2) * 1.4;

    vec3 weatherLit = srgbToLinear(tex.rgb) * (skyAmb * 1.25 * vLightmap.y + blockCol + vec3(0.03));
    float alpha = tex.a * mix(0.42, 0.65, getStormMix());

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(weatherLit, alpha);
}
