// ==============================================================================
// AETHERON SHADERS — Shared Fullscreen Quad Vertex Shader (Deferred/Composite/Final)
// ==============================================================================

out vec2 vTexCoord;

void main() {
    vTexCoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gl_Position = ftransform();
}
