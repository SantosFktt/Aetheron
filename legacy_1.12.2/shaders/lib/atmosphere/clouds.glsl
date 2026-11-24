#ifndef AETHERON_CLOUDS_GLSL
#define AETHERON_CLOUDS_GLSL

// ==============================================================================
// AETHERON SHADERS v1.1 (Legacy 1.12.2 GLSL 120) — Sculpted Multi-Tier Procedural Volumetric Clouds
// Crisp Bliss-inspired cumulus billows, distinct formations, clean sky gaps,
// realistic self-shadowing, and refined silver-lining forward scattering
// ==============================================================================

float getEffectiveCloudCoverage() {
    float rain  = getRainMix();
    float storm = getStormMix();
    float cov = CLOUD_COVERAGE;
    #ifdef BIOME_LIGHTING
        cov -= biomeDesert * 0.16;
        cov += biomeHumid * 0.07 + biomeOcean * 0.04;
    #endif
    cov = mix(cov, 0.78, rain);
    cov = mix(cov, 0.90, storm * 0.65);
    return clamp(cov, 0.10, 0.94);
}

// Sharp flat cumulus base transitioning into puffy rounded domes
float cloudHeightGradient(float hNorm, float anvilFactor) {
    float bottomGrad = smoothstep(0.0, 0.12, hNorm);
    float topHeight  = mix(0.72, 0.96, anvilFactor);
    float topGrad    = 1.0 - smoothstep(topHeight * 0.48, topHeight, hNorm);
    return bottomGrad * topGrad;
}

// Sculpted 3D Perlin-Worley cumulus density (crisp fluffy billows, not blurry fog!)
float sampleCloudDensity(vec3 worldPos, float baseAlt, float thickness, float coverage, bool highDetail) {
    float hNorm = clamp((worldPos.y - baseAlt) / max(thickness, 1.0), 0.0, 1.0);
    if (hNorm <= 0.001 || hNorm >= 0.999) return 0.0;

    float windTime = frameTimeCounter * 4.2 * CLOUD_SPEED;
    vec3 windOffset = vec3(windTime, 0.0, windTime * 0.38);

    // Higher spatial frequency produces distinct medium-sized cloud formations with open blue sky between them
    vec3 p = (worldPos + windOffset) * 0.00285;

    // Macro cumulus weather map (creates clusters & clear blue corridors)
    float macroMap = fbm2D(p.xz * 0.42 + vec2(3.7, -1.9), 3);
    float clusterMask = smoothstep(0.28, 0.74, macroMap);
    float anvilFactor = smoothstep(0.55, 0.88, macroMap + getStormMix() * 0.35);

    // Primary 3D billow shape: blend smooth FBM with cellular Worley domes for genuine fluffy cloud shapes
    float baseFbm    = fbm3D(vec3(p.x, p.y * 1.15, p.z) * 1.15, 3);
    float baseWorley = worleyBillow3D(vec3(p.x, p.y * 1.05, p.z) * 1.45);
    float perlinWorley = remapClamped(baseFbm, (1.0 - baseWorley) * 0.36, 1.0, 0.0, 1.0);

    float heightMask = cloudHeightGradient(hNorm, anvilFactor);
    float localCov = clamp(coverage * (0.55 + 0.85 * clusterMask), 0.0, 0.98);
    float shape = remapClamped(perlinWorley * heightMask, 1.0 - localCov, 1.0, 0.0, 1.0);
    if (shape <= 0.002) return 0.0;

    // Multi-frequency cauliflower edge erosion (creates crisp, volumetric Bliss-like puffs!)
    if (highDetail) {
        vec3 dCoord1 = (worldPos + windOffset * 1.25) * 0.0105;
        vec3 dCoord2 = (worldPos + windOffset * 1.45) * 0.0235;
        float w1 = worleyBillow3D(dCoord1);
        float w2 = valueNoise3D(dCoord2);
        float erosion = (1.0 - (w1 * 0.68 + w2 * 0.32)) * mix(0.42, 0.24, hNorm);
        shape = remapClamped(shape, erosion, 1.0, 0.0, 1.0);
    } else {
        vec3 dCoord = (worldPos + windOffset * 1.25) * 0.0110;
        float w = valueNoise3D(dCoord);
        shape = remapClamped(shape, (1.0 - w) * 0.32, 1.0, 0.0, 1.0);
    }

    // Sharpen edges subtly so clouds feel solid and sculpted rather than wispy blobs
    shape = pow(clamp(shape, 0.0, 1.0), 0.85);
    float stormThick = mix(1.0, 1.38, getStormMix());
    return shape * 0.068 * stormThick;
}

