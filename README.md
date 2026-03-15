# LightCone

**Real-time relativistic aberration in a WebGL2 fragment shader.**

As the camera flies through a star field at a fraction of the speed of light, the visual scene distorts due to relativistic physics: stars bunch toward your heading, blueshift forward and redshift behind, and their apparent brightness surges from relativistic beaming.

## Physics

All effects are derived from the Lorentz transformation of the photon 4-momentum - no classical approximations in the core math.

| Effect | Formula | Status |
|---|---|---|
| Relativistic aberration | $ d^\prime_\parallel = \frac{d_{\parallel} - \beta}{1 - \beta d_\parallel}$ | Exact |
| Relativistic Doppler | $D = \frac{1}{\gamma(1 - \beta d_\parallel)}$ | Exact |
| Relativistic beaming | $I_{\text{obs}} = D^4 I_{\text{src}}$ | Exact |
| Doppler colour shift | Channel redistribution scaled $\times 80$ | Exaggerated for $\text{visibility}^{1}$ |

$^{1}$ The mathematical Doppler factor $D$ is exact.  The *visual colour mapping* is scaled up by $\times 80$ so the $\sim 1\%$ frequency shift at $\beta = 0.01c$ is perceptible on screen.  See `MATH.md` §9 and `DOPPLER_VIS_SCALE` in `fragment.glsl`.

## Controls

| Input | Action |
|---|---|
| Space | Accelerate |
| WASD / Arrow keys | Look |

## Running locally

Browsers block `fetch()` for `file://` URLs, so you need a local HTTP server.  Pick whichever is most convenient:

### Python

```bash
cd lightcone
python3 -m http.server 8080
```

Open [http://localhost:8080](http://localhost:8080).

### Node.js

```bash
npx serve lightcone
# or
npx http-server lightcone -p 8080
```

### VS Code

Install the **Live Server** extension, right-click `index.html`, choose *Open with Live Server*.

### Any static file server

Point its root at the `relativistic-visualization/` directory and open `index.html`.

## File structure

```
relativistic-visualization/
├── index.html      - canvas + HUD markup
├── style.css       - dark space aesthetic
├── main.js         - WebGL2 init, input, camera, animation loop
├── vertex.glsl     - passthrough vertex shader (full-screen quad)
├── fragment.glsl   - aberration, Doppler, beaming, star field
├── MATH.md         - complete mathematical derivation
└── README.md       - this file
```

**Dependencies:** WebGL2, JavaScript, no build step.

## Technical notes

- **Velocity direction** is always world **+Z**, regardless of look direction.  Rotating the camera lets you explore different parts of the aberrated sky - the rotation matrix and aberration are composed in the correct order (rotation -> world space -> aberration).
