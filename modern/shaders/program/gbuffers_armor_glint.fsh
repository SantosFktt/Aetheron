// ==============================================================================
// AETHERON SHADERS — Enchantment Glint Fragment Shader (Modern Iris)
// Vanilla glint uses additive blending (SRC_COLOR, ONE). Writing it into the
// normal/material (colortex1) and lightmap (colortex2) buffers would corrupt
// them and make enchanted gear glow with full blocklight at night, so the glint
// is only added on top of the albedo buffer.
// ==============================================================================

uniform sampler2D gtexture;

in vec2 vTexCoord;
in vec4 vColor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outAlbedo;

void main() {
    outAlbedo = texture(gtexture, vTexCoord) * vColor;
}
