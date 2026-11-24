#ifndef AETHERON_SPACE_GLSL
#define AETHERON_SPACE_GLSL

// ==============================================================================
// AETHERON SHADERS — Coordinate Space Conversions & Shadow Distortion (GLSL 120)
// ==============================================================================

float linearizeDepth(float depth) {
    return (near * far) / max(far - depth * (far - near), 0.00001);
}

vec3 screenToViewPos(vec2 uv, float depth) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / view.w;
}

vec3 viewToScreenPos(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    vec3 ndc = clip.xyz / clip.w;
    return ndc * 0.5 + 0.5;
}

vec3 viewToPlayerPos(vec3 viewPos) {
    return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}

vec3 playerToViewPos(vec3 playerPos) {
    return (gbufferModelView * vec4(playerPos, 1.0)).xyz;
}

vec3 worldToViewDir(vec3 worldDir) {
    return normalize((gbufferModelView * vec4(worldDir, 0.0)).xyz);
}

const float SHADOW_DISTORT_BIAS = 0.86;

float getShadowDistortFactor(vec2 shadowNdcXY) {
    float len = length(shadowNdcXY);
    return mix(1.0, len, SHADOW_DISTORT_BIAS);
}

vec3 distortShadowClip(vec3 shadowClip) {
    float factor = getShadowDistortFactor(shadowClip.xy);
    shadowClip.xy /= max(factor, 0.0001);
    shadowClip.z *= 0.25;
    return shadowClip;
}

vec3 playerToShadowScreenPos(vec3 playerPos, out float distortFactor) {
    vec4 shadowView = shadowModelView * vec4(playerPos, 1.0);
    vec4 shadowClip = shadowProjection * shadowView;
    shadowClip.xyz /= shadowClip.w;
    distortFactor = getShadowDistortFactor(shadowClip.xy);
    shadowClip.xyz = distortShadowClip(shadowClip.xyz);
    return shadowClip.xyz * 0.5 + 0.5;
}

vec3 reprojectToPreviousScreen(vec2 uv, float depth) {
    vec3 viewPos = screenToViewPos(uv, depth);
    vec3 playerPos = viewToPlayerPos(viewPos);
    vec3 prevPlayerPos = playerPos + (cameraPosition - previousCameraPosition);
    vec4 prevClip = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevPlayerPos, 1.0));
    vec3 prevNdc = prevClip.xyz / prevClip.w;
    return prevNdc * 0.5 + 0.5;
}

#endif
