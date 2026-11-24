// ==============================================================================
// AETHERON SHADERS — Weather (Rain & Snow) Fragment Shader (Modern Iris)
// Atmospheric tinted precipitation blended gently onto HDR colortex0
// ==============================================================================

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/atmosphere/scattering.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec2 vLightmap;
in vec4 vColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, vTexCoord) * vColor;
    if (tex.a < max(alphaTestRef, 0.02)) discard;

    vec3 sunDir  = getSunDirWorld();
    vec3 moonDir = getMoonDirWorld();
    vec3 skyAmb  = getSkyAmbientIrradiance(sunDir, moonDir);
    vec3 blockCol = blackbodyColor(float(BLOCKLIGHT_TEMP)) * pow(vLightmap.x, 2.2) * 1.4;

    // Soft silver-blue atmospheric precipitation luminance (never blinding white)
    vec3 weatherLit = srgbToLinear(tex.rgb) * (skyAmb * 1.25 * vLightmap.y + blockCol + vec3(0.03));
    float alpha = tex.a * mix(0.42, 0.65, getStormMix());

    outColor = vec4(weatherLit, alpha);
}
