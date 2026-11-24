#ifndef AETHERON_FOG_GLSL
#define AETHERON_FOG_GLSL

// ==============================================================================
// AETHERON SHADERS — Volumetric Fog, God Rays, Height Mist, Distance & Underwater Fog
// Immersive atmospheric depth without washing out clear scenic visibility
// ==============================================================================

// Sample shadow map visibility along a world ray (with optional stained glass tint)
vec3 sampleVolumetricShadow(vec3 playerPos) {
    float distort;
    vec3 shadowPos = playerToShadowScreenPos(playerPos, distort);
    if (shadowPos.x < 0.002 || shadowPos.x > 0.998 || shadowPos.y < 0.002 || shadowPos.y > 0.998 || shadowPos.z >= 1.0) {
        return vec3(1.0);
    }

    float bias = 0.0012;
    float opaqueDepth = texture(shadowtex1, shadowPos.xy).r;
    if (shadowPos.z - bias > opaqueDepth) {
        return vec3(0.0);
    }

    #ifdef COLORED_SHADOWS
        float fullDepth = texture(shadowtex0, shadowPos.xy).r;
        if (shadowPos.z - bias > fullDepth) {
            vec4 sc = texture(shadowcolor0, shadowPos.xy);
            return mix(vec3(1.0), srgbToLinear(sc.rgb) * 1.15, sc.a);
        }
    #endif

    return vec3(1.0);
}

// Volumetric Lighting & Crepuscular God Rays (Overworld)
vec3 computeVolumetricFogAndGodRays(
    vec3 playerPos,
    vec3 viewDirWorld,
    float viewDist,
    vec3 sunDir,
    vec3 moonDir,
    float dither
) {
    #if VOLUMETRIC_FOG_QUALITY == 0
        return vec3(0.0);
    #endif

    float maxDist = min(viewDist, min(shadowDistance * 0.95, 180.0));
    if (maxDist <= 1.0) return vec3(0.0);

    #if VOLUMETRIC_FOG_QUALITY == 3
        const int STEPS = 20;
    #elif VOLUMETRIC_FOG_QUALITY == 2
        const int STEPS = 12;
    #else
        const int STEPS = 7;
    #endif

    vec3 lightDir = (sunDir.y > -0.05) ? sunDir : moonDir;
    float cosTheta = dot(viewDirWorld, lightDir);

    // Phase function: strong crepuscular forward lobe when looking toward sun/moon
    float godRayPhase = dualMiePhase(cosTheta, 0.80, -0.15, 0.88);
    #if GOD_RAYS == 0
        godRayPhase = 0.12;
    #else
        godRayPhase *= (0.75 + 0.95 * GOD_RAY_STRENGTH);
    #endif

    vec3 directCol = getActiveCelestialColor(sunDir, moonDir);
    vec3 ambientCol = getSkyAmbientIrradiance(sunDir, moonDir);

    float sunset = getSunsetFactor();
    float rain   = getRainMix();
    float baseDensity = 0.0022 * VOLUMETRIC_FOG_DENSITY;
    baseDensity *= (1.0 + sunset * 0.65 + rain * 1.20);
    #ifdef BIOME_LIGHTING
        baseDensity *= (1.0 + biomeHumid * 0.55 + biomeDesert * 0.25);
    #endif

    // Exponential step distribution puts higher sample density closer to the camera
    vec3 accumLight = vec3(0.0);
    float transmittance = 1.0;

    for (int i = 0; i < STEPS; i++) {
        #ifdef ADAPTIVE_RAYMARCHING
            if (transmittance < 0.10) break;
        #endif

        float t0 = float(i) / float(STEPS);
        float t1 = float(i + 1) / float(STEPS);
        float d0 = maxDist * t0 * t0;
        float d1 = maxDist * t1 * t1;
        float stepLen = max(d1 - d0, 0.2);
        float sampleDist = mix(d0, d1, dither);

        vec3 samplePlayerPos = viewDirWorld * sampleDist;
        vec3 sampleWorldPos  = cameraPosition + samplePlayerPos;

        // Height-based falloff (denser in low valleys & near rivers, clear high up)
        float heightAboveSea = max(sampleWorldPos.y - 62.0, -24.0);
        float heightFactor = exp(-max(heightAboveSea, 0.0) * 0.022);
        float localDensity = baseDensity * (0.35 + 0.95 * heightFactor);

        // Subtle animated drifting mist modulation
        #if VOLUMETRIC_FOG_QUALITY >= 2
            float mistNoise = valueNoise3D(sampleWorldPos * 0.035 + vec3(frameTimeCounter * 0.08, 0.0, frameTimeCounter * 0.04));
            localDensity *= (0.72 + 0.56 * mistNoise);
        #endif

        vec3 shadowVis = sampleVolumetricShadow(samplePlayerPos);

        // Direct in-scattering (crepuscular rays) + soft ambient mist fill
        vec3 inScatter = directCol * shadowVis * godRayPhase * 0.55 + ambientCol * 0.065;
        float stepTrans = exp(-localDensity * stepLen);
        accumLight += transmittance * inScatter * (1.0 - stepTrans);
        transmittance *= stepTrans;
    }

    // Attenuate volumetric sunlight deep underground (using smooth eye sky exposure)
    float skyAccess = smoothstep(0.05, 0.45, float(eyeBrightnessSmooth.y) / 240.0);
    return accumLight * mix(0.15, 1.0, skyAccess);
}

