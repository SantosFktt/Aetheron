// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Fullscreen Quad Vertex Shader
// ==============================================================================

varying vec2 vTexCoord;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gl_Position = ftransform();
}
