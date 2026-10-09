
/* Orbiloq Loader — sin dependencias. OrbiloqLoader.mount(elemento, { mode: 'orbit' | 'hop' | 'bounce' | 'progress' | 'mini', speed: 1 }) */
(function (root) {
  var B = '#1F5C8B', G = '#7ED957', W = '#FFFFFF';
  var CX = 200, CY = 200, R = 110, RX = 185, RY = 52, FRY = RY - 16;
  var FONT = "Montserrat,'Arial Rounded MT Bold',Arial,sans-serif";
  var count = 0;

  function wheel(x) {
    return '<g transform="translate(' + x + ' -5)"><circle r="8.5" fill="' + B + '" stroke="' + W + '" stroke-width="3"/>' +
      '<g class="ol-spin"><rect x="-1" y="-5.5" width="2" height="11" rx="1" fill="' + W + '"/><circle r="2.4" fill="' + W + '"/></g></g>';
  }
  function car() {
    return '<g class="ol-car"><g class="ol-body" transform="translate(0 -12)">' +
      '<g class="ol-lines" stroke="' + B + '" stroke-width="3" stroke-linecap="round" opacity="0">' +
      '<line x1="-66" y1="-30" x2="-46" y2="-30"/><line x1="-76" y1="-21" x2="-44" y2="-21"/><line x1="-62" y1="-12" x2="-44" y2="-12"/></g>' +
      '<path d="M-34 -9V-33Q-34 -38 -29 -38H13Q17 -38 19.5 -35L29 -23L34 -21Q37 -20 37 -16V-10Q37 -6 33 -6H-30Q-34 -6 -34 -9Z" fill="' + B + '"/>' +
      '<rect x="-28" y="-33" width="11" height="9" rx="2" fill="' + W + '"/><rect x="-13" y="-33" width="12" height="9" rx="2" fill="' + W + '"/>' +
      '<path d="M3 -33H12L20.5 -23H3Z" fill="' + W + '"/>' + wheel(-20) + wheel(20) + '</g></g>';
  }
  function build(o, id) {
    var mini = o.mode === 'mini', prog = o.mode === 'progress', text = !mini;
    var tr = o.mode === 'hop' ? 160 : 130;
    var ax = (0.819 * tr).toFixed(1), ay = (CY - 0.5736 * tr).toFixed(1);
    var vb = mini ? '12 88 376 236' : (prog ? '0 8 400 398' : '0 8 400 360');
    var ring = 'translate(200 218) rotate(-15)';
    var s = '<svg viewBox="' + vb + '" role="img" aria-label="Cargando" style="display:block;width:100%;height:auto;overflow:visible">' +
      '<defs><clipPath id="c' + id + '"><circle cx="' + CX + '" cy="' + CY + '" r="' + R + '"/></clipPath>' +
      (text ? '<path id="a' + id + '" d="M' + (200 - ax) + ' ' + ay + 'A' + tr + ' ' + tr + ' 0 0 1 ' + (200 + +ax) + ' ' + ay + '" fill="none"/>' : '') + '</defs>';
    if (text) s += '<text fill="' + B + '" font-family="' + FONT + '" font-size="30" font-weight="800" letter-spacing="10"><textPath href="#a' + id + '" startOffset="50%" text-anchor="middle">ORBILOQ</textPath></text>';
    s += '<g transform="' + ring + '"><path d="M' + -RX + ' 0A' + RX + ' ' + RY + ' 0 0 1 ' + RX + ' 0A' + RX + ' ' + (RY - 6) + ' 0 0 0 ' + -RX + ' 0Z" fill="' + B + '"/><g class="ol-back"></g></g>';
    s += '<g class="ol-behind"></g>';
    s += '<circle cx="' + CX + '" cy="' + CY + '" r="' + R + '" fill="' + G + '"/>' +
      '<g clip-path="url(#c' + id + ')" fill="none" stroke="' + W + '" stroke-linecap="round">' +
      '<path d="M70 178Q180 112 330 118" stroke-width="6"/><path d="M60 300Q190 232 335 206" stroke-width="10"/>' +
      '<path d="M88 342Q200 272 335 250" stroke-width="10"/><path d="M150 362Q240 302 335 292" stroke-width="10"/></g>';
    s += '<g transform="' + ring + '"><path d="M' + -RX + ' 0A' + RX + ' ' + RY + ' 0 0 0 ' + RX + ' 0A' + RX + ' ' + FRY + ' 0 0 1 ' + -RX + ' 0Z" fill="' + B + '"/><g class="ol-front">' + car() + '</g></g>';
    if (text) s += '<text x="200" y="352" text-anchor="middle" fill="' + B + '" font-family="' + FONT + '" font-size="24" font-weight="800" letter-spacing="8">BY QUIROMAR</text>';
    if (prog) s += '<rect x="60" y="374" width="230" height="12" rx="6" fill="' + B + '" opacity=".15"/><rect class="ol-bar" x="60" y="374" width="0" height="12" rx="6" fill="' + G + '"/>' +
      '<text class="ol-pct" x="340" y="386" text-anchor="middle" fill="' + B + '" font-family="' + FONT + '" font-size="18" font-weight="800">0%</text>';
    return s + '</svg>';
  }
  function smooth(x) { x = Math.max(0, Math.min(1, x)); return x * x * (3 - 2 * x); }
  function ringPose(t) {
    var front = Math.sin(t) >= 0, ry = front ? FRY : RY;
    var vx = RX * Math.sin(t), vy = -ry * Math.cos(t), sg = vx >= 0 ? 1 : -1;
    var k = Math.min(1, Math.abs(vx) / (RX * 0.35));
    return { front: front, x: RX * Math.cos(t), y: ry * Math.sin(t),
      a: Math.atan2(vy * sg, Math.abs(vx)) * 180 / Math.PI * k,
      fx: sg * Math.max(0.12, k), s: 0.8 + 0.2 * Math.sin(t) };
  }

  function mount(el, opts) {
    opts = opts || {};
    var mode = opts.mode || 'orbit';
    var id = 'ol' + (++count) + Math.random().toString(36).slice(2, 6);
    el.innerHTML = build({ mode: mode }, id);
    var svg = el.querySelector('svg'), car = svg.querySelector('.ol-car'), body = svg.querySelector('.ol-body');
    var lines = svg.querySelector('.ol-lines'), spins = svg.querySelectorAll('.ol-spin');
    var back = svg.querySelector('.ol-back'), front = svg.querySelector('.ol-front'), behind = svg.querySelector('.ol-behind');
    var bar = svg.querySelector('.ol-bar'), pct = svg.querySelector('.ol-pct');
    var reduce = root.matchMedia && root.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var speed = (opts.speed || 1) * (reduce ? 0.5 : 1);
    var target = 0, shown = 0, raf, start = performance.now();

    function put(parent) { if (car.parentNode !== parent) parent.appendChild(car); }
    function pose(x, y, a, fx, s) {
      car.setAttribute('transform', 'translate(' + x.toFixed(2) + ' ' + y.toFixed(2) + ') rotate(' + a.toFixed(2) + ') scale(' + (fx * s).toFixed(3) + ' ' + s.toFixed(3) + ')');
    }
    function frame(now) {
      var e = (now - start) / 1000 * speed, p;
      for (var i = 0; i < spins.length; i++) spins[i].setAttribute('transform', 'rotate(' + ((e * 900) % 360).toFixed(1) + ')');
      if (mode === 'orbit' || mode === 'mini') {
        var t = Math.PI * 0.9 - e * Math.PI * 2 / 3.4;
        p = ringPose(t);
        put(p.front ? front : back);
        pose(p.x, p.y, p.a, p.fx, p.s);
        lines.setAttribute('opacity', p.front ? (0.7 * Math.sin(t)).toFixed(2) : 0);
      } else if (mode === 'hop') {
        var u = (e % 3) / 3, a = Math.min(1, u / 0.85);
        var rise = smooth(Math.min(a / 0.2, (1 - a) / 0.2));
        var th = (-160 + 140 * smooth(a)) * Math.PI / 180, d = R + 3 - 52 * (1 - rise);
        put(behind);
        pose(CX + d * Math.cos(th), CY + d * Math.sin(th), th * 180 / Math.PI + 90, 1, 0.95);
        lines.setAttribute('opacity', (0.55 * rise).toFixed(2));
      } else {
        p = ringPose(Math.PI * 0.32);
        put(front);
        pose(p.x, p.y, p.a, 1, 1);
        body.setAttribute('transform', 'translate(0 ' + (-12 - Math.abs(Math.sin(e * 7)) * 3).toFixed(2) + ')');
        lines.setAttribute('opacity', (0.35 + 0.3 * Math.sin(e * 10)).toFixed(2));
        if (bar) {
          shown = target < shown - 0.2 ? target : shown + (target - shown) * 0.12;
          bar.setAttribute('width', (230 * shown).toFixed(1));
          pct.textContent = Math.round(shown * 100) + '%';
        }
      }
      if (!reduce) raf = requestAnimationFrame(frame);
    }
    frame(start);
    return {
      setProgress: function (v) { target = Math.max(0, Math.min(1, +v || 0)); if (reduce) { shown = target; frame(start); } },
      destroy: function () { cancelAnimationFrame(raf); el.innerHTML = ''; }
    };
  }
  root.OrbiloqLoader = { mount: mount };
})(window);
