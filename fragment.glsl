#version 300 es
precision highp float;

//  Relativistic aberration fragment shader

uniform vec2  u_resolution;
uniform float u_beta;
uniform mat3  u_camMatrix;
uniform float u_fov;
uniform float u_time;

uniform int   u_numStars;
uniform vec3  u_stars[60];   // world-space 3D positions

uniform bool u_showGrid;

out vec4 fragColor;

#define PI  3.14159265359
#define TAU 6.28318530718

// Icosahedron vertices - 12 maximally-spread reference stars
#define ICO0  vec3( 0.0000,  0.5257,  0.8507)
#define ICO1  vec3( 0.0000, -0.5257,  0.8507)
#define ICO2  vec3( 0.0000,  0.5257, -0.8507)
#define ICO3  vec3( 0.0000, -0.5257, -0.8507)
#define ICO4  vec3( 0.5257,  0.8507,  0.0000)
#define ICO5  vec3(-0.5257,  0.8507,  0.0000)
#define ICO6  vec3( 0.5257, -0.8507,  0.0000)
#define ICO7  vec3(-0.5257, -0.8507,  0.0000)
#define ICO8  vec3( 0.8507,  0.0000,  0.5257)
#define ICO9  vec3(-0.8507,  0.0000,  0.5257)
#define ICO10 vec3( 0.8507,  0.0000, -0.5257)
#define ICO11 vec3(-0.8507,  0.0000, -0.5257)

//  1. Utility 