// Height-Based Valley Mist & Atmospheric Perspective Distance Fog (Overworld)
vec3 applyOverworldFog(
    vec3 sceneColor,
    vec3 viewDirWorld,
    float viewDist,
    vec3 sunDir,
    vec3 moonDir,
    bool isSky
) {
    if (isSky) return sceneColor;

    vec3 worldHit = cameraPosition + viewDirWorld * viewDist;
    float rain = getRainMix();
    float sunset = getSunsetFactor();

    // 1. Height-based valley & morning mist (analytic exponential height integral)
    float mistBase = 0.0038 * HEIGHT_FOG_DENSITY * (1.0 + sunset * 0.55 + rain * 0.95);
    #ifdef BIOME_LIGHTING
        mistBase *= (1.0 + biomeHumid * 0.85 - biomeDesert * 0.35);
    #endif

    float y0 = cameraPosition.y - 64.0;
    float y1 = worldHit.y - 64.0;
    float heightFalloff = 0.045;
    float dy = y1 - y0;
    float heightIntegral;
    if (abs(dy) < 0.05) {
        heightIntegral = exp(-max(y0, -10.0) * heightFalloff);
    } else {
        float e0 = exp(-max(y0, -10.0) * heightFalloff);
        float e1 = exp(-max(y1, -10.0) * heightFalloff);
        heightIntegral = clamp((e0 - e1) / max(dy * heightFalloff, 1e-4), 0.0, 1.5);
    }
    float heightFogAmount = 1.0 - exp(-viewDist * mistBase * heightIntegral);
    // Keep foreground crystal clear
    heightFogAmount *= smoothstep(10.0, 48.0, viewDist);

    // 2. Atmospheric perspective (distance aerial scattering toward horizon)
    float distFactor = clamp(viewDist / max(far, 64.0), 0.0, 1.4);
    float aerialBase = (0.28 + rain * 0.48) * DISTANCE_FOG_DENSITY;
    float aerialFog = 1.0 - exp(-pow(distFactor, 1.65) * aerialBase * 2.2);
    // Soft far-clip edge blend so chunk borders dissolve seamlessly into the sky
    float borderFog = smoothstep(0.76, 1.00, distFactor);

    float totalFog = clamp(max(max(heightFogAmount * 0.62, aerialFog), borderFog), 0.0, 1.0);

    // Underground cave fog shouldn't turn bright sky blue!
    float skyAccess = smoothstep(0.02, 0.35, float(eyeBrightnessSmooth.y) / 240.0);
    vec3 skyFogColor = evaluateAtmosphere(normalize(vec3(viewDirWorld.x, max(viewDirWorld.y, 0.03), viewDirWorld.z)), sunDir, moonDir);
    vec3 caveFogColor = vec3(0.012, 0.015, 0.022) * (0.6 + CAVE_BRIGHTNESS * 6.0);
    vec3 fogCol = mix(caveFogColor, skyFogColor, skyAccess);

    // Subtle warm sunlit forward-scatter tint inside valley mist
    float cosSun = max(dot(viewDirWorld, sunDir), 0.0);
    fogCol += getSunLightColor(sunDir) * pow(cosSun, 6.0) * 0.075 * skyAccess;

    return mix(sceneColor, fogCol, totalFog);
}

