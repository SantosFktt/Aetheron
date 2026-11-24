#ifndef AETHERON_SHADING_GLSL
#define AETHERON_SHADING_GLSL

// ==============================================================================
// AETHERON SHADERS — Physically-Inspired Surface Shading & Material Response
// GGX Specular, Sky Hemisphere Ambient, Blocklight, Handheld Light, Emissives,
// Foliage SSS, Rain Puddles, and Dimension Lighting (Overworld / Nether / End)
// ==============================================================================

// GGX Microfacet Specular BRDF (isotropic, energy-conserving)
vec3 evalGGXSpecular(vec3 N, vec3 V, vec3 L, float roughness, vec3 F0) {
    float ndotl = max(dot(N, L), 0.0);
    float ndotv = max(dot(N, V), 1e-4);
    if (ndotl <= 0.0) return vec3(0.0);

    vec3 H = normalize(V + L);
    float ndoth = max(dot(N, H), 0.0);
    float vdoth = max(dot(V, H), 0.0);

    float a  = max(roughness * roughness, 0.0025);
    float a2 = a * a;

    // Trowbridge-Reitz NDF
    float denomD = ndoth * ndoth * (a2 - 1.0) + 1.0;
    float D = a2 / max(PI * denomD * denomD, 1e-6);

    // Smith Schlick-GGX visibility
    float k = a * 0.5;
    float Gv = ndotv / (ndotv * (1.0 - k) + k);
    float Gl = ndotl / (ndotl * (1.0 - k) + k);
    float G  = Gv * Gl;

    // Schlick Fresnel
    vec3 F = F0 + (1.0 - F0) * pow5(1.0 - vdoth);

    return (D * G * F) / max(4.0 * ndotv * ndotl, 1e-4);
}

// Compute puddle wetness mask on exposed upward-facing outdoor surfaces during rain
float computeRainPuddleMask(vec3 worldPos, vec3 worldNormal, float skyLight) {
    #if WEATHER_PUDDLES == 0
        return 0.0;
    #endif
    if (wetness <= 0.01) return 0.0;

    float upFacing = smoothstep(0.75, 0.96, worldNormal.y);
    float skyExposed = smoothstep(0.84, 0.98, skyLight);
    if (upFacing * skyExposed <= 0.01) return 0.0;

    // Natural uneven puddle pooling via domain-warped 2D FBM
    float pool = fbm2D(worldPos.xz * 0.16, 3);
    float puddle = smoothstep(0.42, 0.62, pool + wetness * 0.16 - 0.10);
    return puddle * upFacing * skyExposed * wetness;
}

// Evaluate handheld dynamic light (main hand & offhand)
vec3 computeHandheldLight(vec3 playerPos, vec3 worldNormal) {
    float maxPower = max(float(heldBlockLightValue), float(heldBlockLightValue2));
    if (maxPower <= 0.5) return vec3(0.0);

    int activeItem = (heldBlockLightValue >= heldBlockLightValue2) ? heldItemId : heldItemId2;
    vec3 lightColor = blackbodyColor(float(BLOCKLIGHT_TEMP));
    if (activeItem == 2) {
        lightColor = vec3(0.32, 0.85, 1.05); // Soul / Sea lantern cool teal
    } else if (activeItem == 3) {
        lightColor = vec3(1.15, 0.25, 0.20); // Redstone / Accent crimson
    }

    float dist = length(playerPos);
    float radius = maxPower * 1.15;
    float atten = clamp(1.0 - dist / max(radius, 1.0), 0.0, 1.0);
    atten = atten * atten / (1.0 + dist * dist * 0.16);

    vec3 toCam = normalize(-playerPos + vec3(0.0, 0.25, 0.0));
    float wrapNdotL = clamp(dot(worldNormal, toCam) * 0.65 + 0.35, 0.15, 1.0);

    return lightColor * atten * wrapNdotL * 1.35 * BLOCKLIGHT_INTENSITY;
}

// Improved physically-shaped artificial blocklight curve
vec3 computeBlocklight(float blockLight, vec3 worldPos) {
    if (blockLight <= 0.002) return vec3(0.0);

    // Smooth non-linear falloff avoids flat orange walls while glowing richly near torches
    float falloff = pow(blockLight, 2.6) * 0.70 + pow(blockLight, 5.2) * 1.45;
    // Subtle organic torch warmth shimmer
    float flicker = 1.0 + 0.025 * sin(frameTimeCounter * 5.2 + worldPos.x * 1.7 + worldPos.z * 2.3);
    vec3 tempCol = blackbodyColor(float(BLOCKLIGHT_TEMP));

    return tempCol * falloff * flicker * 1.65 * BLOCKLIGHT_INTENSITY;
}

