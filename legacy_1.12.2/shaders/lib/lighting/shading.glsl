#ifndef AETHERON_SHADING_GLSL
#define AETHERON_SHADING_GLSL

// ==============================================================================
// AETHERON SHADERS v1.1 (Legacy 1.12.2 GLSL 120) — Balanced Photon x Bliss Surface Shading
// Natural sunlit-to-shadow ratio, rich sky fill, warm ground bounce, zero crushed blacks
// ==============================================================================

vec3 evalGGXSpecular(vec3 N, vec3 V, vec3 L, float roughness, vec3 F0) {
    float ndotl = max(dot(N, L), 0.0);
    float ndotv = max(dot(N, V), 1e-4);
    if (ndotl <= 0.0) return vec3(0.0);

    vec3 H = normalize(V + L);
    float ndoth = max(dot(N, H), 0.0);
    float vdoth = max(dot(V, H), 0.0);

    float a  = max(roughness * roughness, 0.0025);
    float a2 = a * a;

    float denomD = ndoth * ndoth * (a2 - 1.0) + 1.0;
    float D = a2 / max(PI * denomD * denomD, 1e-6);

    float k = a * 0.5;
    float Gv = ndotv / (ndotv * (1.0 - k) + k);
    float Gl = ndotl / (ndotl * (1.0 - k) + k);
    float G  = Gv * Gl;

    vec3 F = F0 + (1.0 - F0) * pow5(1.0 - vdoth);
    return (D * G * F) / max(4.0 * ndotv * ndotl, 1e-4);
}

float computeRainPuddleMask(vec3 worldPos, vec3 worldNormal, float skyLight) {
    #if WEATHER_PUDDLES == 0
        return 0.0;
    #endif
    if (wetness <= 0.01) return 0.0;

    float upFacing = smoothstep(0.75, 0.96, worldNormal.y);
    float skyExposed = smoothstep(0.84, 0.98, skyLight);
    if (upFacing * skyExposed <= 0.01) return 0.0;

    float pool = fbm2D(worldPos.xz * 0.16, 3);
    float puddle = smoothstep(0.42, 0.62, pool + wetness * 0.16 - 0.10);
    return puddle * upFacing * skyExposed * wetness;
}

vec3 computeHandheldLight(vec3 playerPos, vec3 worldNormal) {
    float maxPower = max(float(heldBlockLightValue), float(heldBlockLightValue2));
    if (maxPower <= 0.5) return vec3(0.0);

    int activeItem = (heldBlockLightValue >= heldBlockLightValue2) ? heldItemId : heldItemId2;
    vec3 lightColor = blackbodyColor(float(BLOCKLIGHT_TEMP));
    if (activeItem == 2) {
        lightColor = vec3(0.32, 0.85, 1.05);
    } else if (activeItem == 3) {
        lightColor = vec3(1.15, 0.25, 0.20);
    }

    float dist = length(playerPos);
    float radius = maxPower * 1.15;
    float atten = clamp(1.0 - dist / max(radius, 1.0), 0.0, 1.0);
    atten = atten * atten / (1.0 + dist * dist * 0.16);

    vec3 toCam = normalize(-playerPos + vec3(0.0, 0.25, 0.0));
    float wrapNdotL = clamp(dot(worldNormal, toCam) * 0.65 + 0.35, 0.15, 1.0);

    return lightColor * atten * wrapNdotL * 1.35 * BLOCKLIGHT_INTENSITY;
}

