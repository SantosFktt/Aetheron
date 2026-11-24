// ==============================================================================
// AETHERON SHADERS — Basic / Lines / Sky / Emissive Overlay Shaders (Modern Iris)
// ==============================================================================

out vec4 vColor;

void main() {
    vColor = gl_Color;
    gl_Position = ftransform();
}