// Emissive material radiance based on block ID classification
vec3 computeEmissiveRadiance(vec3 albedoLinear, int matId, float emissiveMask) {
    if (emissiveMask <= 0.01) return vec3(0.0);

    vec3 baseGlow = albedoLinear * (1.8 + 3.2 * emissiveMask);
    if (matId == MAT_EMISSIVE_WARM) {
        baseGlow *= vec3(1.22, 0.92, 0.64);
    } else if (matId == MAT_EMISSIVE_COOL) {
        baseGlow *= vec3(0.76, 1.06, 1.24);
    } else if (matId == MAT_EMISSIVE_ACCENT) {
        baseGlow *= vec3(1.15, 0.85, 1.15);
    } else if (matId == MAT_PORTAL) {
        baseGlow = mix(albedoLinear, vec3(0.55, 0.18, 0.95), 0.5) * 3.8;
    }

    return baseGlow * EMISSIVE_INTENSITY;
}

// Master Deferred Opaque Surface Shading (Handles Overworld, Nether & End)
vec3 shadeOpaqueSurface(
    vec3 albedoLinear,
    vec3 viewPos,
    vec3 playerPos,
    vec3 worldNormal,
    vec3 viewNormal,
    vec2 lightmap,
    float vanillaAO,
    float ssao,
    float contactShadow,
    int matId,
    float sssStrength,
    float emissiveMask,
    float dither,
    vec3 ssilBounce
) {
    vec3 worldPos = cameraPosition + playerPos;
    vec3 V = normalize(-playerPos);
    float combinedAO = clamp(mix(1.0, vanillaAO, 0.68) * ssao, 0.08, 1.0);

    // Derive material roughness & reflectance (F0) from material classification
    float roughness = 0.78;
    vec3 F0 = vec3(0.04);
    if (matId == MAT_METALLIC) {
        roughness = 0.26;
        F0 = mix(vec3(0.08), albedoLinear, 0.72);
    } else if (matId == MAT_ICE) {
        roughness = 0.16;
        F0 = vec3(0.05);
    } else if (matId == MAT_SNOW) {
        roughness = 0.62;
        F0 = vec3(0.045);
    } else if (matId == MAT_LEAVES || matId == MAT_FOLIAGE_LOW || matId == MAT_FOLIAGE_TALL || matId == MAT_CROPS) {
        roughness = 0.68;
    }

    // Rain wetness surface response (Overworld only)
    float puddleMask = 0.0;
    #ifdef DIMENSION_OVERWORLD
        float wetExposed = wetness * smoothstep(0.82, 0.98, lightmap.y);
        puddleMask = computeRainPuddleMask(worldPos, worldNormal, lightmap.y);
        // Wet stone/wood darkens slightly due to internal total reflection & gets smoother
        albedoLinear *= mix(1.0, 0.72, wetExposed * 0.65);
        roughness = mix(roughness, 0.32, wetExposed * 0.6);
        roughness = mix(roughness, 0.06, puddleMask);
        F0 = mix(F0, vec3(0.025), puddleMask);
    #endif

    vec3 totalLight = vec3(0.0);

    // =========================================================================
    // OVERWORLD LIGHTING
    // =========================================================================
    #ifdef DIMENSION_OVERWORLD
        vec3 sunDir   = getSunDirWorld();
        vec3 moonDir  = getMoonDirWorld();
        vec3 lightDir = getShadowLightDirWorld();

        vec3 celestialCol = getActiveCelestialColor(sunDir, moonDir);
        vec3 skyAmb       = getSkyAmbientIrradiance(sunDir, moonDir);

        // Directional Shadow + Foliage Subsurface Scattering
        float sssTransmission = 0.0;
        vec3 shadowVis = computeDirectionalShadow(
            playerPos,
            worldNormal,
            lightDir,
            sssStrength,
            dither,
            sssTransmission
        );

        // Prevent direct sun leak inside sealed caves where skylight is zero
        float caveSunGuard = smoothstep(0.02, 0.14, lightmap.y);
        shadowVis *= contactShadow * caveSunGuard;

        float ndotl = max(dot(worldNormal, lightDir), 0.0);

        // Soft wrap diffuse for natural non-harsh shading on foliage
        float diffuseTerm = (sssStrength > 0.05) ? max(dot(worldNormal, lightDir) * 0.75 + 0.25, 0.0) : ndotl;
        vec3 directDiffuse = albedoLinear * celestialCol * diffuseTerm * shadowVis * INV_PI * 2.65;

        // Foliage Subsurface Scattering (back-lit translucent leaf/grass glow)
        vec3 sssLight = vec3(0.0);
        #ifdef FOLIAGE_SSS
            if (sssStrength > 0.05) {
                float backLit = pow(clamp(dot(-V, lightDir), 0.0, 1.0), 3.0) * 0.75 + 0.25;
                vec3 foliageTint = albedoLinear * vec3(1.18, 1.24, 0.76);
                sssLight = foliageTint * celestialCol * sssTransmission * backLit * caveSunGuard * 0.65;
            }
        #endif

        // GGX Direct Specular (sun/moon glints on metals, snow, wet stone, puddles)
        vec3 directSpec = evalGGXSpecular(worldNormal, V, lightDir, roughness, F0)
                        * celestialCol * ndotl * shadowVis * 1.15;

        // Hemisphere Sky Ambient + Ground Bounce Fill
        float hemiUp = worldNormal.y * 0.5 + 0.5;
        float skyMask = pow(lightmap.y, 1.55);
        vec3 groundBounce = skyAmb * vec3(0.32, 0.34, 0.30);
        vec3 skyFill = mix(groundBounce, skyAmb * 1.18, hemiUp) * skyMask;

        // Natural Underground Cave Ambient (cool subtle stone ambience so caves feel deep yet legible)
        vec3 caveAmb = vec3(0.55, 0.66, 0.85) * CAVE_BRIGHTNESS * (0.45 + 0.55 * hemiUp);
        if (nightVision > 0.01) {
            caveAmb += vec3(0.35, 0.40, 0.48) * nightVision;
        }

        // Wet puddle sky reflection hint on opaque surfaces
        vec3 puddleSpec = vec3(0.0);
        if (puddleMask > 0.02) {
            vec3 R = reflect(-V, worldNormal);
            float fresnel = 0.02 + 0.98 * pow5(1.0 - max(dot(worldNormal, V), 0.0));
            vec3 envSky = evaluateAtmosphere(R, sunDir, moonDir);
            puddleSpec = envSky * fresnel * puddleMask * 0.85;
        }

        // Blocklight + Handheld Dynamic Light + SSIL Indirect Bounce
        vec3 blockLight = computeBlocklight(lightmap.x, worldPos);
        vec3 handLight  = computeHandheldLight(playerPos, worldNormal);

        totalLight = directDiffuse + sssLight + directSpec + puddleSpec
                   + albedoLinear * ((skyFill + caveAmb + ssilBounce) * combinedAO + (blockLight + handLight) * mix(0.65, 1.0, combinedAO));

    // =========================================================================
    // NETHER LIGHTING
    // =========================================================================
    #elif defined(DIMENSION_NETHER)
        float hemiUp = worldNormal.y * 0.5 + 0.5;
        vec3 netherFloorGlow = vec3(0.42, 0.14, 0.06); // Warm lava glow from below
        vec3 netherCeilAmb   = vec3(0.16, 0.06, 0.05); // Deep basalt crimson from above
        vec3 netherAmb = mix(netherFloorGlow, netherCeilAmb, hemiUp) * (0.42 + CAVE_BRIGHTNESS * 2.5);

        vec3 blockLight = computeBlocklight(lightmap.x, worldPos) * 1.15;
        vec3 handLight  = computeHandheldLight(playerPos, worldNormal);
        if (nightVision > 0.01) netherAmb += vec3(0.35) * nightVision;

        totalLight = albedoLinear * ((netherAmb + ssilBounce) * combinedAO + (blockLight + handLight));

    // =========================================================================
    // THE END LIGHTING
    // =========================================================================
    #elif defined(DIMENSION_END)
        // Subtle directional ethereal starlight from End zenith-angle
        vec3 endLightDir = normalize(vec3(0.38, 0.82, 0.42));
        float ndotl = max(dot(worldNormal, endLightDir), 0.0);
        vec3 endDirect = vec3(0.66, 0.56, 0.92) * 0.85 * ndotl;

        float hemiUp = worldNormal.y * 0.5 + 0.5;
        vec3 endAmb = mix(vec3(0.05, 0.04, 0.09), vec3(0.18, 0.14, 0.28), hemiUp) * (0.85 + CAVE_BRIGHTNESS * 2.5);
        vec3 endSpec = evalGGXSpecular(worldNormal, V, endLightDir, roughness, F0) * vec3(0.70, 0.58, 0.98) * ndotl * 0.65;

        vec3 blockLight = computeBlocklight(lightmap.x, worldPos);
        vec3 handLight  = computeHandheldLight(playerPos, worldNormal);
        if (nightVision > 0.01) endAmb += vec3(0.35) * nightVision;

        totalLight = albedoLinear * (endDirect * 0.72 + (endAmb + ssilBounce) * combinedAO + blockLight + handLight) + endSpec;
    #endif

    // Emissive Materials (always self-illuminated, unaffected by shadows/AO)
    totalLight += computeEmissiveRadiance(albedoLinear, matId, emissiveMask);

    // Darkness / Blindness potion status effects
    float darkFactor = clamp(max(blindness, darknessFactor), 0.0, 1.0);
    if (darkFactor > 0.01) {
        float fadeDist = length(playerPos);
        totalLight *= mix(1.0, exp(-fadeDist * 0.18), darkFactor);
    }

    return max(totalLight, vec3(0.0));
}

#endif // AETHERON_SHADING_GLSL
