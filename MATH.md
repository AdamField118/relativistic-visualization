# Mathematical Derivation

## 1. Foundations: Minkowski spacetime and 4-vectors

Special relativity is the statement that the **spacetime interval**

$$ds^2 = -c^2 dt^2 + dx^2 + dy^2 + dz^2$$

is invariant under all inertial coordinate changes.  We use the metric signature $(-,+,+,+)$ and natural units $c = 1$ throughout this document (restore $c$ by dimensional analysis at the end).

A **4-vector** $A^\mu = (A^0, A^1, A^2, A^3)$ transforms under a Lorentz boost with velocity $\beta = v/c$ along the $z$-axis as

$$A^{0\prime} = \gamma(A^0 - \beta A^3), \qquad A^{3\prime} = \gamma(A^3 - \beta A^0),$$
$$A^{1\prime} = A^1, \qquad A^{2\prime} = A^2,$$

where $\gamma = (1-\beta^2)^{-1/2}$ is the Lorentz factor.  This is the **forward boost** (primed frame moves in $+z$ relative to unprimed).

For a boost in an arbitrary direction $\hat{\boldsymbol{\beta}}$, decompose any 4-vector into components parallel and perpendicular to $\hat{\boldsymbol{\beta}}$:

$$A^{0\prime} = \gamma(A^0 - \boldsymbol{\beta}\cdot\mathbf{A}), \qquad \mathbf{A}^{\prime}_\parallel = \gamma(\mathbf{A}_\parallel - \beta A^0\,\hat{\boldsymbol{\beta}}), \qquad \mathbf{A}^{\prime}_\perp = \mathbf{A}_\perp.$$

## 2. Photon 4-momentum

A photon with angular frequency $\omega$ travelling in direction $\hat{\mathbf{n}}$ (unit vector *from source toward observer*) carries 4-momentum

$$k^\mu = \frac{\omega}{c}\bigl(1,\, \hat{\mathbf{n}}\bigr).$$

The null condition $k^\mu k_\mu = 0$ is automatically satisfied.  The measured frequency by an observer with 4-velocity $u^\mu$ is

$$\omega_{\text{obs}} = -k_\mu u^\mu \quad \text{(restore sign with metric signature)}.$$

This single scalar invariant encodes both the **Doppler effect** and **aberration**.

## 3. Relativistic Aberration (exact)

### Setup

*Rest frame* $S$: the frame of the star field (inertial, stars approximately at rest).  
*Camera frame* $S'$: the frame of the moving camera, with velocity $\boldsymbol{v} = \beta c\,\hat{\boldsymbol{\beta}}$ relative to $S$.

We observe a photon arriving from rest-frame direction $\hat{\mathbf{d}}_S$ (pointing *away from* the source, i.e., the ray direction cast from the camera into the scene).  We want the corresponding camera-frame direction $\hat{\mathbf{d}}_{S'}$ - this is what gets mapped to a screen pixel.

Equivalently, given a camera-frame ray $\hat{\mathbf{d}}_{S'}$, we want the rest-frame direction $\hat{\mathbf{d}}_S$ to look up in the star catalogue.

### Derivation

The photon 4-momentum in the camera frame is

$$k^{\prime\mu} = \omega'\bigl(1,\, \hat{\mathbf{d}}_{S'}\bigr).$$

Apply the **inverse boost** (camera → rest, i.e., rest frame moves at $-\boldsymbol{v}$ relative to camera):

$$k^0_S = \gamma\bigl(k^{0\prime} + \beta\, k^{\prime}_\parallel\bigr) = \gamma\,\omega'\bigl(1 + \beta\,d'_\parallel\bigr),$$

$$k^S_\parallel = \gamma\bigl(k^{\prime}_\parallel + \beta\, k^{0\prime}\bigr) = \gamma\,\omega'\bigl(d'_\parallel + \beta\bigr),$$

$$\mathbf{k}^S_\perp = \mathbf{k}^{\prime}_\perp = \omega'\,\mathbf{d}'_\perp,$$

where $d'_\parallel = \hat{\mathbf{d}}_{S'}\cdot\hat{\boldsymbol{\beta}}$.

The rest-frame ray direction is $\hat{\mathbf{d}}_S = \mathbf{k}_S / k^0_S$:

$$\boxed{
d_{S,\parallel} = \frac{d'_\parallel + \beta}{1 + \beta\,d'_\parallel}, \qquad
\mathbf{d}_{S,\perp} = \frac{\mathbf{d}'_\perp}{\gamma\,(1 + \beta\,d'_\parallel)}
}$$

followed by normalisation $\hat{\mathbf{d}}_S = \mathbf{d}_S / |\mathbf{d}_S|$.

This is the exact formula used in `fragment.glsl :: aberrateRay()`.

### Implementation note (camera vs. world frame)

