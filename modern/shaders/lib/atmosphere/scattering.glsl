#ifndef AETHERON_SCATTERING_GLSL
#define AETHERON_SCATTERING_GLSL

// ==============================================================================
// AETHERON SHADERS — Physically-Inspired Atmospheric Scattering
// Rayleigh + Dual-Lobe Mie + Chappuis Ozone Absorption (Photon x Bliss Identity)
// ==============================================================================

// Earth-like scattering coefficients (scaled for pleasing Minecraft horizon depth)
const vec3 BETA_RAYLEIGH = vec3(5.8e-6, 13.5e-6, 33.1e-6);
const vec3 BETA_MIE      = vec3(21.0e-6);
const vec3 BETA_OZONE    = vec3(0.650e-6, 1.881e-6, 0.085e-6);

// Rayleigh phase function
float rayleighPhase(float cosTheta) {
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

// Henyey-Greenstein phase function
float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    float denom = max(1.0 + g2 - 2.0 * g * cosTheta, 1e-4);
    return (1.0 - g2) / (4.0 * PI * pow(denom, 1.5));
}

// Dual-lobe Mie phase (strong forward halo + subtle back-scatter for natural haze)
float dualMiePhase(float cosTheta, float gForward, float gBack, float blend) {
    return mix(hgPhase(cosTheta, gBack), hgPhase(cosTheta, gForward), blend);
}

// Kasten-Young optical air mass approximation (smooth near & below horizon)
float computeAirMass(float cosZenith) {
    float c = max(cosZenith, 0.015);
    return 1.0 / (c + 0.15 * pow(max(c * 90.0 + 3.885, 0.1), -1.253));
}

// Spectral atmospheric transmittance along a direction toward sun/moon
vec3 computeSunTransmittance(float sunY) {
    float airMass = computeAirMass(max(sunY + 0.035, 0.01));
    float rayleighDepth = airMass * 8200.0 * ATMOSPHERE_DENSITY;
    float mieDepth      = airMass * 1250.0 * ATMOSPHERE_DENSITY;
    float ozoneDepth    = airMass * 38000.0;

    vec3 opticalDepth = BETA_RAYLEIGH * rayleighDepth + BETA_MIE * mieDepth + BETA_OZONE * ozoneDepth;
    return exp(-opticalDepth);
}

// Direct Sunlight Color (warm-neutral daylight, rich amber-gold sunrise/sunset)
vec3 getSunLightColor(vec3 sunDir) {
    float sunVis = smoothstep(-0.06, 0.05, sunDir.y);
    vec3 transmittance = computeSunTransmittance(sunDir.y);

    // Base solar irradiance (~5800K clean sunlight)
    vec3 baseSun = vec3(1.04, 0.99, 0.93) * 3.85 * SUN_INTENSITY;
    vec3 color = baseSun * transmittance * sunVis;

    // Gentle biome-aware solar warmth modulation
    #ifdef BIOME_LIGHTING
        color *= mix(vec3(1.0), vec3(1.08, 1.01, 0.90), biomeDesert * 0.55);
        color *= mix(vec3(1.0), vec3(0.95, 0.99, 1.06), biomeCold * 0.45);
        color *= mix(vec3(1.0), vec3(0.96, 1.02, 0.94), biomeHumid * 0.35);
    #endif

    // Rain and storms heavily attenuate direct sunlight
    float rain = getRainMix();
    float storm = getStormMix();
    float weatherAtten = mix(1.0, 0.22, rain) * mix(1.0, 0.55, storm);
    return color * weatherAtten;
}

// Direct Moonlight Color (cool silver-indigo modulated by actual moonPhase)
vec3 getMoonLightColor(vec3 moonDir) {
    float moonVis = smoothstep(-0.05, 0.08, moonDir.y);

    // moonPhase: 0 = Full Moon, 4 = New Moon
    float phaseDist = abs(float(moonPhase) - 4.0) / 4.0; // 1.0 at full, 0.0 at new
    float phaseBrightness = mix(0.28, 1.0, phaseDist * phaseDist);

    vec3 baseMoon = vec3(0.42, 0.56, 0.84) * 0.28 * MOON_INTENSITY * phaseBrightness;
    float rain = getRainMix();
    return baseMoon * moonVis * mix(1.0, 0.32, rain);
}

// Active directional shadow-caster light color (Sun by day, Moon by night)
vec3 getActiveCelestialColor(vec3 sunDir, vec3 moonDir) {
    float dayMask = smoothstep(-0.05, 0.04, sunDir.y);
    return mix(getMoonLightColor(moonDir), getSunLightColor(sunDir), dayMask);
}

