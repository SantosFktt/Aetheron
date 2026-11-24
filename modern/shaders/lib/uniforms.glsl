#ifndef AETHERON_UNIFORMS_GLSL
#define AETHERON_UNIFORMS_GLSL

// ==============================================================================
// AETHERON SHADERS — Standard & Custom Uniform Declarations (Modern Iris)
// ==============================================================================

// Screen & Timing
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float frameTime;
uniform float frameTimeCounter;
uniform int   frameCounter;

// World & Celestial
uniform int   worldTime;
uniform int   worldDay;
uniform int   moonPhase;
uniform float sunAngle;
uniform float shadowAngle;
uniform vec3  sunPosition;
uniform vec3  moonPosition;
uniform vec3  shadowLightPosition;
uniform vec3  upPosition;
uniform vec3  skyColor;
uniform vec3  fogColor;

// Weather & Player Status
uniform float rainStrength;
uniform float wetness;
uniform float thunderStrength;
uniform int   isEyeInWater;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform float centerDepthSmooth;
uniform int   heldItemId;
uniform int   heldBlockLightValue;
uniform int   heldItemId2;
uniform int   heldBlockLightValue2;

// Custom CPU-evaluated smooth uniforms from shaders.properties
uniform float biomeDesert;
uniform float biomeCold;
uniform float biomeHumid;
uniform float biomeOcean;
uniform float smoothRain;
uniform float smoothThunder;
uniform float sunElevation;

// Matrices & Camera
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

// Helper: normalized world-space sun & moon directions
vec3 getSunDirWorld() {
    return normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
}

vec3 getMoonDirWorld() {
    return normalize((gbufferModelViewInverse * vec4(moonPosition, 0.0)).xyz);
}

vec3 getShadowLightDirWorld() {
    return normalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz);
}

vec3 getSunDirView() {
    return normalize(sunPosition);
}

vec3 getMoonDirView() {
    return normalize(moonPosition);
}

vec3 getShadowLightDirView() {
    return normalize(shadowLightPosition);
}

// Smooth day/night/twilight factors computed cleanly from sun elevation
float getDayFactor() {
    vec3 sunDir = getSunDirWorld();
    return smoothstep(-0.08, 0.16, sunDir.y);
}

float getSunsetFactor() {
    vec3 sunDir = getSunDirWorld();
    float h = sunDir.y;
    return smoothstep(-0.18, 0.04, h) * (1.0 - smoothstep(0.06, 0.34, h));
}

float getNightFactor() {
    vec3 sunDir = getSunDirWorld();
    return 1.0 - smoothstep(-0.14, 0.06, sunDir.y);
}

float getRainMix() {
    return clamp(max(smoothRain, rainStrength), 0.0, 1.0);
}

float getStormMix() {
    return clamp(max(smoothThunder, thunderStrength) * 0.85 + getRainMix() * 0.25, 0.0, 1.0);
}

#endif // AETHERON_UNIFORMS_GLSL
