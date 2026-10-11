// Library Annex Observatory — WebGL planetarium.
//
// Ported from the observatory handoff (viewer-template.html v1.3.0). Shaders,
// the azimuthal-equidistant projection and great-circle line clipping are
// unchanged from the handoff; see observatory-handoff/IMPLEMENTATION.md for
// the geometry contract. Site-specific changes:
//   - no constellation buttons / figure subduing; instruments are Zenith + Nebular veil
//   - wheel zoom eases towards a goal FoV instead of jumping per event
//   - Zenith (and Home) eases back to the initial view
//   - sized to its container rather than the window; assets fetched, not embedded

// Wheel zoom: degrees of FoV per wheel pixel, and easing time constant (ms).
const ZOOM_PER_PIXEL = 0.02
const ZOOM_TAU_MS = 220
// Double-click zoom: target FoV (degrees) and duration of its ease-in-out (ms).
// When already at or inside that FoV, a double-click halves the current FoV instead.
const DBLCLICK_FOV = 40
const DBLCLICK_MS = 750
// Panning weight: the view follows the pointer on a critically damped spring with this
// smoothing time (ms) — slow to start, no overshoot, settling exactly where the pointer
// put it. There is no momentum after release. Higher feels heavier; 0 is rigid.
const PAN_WEIGHT_MS = 300
// Duration of the eased return to the zenith view (ms).
const ZENITH_MS = 1800
// A wheel gesture keeps its celestial target until this long after its last event.
const ZOOM_IDLE_MS = 1500

// Zenith view: the whole dome, Auxanyr centred.
const HOME = { yaw: 0, alt: 90, fieldOfView: 180, roll: 0 }
// Opening view: hard zoomed in on Auxanyr, slightly off-centre and turned, so the first
// Zenith press pulls out to the whole dome with a visible twist. alt must be >= FoV/2.
const INITIAL = { yaw: 30, alt: 87.5, fieldOfView: 20, roll: 0 }

const rad = x => x * Math.PI / 180
const dot = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0)
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x))
// Signed shortest angular difference in degrees, in [-180, 180).
const wrapDeg = d => ((d % 360) + 540) % 360 - 180
const easeInOutCubic = t => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error(`Failed to load ${url}`))
    img.src = url
  })
}

