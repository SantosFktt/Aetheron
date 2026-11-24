#ifndef AETHERON_SCATTERING_GLSL
#define AETHERON_SCATTERING_GLSL

// ==============================================================================
// AETHERON SHADERS v1.1 — Physically-Inspired Atmospheric Scattering
// Vibrant Bliss-style sky luminance + Photon-style balanced solar/ambient ratio
// ==============================================================================

const vec3 BETA_RAYLEIGH = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const vec3 BETA_MIE      = vec3(21.0e-6);
const vec3 BETA_OZONE    = vec3(0.650e-6, 1.881e-6, 0.085e-6);

float rayleighPhase(float cosTheta) {
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    float denom = max(1.0 + g2 - 2.0 * g * cosTheta, 1e-4);
    return (1.0 - g2) / (4.0 * PI * pow(denom, 1.5));
}

float dualMiePhase(float cosTheta, float gForward, float gBack, float blend) {
    return mix(hgPhase(cosTheta, gBack), hgPhase(cosTheta, gForward), blend);
}

float computeAirMass(float cosZenith) {
    float c = max(cosZenith, 0.02);
    return 1.0 / (c + 0.15 * pow(max(c * 90.0 + 3.885, 0.1), -1.253));
}

// Spectral atmospheric transmittance toward the sun (clean daylight, rich golden sunset)
vec3 computeSunTransmittance(float sunY) {
    float airMass = computeAirMass(max(sunY + 0.04, 0.015));
    float rayleighDepth = airMass * 5800.0 * ATMOSPHERE_DENSITY;
    float mieDepth      = airMass * 900.0 * ATMOSPHERE_DENSITY;
    float ozoneDepth    = airMass * 24000.0;

    vec3 opticalDepth = BETA_RAYLEIGH * rayleighDepth + BETA_MIE * mieDepth + BETA_OZONE * ozoneDepth;
    return exp(-opticalDepth);
}

// Direct Sunlight Color — balanced energy so shadows never crush black
vec3 getSunLightColor(vec3 sunDir) {
    float sunVis = smoothstep(-0.06, 0.05, sunDir.y);
    vec3 transmittance = computeSunTransmittance(sunDir.y);

    // Clean warm-white solar irradiance (~5800K at noon, amber-gold at sunset)
    vec3 baseSun = vec3(1.04, 0.99, 0.92) * 2.95 * SUN_INTENSITY;
    vec3 color = baseSun * transmittance * sunVis;

    #ifdef BIOME_LIGHTING
        color *= mix(vec3(1.0), vec3(1.07, 1.01, 0.91), biomeDesert * 0.50);
        color *= mix(vec3(1.0), vec3(0.95, 0.99, 1.06), biomeCold * 0.45);
        color *= mix(vec3(1.0), vec3(0.96, 1.02, 0.95), biomeHumid * 0.35);
    #endif

    float rain = getRainMix();
    float storm = getStormMix();
    float weatherAtten = mix(1.0, 0.28, rain) * mix(1.0, 0.55, storm);
    return color * weatherAtten;
}

// Direct Moonlight Color (silver-blue, modulated by moonPhase)
vec3 getMoonLightColor(vec3 moonDir) {
    float moonVis = smoothstep(-0.05, 0.08, moonDir.y);
    float phaseDist = abs(float(moonPhase) - 4.0) / 4.0;
    float phaseBrightness = mix(0.38, 1.0, phaseDist * phaseDist);

    vec3 baseMoon = vec3(0.46, 0.62, 0.92) * 0.36 * MOON_INTENSITY * phaseBrightness;
    float rain = getRainMix();
    return baseMoon * moonVis * mix(1.0, 0.38, rain);
}

vec3 getActiveCelestialColor(vec3 sunDir, vec3 moonDir) {
    float dayMask = smoothstep(-0.05, 0.04, sunDir.y);
    return mix(getMoonLightColor(moonDir), getSunLightColor(sunDir), dayMask);
}