vec3 computeBlocklight(float blockLight, vec3 worldPos) {
    if (blockLight <= 0.002) return vec3(0.0);

    float falloff = pow(blockLight, 2.3) * 0.72 + pow(blockLight, 4.8) * 1.40;
    float flicker = 1.0 + 0.022 * sin(frameTimeCounter * 5.2 + worldPos.x * 1.7 + worldPos.z * 2.3);
    vec3 tempCol = blackbodyColor(float(BLOCKLIGHT_TEMP));

    return tempCol * falloff * flicker * 1.75 * BLOCKLIGHT_INTENSITY;
}

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

    // Keep AO natural and grounded without crushing dark dirt/stone into black
    float softVanillaAO = mix(1.0, clamp(vanillaAO, 0.35, 1.0), 0.58);
    float combinedAO = clamp(softVanillaAO * mix(1.0, ssao, 0.85), 0.28, 1.0);

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

    float puddleMask = 0.0;
    #ifdef DIMENSION_OVERWORLD
        float wetExposed = wetness * smoothstep(0.82, 0.98, lightmap.y);
        puddleMask = computeRainPuddleMask(worldPos, worldNormal, lightmap.y);
        albedoLinear *= mix(1.0, 0.78, wetExposed * 0.55);
        roughness = mix(roughness, 0.30, wetExposed * 0.6);
        roughness = mix(roughness, 0.06, puddleMask);
        F0 = mix(F0, vec3(0.025), puddleMask);
    #endif

    vec3 totalLight = vec3(0.0);

    // =========================================================================
    // OVERWORLD LIGHTING (Balanced Sun + Rich Sky Fill + Warm Ground Bounce)
    // =========================================================================
    #ifdef DIMENSION_OVERWORLD
        vec3 sunDir   = getSunDirWorld();
        vec3 moonDir  = getMoonDirWorld();
        vec3 lightDir = getShadowLightDirWorld();

        vec3 celestialCol = getActiveCelestialColor(sunDir, moonDir);
        vec3 skyAmb       = getSkyAmbientIrradiance(sunDir, moonDir);

        float sssTransmission = 0.0;
        vec3 shadowVis = computeDirectionalShadow(
            playerPos,
            worldNormal,
            lightDir,
            sssStrength,
            dither,
            sssTransmission
        );

        // Keep first-person hand cleanly lit without harsh self-shadow clipping
        if (matId == MAT_HAND) {
            shadowVis = mix(vec3(0.75), shadowVis, 0.35);
            contactShadow = 1.0;
        }

        float caveSunGuard = smoothstep(0.02, 0.14, lightmap.y);
        shadowVis *= contactShadow * caveSunGuard;

        float ndotl = max(dot(worldNormal, lightDir), 0.0);
        // Gentle diffuse wrap for foliage & natural terrain transition
        float diffuseTerm = (sssStrength > 0.05) ? max(dot(worldNormal, lightDir) * 0.72 + 0.28, 0.0) : ndotl;
        vec3 directDiffuse = albedoLinear * celestialCol * diffuseTerm * shadowVis * INV_PI * 2.35;

        // Foliage Subsurface Scattering
        vec3 sssLight = vec3(0.0);
        #ifdef FOLIAGE_SSS
            if (sssStrength > 0.05) {
                float backLit = pow(clamp(dot(-V, lightDir), 0.0, 1.0), 3.0) * 0.75 + 0.25;
                vec3 foliageTint = albedoLinear * vec3(1.16, 1.22, 0.78);
                sssLight = foliageTint * celestialCol * sssTransmission * backLit * caveSunGuard * 0.55;
            }
        #endif

        // GGX Direct Specular
        vec3 directSpec = evalGGXSpecular(worldNormal, V, lightDir, roughness, F0)
                        * celestialCol * ndotl * shadowVis * 1.05;

        // Rich Hemisphere Sky Fill + Indirect Sunlit Ground Bounce (prevents dark/black hillsides!)
        float hemiUp = worldNormal.y * 0.5 + 0.5;
        float skyMask = pow(clamp(lightmap.y, 0.0, 1.0), 1.15);

        // Sunlit ground reflects warm bounced radiance onto vertical cliff faces & undersides
        vec3 warmGroundBounce = celestialCol * vec3(0.11, 0.10, 0.085) * (1.0 - 0.35 * hemiUp)
                              + skyAmb * vec3(0.42, 0.45, 0.48);
        vec3 coolSkyTop       = skyAmb * vec3(0.86, 0.96, 1.12);
        vec3 skyFill          = mix(warmGroundBounce, coolSkyTop, hemiUp) * skyMask;

        // Natural Underground Cave Ambient
        vec3 caveAmb = vec3(0.56, 0.68, 0.88) * CAVE_BRIGHTNESS * (0.55 + 0.45 * hemiUp);
        if (nightVision > 0.01) {
            caveAmb += vec3(0.38, 0.42, 0.50) * nightVision;
        }

        vec3 puddleSpec = vec3(0.0);
        if (puddleMask > 0.02) {
            vec3 R = reflect(-V, worldNormal);
            float fresnel = 0.02 + 0.98 * pow5(1.0 - max(dot(worldNormal, V), 0.0));
            vec3 envSky = evaluateAtmosphere(R, sunDir, moonDir);
            puddleSpec = envSky * fresnel * puddleMask * 0.85;
        }

        vec3 blockLight = computeBlocklight(lightmap.x, worldPos);
        vec3 handLight  = computeHandheldLight(playerPos, worldNormal);

        totalLight = directDiffuse + sssLight + directSpec + puddleSpec
                   + albedoLinear * ((skyFill + caveAmb + ssilBounce) * combinedAO + (blockLight + handLight) * mix(0.70, 1.0, combinedAO));

    // =========================================================================
    // NETHER LIGHTING
    // =========================================================================
    #elif defined(DIMENSION_NETHER)
        float hemiUp = worldNormal.y * 0.5 + 0.5;
        vec3 netherFloorGlow = vec3(0.48, 0.17, 0.08);
        vec3 netherCeilAmb   = vec3(0.20, 0.08, 0.06);
        vec3 netherAmb = mix(netherFloorGlow, netherCeilAmb, hemiUp) * (0.48 + CAVE_BRIGHTNESS * 2.5);

        vec3 blockLight = computeBlocklight(lightmap.x, worldPos) * 1.15;
        vec3 handLight  = computeHandheldLight(playerPos, worldNormal);
        if (nightVision > 0.01) netherAmb += vec3(0.38) * nightVision;

        totalLight = albedoLinear * ((netherAmb + ssilBounce) * combinedAO + (blockLight + handLight));

    // =========================================================================
    // THE END LIGHTING
    // =========================================================================
    #elif defined(DIMENSION_END)
        vec3 endLightDir = normalize(vec3(0.38, 0.82, 0.42));
        float ndotl = max(dot(worldNormal, endLightDir), 0.0);
        vec3 endDirect = vec3(0.68, 0.58, 0.94) * 0.92 * ndotl;

        float hemiUp = worldNormal.y * 0.5 + 0.5;
        vec3 endAmb = mix(vec3(0.08, 0.06, 0.14), vec3(0.24, 0.18, 0.36), hemiUp) * (0.95 + CAVE_BRIGHTNESS * 2.5);
        vec3 endSpec = evalGGXSpecular(worldNormal, V, endLightDir, roughness, F0) * vec3(0.70, 0.58, 0.98) * ndotl * 0.65;

        vec3 blockLight = computeBlocklight(lightmap.x, worldPos);
        vec3 handLight  = computeHandheldLight(playerPos, worldNormal);
        if (nightVision > 0.01) endAmb += vec3(0.38) * nightVision;

        totalLight = albedoLinear * (endDirect * 0.72 + (endAmb + ssilBounce) * combinedAO + blockLight + handLight) + endSpec;
    #endif

    totalLight += computeEmissiveRadiance(albedoLinear, matId, emissiveMask);

    float darkFactor = clamp(blindness, 0.0, 1.0);
    if (darkFactor > 0.01) {
        float fadeDist = length(playerPos);
        totalLight *= mix(1.0, exp(-fadeDist * 0.18), darkFactor);
    }

    return max(totalLight, vec3(0.0));
}

#endif // AETHERON_SHADING_GLSL
