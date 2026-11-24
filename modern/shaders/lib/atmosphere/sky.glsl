#ifndef AETHERON_SKY_GLSL
#define AETHERON_SKY_GLSL

// ==============================================================================
// AETHERON SHADERS — Complete Sky Dome, Sun, Phase-Shaded Moon, Stars & Dimensions
// ==============================================================================

// Procedural solar disc with physical limb darkening & atmospheric aureole
vec3 renderSunDisc(vec3 viewDir, vec3 sunDir) {
    float cosTheta = dot(viewDir, sunDir);
    const float sunAngularCos = 0.99945; // ~1.9 degrees visual radius (cinematic scale)

    vec3 sunTrans = computeSunTransmittance(sunDir.y);
    float horizonVis = smoothstep(-0.04, 0.03, sunDir.y);
    float weatherFade = 1.0 - getRainMix() * 0.92;

    // Soft solar corona / aureole
    float corona = pow(max(cosTheta, 0.0), 420.0) * 1.4 + pow(max(cosTheta, 0.0), 48.0) * 0.16;

    // Sharp limb-darkened solar photosphere
    float discEdge = smoothstep(sunAngularCos - 0.00018, sunAngularCos + 0.00008, cosTheta);
    float rNorm = clamp((1.0 - cosTheta) / max(1.0 - sunAngularCos, 1e-6), 0.0, 1.0);
    float mu = sqrt(max(1.0 - rNorm, 0.0));
    float limbDarkening = mix(0.45, 1.0, pow(mu, 0.55));

    vec3 discColor = vec3(1.05, 0.98, 0.90) * sunTrans * (discEdge * limbDarkening * 28.0 + corona * 2.2);
    return discColor * horizonVis * weatherFade * SUN_INTENSITY;
}

