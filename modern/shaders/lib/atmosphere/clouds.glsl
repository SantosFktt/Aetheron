#ifndef AETHERON_CLOUDS_GLSL
#define AETHERON_CLOUDS_GLSL

// ==============================================================================
// AETHERON SHADERS — Multi-Tier Procedural Volumetric Cloud Engine
// Inspired by Bliss's expansive cloudscapes & Photon's sunset illumination
//   CLOUD_QUALITY == 1 (Low)    : Fast analytic 2D cloud plane + Mie rim
//   CLOUD_QUALITY == 2 (Medium) : Optimized 3D volumetric raymarch + 2-tap sun march
//   CLOUD_QUALITY == 3 (Ultra)  : Full 3D Perlin-Worley cumulus + 4-tap self-shadow
//                                 + Beer-Powder multi-scattering + Cirrus layer
// ==============================================================================

// Effective cloud coverage reacting smoothly to weather & biome
float getEffectiveCloudCoverage() {
    float rain  = getRainMix();
    float storm = getStormMix();
    float cov = CLOUD_COVERAGE;
    #ifdef BIOME_LIGHTING
        cov -= biomeDesert * 0.18;
        cov += biomeHumid * 0.08 + biomeOcean * 0.05;
    #endif
    cov = mix(cov, 0.82, rain);
    cov = mix(cov, 0.93, storm * 0.65);
    return clamp(cov, 0.08, 0.96);
}

// Vertical cloud height density profile (flat cumulus bottom, rounded billowing top)
float cloudHeightGradient(float hNorm, float anvilFactor) {
    float bottomGrad = smoothstep(0.0, 0.16, hNorm);
    float topSoft    = mix(0.75, 0.96, anvilFactor);
    float topGrad    = 1.0 - smoothstep(topSoft * 0.65, topSoft, hNorm);
    return bottomGrad * topGrad;
}

// Sample 3D volumetric cloud density at world position p
float sampleCloudDensity(vec3 worldPos, float baseAlt, float thickness, float coverage, bool highDetail) {
    float hNorm = clamp((worldPos.y - baseAlt) / max(thickness, 1.0), 0.0, 1.0);
    if (hNorm <= 0.001 || hNorm >= 0.999) return 0.0;

    float windTime = frameTimeCounter * 4.5 * CLOUD_SPEED;
    vec3 windOffset = vec3(windTime, 0.0, windTime * 0.42);
    vec3 p = (worldPos + windOffset) * 0.00135;

    // Macro weather & cumulus formation field (multiple cloud types via domain warp)
    vec2 macroUV = p.xz * 0.68;
    float weatherField = fbm2D(macroUV, 3);
    float anvilFactor  = smoothstep(0.50, 0.85, weatherField + getStormMix() * 0.35);

    // Base low-frequency 3D shape
    float baseNoise = fbm3D(vec3(p.x, p.y * 1.45, p.z) * 1.35, highDetail ? 4 : 3);
    float heightMask = cloudHeightGradient(hNorm, anvilFactor);

    // Combine weather distribution with local coverage threshold
    float localCoverage = clamp(coverage * (0.72 + 0.56 * weatherField), 0.0, 1.0);
    float baseCloud = remapClamped(baseNoise * heightMask, 1.0 - localCoverage, 1.0, 0.0, 1.0);
    if (baseCloud <= 0.002) return 0.0;

    // Fine Worley-billow edge erosion (Ultra & Medium)
    if (highDetail) {
        vec3 detailCoord = (worldPos + windOffset * 1.35) * 0.0068;
        float billow = worleyBillow3D(detailCoord);
        float fineFbm = valueNoise3D(detailCoord * 2.1);
        float erosion = mix(billow, 1.0 - fineFbm, 0.35) * (1.0 - hNorm * 0.35);
        baseCloud = remapClamped(baseCloud, erosion * 0.38, 1.0, 0.0, 1.0);
    } else {
        vec3 detailCoord = (worldPos + windOffset * 1.25) * 0.0055;
        float erosion = valueNoise3D(detailCoord);
        baseCloud = remapClamped(baseCloud, erosion * 0.24, 1.0, 0.0, 1.0);
    }

    float stormThick = mix(1.0, 1.45, getStormMix());
    return baseCloud * 0.042 * stormThick;
}