// Evaluate physically-inspired atmospheric scattering for any view direction
vec3 evaluateAtmosphere(vec3 viewDir, vec3 sunDir, vec3 moonDir) {
    vec3 dir = normalize(viewDir);
    float up = max(dir.y, 0.0);
    float horizonFade = pow(1.0 - up, 4.0);

    // Optical depth along view ray (capped near horizon to avoid dark band)
    float viewAirMass = 1.0 / (max(up, 0.03) + 0.12);
    float rayleighLen = min(viewAirMass, 14.0) * 7600.0 * ATMOSPHERE_DENSITY;
    float mieLen      = min(viewAirMass, 14.0) * 1450.0 * ATMOSPHERE_DENSITY;

    // Biome atmospheric haze variation
    #ifdef BIOME_LIGHTING
        mieLen *= 1.0 + biomeDesert * 0.55 + biomeHumid * 0.40 - biomeCold * 0.18;
    #endif

    // Sun scattering
    float cosSun = dot(dir, sunDir);
    vec3 sunTrans = computeSunTransmittance(sunDir.y);
    float dayPresence = smoothstep(-0.20, 0.06, sunDir.y);
    float sunset = getSunsetFactor();

    vec3 rayleighIn = BETA_RAYLEIGH * rayleighLen * rayleighPhase(cosSun);
    vec3 mieIn      = BETA_MIE * mieLen * dualMiePhase(cosSun, 0.78, -0.25, 0.88);

    // Ozone twilight zenith enrichment (gives authentic Bliss cobalt-indigo twilight zenith)
    vec3 ozoneTint = exp(-BETA_OZONE * (26000.0 + sunset * 34000.0) * (1.0 - up * 0.45));

    vec3 viewExtinction = exp(-(BETA_RAYLEIGH * rayleighLen * 0.65 + BETA_MIE * mieLen * 0.45));
    vec3 scatterSun = (rayleighIn * 1.15 + mieIn * (0.95 + sunset * 1.15)) * (1.0 - viewExtinction * 0.55);

    // Solar sky radiance
    vec3 sunSky = scatterSun * sunTrans * ozoneTint * 3.6 * dayPresence;

    // Warm golden-coral sunset horizon glow (multi-scatter approximation)
    float sunAzimuthGlow = pow(max(cosSun * 0.5 + 0.5, 0.0), 3.0);
    vec3 sunsetGlow = vec3(1.15, 0.44, 0.18) * sunset * horizonFade * (0.35 + 0.85 * sunAzimuthGlow);
    sunSky += sunsetGlow * 0.52;

    // Crisp Bliss-style daytime zenith depth + pale luminous horizon
    vec3 zenithBoost = vec3(0.08, 0.22, 0.52) * pow(up, 0.7) * smoothstep(0.0, 0.30, sunDir.y) * 0.35;
    sunSky += zenithBoost;

    // Nocturnal sky (deep indigo zenith, gentle moonlit Rayleigh haze)
    float night = getNightFactor();
    float cosMoon = dot(dir, moonDir);
    float moonPhaseBright = mix(0.35, 1.0, abs(float(moonPhase) - 4.0) / 4.0);
    vec3 nightZenith  = vec3(0.008, 0.015, 0.036);
    vec3 nightHorizon = vec3(0.020, 0.034, 0.064);
    vec3 nightSky = mix(nightZenith, nightHorizon, horizonFade) * (0.65 + 0.55 * moonPhaseBright);
    nightSky += vec3(0.14, 0.21, 0.36) * dualMiePhase(cosMoon, 0.72, -0.1, 0.85) * 0.06 * moonPhaseBright * smoothstep(-0.05, 0.15, moonDir.y);

    vec3 sky = sunSky + nightSky * (0.30 + 0.70 * night);

    // Biome subtle atmospheric tinting
    #ifdef BIOME_LIGHTING
        sky = mix(sky, sky * vec3(1.08, 0.99, 0.88), biomeDesert * 0.35 * dayPresence);
        sky = mix(sky, sky * vec3(0.93, 1.00, 1.08), biomeCold * 0.30 * dayPresence);
        sky = mix(sky, sky * vec3(0.92, 1.03, 0.95), biomeHumid * 0.30 * dayPresence);
    #endif

    // Rain / Overcast / Thunderstorm atmosphere blending
    float rain = getRainMix();
    float storm = getStormMix();
    if (rain > 0.001 || storm > 0.001) {
        float overcastLuma = mix(0.035, 0.42, smoothstep(-0.08, 0.25, sunDir.y));
        overcastLuma *= mix(1.0, 0.48, storm);
        vec3 overcastZenith  = vec3(0.46, 0.52, 0.60) * overcastLuma;
        vec3 overcastHorizon = vec3(0.62, 0.67, 0.73) * overcastLuma;
        vec3 overcastSky = mix(overcastZenith, overcastHorizon, pow(1.0 - up, 2.2));
        // Keep subtle directional sun brightening through overcast clouds
        overcastSky += sunTrans * 0.08 * pow(max(cosSun, 0.0), 4.0) * dayPresence * (1.0 - storm * 0.7);
        sky = mix(sky, overcastSky, clamp(rain * 0.84 + storm * 0.25, 0.0, 0.94));
    }

    // Smooth ground reflection below horizon so water/fog never sees black void
    if (dir.y < 0.0) {
        vec3 groundTint = mix(vec3(0.010, 0.014, 0.022), vec3(0.18, 0.20, 0.22), dayPresence * (1.0 - rain * 0.5));
        sky = mix(sky, groundTint, smoothstep(0.0, -0.25, dir.y));
    }

    return max(sky, vec3(0.0));
}

// Fast hemisphere sky ambient irradiance (used for deferred terrain & fog ambient)
vec3 getSkyAmbientIrradiance(vec3 sunDir, vec3 moonDir) {
    vec3 zenith  = evaluateAtmosphere(vec3(0.0, 0.92, 0.39), sunDir, moonDir);
    vec3 horizon = evaluateAtmosphere(vec3(0.0, 0.16, 0.98), sunDir, moonDir);
    return (zenith * 0.55 + horizon * 0.45) * 0.62 * AMBIENT_INTENSITY;
}

#endif // AETHERON_SCATTERING_GLSL
