// ==============================================================================
// AETHERON SHADERS — Shadow Pass Fragment Shader (Modern Iris)
// Discards water from opaque shadows & outputs stained-glass color to shadowcolor0
// ==============================================================================

#include "/lib/settings.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 vTexCoord;
in vec4 vColor;
flat in int vMatId;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outShadowColor0;

void main() {
    // Discard water so underwater terrain receives crisp sunlight & caustics
    if (vMatId == MAT_WATER) {
        discard;
    }

    vec4 tex = texture(gtexture, vTexCoord) * vec4(vColor.rgb, 1.0);
    if (tex.a < max(alphaTestRef, 0.05)) {
        discard;
    }

    // Translucent stained glass writes its tint & opacity to shadowcolor0
    outShadowColor0 = vec4(tex.rgb, tex.a);
}
