// ==============================================================================
// AETHERON SHADERS — Sky Basic / Sky Textured / Clouds Discard (Procedural Sky Used)
// ==============================================================================

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    // Procedural physically-inspired sky, sun, moon, stars, and volumetric clouds
    // are rendered cleanly in deferred/deferred1 without vanilla skybox artifacts.
    discard;
}
