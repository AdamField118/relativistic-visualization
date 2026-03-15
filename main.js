//  main.js

const ACCEL_RATE_MIN  = 0.15;   // c s^{-1} - acceleration at start of hold
const ACCEL_RATE_MAX  = 1.50;   // c s^{-1} - peak acceleration after ramp
const ACCEL_RAMP_TIME = 3.0;    // seconds to reach peak acceleration rate
const BETA_MAX        = 0.9999; // absolute speed ceiling
// Speed holds when key is released - no deceleration.

const FOV_Y          = Math.PI / 2.5;
const KEY_TURN_SPEED = 1.4;     // rad s^{-1}

// 3D star pool
// Stars are fixed world-space points around the camera origin.
// Stars that fall behind (worldZ < -CULL_Z) respawn ahead (worldZ > 0).

const NUM_STARS  = 60;
const SPREAD_XY  = 20.0;   // half-width in X and Y
const SPAWN_ZMAX = 80.0;   // max distance ahead to spawn
const CULL_Z     = 5.0;    // respawn when z falls below -CULL_Z

const starPos = new Float32Array(NUM_STARS * 3);  // [x,y,z, ...]

function spawnStar(i) {
    starPos[i*3+0] = (Math.random()*2 - 1) * SPREAD_XY;
    starPos[i*3+1] = (Math.random()*2 - 1) * SPREAD_XY;
    starPos[i*3+2] = Math.random() * SPAWN_ZMAX + 2.0;
}

function initStars() {
    for (let i = 0; i < NUM_STARS; i++) spawnStar(i);
}

// Called each frame: respawn any star that has been "passed" (z gone negative).
function updateStars() {
    for (let i = 0; i < NUM_STARS; i++) {
        if (starPos[i*3+2] < -CULL_Z) spawnStar(i);
    }
}

// State

let canvas, gl, program;
let positionBuffer;
const uLoc = {};

let beta          = 0.0;
let yaw           = 0.0;
let pitch         = 0.0;
let accelerating  = false;
let accelHeldTime = 0.0;
let decelerating  = false;
let decelHeldTime = 0.0;
let lastTime      = 0;

const keys = new Set();

// Boot

async function init() {
    canvas = document.getElementById('glCanvas');
    gl = canvas.getContext('webgl2');
    if (!gl) {
        document.body.innerHTML =
            '<p style="color:#f88;font-family:monospace;padding:2rem">WebGL 2 required.</p>';
        return;
    }

    let vertSrc, fragSrc;
    try {
        [vertSrc, fragSrc] = await Promise.all([
            fetch('vertex.glsl').then(r => { if (!r.ok) throw r; return r.text(); }),
            fetch('fragment.glsl').then(r => { if (!r.ok) throw r; return r.text(); }),
        ]);
    } catch (e) {
        alert('Could not load shaders. Run a local server (see README).');
        return;
    }

    const vert = compileShader(gl.VERTEX_SHADER,   vertSrc,  'vertex');
    const frag = compileShader(gl.FRAGMENT_SHADER, fragSrc, 'fragment');
    if (!vert || !frag) return;

    program = gl.createProgram();
    gl.attachShader(program, vert);
    gl.attachShader(program, frag);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        console.error('Link error:', gl.getProgramInfoLog(program));
        return;
    }

    const quad = new Float32Array([-1,-1, 1,-1, -1,1, -1,1, 1,-1, 1,1]);
    positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, quad, gl.STATIC_DRAW);

    for (const name of ['u_resolution','u_beta','u_camMatrix','u_fov','u_time','u_numStars','u_stars'])
        uLoc[name] = gl.getUniformLocation(program, name);

    initStars();
    setupInput();
    window.addEventListener('resize', onResize);
    onResize();
    requestAnimationFrame(render);
}

function compileShader(type, src, label) {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        console.error(`[${label}] compile error:`, gl.getShaderInfoLog(s));
        return null;
    }
    return s;
}

// Input

function setupInput() {
    document.addEventListener('keydown', e => {
        keys.add(e.code);
        if (e.code === 'Space') {
            e.preventDefault();
            if (e.shiftKey) { startDecel(); } else { startAccel(); }
        }
    });
    document.addEventListener('keyup', e => {
        keys.delete(e.code);
        if (e.code === 'Space') { stopAccel(); stopDecel(); }
    });
}