// Procedural shaded Lunar Disc with lunar maria, craters & authentic moonPhase lighting
vec3 renderMoonDisc(vec3 viewDir, vec3 moonDir) {
    float cosTheta = dot(viewDir, moonDir);
    float moonRad = 0.026 * MOON_SIZE;
    float moonCos = cos(moonRad);

    float weatherFade = 1.0 - getRainMix() * 0.90;
    float horizonVis  = smoothstep(-0.04, 0.05, moonDir.y);

    // Lunar atmospheric glow halo
    float phaseFullness = mix(0.25, 1.0, abs(float(moonPhase) - 4.0) / 4.0);
    float halo = pow(max(cosTheta, 0.0), 220.0) * 0.35 * phaseFullness;
    vec3 haloColor = vec3(0.55, 0.68, 0.95) * halo * horizonVis * weatherFade;

    if (cosTheta < moonCos - 0.002) {
        return haloColor;
    }

    // Build local tangent frame on lunar disc
    vec3 upRef = abs(moonDir.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 rightAxis = normalize(cross(upRef, moonDir));
    vec3 upAxis    = normalize(cross(moonDir, rightAxis));

    vec2 localPos = vec2(dot(viewDir, rightAxis), dot(viewDir, upAxis)) / max(moonRad, 1e-4);
    float r2 = dot(localPos, localPos);
    if (r2 >= 1.0) {
        return haloColor;
    }

    // Spherical normal on moon surface
    vec3 sphereN = vec3(localPos.x, localPos.y, sqrt(max(1.0 - r2, 0.0)));
    float edgeAA = smoothstep(1.0, 0.93, r2);

    // Procedural lunar maria & highland albedo
    float maria = fbm2D(localPos * 3.2 + vec2(1.7, -0.9), 4);
    float craters = fbm2D(localPos * 9.5 + vec2(4.2, 2.3), 3);
    float albedo = mix(0.42, 0.92, smoothstep(0.36, 0.66, maria)) * mix(0.84, 1.06, craters);

    // Authentic lunar phase illumination direction (0 = Full, 4 = New)
    float phaseAngle = float(moonPhase) * (TAU / 8.0);
    vec3 phaseLightDir = normalize(vec3(sin(phaseAngle), 0.12, cos(phaseAngle)));
    float ndotl = smoothstep(-0.08, 0.25, dot(sphereN, phaseLightDir));

    // Subtle Earthshine on the unlit lunar crescent
    float earthshine = 0.035;
    vec3 moonLit = vec3(0.82, 0.88, 1.00) * albedo * (ndotl * 2.4 + earthshine);

    return haloColor + moonLit * edgeAA * horizonVis * weatherFade * MOON_INTENSITY;
}

// Multi-layer twinkling starfield & subtle Milky Way galactic band
vec3 renderStars(vec3 viewDir, vec3 sunDir) {
    if (STAR_BRIGHTNESS <= 0.001) return vec3(0.0);

    float nightVis = smoothstep(0.08, -0.14, sunDir.y);
    float weatherVis = 1.0 - getRainMix() * 0.95;
    float horizonFade = smoothstep(0.0, 0.22, viewDir.y);
    float visibility = nightVis * weatherVis * horizonFade;
    if (visibility <= 0.001) return vec3(0.0);

    // Slowly rotate celestial sphere with world time
    float rot = sunAngle * TAU;
    float cr = cos(rot);
    float sr = sin(rot);
    vec3 skyDir = normalize(vec3(
        viewDir.x * cr - viewDir.y * sr,
        viewDir.x * sr + viewDir.y * cr,
        viewDir.z
    ));

    // Cube-face spherical projection for uniform star density without polar pinching
    vec3 absDir = abs(skyDir);
    vec2 starUV;
    if (absDir.x >= absDir.y && absDir.x >= absDir.z) {
        starUV = skyDir.yz / absDir.x;
    } else if (absDir.y >= absDir.x && absDir.y >= absDir.z) {
        starUV = skyDir.xz / absDir.y;
    } else {
        starUV = skyDir.xy / absDir.z;
    }

    vec3 stars = vec3(0.0);

    // Layer 1: Primary bright stars with realistic spectral colors (O/B/A/F/G/K/M)
    vec2 grid1 = starUV * 95.0;
    vec2 id1 = floor(grid1);
    vec2 f1  = fract(grid1) - 0.5;
    vec2 rnd1 = hash22(id1);
    vec2 offset1 = (rnd1 - 0.5) * 0.65;
    float d1 = length(f1 - offset1);
    float starChance1 = hash12(id1 + 19.3);
    if (starChance1 > 0.968) {
        float mag = smoothstep(0.968, 1.0, starChance1);
        float twinkle = 0.78 + 0.22 * sin(frameTimeCounter * (2.2 + rnd1.x * 3.5) + rnd1.y * TAU);
        float core = exp(-d1 * d1 * 95.0) * (0.4 + 1.8 * mag) * twinkle;
        // Spectral star tint: cool blue-white to warm amber
        vec3 starTint = mix(vec3(0.72, 0.84, 1.0), vec3(1.0, 0.86, 0.68), hash12(id1 + 73.1));
        stars += starTint * core * 1.45;
    }

    // Layer 2: Finer background star dust
    vec2 grid2 = starUV * 210.0 + 37.0;
    vec2 id2 = floor(grid2);
    vec2 f2  = fract(grid2) - 0.5;
    float d2 = length(f2 - (hash22(id2) - 0.5) * 0.6);
    float starChance2 = hash12(id2 + 91.7);
    if (starChance2 > 0.955) {
        float core2 = exp(-d2 * d2 * 130.0) * smoothstep(0.955, 1.0, starChance2);
        stars += vec3(0.80, 0.88, 1.0) * core2 * 0.55;
    }

    // Subtle Milky Way galactic band tilted across the celestial sphere
    float galacticPlane = abs(dot(skyDir, normalize(vec3(0.42, 0.68, 0.60))));
    float bandMask = exp(-galacticPlane * galacticPlane * 16.0);
    float dustLanes = fbm2D(starUV * 4.5 + vec2(3.1, 1.7), 4);
    float dustRift  = smoothstep(0.38, 0.68, fbm2D(starUV * 8.0 - vec2(2.4, 5.1), 3));
    vec3 milkyWay = mix(vec3(0.18, 0.24, 0.38), vec3(0.32, 0.28, 0.42), dustLanes)
                  * bandMask * (0.55 + 0.45 * dustLanes) * (1.0 - 0.55 * dustRift) * 0.045;

    return (stars + milkyWay) * visibility * STAR_BRIGHTNESS;
}

// Complete Overworld Sky (Atmosphere + Sun + Moon + Stars)
vec3 computeOverworldSky(vec3 viewDir, vec3 sunDir, vec3 moonDir, bool includeCelestials) {
    vec3 sky = evaluateAtmosphere(viewDir, sunDir, moonDir);
    if (includeCelestials) {
        sky += renderSunDisc(viewDir, sunDir);
        sky += renderMoonDisc(viewDir, moonDir);
        sky += renderStars(viewDir, sunDir);
    }
    return sky;
}

// Dedicated Nether Atmospheric Backdrop
vec3 computeNetherSky(vec3 viewDir) {
    float up = clamp(viewDir.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 baseFog = srgbToLinear(max(fogColor, vec3(0.06, 0.02, 0.015)));
    vec3 deepCrimson = mix(vec3(0.08, 0.018, 0.012), baseFog * 0.85, 0.65);
    vec3 warmHorizon = mix(vec3(0.26, 0.065, 0.028), baseFog * 1.45, 0.55);
    float swirl = fbm2D(viewDir.xz / (abs(viewDir.y) + 0.45) * 1.6 + vec2(frameTimeCounter * 0.015), 3);
    return mix(warmHorizon, deepCrimson, abs(viewDir.y)) * (0.85 + 0.30 * swirl);
}

// Dedicated End Dimension Cosmic Sky (Ethereal Violet Nebula + Swirling Aurora Ring + Stars)
vec3 computeEndSky(vec3 viewDir) {
    vec3 dir = normalize(viewDir);
    float up = abs(dir.y);

    // Deep obsidian-violet void
    vec3 zenith  = vec3(0.010, 0.007, 0.022);
    vec3 horizon = vec3(0.045, 0.026, 0.082);
    vec3 sky = mix(horizon, zenith, pow(up, 0.65));

    // Swirling cosmic nebula ring near the End equatorial plane
    float angle = atan(dir.z, dir.x);
    vec2 nebUV = vec2(angle * 1.8 + frameTimeCounter * 0.012, dir.y * 3.5);
    float n1 = fbm2D(nebUV * 1.4, 4);
    float n2 = fbm2D(nebUV * 3.0 + vec2(n1 * 1.5, -frameTimeCounter * 0.01), 3);
    float ringMask = exp(-sqr(dir.y - 0.14 * sin(angle * 2.0 + 0.7)) * 18.0);
    vec3 nebColor = mix(vec3(0.24, 0.11, 0.42), vec3(0.14, 0.34, 0.46), n2);
    sky += nebColor * ringMask * n1 * 0.55;

    // Distant pale lavender End vortex at zenith
    float vortexDist = length(dir.xz) / max(dir.y + 0.35, 0.15);
    if (dir.y > 0.0) {
        float vortexAngle = angle + vortexDist * 2.2 - frameTimeCounter * 0.05;
        float spiral = fbm2D(vec2(cos(vortexAngle), sin(vortexAngle)) * vortexDist * 1.5, 3);
        float vortexGlow = exp(-vortexDist * 1.6) * (0.6 + 0.6 * spiral);
        sky += vec3(0.32, 0.18, 0.55) * vortexGlow * 0.40;
    }

    // Fine cosmic End stars
    vec2 sGrid = vec2(angle * 32.0, dir.y * 55.0);
    vec2 sId = floor(sGrid);
    float sRnd = hash12(sId + 5.7);
    if (sRnd > 0.96) {
        float sd = length(fract(sGrid) - 0.5 - (hash22(sId) - 0.5) * 0.5);
        float spark = exp(-sd * sd * 110.0) * smoothstep(0.96, 1.0, sRnd);
        sky += mix(vec3(0.75, 0.65, 1.0), vec3(0.65, 0.92, 1.0), hash12(sId + 22.1)) * spark * 0.85;
    }

    return sky;
}

#endif // AETHERON_SKY_GLSL