function createObservatory(root) {
  const q = sel => root.querySelector(sel)
  const canvas = q("[data-sky]"), overlay = q("[data-overlay]"), message = q("[data-message]")
  const veil = q("[data-veil]"), zenithButton = q("[data-zenith]")
  const ctx = overlay.getContext("2d")
  const showMessage = text => { message.textContent = text; message.hidden = !text }

  let destroyed = false
  const cleanups = []
  const listen = (el, type, fn, opts) => { el.addEventListener(type, fn, opts); cleanups.push(() => el.removeEventListener(type, fn, opts)) }

  const gl = canvas.getContext("webgl", { alpha: false, antialias: true })
  if (!gl) {
    showMessage("The observatory's instruments require WebGL, which this browser cannot provide.")
    return { destroy() { } }
  }

  // Viewport size in CSS pixels; refreshed on every draw.
  let W = 1, H = 1
  const measure = () => { W = Math.max(1, root.clientWidth); H = Math.max(1, root.clientHeight) }
  measure()

  const state = { backgroundBrightness: 4 / 3, constellationBrightness: 2, nebulaBrightness: 4, lines: true, ...INITIAL }
  let DATA = null, byId = null, starCount = 0

  function program(v, f) {
    function shader(type, src) { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw Error(gl.getShaderInfoLog(s)); return s }
    const p = gl.createProgram(); gl.attachShader(p, shader(gl.VERTEX_SHADER, v)); gl.attachShader(p, shader(gl.FRAGMENT_SHADER, f)); gl.linkProgram(p)
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw Error(gl.getProgramInfoLog(p))
    return p
  }
  const common = "uniform vec3 rightv,upv,forwardv,zenith;uniform float aspect,vertical,halfangle;"
  const bg = program("attribute vec2 pos;varying vec2 uv;void main(){uv=pos;gl_Position=vec4(pos,0.,1.);}", `precision highp float;varying vec2 uv;${common}uniform sampler2D tex;uniform float brightness;void main(){vec2 q=uv*vec2(aspect,vertical);float rho=length(q);if(rho>1.){gl_FragColor=vec4(0.,0.,0.,1.);return;}float angle=rho*halfangle;vec3 r=cos(angle)*forwardv;if(rho>.000001)r+=sin(angle)*(q.x*rightv+q.y*upv)/rho;if(dot(r,zenith)<0.){gl_FragColor=vec4(0.,0.,0.,1.);return;}if(r.y<0.){gl_FragColor=vec4(0.,0.,0.,1.);return;}float t=atan(length(r.xz),r.y);float d=length(r.xz);vec2 p=vec2(1500.,1560.);if(d>.00001)p+=1380.*t/1.57079632679*vec2(r.x,-r.z)/d;vec2 absence=(p-vec2(1500.,1870.))/190.;float boundaryAngle=atan(absence.y,absence.x);if(length(absence)<1.+.07*sin(boundaryAngle*5.)+.045*cos(boundaryAngle*9.)){gl_FragColor=vec4(0.,0.,0.,1.);return;}vec3 col=texture2D(tex,p/vec2(3000.,3030.)).rgb;vec3 cloud=max(col-vec3(3.,7.,16.)/255.,vec3(0.));float signal=max(cloud.r,max(cloud.g,cloud.b));cloud*=smoothstep(0.,.035,signal);gl_FragColor=vec4(cloud*brightness,1.);}`)
  const stars = program(`${common}attribute vec3 pos,col;attribute vec2 corner;attribute float radius,intensity,group,sprite;uniform float backgroundBrightness,constellationBrightness,scale;uniform vec2 viewport;varying vec3 colour;varying float light;varying vec2 atlasUV;void main(){float z=dot(pos,forwardv);vec2 xy=vec2(dot(pos,rightv),dot(pos,upv));float transverse=length(xy);float theta=atan(transverse,z);vec2 projected=vec2(0.);if(transverse>.000001)projected=xy/transverse*theta/halfangle;vec4 clip=vec4(projected/vec2(aspect,vertical),0.,1.);float rawSize=radius*scale*2.5;float size=sqrt(rawSize*rawSize+7.*7.);clip.xy+=corner*size*2./viewport;gl_Position=clip;if(theta>halfangle||pos.y<0.)gl_Position=vec4(2.,2.,2.,1.);vec2 cell=vec2(mod(sprite,4.),floor(sprite/4.));atlasUV=(cell+(corner*.5+.5)*.992+.004)/4.;colour=col;light=2.5*intensity*rawSize*rawSize/(size*size)*(group< -0.5&&group> -1.5?backgroundBrightness:constellationBrightness);}`, "precision mediump float;uniform sampler2D starAtlas;varying vec3 colour;varying float light;varying vec2 atlasUV;void main(){vec3 profile=texture2D(starAtlas,atlasUV).rgb;vec3 coreColour=mix(colour,vec3(1.),.58);vec3 energy=profile.r*coreColour+(profile.g+profile.b)*colour;gl_FragColor=vec4(energy*light,1.);}")
  const lineProg = program(`${common}attribute vec3 pos;void main(){float z=dot(pos,forwardv);vec2 xy=vec2(dot(pos,rightv),dot(pos,upv));float transverse=length(xy);float theta=atan(transverse,z);vec2 projected=vec2(0.);if(transverse>.000001)projected=xy/transverse*theta/halfangle;gl_Position=vec4(projected/vec2(aspect,vertical),0.,1.);}`, "precision highp float;uniform vec2 viewport;uniform float aspect,vertical;void main(){vec2 q=(gl_FragCoord.xy/viewport*2.-1.)*vec2(aspect,vertical);if(dot(q,q)>1.)discard;gl_FragColor=vec4(.55,.65,.85,.28);}")

  function buffer(arr) { const b = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, b); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(arr), gl.STATIC_DRAW); return b }
  const quad = buffer([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1])
  const corners = [[-1, -1], [1, -1], [-1, 1], [-1, 1], [1, -1], [1, 1]]
  let starBuffer = null
  const lineBuffer = buffer([])

  // Clip the true great-circle arc to the view cap and physical dome before projection.
  // A*cos(t)+U*sin(t) gives exact plane-boundary intersections, including arcs
  // whose endpoints are both outside but whose middle crosses into view.
  function clippedArcs(c, forward, half, out) {
    const threshold = Math.cos(half), eps = 1e-10
    for (const [a, b] of c.edges) {
      const unit = v => { const n = Math.hypot(...v); return v.map(x => x / n) }
      const A = unit(byId.get(a).direction), B = unit(byId.get(b).direction)
      const theta = Math.acos(clamp(dot(A, B), -1, 1))
      if (theta < eps) continue
      const U = B.map((v, i) => (v - A[i] * Math.cos(theta)) / Math.sin(theta))
      const point = t => A.map((v, i) => v * Math.cos(t) + U[i] * Math.sin(t))
      const cuts = [0, theta]
      function intersections(normal, limit) {
        const aa = dot(A, normal), bb = dot(U, normal), amp = Math.hypot(aa, bb)
        if (amp < eps || Math.abs(limit) > amp + eps) return
        const phase = Math.atan2(bb, aa), delta = Math.acos(clamp(limit / amp, -1, 1))
        for (const sign of [-1, 1]) for (let k = -2; k <= 2; k++) {
          const t = phase + sign * delta + k * 2 * Math.PI
          if (t > eps && t < theta - eps) cuts.push(t)
        }
      }
      intersections(forward, threshold); intersections([0, 1, 0], 0)
      cuts.sort((a, b) => a - b)
      for (let j = 1; j < cuts.length; j++) {
        const lo = cuts[j - 1], hi = cuts[j]; if (hi - lo < eps) continue
        const middle = point((lo + hi) / 2)
        if (dot(middle, forward) < threshold - eps || middle[1] < -eps) continue
        const n = Math.max(1, Math.ceil((hi - lo) / rad(0.5)))
        for (let i = 0; i < n; i++) out.push(...point(lo + (hi - lo) * i / n), ...point(lo + (hi - lo) * (i + 1) / n))
      }
    }
    return out
  }

  function makeTexture(unit) {
    const t = gl.createTexture(); gl.activeTexture(unit); gl.bindTexture(gl.TEXTURE_2D, t)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, 1, 1, 0, gl.RGB, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0]))
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    return t
  }
  const texture = makeTexture(gl.TEXTURE0)
  const starTexture = makeTexture(gl.TEXTURE1)
  function uploadNebula(img) {
    // Resample to a power of two so the nebula can be mipmapped (trilinear minification).
    const filtered = document.createElement("canvas"); filtered.width = filtered.height = 2048
    const paint = filtered.getContext("2d"); paint.imageSmoothingEnabled = true; paint.imageSmoothingQuality = "high"; paint.drawImage(img, 0, 0, 2048, 2048)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, gl.RGB, gl.UNSIGNED_BYTE, filtered); gl.generateMipmap(gl.TEXTURE_2D)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
  }
  function uploadStarAtlas(img) {
    // Data texture (core/halo/diffraction channels): linear, no mipmaps.
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, starTexture)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, gl.RGB, gl.UNSIGNED_BYTE, img)
  }

  let basis
  // A spherical view cap fits inside the northern hemisphere iff altitude >= half-FoV.
  function constrainView() {
    state.fieldOfView = clamp(state.fieldOfView, 20, 180)
    state.alt = clamp(state.alt, state.fieldOfView / 2, 90)
  }
  function camera() {
    constrainView()
    const l = rad(90), y = rad(state.yaw), a = rad(state.alt), Z = [0, Math.sin(l), Math.cos(l)], N = [0, Math.cos(l), -Math.sin(l)], E = [1, 0, 0]
    const F = Z.map((v, i) => Math.sin(a) * v + Math.cos(a) * (Math.cos(y) * N[i] + Math.sin(y) * E[i]))
    const R = E.map((v, i) => Math.cos(y) * v - Math.sin(y) * N[i]), U = cross(R, F)
    const r = rad(state.roll || 0), RR = R.map((v, i) => v * Math.cos(r) + U[i] * Math.sin(r)), UU = U.map((v, i) => v * Math.cos(r) - R[i] * Math.sin(r))
    return { R: RR, U: UU, F, Z }
  }
  // Inverse equidistant projection in CSS pixels (relative to the container), independent of DPR.
  function cursorRay(b, x, y, fov) {
    const radius = Math.min(W, H) / 2, qx = (x - W / 2) / radius, qy = (H / 2 - y) / radius, rho = Math.hypot(qx, qy)
    if (!Number.isFinite(rho) || rho > 1) return null
    const t = rho * rad(fov) / 2, c = Math.cos(t), k = rho > 1e-10 ? Math.sin(t) / rho : 0
    return b.F.map((v, i) => c * v + k * (qx * b.R[i] + qy * b.U[i]))
  }
  function zoomAtCursor(fov, x, y, fixedAnchor = null) {
    const old = camera(), oldFov = state.fieldOfView, anchor = fixedAnchor || cursorRay(old, x, y, oldFov)
    state.fieldOfView = clamp(fov, 20, 180)
    if (anchor) {
      // Shortest spherical rotation transports the whole camera frame without a pole flip.
      const moving = cursorRay(old, x, y, state.fieldOfView)
      if (moving) {
        const axis = cross(moving, anchor), sin = Math.hypot(...axis), cos = clamp(dot(moving, anchor), -1, 1)
        if (sin > 1e-10) {
          const n = axis.map(v => v / sin), rotate = v => { const nv = cross(n, v), d = dot(n, v); return v.map((a, i) => a * cos + nv[i] * sin + n[i] * d * (1 - cos)) }, F = rotate(old.F), R = rotate(old.R)
          state.alt = Math.asin(clamp(F[1], -1, 1)) * 180 / Math.PI
          if (Math.hypot(F[0], F[2]) > 1e-8) state.yaw = Math.atan2(F[0], -F[2]) * 180 / Math.PI
          const yy = rad(state.yaw), baseR = [Math.cos(yy), 0, Math.sin(yy)], baseU = cross(baseR, F)
          state.roll = Math.atan2(dot(R, baseU), dot(R, baseR)) * 180 / Math.PI
        }
      }
    }
    // Ease out transported roll as the view narrows: fully pole-upright at 100 degrees.
    // A ratio of remaining alignment weights makes this independent of step size.
    if (anchor && state.fieldOfView < oldFov) {
      const weight = f => Math.pow(clamp((f - 100) / 80, 0, 1), 2), before = weight(oldFov), after = weight(state.fieldOfView)
      state.roll *= before > 1e-10 ? after / before : 0
    }
    constrainView()
  }
  function screen(v) {
    const x = dot(v, basis.R), y = dot(v, basis.U), z = dot(v, basis.F), r = Math.hypot(x, y), theta = Math.atan2(r, z), half = rad(state.fieldOfView) / 2
    if (v[1] < 0 || theta > half) return null
    const k = r > 0.000001 ? theta / r / half * Math.min(W, H) / 2 : 0
    return [W / 2 + x * k, H / 2 - y * k]
  }

  // ---- Animation: eased wheel zoom, eased return to zenith, gnosis shimmer ----
  // All of this deliberately ignores prefers-reduced-motion (site owner's call).
  // Transient gesture state: the celestial direction a wheel gesture zooms towards.
  let zoomTarget = null, zoomLast = 0, zoomBirth = 0, zoomExpiry = null
  let fovGoal = null   // FoV the eased zoom is approaching, or null when idle
  let zoomTween = null // { t0, from } while a double-click zoom eases in-out to fovGoal
  let homing = null    // { t0, from } while easing back to the zenith view
  // Weighted panning: the view springs towards pan.goal, which the pointer moves.
  let pan = null       // { goal: {yaw, alt}, vel: {yaw, alt}, dragging, idle, lastX, lastY }
  let frame = null, lastFrameT = 0

  function clearZoomTarget() {
    zoomTarget = null; zoomLast = 0; fovGoal = null; zoomTween = null
    if (zoomExpiry !== null) clearTimeout(zoomExpiry)
    zoomExpiry = null
  }
  function startLoop() { if (frame === null && !destroyed) { lastFrameT = 0; frame = requestAnimationFrame(tick) } }

  // Projected screen position of the gesture target, bounded just inside the rim.
  function targetScreenPoint(b) {
    const rx = dot(zoomTarget, b.R), ry = dot(zoomTarget, b.U), rz = dot(zoomTarget, b.F), r = Math.hypot(rx, ry), theta = Math.atan2(r, rz), radius = Math.min(W, H) / 2
    const rho = Math.min(0.999999, theta / (rad(state.fieldOfView) / 2)), k = r > 1e-10 ? radius * rho / r : 0
    return [W / 2 + rx * k, H / 2 - ry * k]
  }
  function stepZoom(now, dt) {
    let next
    if (zoomTween) {
      // Double-click: timed ease-in-out, so it accelerates gently rather than lurching.
      const t = clamp((now - zoomTween.t0) / DBLCLICK_MS, 0, 1)
      next = zoomTween.from + (fovGoal - zoomTween.from) * easeInOutCubic(t)
      if (t >= 1) { next = fovGoal; fovGoal = null; zoomTween = null }
    } else {
      // Wheel: exponential approach to an accumulating goal.
      const f = state.fieldOfView
      next = f + (fovGoal - f) * (1 - Math.exp(-dt / ZOOM_TAU_MS))
      if (Math.abs(fovGoal - next) < 0.01) { next = fovGoal; fovGoal = null }
    }
    if (zoomTarget) {
      const [x, y] = targetScreenPoint(camera())
      zoomAtCursor(next, x, y, zoomTarget)
    } else {
      state.fieldOfView = clamp(next, 20, 180); constrainView()
    }
  }
  function stepHoming(now) {
    const { t0, from } = homing
    const t = clamp((now - t0) / ZENITH_MS, 0, 1), e = easeInOutCubic(t)
    // alt and FoV/2 both move linearly in e towards 90, so alt >= FoV/2 holds throughout.
    state.yaw = from.yaw + wrapDeg(HOME.yaw - from.yaw) * e
    state.roll = from.roll + wrapDeg(HOME.roll - from.roll) * e
    state.alt = from.alt + (HOME.alt - from.alt) * e
    state.fieldOfView = from.fieldOfView + (HOME.fieldOfView - from.fieldOfView) * e
    if (t >= 1) { Object.assign(state, HOME); homing = null }
  }
  // Critically damped spring step (Game Programming Gems 4 "SmoothDamp" approximation).
  function springAxis(axis, dt) {
    const omega = 2 / PAN_WEIGHT_MS, x = omega * dt, decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    const change = state[axis] - pan.goal[axis], temp = (pan.vel[axis] + omega * change) * dt
    pan.vel[axis] = (pan.vel[axis] - omega * temp) * decay
    state[axis] = pan.goal[axis] + (change + temp) * decay
  }
  function stepPan(dt) {
    const { goal, vel } = pan
    if (PAN_WEIGHT_MS > 0) { springAxis("yaw", dt); springAxis("alt", dt) }
    else { state.yaw = goal.yaw; state.alt = goal.alt }
    const settled = Math.hypot(vel.yaw, vel.alt) < 1e-5 && Math.abs(goal.yaw - state.yaw) < 0.005 && Math.abs(goal.alt - state.alt) < 0.005
    if (!pan.dragging && settled) { state.yaw = goal.yaw; state.alt = goal.alt; pan = null }
    // Held still mid-drag: stop animating until the pointer moves again.
    else if (pan.dragging) pan.idle = settled
  }
  function tick(now) {
    frame = null
    const dt = lastFrameT ? Math.min(64, now - lastFrameT) : 16
    lastFrameT = now
    const moving = homing !== null || fovGoal !== null || (pan !== null && !pan.idle)
    if (homing) stepHoming(now)
    if (fovGoal !== null) stepZoom(now, dt)
    if (pan) stepPan(dt)
    if (moving) draw()
    else renderOverlay()
    if (homing !== null || fovGoal !== null || (pan !== null && !pan.idle) || zoomTarget) frame = requestAnimationFrame(tick)
  }

  function goZenith() {
    clearZoomTarget(); pan = null
    const from = { yaw: wrapDeg(state.yaw), alt: state.alt, fieldOfView: state.fieldOfView, roll: wrapDeg(state.roll || 0) }
    homing = { t0: performance.now(), from }
    startLoop()
  }

  // Start or continue a zoom gesture towards the sky under (x, y); `fresh` forces a new target.
  function refreshZoomGesture(x, y, fresh) {
    homing = null; pan = null
    const now = performance.now()
    if (fresh || !zoomTarget || now - zoomLast > ZOOM_IDLE_MS) {
      zoomTarget = cursorRay(camera(), x, y, state.fieldOfView); zoomBirth = now
    }
    zoomLast = now
    if (zoomExpiry !== null) clearTimeout(zoomExpiry)
    zoomExpiry = setTimeout(() => { zoomExpiry = null; zoomTarget = null; zoomLast = 0; renderOverlay() }, ZOOM_IDLE_MS)
  }
  function wheelZoom(e, x, y) {
    let dy = e.deltaY * (e.deltaMode === 1 ? 33 : e.deltaMode === 2 ? H : 1)
    dy = clamp(dy, -150, 150)
    if (!dy) return
    refreshZoomGesture(x, y, false)
    zoomTween = null
    fovGoal = clamp((fovGoal ?? state.fieldOfView) + dy * ZOOM_PER_PIXEL, 20, 180)
    startLoop()
  }
  function doubleClickZoom(x, y) {
    refreshZoomGesture(x, y, true)
    const f = state.fieldOfView
    fovGoal = clamp(f > DBLCLICK_FOV + 1 ? DBLCLICK_FOV : f / 2, 20, 180)
    zoomTween = { t0: performance.now(), from: f }
    startLoop()
  }

  function drawZoomTarget() {
    if (!zoomTarget) return
    const now = performance.now(), idle = now - zoomLast; if (idle >= ZOOM_IDLE_MS) return
    const p = screen(zoomTarget); if (!p) return
    const form = Math.min(1, (now - zoomBirth) / 180), fade = clamp((ZOOM_IDLE_MS - idle) / 500, 0, 1), strength = form * fade, t = (now - zoomBirth) / 1000
    const radius = 19 + 5 * (1 - form) + 9 * (1 - fade)
    ctx.save(); ctx.beginPath(); ctx.arc(W / 2, H / 2, Math.min(W, H) / 2, 0, Math.PI * 2); ctx.clip(); ctx.translate(p[0], p[1]); ctx.globalAlpha = strength; ctx.globalCompositeOperation = "screen"
    // Open luminous arcs and fine prismatic fragments, with a clear central aperture.
    for (let layer = 0; layer < 2; layer++) {
      ctx.strokeStyle = layer ? "#d4b5ff" : "#a8ffe1"; ctx.shadowColor = layer ? "#9d7af9" : "#6effcc"; ctx.shadowBlur = layer ? 6 : 12; ctx.lineWidth = layer ? 0.8 : 1.6
      for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + 0.2 + Math.sin(t * 0.7) * 0.06 + (layer ? 0.11 : 0), r = radius + (layer ? 4 : 0); ctx.beginPath(); ctx.arc(0, 0, r, a, a + 0.64 * form); ctx.stroke() }
    }
    ctx.shadowBlur = 5; ctx.fillStyle = "#dcfff0"
    for (let i = 0; i < 12; i++) { const a = i * Math.PI / 6 + t * 0.09, r = radius + 6 + 3 * Math.sin(i * 2.1 + t * 1.3) + (1 - fade) * 8; ctx.globalAlpha = strength * (0.25 + 0.5 * (0.5 + 0.5 * Math.sin(i * 1.7 + t))); ctx.beginPath(); ctx.arc(Math.cos(a) * r, Math.sin(a) * r, i % 3 === 0 ? 1.25 : 0.7, 0, Math.PI * 2); ctx.fill() }
    ctx.restore()
  }

  // ---- Rendering ----
  const dpr = () => Math.min(window.devicePixelRatio || 1, 2)
  function uniforms(p) {
    for (let i = 0; i < gl.getParameter(gl.MAX_VERTEX_ATTRIBS); i++) gl.disableVertexAttribArray(i)
    gl.useProgram(p)
    for (const [name, v] of Object.entries({ rightv: basis.R, upv: basis.U, forwardv: basis.F, zenith: basis.Z })) gl.uniform3fv(gl.getUniformLocation(p, name), v)
    const diameter = Math.min(canvas.width, canvas.height)
    gl.uniform1f(gl.getUniformLocation(p, "aspect"), canvas.width / diameter); gl.uniform1f(gl.getUniformLocation(p, "vertical"), canvas.height / diameter); gl.uniform1f(gl.getUniformLocation(p, "halfangle"), rad(state.fieldOfView) / 2)
  }
  function attr(p, name, size, stride, offset) { const i = gl.getAttribLocation(p, name); gl.enableVertexAttribArray(i); gl.vertexAttribPointer(i, size, gl.FLOAT, false, stride, offset) }
  function renderOverlay() { if (destroyed) return; const d = dpr(); ctx.setTransform(d, 0, 0, d, 0, 0); ctx.clearRect(0, 0, W, H); drawZoomTarget() }
  function draw() {
    if (destroyed || gl.isContextLost()) return
    measure()
    const d = dpr(), width = Math.round(W * d), height = Math.round(H * d)
    if (canvas.width !== width || canvas.height !== height) { canvas.width = width; canvas.height = height; overlay.width = width; overlay.height = height }
    basis = camera()
    gl.viewport(0, 0, canvas.width, canvas.height); gl.disable(gl.BLEND)
    uniforms(bg); gl.bindBuffer(gl.ARRAY_BUFFER, quad); attr(bg, "pos", 2, 0, 0)
    gl.uniform1f(gl.getUniformLocation(bg, "brightness"), state.nebulaBrightness)
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, texture); gl.uniform1i(gl.getUniformLocation(bg, "tex"), 0)
    gl.drawArrays(gl.TRIANGLES, 0, 6)
    if (starBuffer) {
      gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA, gl.ONE)
      uniforms(stars); gl.bindBuffer(gl.ARRAY_BUFFER, starBuffer)
      for (const [n, s, o] of [["pos", 3, 0], ["col", 3, 12], ["radius", 1, 24], ["intensity", 1, 28], ["group", 1, 32], ["corner", 2, 36], ["sprite", 1, 44]]) attr(stars, n, s, 48, o)
      for (const n of ["backgroundBrightness", "constellationBrightness"]) gl.uniform1f(gl.getUniformLocation(stars, n), state[n])
      gl.uniform1f(gl.getUniformLocation(stars, "scale"), d * Math.min(W, H) / 900 * 0.72 * Math.sqrt(180 / state.fieldOfView))
      gl.uniform2f(gl.getUniformLocation(stars, "viewport"), canvas.width, canvas.height)
      gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, starTexture); gl.uniform1i(gl.getUniformLocation(stars, "starAtlas"), 1)
      gl.drawArrays(gl.TRIANGLES, 0, starCount * 6)
      if (state.lines) {
        const vertices = []
        for (const c of DATA.constellations) clippedArcs(c, basis.F, rad(state.fieldOfView) / 2, vertices)
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        uniforms(lineProg); gl.uniform2f(gl.getUniformLocation(lineProg, "viewport"), canvas.width, canvas.height)
        gl.bindBuffer(gl.ARRAY_BUFFER, lineBuffer); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.DYNAMIC_DRAW)
        attr(lineProg, "pos", 3, 0, 0); gl.drawArrays(gl.LINES, 0, vertices.length / 3)
      }
    }
    renderOverlay()
  }

  // ---- Input ----
  const local = e => { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top] }
  const interrupt = () => { clearZoomTarget(); homing = null; pan = null }

  listen(zenithButton, "click", goZenith)
  veil.value = state.nebulaBrightness
  listen(veil, "input", () => { state.nebulaBrightness = clamp(Number(veil.value), 0, 4); draw() })

  listen(canvas, "pointerdown", e => {
    // Grabbing the sky while it is still settling holds it where it currently is.
    interrupt()
    pan = { goal: { yaw: state.yaw, alt: state.alt }, vel: { yaw: 0, alt: 0 }, dragging: true, idle: true, lastX: e.clientX, lastY: e.clientY }
    canvas.setPointerCapture(e.pointerId); canvas.focus()
  })
  // On release the view finishes settling onto the goal; it never travels past it.
  const release = () => { if (pan && pan.dragging) { pan.dragging = false; pan.idle = false; startLoop() } }
  listen(canvas, "pointerup", release)
  listen(canvas, "pointercancel", release)
  listen(canvas, "pointermove", e => {
    if (!pan || !pan.dragging) return
    const { goal } = pan
    goal.yaw -= (e.clientX - pan.lastX) * 0.15
    goal.alt = clamp(goal.alt + (e.clientY - pan.lastY) * 0.15, state.fieldOfView / 2, 90)
    pan.lastX = e.clientX; pan.lastY = e.clientY; pan.idle = false
    startLoop()
  })
  listen(canvas, "dblclick", e => { e.preventDefault(); const [x, y] = local(e); doubleClickZoom(x, y) })
  listen(canvas, "wheel", e => { e.preventDefault(); const [x, y] = local(e); wheelZoom(e, x, y) }, { passive: false })
  listen(canvas, "keydown", e => {
    if (e.key === "Home") { e.preventDefault(); goZenith(); return }
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "+", "-", "="].includes(e.key)) return
    e.preventDefault(); interrupt()
    if (e.key === "ArrowLeft") state.yaw -= 3
    if (e.key === "ArrowRight") state.yaw += 3
    if (e.key === "ArrowUp") state.alt = Math.min(90, state.alt + 3)
    if (e.key === "ArrowDown") state.alt = Math.max(state.fieldOfView / 2, state.alt - 3)
    if (e.key === "+" || e.key === "=") state.fieldOfView = Math.max(20, state.fieldOfView - 3)
    if (e.key === "-") state.fieldOfView = Math.min(180, state.fieldOfView + 3)
    draw()
  })
  listen(canvas, "webglcontextlost", e => {
    e.preventDefault(); interrupt()
    showMessage("The observatory has lost its sight. Reload the page to recalibrate.")
  })

  const resizer = new ResizeObserver(() => draw())
  resizer.observe(root)
  cleanups.push(() => resizer.disconnect())

  // The site's music player is fixed to the bottom of the viewport; end the sky at its top edge.
  const player = document.getElementById("music-player")
  if (player) {
    const fitAbovePlayer = () => { root.style.bottom = `${player.offsetHeight}px` }
    const playerResizer = new ResizeObserver(fitAbovePlayer)
    playerResizer.observe(player)
    fitAbovePlayer()
    cleanups.push(() => playerResizer.disconnect())
  }

  // ---- Load ----
  showMessage("Calibrating…")
  const { catalogue, nebula, starAtlas } = root.dataset
  loadImage(starAtlas).then(img => { if (!destroyed) { uploadStarAtlas(img); draw() } }).catch(() => { })
  loadImage(nebula).then(img => { if (!destroyed) { uploadNebula(img); draw() } }).catch(() => { })
  fetch(catalogue)
    .then(r => { if (!r.ok) throw new Error(`Catalogue ${r.status}`); return r.json() })
    .then(data => {
      if (destroyed) return
      DATA = data
      byId = new Map(DATA.stars.map(s => [s.id, s]))
      starCount = DATA.stars.length
      starBuffer = buffer(DATA.stars.flatMap(s => corners.flatMap(c => [...s.direction, ...s.colour, s.radius, s.intensity, s.group, ...c, s.sprite])))
      showMessage("")
      draw()
    })
    .catch(() => { if (!destroyed) showMessage("The star catalogue could not be read. Reload the page to try again.") })

  draw()

  return {
    destroy() {
      destroyed = true
      if (frame !== null) cancelAnimationFrame(frame)
      clearZoomTarget()
      cleanups.forEach(fn => fn())
      // Release the GPU context promptly rather than waiting for GC.
      const lose = gl.getExtension("WEBGL_lose_context")
      if (lose) lose.loseContext()
    }
  }
}

export const Observatory = {
  mounted() { this.observatory = createObservatory(this.el) },
  destroyed() { if (this.observatory) this.observatory.destroy() }
}
