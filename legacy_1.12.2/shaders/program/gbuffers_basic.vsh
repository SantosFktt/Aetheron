// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Basic Vertex & Fragment
// ==============================================================================

varying vec4 vColor;

void main() {
    vColor = gl_Color;
    gl_Position = ftransform();
}
