// jeSDR website: the hero background, a slowly scrolling waterfall with a few
// FT8-style signals. Used by every page that has <canvas id="spectrum">.
(function () {
  const c = document.getElementById('spectrum');
  if (!c || !c.getContext) return;
  const ctx = c.getContext('2d');
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) { draw(true); return; }
  let w, h, img, sigs = [];
  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    w = c.width = Math.floor(c.clientWidth * dpr / 3);
    h = c.height = Math.floor(c.clientHeight * dpr / 3);
    ctx.fillStyle = '#05080c'; ctx.fillRect(0, 0, w, h);
    sigs = Array.from({ length: Math.max(6, Math.floor(w / 18)) }, () => newSig());
  }
  function newSig() {
    return { x: Math.random() * w, life: 20 + Math.random() * 60, gap: Math.random() * 80, a: .4 + Math.random() * .6, wd: 1 + Math.random() * 2 };
  }
  function color(v) {
    // dark blue -> cyan -> amber
    if (v < .5) { const t = v / .5; return [5 + 20 * t, 8 + 120 * t, 12 + 150 * t]; }
    const t = (v - .5) / .5; return [25 + 230 * t, 128 + 54 * t, 162 - 123 * t];
  }
  function line() {
    ctx.drawImage(c, 0, 0, w, h - 1, 0, 1, w, h - 1);
    img = ctx.createImageData(w, 1);
    const row = new Float32Array(w);
    for (let x = 0; x < w; x++) row[x] = Math.random() * .22;
    for (const s of sigs) {
      if (s.gap > 0) { s.gap--; continue; }
      for (let dx = -3; dx <= 3; dx++) {
        const x = Math.round(s.x + dx); if (x < 0 || x >= w) continue;
        row[x] = Math.max(row[x], s.a * Math.exp(-(dx * dx) / (2 * s.wd)));
      }
      if (--s.life <= 0) Object.assign(s, newSig());
    }
    for (let x = 0; x < w; x++) {
      const [r, g, b] = color(Math.min(1, row[x]));
      img.data.set([r, g, b, 255], x * 4);
    }
    ctx.putImageData(img, 0, 0);
  }
  function draw(still) {
    resize();
    if (still) { for (let i = 0; i < h; i++) line(); return; }
    for (let i = 0; i < h; i++) line();
    let last = 0;
    (function tick(t) {
      if (t - last > 70) { line(); last = t; }
      requestAnimationFrame(tick);
    })(0);
  }
  window.addEventListener('resize', () => { clearTimeout(window._rs); window._rs = setTimeout(resize, 200); });
  draw(false);
})();
