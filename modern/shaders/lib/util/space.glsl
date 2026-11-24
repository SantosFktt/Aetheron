#ifndef AETHERON_SPACE_GLSL
#define AETHERON_SPACE_GLSL

// ==============================================================================
// AETHERON SHADERS — Coordinate Space Conversions & Shadow Distortion
// ==============================================================================

// Linearize depth buffer value [0, 1] -> positive view-space distance
float linearizeDepth(float depth) {
    return (near * far) / max(far - depth * (far - near), 1e-5);
}

// Screen UV [0, 1] + depth [0, 1] -> View-space position
vec3 screenToViewPos(vec2 uv, float depth) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / view.w;
}

// View-space position -> Screen UV + depth [0, 1]
vec3 viewToScreenPos(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    vec3 ndc = clip.xyz / clip.w;
    return ndc * 0.5 + 0.5;
}

// View-space position -> Player-feet space (world-oriented, centered at camera)
vec3 viewToPlayerPos(vec3 viewPos) {
    return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}

// Player-feet space -> View space
vec3 playerToViewPos(vec3 playerPos) {
    return (gbufferModelView * vec4(playerPos, 1.0)).xyz;
}

// View-space direction -> World-space direction
vec3 viewToWorldDir(vec3 viewDir) {
    return normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
}

// World-space direction -> View-space direction
vec3 worldToViewDir(vec3 worldDir) {
    return normalize((gbufferModelView * vec4(worldDir, 0.0)).xyz);
}

// ------------------------------------------------------------------------------
// Shadow Map Non-Linear Distortion
// Concentrates high shadow resolution near the player while preserving long range
// ------------------------------------------------------------------------------
const float SHADOW_DISTORT_BIAS = 0.86;

float getShadowDistortFactor(vec2 shadowNdcXY) {
    float len = length(shadowNdcXY);
    return mix(1.0, len, SHADOW_DISTORT_BIAS);
}

vec3 distortShadowClip(vec3 shadowClip) {
    float factor = getShadowDistortFactor(shadowClip.xy);
    shadowClip.xy /= max(factor, 1e-4);
    shadowClip.z *= 0.25; // Prevent near/far clipping in deep valleys & mountains
    return shadowClip;
}

// Player-feet position -> Shadow screen-space [0, 1] (with distortion)
vec3 playerToShadowScreenPos(vec3 playerPos, out float distortFactor) {
    vec4 shadowView = shadowModelView * vec4(playerPos, 1.0);
    vec4 shadowClip = shadowProjection * shadowView;
    shadowClip.xyz /= shadowClip.w;
    distortFactor = getShadowDistortFactor(shadowClip.xy);
    shadowClip.xyz = distortShadowClip(shadowClip.xyz);
    return shadowClip.xyz * 0.5 + 0.5;
}

// Reproject current screen pos into previous frame screen pos for TAA & Motion Blur
vec3 reprojectToPreviousScreen(vec2 uv, float depth) {
    vec3 viewPos = screenToViewPos(uv, depth);
    vec3 playerPos = viewToPlayerPos(viewPos);
    vec3 prevPlayerPos = playerPos + (cameraPosition - previousCameraPosition);
    vec4 prevClip = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevPlayerPos, 1.0));
    vec3 prevNdc = prevClip.xyz / prevClip.w;
    return prevNdc * 0.5 + 0.5;
}

#endif // AETHERON_SPACE_GLSL
