// Human-like drag trajectory modelled on DataDome's own signal definitions.
// 50-70 points, y wander ±5 with one mid-drag jump, 5-20ms between samples,
// slight deceleration near the end, no perfectly even spacing.
function randNum(min, max, round = false) {
  const d = max - min;
  const r = round ? Math.floor(Math.random() * d) : Math.random() * d;
  return r + min;
}

function humanTrajectory(startX, startY, distance) {
  const steps = randNum(52, 68, true);
  const yJumpAt = Math.floor(Math.random() * (steps / 2));
  let y = startY;
  const endY = startY + randNum(-22, 22, true);
  const pts = [];
  let t = randNum(80, 200, true);

  for (let i = 0; i < steps; i++) {
    const p = i / (steps - 1);
    // ease-out: fast start, slow landing — like a real finger
    const ease = 1 - Math.pow(1 - p, 2.2);
    const x = Math.round(startX + distance * ease + randNum(-1.5, 1.5));

    if (i === yJumpAt) y = endY;
    else if (i > 0) y += randNum(-5, 5, true);

    t += randNum(5, 20);
    pts.push({ x, y: Math.round(y), ts: t });
  }
  return pts;
}

function computeHash(pts) {
  const head = pts.slice(0, 100);
  let s = "";
  for (const p of head) s += p.x + "," + p.y + "|";
  let h = 0;
  for (let i = 0; i < s.length; i++) h = ((h << 5) - h + s.charCodeAt(i)) | 0;
  return h;
}

// same statistics DataDome derives, so we can verify our own trajectory
function stats(pts) {
  const dist = (a, b) => Math.hypot(b.x - a.x, b.y - a.y);
  const mean = a => a.reduce((x, y) => x + y, 0) / a.length;
  const sd = a => { const m = mean(a); return Math.sqrt(mean(a.map(v => (v - m) ** 2))); };
  const ys = pts.map(p => p.y);
  const speeds = [];
  for (let i = 0; i + 4 < pts.length; i++) {
    const a = pts[i], b = pts[i + 4];
    const dt = (b.ts - a.ts) / 1000;
    speeds.push(dist(a, b) / dt);
  }
  const first = pts[0], last = pts[pts.length - 1];
  const straight = Math.hypot(last.x - first.x, last.y - first.y);
  let travelled = 0;
  for (let i = 1; i < pts.length; i++) travelled += dist(pts[i - 1], pts[i]);
  return {
    m_cnt: pts.length,
    m_yDspA: +mean(ys).toFixed(2),
    m_yDspSD: +sd(ys).toFixed(2),
    m_spdA: +mean(speeds).toFixed(1),
    m_spdSD: +sd(speeds).toFixed(1),
    m_str8: +(straight / travelled).toFixed(4),
    m_inhsh: computeHash(pts),
  };
}

module.exports = { humanTrajectory, stats, computeHash };

if (require.main === module) {
  for (let i = 0; i < 3; i++) {
    const t = humanTrajectory(500, 450, 222);
    console.log(JSON.stringify(stats(t)));
  }
}