float hash(vec2 p) {
    p  = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

//  2. Relativistic physics

// Exact Lorentz boost of photon direction: camera frame → rest frame.
vec3 aberrateRay(vec3 d, float beta, vec3 betaHat) {
    if (beta < 1e-7) return d;
    float gamma  = 1.0 / sqrt(1.0 - beta * beta);
    float d_par  = dot(d, betaHat);
    vec3  d_perp = d - d_par * betaHat;
    float denom  = 1.0 - beta * d_par;
    return normalize(((d_par - beta) / denom) * betaHat + d_perp / (gamma * denom));
}

// D = f_obs/f_emit = 1 / [γ(1 − β d_∥)]
float dopplerFactor(float d_par, float beta, float gamma) {
    return 1.0 / (gamma * (1.0 - beta * d_par));
}

//  3. Blackbody colour

// Tanner Helland polynomial fit.  Valid ~1000–40000 K.
vec3 blackbodyRGB(float T) {
    T = clamp(T, 1000.0, 40000.0) / 100.0;
    float r, g, b;
    if (T <= 66.0) { r = 1.0; }
    else { r = clamp(329.698727446 * pow(T-60.0, -0.1332047592) / 255.0, 0.0, 1.0); }
    if (T <= 66.0) { g = clamp((99.4708025861*log(T) - 161.1195681661) / 255.0, 0.0, 1.0); }
    else           { g = clamp(288.1221695283 * pow(T-60.0, -0.0755148492) / 255.0, 0.0, 1.0); }
    if      (T >= 66.0) { b = 1.0; }
    else if (T <= 19.0) { b = 0.0; }
    else { b = clamp((138.5177312231*log(T-10.0) - 305.0447927307) / 255.0, 0.0, 1.0); }
    return vec3(r, g, b);
}

//  4. Doppler colour + beaming 

// T_obs = D × T_source  (Wien's law + λ_obs = λ/D)
// I_obs = D^4 × I_source  (relativistic beaming, exact)
vec3 dopplerColour(float T_source, float D) {
    return blackbodyRGB(T_source * D) * pow(D, 4.0);
}

vec3 dopplerColourRGB(vec3 c, float D) {
    float maxC = max(c.r, max(c.g, c.b)) + 1e-6;
    float rb = c.r/maxC, gb = c.g/maxC, bb = c.b/maxC;
    float T_est;
    if      (bb > gb && bb > rb) { T_est = 12000.0 + bb*8000.0; }
    else if (rb > gb && rb > bb) { T_est =  3000.0 + rb*1500.0; }
    else                         { T_est =  5000.0 + gb*3000.0; }
    vec3  bbCol = blackbodyRGB(T_est * D);
    float blend = clamp(abs(D-1.0)*4.0, 0.0, 1.0);
    return mix(c, bbCol, blend) * pow(D, 4.0);
}

//  5. Streak geometry 
//
//  Physical basis: relativistic aberration pulls every star toward the forward
//  pole (betaHat).  A star at rest-frame position sd has been "swept" from its
//  beta=0 position toward betaHat as speed increased.  Render this sweep as a
//  radial streak in the rest-frame sky.
//
//  streakEnd = slerp(sd, betaHat, t)  where t proportional to beta
//
//  We approximate slerp as normalise(mix(sd, betaHat, t)) - valid for smooth
//  geometry since both inputs are unit vectors.
//
//  The query ray dir must lie within angularWidth of the chord sd->streakEnd
//  for the pixel to be lit.

float streakBrightness(vec3 dir, vec3 sd, float beta, float angularWidth) {
    if (beta < 1e-4) {
        // No streak at rest - just a point
        float ang = acos(clamp(dot(dir, sd), -1.0, 1.0));
        return smoothstep(angularWidth, 0.0, ang);
    }

    // Streak tip: how far toward forward pole the star has been swept
    float streakT = clamp(beta * 3.5, 0.0, 0.995);
    vec3  fwd     = vec3(0.0, 0.0, 1.0);
    vec3  tip     = normalize(mix(sd, fwd, streakT));

    // Distance from dir to the line segment sd -> tip (chord on unit sphere)
    vec3  chord   = tip - sd;
    float chord2  = dot(chord, chord);
    float t       = (chord2 < 1e-8) ? 0.0 : clamp(dot(dir - sd, chord) / chord2, 0.0, 1.0);
    vec3  closest = normalize(sd + t * chord);

    float ang     = acos(clamp(dot(dir, closest), -1.0, 1.0));

    // Brightness: full at the base (star position), fades toward tip
    float fade = 1.0 - t * 0.6;
    return smoothstep(angularWidth, 0.0, ang) * fade;
}

//  6. Sky scene 

vec3 milkyWay(vec3 dir) {
    vec3  galN = normalize(vec3(0.0, 0.87, 0.49));
    float galB = abs(dot(dir, galN));
    float band = exp(-galB * galB * 18.0);
    float lon  = atan(dir.z, dir.x);
    float vary = 0.5 + 0.3*sin(lon*2.3+0.7) + 0.2*sin(lon*5.1-1.2);
    return vec3(0.06, 0.08, 0.16) * band * vary;
}

float celestialGrid(vec3 dir) {
    float lon  = atan(dir.z, dir.x);
    float lat  = asin(clamp(dir.y, -0.9999, 0.9999));
    float s    = PI / 6.0;
    float lonD = abs(fract(lon/s + 0.5) - 0.5);
    float latD = abs(fract(lat/s + 0.5) - 0.5);
    return smoothstep(0.040, 0.0, min(lonD, latD)) * 0.10;
}

vec3 brightStarDir(int i) {
    if (i==0) return ICO0; if (i==1) return ICO1;
    if (i==2) return ICO2; if (i==3) return ICO3;
    if (i==4) return ICO4; if (i==5) return ICO5;
    if (i==6) return ICO6; if (i==7) return ICO7;
    if (i==8) return ICO8; if (i==9) return ICO9;
    if (i==10) return ICO10;
    return ICO11;
}

float brightStarTemp(int i) {
    if (i==0||i==1) return 20000.0;
    if (i==2||i==3) return  4500.0;
    if (i==4||i==5) return  5800.0;
    if (i==6||i==7) return  3200.0;
    if (i==8||i==9) return  9500.0;
    return 7200.0;
}

// dir: rest-frame ray.  Render 12 reference stars with streaks.
vec3 referenceStars(vec3 dir, float beta, float D) {
    vec3 col = vec3(0.0);
    for (int i = 0; i < 12; i++) {
        float br = streakBrightness(dir, brightStarDir(i), beta, 0.018);
        if (br > 0.001) {
            col += br * 3.0 * dopplerColour(brightStarTemp(i), D);
        }
    }
    return col;
}

// Procedural background star field with streaks.
vec3 starField(vec3 dir, float beta, float D) {
    vec3  col = vec3(0.0);
    float u   = atan(dir.z, dir.x) / TAU + 0.5;
    float v   = asin(clamp(dir.y, -0.9999, 0.9999)) / PI + 0.5;

    for (int layer = 0; layer < 2; layer++) {
        float fL     = float(layer);
        float scale  = (layer == 0) ? 130.0 : 60.0;
        float thresh = (layer == 0) ? 0.960 : 0.925;
        float sz     = (layer == 0) ? 0.0025 : 0.007;
        vec2  cell   = floor(vec2(u, v) * scale);

        for (int di = -1; di <= 1; di++) {
        for (int dj = -1; dj <= 1; dj++) {
            vec2  nc   = cell + vec2(float(di), float(dj));
            vec2  seed = nc + fL * vec2(137.0, 241.0);
            if (hash(seed) > thresh) {
                float h2  = hash(seed + vec2(47.5, 91.2));
                float h3  = hash(seed + vec2(17.3, 43.8));
                vec2  sUV = (nc + vec2(h2, h3)) / scale;
                float sT  = (sUV.x - 0.5) * TAU;
                float sP  = (sUV.y - 0.5) * PI;
                vec3  sd  = vec3(cos(sP)*cos(sT), sin(sP), cos(sP)*sin(sT));

                float sz2 = sz * (1.0 + hash(seed + vec2(200.0)));
                float br  = streakBrightness(dir, sd, beta, sz2);
                if (br > 0.001) {
                    float t  = hash(seed + vec2(333.0, 777.0));
                    float Ts = exp(log(3000.0) + t * log(10.0));
                    float mg = 0.4 + hash(seed + vec2(500.0)) * 1.4;
                    col += br * mg * dopplerColour(Ts, D);
                }
            }
        }
        }
    }
    return col;
}

//  7. Nearby 3D stars 
//
//  Stars are actual 3D world-space positions.  Project from camera, aberrate,
//  render as streaks.  These create the "flying through space" sensation.
//
//  Since the camera travels along world +Z and betaHat = (0,0,1), the
//  direction to a nearby star is already in the camera frame (don't rotate
//  the velocity vector). Compute the streak in camera-frame world space,
//  then check against d_world (the pre-aberration camera-frame ray).

vec3 nearbyStars(vec3 d_world, float beta, float D) {
    vec3  col    = vec3(0.0);
    vec3  fwd    = vec3(0.0, 0.0, 1.0);
    float streakT = clamp(beta * 4.0, 0.0, 0.998);

    for (int i = 0; i < 60; i++) {
        if (i >= u_numStars) break;

        // Direction to star from camera (world space = camera frame for translation)
        vec3  toStar = u_stars[i];
        float dist   = length(toStar);
        if (dist < 0.5) continue;
        vec3 sd = toStar / dist;

        // Only show stars in the forward hemisphere (behind camera look dull)
        // (still rendered, just naturally dim via beaming)
        float d_par = sd.z;
        float gam   = 1.0 / sqrt(max(1.0 - beta*beta, 1e-10));
        float Dstar = dopplerFactor(d_par, beta, gam);

        // Streak: in camera frame, star sweeps from sd toward fwd as beta increases.
        // Width scales with proximity: nearer = wider streak.
        float nearFactor = clamp(30.0 / dist, 0.2, 1.0);
        float baseWidth  = 0.012 * nearFactor;

        // Build streak tip in camera frame
        vec3  tip   = normalize(mix(sd, fwd, streakT));
        vec3  chord = tip - sd;
        float chord2= dot(chord, chord);
        float t     = (chord2 < 1e-8) ? 0.0 : clamp(dot(d_world - sd, chord)/chord2, 0.0, 1.0);
        vec3  cls   = normalize(sd + t * chord);
        float ang   = acos(clamp(dot(d_world, cls), -1.0, 1.0));
        float fade  = 1.0 - t * 0.5;
        float br    = smoothstep(baseWidth, 0.0, ang) * fade;

        if (br > 0.001) {
            // Brightness also falls off with distance (inverse square, loosely)
            float distFade = clamp(10.0 / (dist * dist * 0.05 + 1.0), 0.0, 1.0);
            float Ts = 6000.0 + hash(vec2(float(i)*0.317, 0.0)) * 8000.0;
            col += br * distFade * 4.0 * dopplerColour(Ts, Dstar);
        }
    }
    return col;
}

//  8. Main

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / u_resolution.y;

    // World-space ray direction (camera frame)
    float fLen  = 1.0 / tan(u_fov * 0.5);
    vec3  d_world = normalize(
        uv.x * u_camMatrix[0]
      + uv.y * u_camMatrix[1]
      + fLen * u_camMatrix[2]
    );

    // Relativistic kinematics - flight direction is always world +Z
    const vec3 betaHat = vec3(0.0, 0.0, 1.0);
    float beta  = u_beta;
    float gamma = 1.0 / sqrt(max(1.0 - beta*beta, 1e-10));
    float d_par = d_world.z;
    float D     = dopplerFactor(d_par, beta, gamma);

    // Aberrate to rest frame for background sky lookup
    vec3 dR = aberrateRay(d_world, beta, betaHat);

    // Accumulate scene
    vec3 col = vec3(0.0);
    col += milkyWay(dR);
    col += starField(dR, beta, D);
    col += referenceStars(dR, beta, D);
    if (u_showGrid)
        col += celestialGrid(dR) * dopplerColourRGB(vec3(0.25, 0.45, 0.75), D);

    // Nearby 3D stars - checked against camera-frame ray d_world (not aberrated)
    // because their positions are in camera/world space, not rest-frame sky
    col += nearbyStars(d_world, beta, D);

    // Reinhard tone-map + sRGB gamma
    col = col / (1.0 + col);
    col = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2));

    fragColor = vec4(col, 1.0);
}