// Underwater Beer-Lambert Absorption & Scattering Fog (when camera is submerged)
vec3 applyUnderwaterFog(vec3 sceneColor, vec3 viewDirWorld, float viewDist, vec3 sunDir, vec3 moonDir, bool isSky) {
    float effDist = isSky ? 64.0 : viewDist;
    float density = UNDERWATER_FOG_DENSITY / max(WATER_CLARITY, 0.25);

    // Spectral water absorption coefficients (red attenuates fastest, blue-teal travels farthest)
    vec3 absorptionCoeff = vec3(0.165, 0.058, 0.036) * density;
    vec3 transmittance = exp(-absorptionCoeff * effDist);

    // In-scattered underwater ambient color
    vec3 directCol = getActiveCelestialColor(sunDir, moonDir);
    vec3 skyAmb    = getSkyAmbientIrradiance(sunDir, moonDir);
    vec3 waterScatter = (vec3(0.04, 0.22, 0.30) * (luminance(skyAmb) * 1.4 + 0.06)
                      + vec3(0.08, 0.32, 0.38) * luminance(directCol) * 0.22);

    #ifdef BIOME_LIGHTING
        waterScatter = mix(waterScatter, waterScatter * vec3(0.78, 1.12, 0.72), biomeHumid * 0.55);
        waterScatter = mix(waterScatter, waterScatter * vec3(0.88, 1.08, 1.15), biomeOcean * 0.35);
    #endif

    // Forward-scattered underwater light shafts near sun
    float cosLight = max(dot(viewDirWorld, (sunDir.y > -0.05) ? sunDir : moonDir), 0.0);
    waterScatter += directCol * vec3(0.18, 0.48, 0.55) * pow(cosLight, 5.0) * 0.14;

    return sceneColor * transmittance + waterScatter * (1.0 - transmittance);
}

// Nether Volcanic Atmospheric Fog
vec3 applyNetherFog(vec3 sceneColor, vec3 viewDirWorld, float viewDist, bool isSky) {
    if (isSky) return sceneColor;
    float fogAmount = 1.0 - exp(-pow(viewDist / max(far * 0.72, 48.0), 1.35) * 1.65);
    fogAmount = clamp(fogAmount, 0.0, 0.96);
    vec3 netherFogCol = computeNetherSky(viewDirWorld);
    return mix(sceneColor, netherFogCol, fogAmount);
}

// End Dimension Ethereal Void Fog
vec3 applyEndFog(vec3 sceneColor, vec3 viewDirWorld, float viewDist, bool isSky) {
    if (isSky) return sceneColor;
    float fogAmount = 1.0 - exp(-pow(viewDist / max(far * 0.85, 64.0), 1.45) * 1.35);
    fogAmount = clamp(fogAmount, 0.0, 0.95);
    vec3 endFogCol = computeEndSky(viewDirWorld);
    return mix(sceneColor, endFogCol, fogAmount);
}

#endif // AETHERON_FOG_GLSL