// High-altitude wispy cirrus clouds
vec4 renderCirrusLayer(vec3 rayDir, vec3 sunDir, vec3 moonDir) {
    #ifndef CIRRUS_CLOUDS
        return vec4(0.0, 0.0, 0.0, 1.0);
    #endif
    if (rayDir.y <= 0.025) return vec4(0.0, 0.0, 0.0, 1.0);

    float cirrusAlt = CLOUD_ALTITUDE + CLOUD_THICKNESS + 520.0;
    float dist = (cirrusAlt - cameraPosition.y) / rayDir.y;
    if (dist <= 0.0 || dist > 22000.0) return vec4(0.0, 0.0, 0.0, 1.0);

    vec2 hitXZ = cameraPosition.xz + rayDir.xz * dist;
    float wind = frameTimeCounter * 5.5 * CLOUD_SPEED;
    vec2 uv = (hitXZ + vec2(wind, wind * 0.25)) * 0.00034;

    float warp = fbm2D(uv * 1.5, 3);
    float streaks = fbm2D(vec2(uv.x * 2.8 + warp * 1.1, uv.y * 0.85 - warp * 0.5), 4);
    float density = smoothstep(0.58, 0.86, streaks) * 0.32;

    float horizonFade = smoothstep(0.025, 0.20, rayDir.y);
    density *= horizonFade * (1.0 - getRainMix() * 0.80);
    if (density <= 0.002) return vec4(0.0, 0.0, 0.0, 1.0);

    vec3 lightDir = (sunDir.y > -0.05) ? sunDir : moonDir;
    float cosTheta = dot(rayDir, lightDir);
    float phase = 0.55 + hgPhase(cosTheta, 0.65) * 1.1;

    vec3 directCol = getActiveCelestialColor(sunDir, moonDir);
    float highSunset = smoothstep(-0.14, 0.02, sunDir.y) * (1.0 - smoothstep(0.05, 0.26, sunDir.y));
    vec3 sunsetHighlight = vec3(1.25, 0.56, 0.34) * highSunset * 0.65;
    vec3 ambientCol = getSkyAmbientIrradiance(sunDir, moonDir) * 0.72;

    vec3 col = (directCol * phase * 0.42 + sunsetHighlight + ambientCol) * density;
    float trans = exp(-density * 1.10);
    return vec4(col, trans);
}