// Physically-inspired vibrant sky dome (Bliss airy azure zenith + crisp pale-cyan horizon + focused solar aureole)
vec3 evaluateAtmosphere(vec3 viewDir, vec3 sunDir, vec3 moonDir) {
    vec3 dir = normalize(viewDir);
    float up = max(dir.y, 0.0);
    float horizonCurve = pow(1.0 - up, 3.2);
    float tightHorizon = pow(1.0 - up, 7.5);

    float dayPresence = smoothstep(-0.18, 0.08, sunDir.y);
    float highDay     = smoothstep(0.06, 0.38, sunDir.y);
    float sunset      = getSunsetFactor();
    float night       = getNightFactor();

    float cosSun  = dot(dir, sunDir);
    float cosMoon = dot(dir, moonDir);
    vec3 sunTrans = computeSunTransmittance(sunDir.y);

    // 1. Airy, luminous daytime Rayleigh gradient (deep azure zenith -> luminous pale-cyan horizon)
    vec3 dayZenith  = vec3(0.11, 0.32, 0.86);
    vec3 dayMid     = vec3(0.28, 0.58, 0.98);
    vec3 dayHorizon = vec3(0.68, 0.86, 1.02);

    vec3 dayGradient = mix(dayZenith, dayMid, pow(1.0 - up, 1.45));
    dayGradient = mix(dayGradient, dayHorizon, horizonCurve);
    // Subtle physical Rayleigh directional sheen
    dayGradient *= (0.88 + 0.24 * rayleighPhase(cosSun) * 4.0) * (1.28 * ATMOSPHERE_DENSITY);

    // 2. Twilight / Golden Hour palette (Ozone cobalt-indigo zenith -> warm peach-amber horizon)
    vec3 sunsetZenith  = vec3(0.08, 0.16, 0.44);
    vec3 sunsetMid     = vec3(0.42, 0.36, 0.54);
    vec3 sunsetHorizon = vec3(1.18, 0.56, 0.28);

    float sunAzimuth = pow(max(cosSun * 0.5 + 0.5, 0.0), 2.5);
    vec3 sunsetGradient = mix(sunsetZenith, sunsetMid, pow(1.0 - up, 1.6));
    sunsetGradient = mix(sunsetGradient, sunsetHorizon * (0.65 + 0.65 * sunAzimuth), horizonCurve);
    sunsetGradient += vec3(1.35, 0.52, 0.20) * tightHorizon * sunAzimuth * 0.55;

    // Smooth blend between golden hour and bright daytime sky
    vec3 skyDay = mix(sunsetGradient, dayGradient, highDay) * dayPresence;

    // 3. Focused Mie solar scattering (tight luminous sun halo without washing out the whole sky)
    float mieTight = hgPhase(cosSun, 0.88) * 0.22;
    float mieSoft  = hgPhase(cosSun, 0.58) * 0.14;
    vec3 mieScatter = sunTrans * (mieTight + mieSoft * (0.45 + 0.85 * sunset)) * dayPresence * ATMOSPHERE_DENSITY;
    skyDay += mieScatter * (0.55 + 0.65 * horizonCurve);

    // 4. Nocturnal sky (rich midnight-indigo zenith, softly lit moonlit horizon)
    float moonPhaseBright = mix(0.42, 1.0, abs(float(moonPhase) - 4.0) / 4.0);
    vec3 nightZenith  = vec3(0.012, 0.022, 0.052);
    vec3 nightHorizon = vec3(0.032, 0.054, 0.098);
    vec3 nightSky = mix(nightZenith, nightHorizon, horizonCurve) * (0.70 + 0.55 * moonPhaseBright);
    nightSky += vec3(0.16, 0.26, 0.46) * hgPhase(cosMoon, 0.78) * 0.08 * moonPhaseBright * smoothstep(-0.05, 0.15, moonDir.y);

    vec3 sky = skyDay + nightSky * (0.25 + 0.75 * night);

    // Subtle biome atmosphere flavor
    #ifdef BIOME_LIGHTING
        sky = mix(sky, sky * vec3(1.07, 0.99, 0.89), biomeDesert * 0.35 * dayPresence);
        sky = mix(sky, sky * vec3(0.93, 1.01, 1.08), biomeCold * 0.30 * dayPresence);
        sky = mix(sky, sky * vec3(0.92, 1.04, 0.96), biomeHumid * 0.30 * dayPresence);
    #endif

    // Rain / Overcast / Storm sky transition (bright silver-slate overcast, never pitch muddy grey)
    float rain  = getRainMix();
    float storm = getStormMix();
    if (rain > 0.001 || storm > 0.001) {
        float overcastLuma = mix(0.06, 0.68, smoothstep(-0.08, 0.22, sunDir.y));
        overcastLuma *= mix(1.0, 0.52, storm);
        vec3 overcastZenith  = vec3(0.50, 0.58, 0.68) * overcastLuma;
        vec3 overcastHorizon = vec3(0.70, 0.76, 0.84) * overcastLuma;
        vec3 overcastSky = mix(overcastZenith, overcastHorizon, pow(1.0 - up, 2.0));
        overcastSky += sunTrans * 0.10 * pow(max(cosSun, 0.0), 6.0) * dayPresence * (1.0 - storm * 0.7);
        sky = mix(sky, overcastSky, clamp(rain * 0.82 + storm * 0.22, 0.0, 0.92));
    }

    // Smooth ground bounce color below horizon (prevents dark artifacts in water reflections)
    if (dir.y < 0.0) {
        vec3 groundTint = mix(vec3(0.015, 0.022, 0.036), vec3(0.28, 0.34, 0.42), dayPresence * (1.0 - rain * 0.4));
        sky = mix(sky, groundTint, smoothstep(0.0, -0.22, dir.y));
    }

    return max(sky, vec3(0.0));
}

// Physically calibrated sky hemisphere ambient irradiance (gives crisp blue-tinted open shadows!)
vec3 getSkyAmbientIrradiance(vec3 sunDir, vec3 moonDir) {
    vec3 zenith  = evaluateAtmosphere(vec3(0.0, 0.88, 0.47), sunDir, moonDir);
    vec3 horizon = evaluateAtmosphere(vec3(0.0, 0.18, 0.98), sunDir, moonDir);
    return (zenith * 0.50 + horizon * 0.50) * 0.95 * AMBIENT_INTENSITY;
}

#endif // AETHERON_SCATTERING_GLSL
