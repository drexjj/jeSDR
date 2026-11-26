// jeSDR manual: search (offline, from search.js) and the contents menu
(function () {
  var idx = window.MANUAL_INDEX || [];
  var q = document.getElementById('q'), box = document.getElementById('results');
  var sel = -1, hits = [];
  function norm(s) { return s.toLowerCase(); }
  function esc(s) { return s.replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function words(s) { return norm(s).split(/[^\wÀ-ɏ.+#-]+/).filter(function (w) { return w.length > 1 || /\d/.test(w); }); }
  function search(text) {
    var ws = words(text);
    if (!ws.length) return [];
    var out = [];
    for (var i = 0; i < idx.length; i++) {
      var e = idx[i], h = norm(e.h), t = norm(e.t), x = norm(e.x), score = 0, all = true;
      for (var k = 0; k < ws.length; k++) {
        var w = ws[k], s = 0;
        if (h.indexOf(w) >= 0) s += 12;
        if (t.indexOf(w) >= 0) s += 5;
        var n = 0, p = x.indexOf(w);
        while (p >= 0 && n < 20) { n++; p = x.indexOf(w, p + w.length); }
        s += Math.min(n, 8);
        if (!s) { all = false; break; }
        score += s;
      }
      if (all) out.push({ e: e, s: score + (norm(e.h + ' ' + e.x).indexOf(norm(text)) >= 0 ? 10 : 0) });
    }
    out.sort(function (a, b) { return b.s - a.s; });
    return out.slice(0, 25);
  }
  function snippet(x, ws) {
    var lx = norm(x), p = -1;
    for (var k = 0; k < ws.length && p < 0; k++) p = lx.indexOf(ws[k]);
    var a = Math.max(0, p - 60), s = (a ? '… ' : '') + x.substr(a, 170) + (a + 170 < x.length ? ' …' : '');
    s = esc(s);
    ws.forEach(function (w) {
      if (w.length < 2) return;
      s = s.replace(new RegExp('(' + w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig'), '<mark>$1</mark>');
    });
    return s;
  }
  function render() {
    var text = q.value.trim();
    hits = search(text);
    sel = -1;
    if (!text) { box.hidden = true; return; }
    var ws = words(text);
    box.innerHTML = hits.length ? hits.map(function (r, i) {
      var e = r.e;
      return '<a class="hit" data-i="' + i + '" href="' + e.p + (e.a ? '#' + e.a : '') + '"><b>' + esc(e.h) + '</b>' +
        (e.h !== e.t ? '<span class="pg">' + esc(e.t) + '</span>' : '') + '<span class="sn">' + snippet(e.x, ws) + '</span></a>';
    }).join('') : '<p class="none">Nothing found for “' + esc(text) + '”.</p>';
    box.hidden = false;
  }
  function move(d) {
    var a = box.querySelectorAll('.hit');
    if (!a.length) return;
    sel = (sel + d + a.length) % a.length;
    a.forEach(function (x, i) { x.classList.toggle('on', i === sel); });
    a[sel].scrollIntoView({ block: 'nearest' });
  }
  if (q) {
    q.addEventListener('input', render);
    q.addEventListener('focus', function () { if (q.value.trim()) render(); });
    q.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { move(1); e.preventDefault(); }
      else if (e.key === 'ArrowUp') { move(-1); e.preventDefault(); }
      else if (e.key === 'Enter') { var a = box.querySelectorAll('.hit'); var t = a[sel >= 0 ? sel : 0]; if (t) location.href = t.href; }
      else if (e.key === 'Escape') { box.hidden = true; q.blur(); }
    });
    document.addEventListener('click', function (e) { if (!e.target.closest('.search')) box.hidden = true; });
    document.addEventListener('keydown', function (e) {
      if (e.key === '/' && document.activeElement !== q) { e.preventDefault(); q.focus(); }
    });
    var m = /[?&]q=([^&]+)/.exec(location.search);
    if (m) { q.value = decodeURIComponent(m[1].replace(/\+/g, ' ')); render(); }
  }
  // contents menu on narrow screens
  var menu = document.querySelector('details.side-menu');
  if (menu) menu.addEventListener('toggle', function () { document.body.classList.toggle('side-open', menu.open); });
  document.querySelectorAll('.side a').forEach(function (a) { a.addEventListener('click', function () { if (menu) menu.open = false; }); });
})();