// Fast analytic 2D clouds (CLOUD_QUALITY == 1 / LOW preset & water reflection helper)
vec4 renderAnalyticClouds(vec3 rayDir, vec3 sunDir, vec3 moonDir) {
    if (rayDir.y <= 0.018) return vec4(0.0, 0.0, 0.0, 1.0);

    float alt = CLOUD_ALTITUDE;
    float dist = (alt - cameraPosition.y) / rayDir.y;
    if (dist <= 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    vec2 p = cameraPosition.xz + rayDir.xz * dist;
    float wind = frameTimeCounter * 4.2 * CLOUD_SPEED;
    vec2 uv = (p + vec2(wind, wind * 0.38)) * 0.0024;

    float coverage = getEffectiveCloudCoverage();
    float macro = smoothstep(0.28, 0.75, fbm2D(uv * 0.45, 3));
    float n1 = fbm2D(uv, 4);
    float w1 = worleyBillow2D(uv * 2.1);
    float shape = remapClamped(n1 * 0.65 + w1 * 0.35, 1.0 - coverage * (0.55 + 0.85 * macro), 1.0, 0.0, 1.0);

    float horizonFade = smoothstep(0.018, 0.15, rayDir.y);
    float alpha = clamp(pow(shape, 0.8) * 1.35, 0.0, 0.96) * horizonFade;
    if (alpha <= 0.002) return vec4(0.0, 0.0, 0.0, 1.0);

    vec3 lightDir = (sunDir.y > -0.05) ? sunDir : moonDir;
    vec2 sunSampleUV = uv + lightDir.xz * 0.08;
    float shadowN = remapClamped(fbm2D(sunSampleUV, 3), 1.0 - coverage, 1.0, 0.0, 1.0);
    float lightEnergy = exp(-shadowN * 1.85);

    float cosTheta = dot(rayDir, lightDir);
    float phase = 0.65 + hgPhase(cosTheta, 0.68) * 1.35;
    vec3 directCol  = getActiveCelestialColor(sunDir, moonDir);
    vec3 ambientCol = getSkyAmbientIrradiance(sunDir, moonDir);

    float sunset = getSunsetFactor();
    vec3 sunsetTint = vec3(1.15, 0.50, 0.24) * sunset * 0.42;

    vec3 cloudColor = directCol * lightEnergy * phase * 0.45 + ambientCol * (0.52 + 0.45 * (1.0 - shape)) + sunsetTint;

    float fogFactor = 1.0 - exp(-dist * 0.00022);
    vec3 horizonSky = evaluateAtmosphere(rayDir, sunDir, moonDir);
    cloudColor = mix(cloudColor, horizonSky, fogFactor * 0.78);

    return vec4(cloudColor * alpha, 1.0 - alpha);
}

// Main Volumetric Cloud Raymarcher (returns vec4(scatteredRadiance.rgb, transmittance))
vec4 renderVolumetricClouds(vec3 rayDir, vec3 sunDir, vec3 moonDir, float dither, float maxTerrainDist) {
    #if CLOUD_QUALITY == 0
        return vec4(0.0, 0.0, 0.0, 1.0);
    #elif CLOUD_QUALITY == 1
        vec4 lowC = renderAnalyticClouds(rayDir, sunDir, moonDir);
        vec4 cirrus = renderCirrusLayer(rayDir, sunDir, moonDir);
        return vec4(lowC.rgb + cirrus.rgb * lowC.a, lowC.a * cirrus.a);
    #else

    float baseAlt   = CLOUD_ALTITUDE;
    float thickness = CLOUD_THICKNESS;
    float topAlt    = baseAlt + thickness;

    if (abs(rayDir.y) < 0.015 && (cameraPosition.y < baseAlt || cameraPosition.y > topAlt)) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    float tBottom = (baseAlt - cameraPosition.y) / (abs(rayDir.y) < 1e-4 ? 1e-4 : rayDir.y);
    float tTop    = (topAlt  - cameraPosition.y) / (abs(rayDir.y) < 1e-4 ? 1e-4 : rayDir.y);

    float tStart, tEnd;
    if (cameraPosition.y < baseAlt) {
        if (rayDir.y <= 0.015) return vec4(0.0, 0.0, 0.0, 1.0);
        tStart = tBottom;
        tEnd   = tTop;
    } else if (cameraPosition.y > topAlt) {
        if (rayDir.y >= -0.015) return renderCirrusLayer(rayDir, sunDir, moonDir);
        tStart = tTop;
        tEnd   = tBottom;
    } else {
        tStart = 0.0;
        tEnd   = (rayDir.y > 0.0) ? tTop : tBottom;
    }

    float maxCloudRange = 3600.0;
    tStart = max(tStart, 0.0);
    tEnd   = min(tEnd, min(maxCloudRange, maxTerrainDist));
    if (tEnd <= tStart + 1.0) {
        vec4 cirrusOnly = (maxTerrainDist > 1e5) ? renderCirrusLayer(rayDir, sunDir, moonDir) : vec4(0.0, 0.0, 0.0, 1.0);
        return cirrusOnly;
    }

    #if CLOUD_QUALITY == 3
        const int MAX_STEPS = 32;
        const int SUN_STEPS = 4;
        const bool HIGH_DETAIL = true;
    #else
        const int MAX_STEPS = 18;
        const int SUN_STEPS = 2;
        const bool HIGH_DETAIL = false;
    #endif

    int steps = MAX_STEPS;
    #ifdef ADAPTIVE_RAYMARCHING
        float angleFactor = mix(1.0, 0.68, smoothstep(0.12, 0.65, abs(rayDir.y)));
        steps = int(max(10.0, float(MAX_STEPS) * angleFactor));
    #endif

    float slabDist = tEnd - tStart;
    float stepSize = slabDist / float(steps);
    float t = tStart + dither * stepSize;

    float coverage = getEffectiveCloudCoverage();
    vec3 lightDir   = (sunDir.y > -0.05) ? sunDir : moonDir;
    vec3 directCol  = getActiveCelestialColor(sunDir, moonDir);
    vec3 skyAmb     = getSkyAmbientIrradiance(sunDir, moonDir);
    // Cool-slate cloud underside shading gives crisp 3D depth contrast against bright sunlit cloud tops!
    vec3 baseShadowAmb = skyAmb * vec3(0.38, 0.44, 0.56);

    float cosTheta = dot(rayDir, lightDir);
    // Refined silver lining (bright near thin edges toward sun, never blowing out the entire sky white)
    float phasePrimary = 0.55 + dualMiePhase(cosTheta, 0.78, -0.25, 0.75) * 1.45;
    float phaseMulti   = 0.45 + dualMiePhase(cosTheta, 0.30, -0.10, 0.65) * 0.65;

    float sunset = getSunsetFactor();
    vec3 sunsetWarmth = vec3(1.18, 0.48, 0.22) * sunset * 0.45;

    vec3 scatteredLight = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        if (i >= steps) break;
        #ifdef ADAPTIVE_RAYMARCHING
            if (transmittance < 0.02) break;
        #endif

        vec3 samplePos = cameraPosition + rayDir * t;
        float density = sampleCloudDensity(samplePos, baseAlt, thickness, coverage, HIGH_DETAIL);

        if (density > 0.0005) {
            // Directional sun self-shadowing light march
            float sunOpticalDepth = 0.0;
            float sunStep = thickness * 0.14;
            for (int j = 0; j < SUN_STEPS; j++) {
                float fj = float(j) + 0.5;
                vec3 sunPos = samplePos + lightDir * (sunStep * fj * (1.0 + 0.30 * fj));
                sunOpticalDepth += sampleCloudDensity(sunPos, baseAlt, thickness, coverage, false) * sunStep;
            }

            // Crisp Beer-Lambert + Beer-Powder multiple scattering for defined puffy lighting
            float beer1  = exp(-sunOpticalDepth * 1.55);
            float beer2  = exp(-sunOpticalDepth * 0.36) * 0.36;
            float powder = 1.0 - exp(-sunOpticalDepth * 2.6);
            float directEnergy = beer1 * (0.48 + 0.72 * powder);

            float hNorm = clamp((samplePos.y - baseAlt) / max(thickness, 1.0), 0.0, 1.0);
            // Distinct bright cloud top vs softly shadowed blue-slate cloud underside
            vec3 ambient = mix(baseShadowAmb, skyAmb * 1.15, smoothstep(0.05, 0.85, hNorm));

            vec3 directScatter = directCol * (directEnergy * phasePrimary + beer2 * phaseMulti) + sunsetWarmth * (beer1 + beer2);
            vec3 stepRadiance = directScatter * 0.58 + ambient * (0.55 + 0.35 * beer2);

            float stepExtinction = max(density * 1.35, 1e-5);
            float stepTrans = exp(-stepExtinction * stepSize);
            vec3 stepIntegral = stepRadiance * (1.0 - stepTrans);

            scatteredLight += transmittance * stepIntegral;
            transmittance *= stepTrans;
        }

        t += stepSize;
    }

    // Smooth atmospheric perspective into horizon sky
    float meanDist = 0.5 * (tStart + tEnd);
    float distFade = exp(-meanDist * 0.00028);
    float cloudAlpha = 1.0 - transmittance;
    if (cloudAlpha > 0.001) {
        vec3 horizonSky = evaluateAtmosphere(rayDir, sunDir, moonDir);
        scatteredLight = mix(horizonSky * cloudAlpha, scatteredLight, distFade);
    }

    if (maxTerrainDist > 1e5) {
        vec4 cirrus = renderCirrusLayer(rayDir, sunDir, moonDir);
        scatteredLight += cirrus.rgb * transmittance;
        transmittance *= cirrus.a;
    }

    return vec4(max(scatteredLight, vec3(0.0)), clamp(transmittance, 0.0, 1.0));
    #endif
}

#endif // AETHERON_CLOUDS_GLSL