// High-altitude wispy cirrus cloud deck (adds authentic atmospheric scale & sunset glow)
vec4 renderCirrusLayer(vec3 rayDir, vec3 sunDir, vec3 moonDir) {
    #ifndef CIRRUS_CLOUDS
        return vec4(0.0, 0.0, 0.0, 1.0);
    #endif
    if (rayDir.y <= 0.02) return vec4(0.0, 0.0, 0.0, 1.0);

    float cirrusAlt = CLOUD_ALTITUDE + CLOUD_THICKNESS + 480.0;
    float dist = (cirrusAlt - cameraPosition.y) / rayDir.y;
    if (dist <= 0.0 || dist > 22000.0) return vec4(0.0, 0.0, 0.0, 1.0);

    vec2 hitXZ = cameraPosition.xz + rayDir.xz * dist;
    float wind = frameTimeCounter * 6.0 * CLOUD_SPEED;
    vec2 uv = (hitXZ + vec2(wind, wind * 0.25)) * 0.00028;

    // Streaky wind-sheared cirrus filaments
    float warp = fbm2D(uv * 1.4, 3);
    float streaks = fbm2D(vec2(uv.x * 2.4 + warp * 0.9, uv.y * 0.9 - warp * 0.6), 4);
    float density = smoothstep(0.54, 0.84, streaks) * 0.42;

    // Fade gently near horizon and under heavy overcast
    float horizonFade = smoothstep(0.02, 0.18, rayDir.y);
    density *= horizonFade * (1.0 - getRainMix() * 0.75);
    if (density <= 0.002) return vec4(0.0, 0.0, 0.0, 1.0);

    vec3 lightDir = (sunDir.y > -0.05) ? sunDir : moonDir;
    float cosTheta = dot(rayDir, lightDir);
    float phase = dualMiePhase(cosTheta, 0.65, -0.15, 0.80) * 2.8 + 0.35;

    vec3 directCol = getActiveCelestialColor(sunDir, moonDir);
    // Cirrus catches high-altitude pink/gold sunset light slightly longer than ground!
    float highSunset = smoothstep(-0.14, 0.02, sunDir.y) * (1.0 - smoothstep(0.05, 0.26, sunDir.y));
    vec3 sunsetHighlight = vec3(1.25, 0.56, 0.34) * highSunset * 0.85;
    vec3 ambientCol = getSkyAmbientIrradiance(sunDir, moonDir) * 0.85;

    vec3 col = (directCol * phase * 0.55 + sunsetHighlight + ambientCol) * density;
    float trans = exp(-density * 1.15);
    return vec4(col, trans);
}