In this simulator the camera *flies* in world $+Z$ but can *look* in any direction.  The velocity 4-vector is always $\hat{\boldsymbol{\beta}} = \hat{z}$ in world space.  The camera rotation matrix $M$ maps camera-space ray coordinates to world space:

$$\hat{\mathbf{d}}_{\text{world}} = M\,\hat{\mathbf{d}}_{\text{screen}}.$$

We then apply the aberration formula entirely in world space with $\hat{\boldsymbol{\beta}} = \hat{z}$.  This is equivalent to what the user suggested: *multiply by the rotation matrix of the plane in the fragment shader* - the rotation is folded into the construction of $\hat{\mathbf{d}}_{\text{world}}$ before aberration is applied.

## 4. Relativistic Doppler Effect (exact)

The observed-to-emitted frequency ratio follows from the invariant $k_\mu u^\mu$:

$$\omega_{S'} = -k_\mu u^\mu_{S'}.$$

The camera 4-velocity in the rest frame is $u^\mu_{S} = \gamma(1, \boldsymbol{\beta})$.  The photon arrives from direction $\hat{\mathbf{d}}_S$ (outward ray), so in the rest frame $k^\mu_S = \omega_S(1, \hat{\mathbf{d}}_S)$ and

$$\omega_{S'} = \omega_S\,\gamma\bigl(1 + \boldsymbol{\beta}\cdot\hat{\mathbf{d}}_S\bigr) = \omega_S\,\gamma(1 + \beta\,d_{S,\parallel}).$$

Substituting $d_{S,\parallel}$ from §3:

$$D \equiv \frac{\omega_{S'}}{\omega_S}
= \gamma\!\left(1 + \beta\cdot\frac{d'_\parallel + \beta}{1 + \beta\,d'_\parallel}\right)
= \gamma \cdot \frac{1 - \beta^2}{1 - \beta\,d'_\parallel}
= \frac{1}{\gamma(1 - \beta\,d'_\parallel)}.$$

$$\boxed{D = \frac{1}{\gamma\,(1 - \beta\,d'_\parallel)}}$$

where $ d^{'}_{\parallel} = \hat{\mathbf{d}}_{S'}\cdot\hat{\boldsymbol{\beta}} $ is the projection of the *camera-frame* ray onto the velocity direction.

**Limiting cases:**

| Look direction | $d'_\parallel$ | $D$ | Effect |
|---|---|---|---|
| Exactly forward ($d'_\parallel = 1$) | 1 | $\sqrt{(1+\beta)/(1-\beta)}$ | Blueshift |
| Exactly backward ($d'_\parallel = -1$) | −1 | $\sqrt{(1-\beta)/(1+\beta)}$ | Redshift |
| Transverse ($d'_\parallel = 0$) | 0 | $1/\gamma$ | Transverse redshift (purely quantum) |

Note: the transverse direction gives a *redshift* even at 90°, a purely relativistic effect with no classical analogue.

## 5. Relativistic Beaming (exact)

The *intensity* (energy flux per unit solid angle) transforms as

$$I_{S'} = D^4\, I_S,$$

where the four powers of $D$ arise from:

- $D^1$ - the photon energy blueshift $\omega_{S'} = D\,\omega_S$
- $D^1$ - the photon arrival rate (time dilation)
- $D^2$ - the solid angle compression $d\Omega_{S'} = D^{-2}\,d\Omega_S$ (aberration of solid angle)

**Derivation of solid angle factor.**  The differential solid angle element transforms as

$$d\Omega_S = \sin\theta_S\,d\theta_S\,d\phi.$$

Differentiating the aberration formula:

$$\frac{d(\cos\theta_S)}{d(\cos\theta_{S'})} = \frac{1}{\gamma^2(1 + \beta\cos\theta_{S'})^2} = D^{-2}\Big|_{\phi=0},$$

so $d\Omega_S = D^{-2}\,d\Omega_{S'}$.  Combined with the energy factors, $I_{S'} = D^4 I_S$.

This is the **headlight effect**: forward emission ($D > 1$) is dramatically brightened.  At $\beta = 0.9c$, $D_{\text{fwd}} \approx 4.4$, so forward intensity increases by $4.4^4 \approx 374\times$.

## 6. Penrose-Terrell Rotation

A remarkable result: a **sphere** moving at relativistic speed still *appears* as a circle (not a squashed ellipse), merely *rotated* by the Penrose-Terrell angle.

The reason is that length contraction is exactly cancelled by the retarded-time correction - photons from the far edge of the sphere left slightly *earlier*, when the sphere was further away, precisely compensating the contraction.

For a sphere of angular radius $\alpha$ at rest subtending angle $\alpha_0$:

$$\sin\alpha = \frac{\sin\alpha_0}{D}, \qquad \text{(apparent size change from beaming)}.$$

The rotation angle $\psi$ satisfies $\tan\psi = \beta\sin\theta_{S'}/\gamma$, where $\theta_{S'}$ is the angle between the velocity and the line of sight.

**Practical consequence for this simulator:** extended sources (not points) would need ray-tracing with retarded positions, not just the aberration formula applied to a direction.  Point stars are correctly handled by the direction-only approach.

## 7. Camera Model

### Pinhole camera

The camera maps world directions onto pixels via a pinhole (perspective) projection.  A pixel at normalised screen coordinate $(u, v)$ (with $v/u = \text{aspect ratio}$ and $v \in [-1,1]$) corresponds to camera-space direction

$$\hat{\mathbf{d}}_{\text{cam}} = \frac{1}{\sqrt{u^2 + v^2 + f^2}}(u,\, v,\, f),$$

where $f = [\tan(\theta_{\text{FOV}}/2)]^{-1}$ is the focal length in normalised units.

### Camera rotation matrix

Let $(\hat{\boldsymbol{R}}, \hat{\boldsymbol{U}}, \hat{\boldsymbol{F}})$ be the camera's right, up, and forward unit vectors in world space (built from yaw $\psi$ and pitch $\phi$):

$$\hat{\boldsymbol{F}} = (\sin\psi\cos\phi,\; \sin\phi,\; \cos\psi\cos\phi),$$
$$\hat{\boldsymbol{R}} = \frac{\hat{y}\times\hat{\boldsymbol{F}}}{|\hat{y}\times\hat{\boldsymbol{F}}|}, \qquad \hat{\boldsymbol{U}} = \hat{\boldsymbol{F}}\times\hat{\boldsymbol{R}}.$$

The camera matrix $M = [\hat{\boldsymbol{R}} \mid \hat{\boldsymbol{U}} \mid \hat{\boldsymbol{F}}]$ (column vectors) maps camera to world:

$$\hat{\mathbf{d}}_{\text{world}} = M\,\hat{\mathbf{d}}_{\text{cam}} = u\,\hat{\boldsymbol{R}} + v\,\hat{\boldsymbol{U}} + f\,\hat{\boldsymbol{F}}.$$

## 8. Composing Rotation and Aberration

The full pipeline per pixel is:

$$\underbrace{(u,v)}_{\text{screen}} \xrightarrow{\text{pinhole}} \hat{\mathbf{d}}_{\text{cam}} \xrightarrow{M} \hat{\mathbf{d}}_{\text{world}} \xrightarrow{\text{aberration}(\beta)} \hat{\mathbf{d}}_{\text{rest}} \xrightarrow{\text{star lookup}} I_{\text{rest}} \xrightarrow{D^4,\,\Delta\lambda} I_{\text{obs}}$$

Key insight: because the camera rotation is applied *before* aberration, and aberration is applied in world space with $\hat{\boldsymbol{\beta}} = \hat{z}$ fixed, rotating the camera is equivalent to the user's suggestion of multiplying by the rotation matrix in the fragment shader.  The rotation matrix and the aberration matrix do **not** commute in general, but since aberration acts on the world-space ray and rotation maps screen to world, the correct order is $M$ first, aberration second.

## 9. Approximations Applied for Real-Time Rendering

All physics in §§1–7 is exact.  We make only the following concessions to real-time constraints:

| Approximation | Where | Physical error |
|---|---|---|
| Stars at $r = \infty$ (skybox) | starField, referenceStars | Parallax shift ignored; correct for $r \gg vt$ |
| No time retardation for nearby objects | - | Penrose-Terrell rotation not applied to point stars (which are isotropic anyway) |
| Exaggerated Doppler colour mapping ($\times 80$ scale) | `applyDoppler()` | Channel redistribution is exaggerated; $D$ itself is exact |
| No aberration of the camera's *own* orientation | buildCamMatrix | At $\beta < 0.01c$, this is $O(\beta^2) < 10^{-4}$ |
| Float32 precision | Throughout | Rounding errors $\sim 10^{-7}$; negligible for $\beta < 0.99$ |

## 10. Non-Relativistic Limit

At $\beta \ll 1$, expand to first order:

$$d_{S,\parallel} \approx d'_\parallel + \beta(1 - d^{\prime 2}_\parallel), \qquad \mathbf{d}_{S,\perp} \approx \mathbf{d}'_\perp\bigl(1 - \beta d'_\parallel\bigr).$$

The angular shift of a source originally at angle $\theta'$ from the velocity axis is

$$\delta\theta \approx -\beta\sin\theta',$$

which agrees with the **classical stellar aberration** formula used in observational astronomy.  The maximum shift is $\beta$ radians, occurring at $\theta' = 90°$.

At $\beta = 0.01c$, $\delta\theta_{\text{max}} \approx 0.01\,\text{rad} \approx 0.57°$.  This is subtle but measurable in a star field with known positions.  Raise `BETA_MAX` to $0.5$ or higher in `main.js` to enter the manifestly relativistic regime.