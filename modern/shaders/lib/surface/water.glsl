#ifndef AETHERON_WATER_GLSL
#define AETHERON_WATER_GLSL

// ==============================================================================
// AETHERON SHADERS v1.1 — Smooth Multi-Octave Water, Rain Ripples & Crystal Absorption
// ==============================================================================

float waterWaveHeight(vec2 posXZ, float time) {
    float rainBoost = 1.0 + getRainMix() * 0.40;
    float h = 0.0;

    // Smooth rolling swells (avoid high-frequency noisy grain at medium distance)
    vec2 p1 = posXZ * 0.34 + vec2(time * 0.55, time * 0.28);
    h += (1.0 - abs(sin(p1.x + valueNoise2D(p1 * 0.65) * 1.25))) * 0.48;

    vec2 p2 = posXZ * 0.68 + vec2(-time * 0.42, time * 0.62);
    h += valueNoise2D(p2) * 0.30;

    #if WATER_QUALITY >= 2
        vec2 p3 = posXZ * 1.35 + vec2(time * 0.80, -time * 0.52);
        h += valueNoise2D(p3) * 0.14;
    #endif

    #if WATER_QUALITY >= 3
        vec2 p4 = posXZ * 2.55 + vec2(-time * 1.15, -time * 0.90);
        h += valueNoise2D(p4) * 0.06;
        vec2 p5 = posXZ * 4.40 + vec2(time * 1.45, time * 1.20);
        h += valueNoise2D(p5) * 0.025;
    #endif

    return h * WATER_WAVE_HEIGHT * rainBoost;
}

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

    return rippleSum * rain * smoothstep(0.75, 0.96, skyLight) * 0.12;
}

vec3 computeWaterNormal(vec3 worldPos, vec3 geoNormalWorld, float skyLight, float distToCam) {
    // Stronger distance attenuation keeps distant ocean/lake reflections silky smooth
    float distFade = 1.0 - smoothstep(14.0, 95.0, distToCam);
    if (distFade <= 0.01) return geoNormalWorld;

    float t = frameTimeCounter * 0.95;
    float eps = mix(0.08, 0.28, clamp(distToCam / 60.0, 0.0, 1.0));

    vec2 p = worldPos.xz;
    float hC = waterWaveHeight(p, t) + waterRainRipples(p, t, skyLight);
    float hX = waterWaveHeight(p + vec2(eps, 0.0), t) + waterRainRipples(p + vec2(eps, 0.0), t, skyLight);
    float hZ = waterWaveHeight(p + vec2(0.0, eps), t) + waterRainRipples(p + vec2(0.0, eps), t, skyLight);

    float strength = 0.17 * distFade;
    vec2 grad = vec2(hX - hC, hZ - hC) / eps * strength;

    if (abs(geoNormalWorld.y) > 0.5) {
        float signY = sign(geoNormalWorld.y);
        return normalize(vec3(-grad.x, signY, -grad.y));
    } else {
        vec3 sideRipple = vec3(grad.x * 0.35, sin(worldPos.y * 5.0 - t * 6.0) * 0.05 * distFade, grad.y * 0.35);
        return normalize(geoNormalWorld + sideRipple);
    }
}

float computeWaterCaustics(vec3 worldPos, vec3 lightDir) {
    #ifndef WATER_CAUSTICS
        return 0.0;
    #endif
    vec2 projXZ = worldPos.xz - lightDir.xz / max(abs(lightDir.y), 0.25) * worldPos.y;
    float t = frameTimeCounter * 0.85;

    float c1 = worleyBillow2D(projXZ * 0.55 + vec2(t * 0.25, t * 0.18));
    float c2 = worleyBillow2D(projXZ * 0.72 - vec2(t * 0.22, -t * 0.30));
    float caustic = pow(clamp(1.0 - abs(c1 - c2) * 1.65, 0.0, 1.0), 4.0);
    return caustic * 1.85;
}

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

    // Clear turquoise-cerulean spectral Beer-Lambert absorption
    vec3 baseAbsorption = vec3(0.18, 0.058, 0.036) * clarityInv;
    #ifdef BIOME_LIGHTING
        baseAbsorption = mix(baseAbsorption, vec3(0.24, 0.095, 0.125) * clarityInv, biomeHumid * 0.65);
        baseAbsorption = mix(baseAbsorption, vec3(0.17, 0.052, 0.030) * clarityInv, biomeOcean * 0.45);
    #endif

    vec3 tintMod = mix(vec3(1.0), clamp(waterTintLinear * 1.65, vec3(0.45), vec3(1.35)), 0.32);
    vec3 transmittance = exp(-baseAbsorption * waterThickness);

    float causticVis = exp(-waterThickness * 0.10) * smoothstep(0.2, 0.85, skyLight);
    float caustics = computeWaterCaustics(submergedWorldPos, lightDir) * causticVis;
    vec3 litBehind = behindColor + behindColor * directCol * caustics * 0.26;

    // Luminous crystal turquoise-blue deep water scatter
    vec3 deepScatter = vec3(0.038, 0.215, 0.305) * tintMod * (luminance(skyAmb) * 1.25 + luminance(directCol) * 0.22 + 0.04);
    transmittedColor = litBehind * transmittance + deepScatter * (1.0 - transmittance);
}

#endif // AETHERON_WATER_GLSL
