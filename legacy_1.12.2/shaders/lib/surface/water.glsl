#ifndef AETHERON_WATER_GLSL
#define AETHERON_WATER_GLSL

// ==============================================================================
// AETHERON SHADERS (Legacy 1.12.2 GLSL 120) — Animated Water Waves, Rain Ripples, Caustics & Optical Depth
// ==============================================================================

// Multi-octave directional wave heightfield (smooth wind-driven swells + fine capillary ripples)
float waterWaveHeight(vec2 posXZ, float time) {
    float rainBoost = 1.0 + getRainMix() * 0.45;
    float h = 0.0;

    // Primary wind swells (Gerstner-inspired sharp crests)
    vec2 p1 = posXZ * 0.42 + vec2(time * 0.65, time * 0.35);
    h += (1.0 - abs(sin(p1.x + valueNoise2D(p1 * 0.7) * 1.4))) * 0.42;

    vec2 p2 = posXZ * 0.78 + vec2(-time * 0.48, time * 0.72);
    h += valueNoise2D(p2) * 0.30;

    #if WATER_QUALITY >= 2
        vec2 p3 = posXZ * 1.65 + vec2(time * 0.95, -time * 0.62);
        h += valueNoise2D(p3) * 0.16;
    #endif

    #if WATER_QUALITY >= 3
        vec2 p4 = posXZ * 3.40 + vec2(-time * 1.35, -time * 1.10);
        h += valueNoise2D(p4) * 0.08;
        vec2 p5 = posXZ * 6.80 + vec2(time * 1.90, time * 1.55);
        h += valueNoise2D(p5) * 0.04;
    #endif

    return h * WATER_WAVE_HEIGHT * rainBoost;
}

// Animated concentric raindrop impact rings on exposed water during rain
float waterRainRipples(vec2 posXZ, float time, float skyLight) {
    #ifndef RAIN_RIPPLES
        return 0.0;
    #endif
    float rain = getRainMix();
    if (rain <= 0.02 || skyLight < 0.75) return 0.0;

    float rippleSum = 0.0;
    vec2 cellBase = posXZ * 1.85;
    vec2 id = floor(cellBase);
    vec2 f  = fract(cellBase);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = vec2(float(x), float(y));
            vec2 cid = id + off;
            vec2 rnd = hash22(cid);
            float phase = fract(time * (0.75 + rnd.x * 0.45) + rnd.y);
            vec2 center = off + 0.15 + 0.70 * rnd;
            float dist = length(f - center);

            float radius = phase * 0.78;
            float ring = sin((dist - radius) * 32.0) * exp(-abs(dist - radius) * 14.0);
            float env  = (1.0 - phase) * smoothstep(0.0, 0.10, phase);
            rippleSum += ring * env;
        }
    }

    return rippleSum * rain * smoothstep(0.75, 0.96, skyLight) * 0.14;
}

// Analytical finite-difference perturbed world-space water normal
vec3 computeWaterNormal(vec3 worldPos, vec3 geoNormalWorld, float skyLight, float distToCam) {
    // Attenuate micro-wave aliasing smoothly at long range for stable reflections
    float distFade = 1.0 - smoothstep(24.0, 140.0, distToCam);
    if (distFade <= 0.01) return geoNormalWorld;

    float t = frameTimeCounter * 1.05;
    float eps = mix(0.06, 0.22, clamp(distToCam / 80.0, 0.0, 1.0));

    vec2 p = worldPos.xz;
    float hC = waterWaveHeight(p, t) + waterRainRipples(p, t, skyLight);
    float hX = waterWaveHeight(p + vec2(eps, 0.0), t) + waterRainRipples(p + vec2(eps, 0.0), t, skyLight);
    float hZ = waterWaveHeight(p + vec2(0.0, eps), t) + waterRainRipples(p + vec2(0.0, eps), t, skyLight);

    float strength = 0.24 * distFade;
    vec2 grad = vec2(hX - hC, hZ - hC) / eps * strength;

    // Apply wave normal primarily on top/bottom water faces; subtle ripple on waterfalls
    if (abs(geoNormalWorld.y) > 0.5) {
        float signY = sign(geoNormalWorld.y);
        return normalize(vec3(-grad.x, signY, -grad.y));
    } else {
        vec3 sideRipple = vec3(grad.x * 0.35, sin(worldPos.y * 5.0 - t * 6.0) * 0.06 * distFade, grad.y * 0.35);
        return normalize(geoNormalWorld + sideRipple);
    }
}

// Animated Underwater Sunlight Caustics Pattern
float computeWaterCaustics(vec3 worldPos, vec3 lightDir) {
    #ifndef WATER_CAUSTICS
        return 0.0;
    #endif
    // Project along light direction onto horizontal plane
    vec2 projXZ = worldPos.xz - lightDir.xz / max(abs(lightDir.y), 0.25) * worldPos.y;
    float t = frameTimeCounter * 0.85;

    float c1 = worleyBillow2D(projXZ * 0.55 + vec2(t * 0.25, t * 0.18));
    float c2 = worleyBillow2D(projXZ * 0.72 - vec2(t * 0.22, -t * 0.30));
    float caustic = pow(clamp(1.0 - abs(c1 - c2) * 1.65, 0.0, 1.0), 4.5);
    return caustic * 1.65;
}

// Compute natural water absorption & volume scatter across underwater depth
void evaluateWaterOpticalDepth(
    float waterThickness,
    vec3 behindColor,
    vec3 waterTintLinear,
    vec3 directCol,
    vec3 skyAmb,
    vec3 submergedWorldPos,
    vec3 lightDir,
    float skyLight,
    out vec3 transmittedColor
) {
    float clarityInv = 1.0 / max(WATER_CLARITY, 0.25);

    // Spectral Beer-Lambert absorption (red absorbs fastest -> turquoise/cerulean depths)
    vec3 baseAbsorption = vec3(0.24, 0.085, 0.055) * clarityInv;
    #ifdef BIOME_LIGHTING
        // Swamps/jungles slightly greener; oceans deeper sapphire-teal
        baseAbsorption = mix(baseAbsorption, vec3(0.28, 0.11, 0.14) * clarityInv, biomeHumid * 0.65);
        baseAbsorption = mix(baseAbsorption, vec3(0.22, 0.075, 0.042) * clarityInv, biomeOcean * 0.45);
    #endif

    // Blend subtle Minecraft biome water tint cleanly
    vec3 tintMod = mix(vec3(1.0), clamp(waterTintLinear * 1.65, vec3(0.35), vec3(1.35)), 0.35);
    vec3 transmittance = exp(-baseAbsorption * waterThickness);

    // Projected sunlight caustics on shallow underwater beds
    float causticVis = exp(-waterThickness * 0.12) * smoothstep(0.2, 0.85, skyLight);
    float caustics = computeWaterCaustics(submergedWorldPos, lightDir) * causticVis;
    vec3 litBehind = behindColor + behindColor * directCol * caustics * 0.22;

    // Volume in-scattering within the water body
    vec3 deepScatter = vec3(0.025, 0.145, 0.215) * tintMod * (luminance(skyAmb) * 1.35 + luminance(directCol) * 0.18 + 0.025);
    transmittedColor = litBehind * transmittance + deepScatter * (1.0 - transmittance);
}

#endif // AETHERON_WATER_GLSL