// Fast analytic 2D clouds (CLOUD_QUALITY == 1 / LOW preset)
vec4 renderAnalyticClouds(vec3 rayDir, vec3 sunDir, vec3 moonDir) {
    if (rayDir.y <= 0.015) return vec4(0.0, 0.0, 0.0, 1.0);

    float alt = CLOUD_ALTITUDE;
    float dist = (alt - cameraPosition.y) / rayDir.y;
    if (dist <= 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    vec2 p = cameraPosition.xz + rayDir.xz * dist;
    float wind = frameTimeCounter * 4.5 * CLOUD_SPEED;
    vec2 uv = (p + vec2(wind, wind * 0.42)) * 0.0012;

    float coverage = getEffectiveCloudCoverage();
    float n1 = fbm2D(uv, 4);
    float n2 = fbm2D(uv * 2.7 + vec2(n1 * 0.6), 2);
    float shape = remapClamped(n1 * 0.78 + n2 * 0.22, 1.0 - coverage, 1.0, 0.0, 1.0);

    // Distance horizon fade
    float horizonFade = smoothstep(0.015, 0.14, rayDir.y);
    float alpha = clamp(shape * 1.25, 0.0, 0.96) * horizonFade;
    if (alpha <= 0.002) return vec4(0.0, 0.0, 0.0, 1.0);

    // Pseudo self-shadowing via sun-offset sample
    vec3 lightDir = (sunDir.y > -0.05) ? sunDir : moonDir;
    vec2 sunSampleUV = uv + lightDir.xz * 0.055;
    float shadowN = remapClamped(fbm2D(sunSampleUV, 3), 1.0 - coverage, 1.0, 0.0, 1.0);
    float lightEnergy = exp(-shadowN * 1.9);

    float cosTheta = dot(rayDir, lightDir);
    float phase = dualMiePhase(cosTheta, 0.72, -0.20, 0.75) * 3.2 + 0.45;
    vec3 directCol  = getActiveCelestialColor(sunDir, moonDir);
    vec3 ambientCol = getSkyAmbientIrradiance(sunDir, moonDir);

    // Warm sunset under-lighting
    float sunset = getSunsetFactor();
    vec3 sunsetTint = vec3(1.20, 0.55, 0.28) * sunset * 0.45;

    vec3 cloudColor = directCol * lightEnergy * phase * 0.52 + ambientCol * (0.72 + 0.28 * (1.0 - shape)) + sunsetTint;

    // Aerial perspective blend into horizon sky
    float fogFactor = 1.0 - exp(-dist * 0.00018);
    vec3 horizonSky = evaluateAtmosphere(rayDir, sunDir, moonDir);
    cloudColor = mix(cloudColor, horizonSky, fogFactor * 0.75);

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

    // Only raymarch sky & rays that can intersect the cloud slab
    float baseAlt   = CLOUD_ALTITUDE;
    float thickness = CLOUD_THICKNESS;
    float topAlt    = baseAlt + thickness;

    // Prevent extreme grazing horizon cost
    if (abs(rayDir.y) < 0.012 && (cameraPosition.y < baseAlt || cameraPosition.y > topAlt)) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    float tBottom = (baseAlt - cameraPosition.y) / (abs(rayDir.y) < 1e-4 ? 1e-4 : rayDir.y);
    float tTop    = (topAlt  - cameraPosition.y) / (abs(rayDir.y) < 1e-4 ? 1e-4 : rayDir.y);

    float tStart, tEnd;
    if (cameraPosition.y < baseAlt) {
        if (rayDir.y <= 0.012) return vec4(0.0, 0.0, 0.0, 1.0);
        tStart = tBottom;
        tEnd   = tTop;
    } else if (cameraPosition.y > topAlt) {
        if (rayDir.y >= -0.012) return renderCirrusLayer(rayDir, sunDir, moonDir);
        tStart = tTop;
        tEnd   = tBottom;
    } else {
        tStart = 0.0;
        tEnd   = (rayDir.y > 0.0) ? tTop : tBottom;
    }

    // Clamp max march distance for horizon performance & terrain occlusion
    float maxCloudRange = 4200.0;
    tStart = max(tStart, 0.0);
    tEnd   = min(tEnd, min(maxCloudRange, maxTerrainDist));
    if (tEnd <= tStart + 1.0) {
        vec4 cirrusOnly = (maxTerrainDist > 1e5) ? renderCirrusLayer(rayDir, sunDir, moonDir) : vec4(0.0, 0.0, 0.0, 1.0);
        return cirrusOnly;
    }

    // Quality-scaled adaptive step counts
    #if CLOUD_QUALITY == 3
        const int MAX_STEPS = 28;
        const int SUN_STEPS = 4;
        const bool HIGH_DETAIL = true;
    #else
        const int MAX_STEPS = 16;
        const int SUN_STEPS = 2;
        const bool HIGH_DETAIL = false;
    #endif

    // Adaptive step count based on elevation angle (more steps near horizon where slab path is longer)
    int steps = MAX_STEPS;
    #ifdef ADAPTIVE_RAYMARCHING
        float angleFactor = mix(1.0, 0.65, smoothstep(0.10, 0.65, abs(rayDir.y)));
        steps = max(8, int(float(MAX_STEPS) * angleFactor));
    #endif

    float slabDist = tEnd - tStart;
    float stepSize = slabDist / float(steps);
    float t = tStart + dither * stepSize;

    float coverage = getEffectiveCloudCoverage();
    vec3 lightDir = (sunDir.y > -0.05) ? sunDir : moonDir;
    vec3 directCol  = getActiveCelestialColor(sunDir, moonDir);
    vec3 skyAmb     = getSkyAmbientIrradiance(sunDir, moonDir);
    vec3 groundAmb  = skyAmb * vec3(0.45, 0.48, 0.52);

    float cosTheta = dot(rayDir, lightDir);
    // Dual-lobe Henyey-Greenstein phase: bright silver lining forward + soft back-scatter
    float phasePrimary = dualMiePhase(cosTheta, 0.76, -0.28, 0.72) * 3.8;
    float phaseMulti   = dualMiePhase(cosTheta, 0.35, -0.10, 0.65) * 1.4;

    float sunset = getSunsetFactor();
    vec3 sunsetWarmth = vec3(1.18, 0.52, 0.24) * sunset * 0.35;

    vec3 scatteredLight = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        if (i >= steps) break;
        #ifdef ADAPTIVE_RAYMARCHING
            if (transmittance < 0.025) break;
        #endif

        vec3 samplePos = cameraPosition + rayDir * t;
        float density = sampleCloudDensity(samplePos, baseAlt, thickness, coverage, HIGH_DETAIL);

        if (density > 0.0004) {
            // Directional light march for realistic cloud self-shadowing
            float sunOpticalDepth = 0.0;
            float sunStep = thickness * 0.16;
            for (int j = 0; j < SUN_STEPS; j++) {
                float fj = float(j) + 0.5;
                vec3 sunPos = samplePos + lightDir * (sunStep * fj * (1.0 + 0.35 * fj));
                sunOpticalDepth += sampleCloudDensity(sunPos, baseAlt, thickness, coverage, false) * sunStep;
            }

            // Beer-Lambert + Multiple-Scattering Powder Effect (Schneider / Oz Volumes)
            float beer1 = exp(-sunOpticalDepth * 1.35);
            float beer2 = exp(-sunOpticalDepth * 0.32) * 0.48; // Multi-scatter energy conservation
            float powder = 1.0 - exp(-sunOpticalDepth * 2.2);
            float lightEnergy = mix(beer1, beer1 * (0.55 + 0.85 * powder), 0.55) + beer2;

            // Vertical height ambient gradient (darker cloud base, luminous cloud top)
            float hNorm = clamp((samplePos.y - baseAlt) / max(thickness, 1.0), 0.0, 1.0);
            vec3 ambient = mix(groundAmb * 0.85, skyAmb * 1.35, smoothstep(0.05, 0.85, hNorm));

            // Combine primary + multi-scatter sunlight + sunset rim + sky ambient
            vec3 directScatter = directCol * (beer1 * phasePrimary + beer2 * phaseMulti + sunsetWarmth * lightEnergy);
            vec3 stepRadiance = (directScatter * 0.52 + ambient * (0.75 + 0.25 * beer2));

            // Analytical step integration (prevents banding at large step sizes)
            float stepExtinction = max(density * 1.25, 1e-5);
            float stepTrans = exp(-stepExtinction * stepSize);
            vec3 stepIntegral = stepRadiance * (1.0 - stepTrans);

            scatteredLight += transmittance * stepIntegral;
            transmittance *= stepTrans;
        }

        t += stepSize;
    }

    // Distance atmospheric perspective blend so distant clouds dissolve naturally into horizon haze
    float meanDist = 0.5 * (tStart + tEnd);
    float distFade = exp(-meanDist * 0.00024);
    float cloudAlpha = 1.0 - transmittance;
    if (cloudAlpha > 0.001) {
        vec3 horizonSky = evaluateAtmosphere(rayDir, sunDir, moonDir);
        vec3 cloudPremult = mix(horizonSky * cloudAlpha, scatteredLight, distFade);
        scatteredLight = cloudPremult;
    }

    // Composite upper-troposphere cirrus behind cumulus clouds (for sky pixels)
    if (maxTerrainDist > 1e5) {
        vec4 cirrus = renderCirrusLayer(rayDir, sunDir, moonDir);
        scatteredLight += cirrus.rgb * transmittance;
        transmittance *= cirrus.a;
    }

    return vec4(max(scatteredLight, vec3(0.0)), clamp(transmittance, 0.0, 1.0));
    #endif
}

#endif // AETHERON_CLOUDS_GLSL