function startAccel() { accelerating = true; }
function stopAccel()  { accelerating = false; accelHeldTime = 0.0; }
function startDecel() { decelerating = true; }
function stopDecel()  { decelerating = false; decelHeldTime = 0.0; }

function clampPitch() {
    pitch = Math.max(-Math.PI/2 + 0.01, Math.min(Math.PI/2 - 0.01, pitch));
}

function onResize() {
    canvas.width  = window.innerWidth;
    canvas.height = window.innerHeight;
    gl.viewport(0, 0, canvas.width, canvas.height);
}

// Camera matrix

function buildCamMatrix() {
    const cy = Math.cos(yaw),   sy = Math.sin(yaw);
    const cp = Math.cos(pitch), sp = Math.sin(pitch);
    const fx = sy*cp, fy = sp, fz = cy*cp;
    let rx = fz, ry = 0, rz = -fx;
    const rlen = Math.hypot(rx, ry, rz) || 1;
    rx /= rlen; ry /= rlen; rz /= rlen;
    const ux = fy*rz - fz*ry;
    const uy = fz*rx - fx*rz;
    const uz = fx*ry - fy*rx;
    return new Float32Array([rx,ry,rz, ux,uy,uz, fx,fy,fz]);
}

// Render loop

function render(timestamp) {
    const t  = timestamp / 1000;
    const dt = Math.min(t - lastTime, 0.05);
    lastTime = t;

    // look left / look right
    const turn = KEY_TURN_SPEED * dt;
    if (keys.has('ArrowLeft')  || keys.has('KeyA')) yaw   -= turn;
    if (keys.has('ArrowRight') || keys.has('KeyD')) yaw   += turn;
    if (keys.has('ArrowUp')    || keys.has('KeyW')) pitch += turn;
    if (keys.has('ArrowDown')  || keys.has('KeyS')) pitch -= turn;
    clampPitch();

    // Accelerate
    if (accelerating) {
        accelHeldTime += dt;
        const frac      = Math.min(accelHeldTime / ACCEL_RAMP_TIME, 1.0);
        const accelRate = ACCEL_RATE_MIN + frac * (ACCEL_RATE_MAX - ACCEL_RATE_MIN);
        beta = Math.min(beta + accelRate * dt, BETA_MAX);
    }
    if (decelerating) {
        decelHeldTime += dt;
        const frac      = Math.min(decelHeldTime / ACCEL_RAMP_TIME, 1.0);
        const accelRate = ACCEL_RATE_MIN + frac * (ACCEL_RATE_MAX - ACCEL_RATE_MIN);
        beta = Math.max(beta - accelRate * dt, 0.0);
    }

    updateStars();

    const gamma = 1.0 / Math.sqrt(Math.max(1 - beta*beta, 1e-10));

    gl.useProgram(program);
    const posLoc = gl.getAttribLocation(program, 'a_position');
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.enableVertexAttribArray(posLoc);
    gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

    gl.uniform2f(uLoc.u_resolution, canvas.width, canvas.height);
    gl.uniform1f(uLoc.u_beta, beta);
    gl.uniformMatrix3fv(uLoc.u_camMatrix, false, buildCamMatrix());
    gl.uniform1f(uLoc.u_fov, FOV_Y);
    gl.uniform1f(uLoc.u_time, t);
    gl.uniform1i(uLoc.u_numStars, NUM_STARS);
    gl.uniform3fv(uLoc.u_stars, starPos);

    gl.drawArrays(gl.TRIANGLES, 0, 6);

    updateHUD(beta, gamma);
    requestAnimationFrame(render);
}

// HUD 

function updateHUD(b, g) {
    const pct  = b / BETA_MAX * 100;
    const Dfwd = 1 / (g * (1 - b));
    const Dbwd = 1 / (g * (1 + b));
    document.getElementById('speed-value').textContent = b.toFixed(5) + ' c';
    document.getElementById('gamma-value').textContent = 'gamma = ' + g.toFixed(5);
    document.getElementById('doppler-fwd').textContent = Dfwd.toFixed(5);
    document.getElementById('doppler-bwd').textContent = Dbwd.toFixed(5);
    document.getElementById('speed-bar').style.width = pct.toFixed(1) + '%';
    const hue = 200 - pct * 1.6;
    document.getElementById('speed-bar').style.background = `hsl(${hue},80%,55%)`;
}

init();