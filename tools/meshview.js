// Renders MeshParts from the open Studio place to a PNG offline (front, side,
// back and top views), for checking AI-generated meshes when the Studio
// viewport can't be captured.
// Usage: node tools/meshview.js <Instance path, e.g. workspace.FoeStage.Gen_X> <out.png> [px]
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { session } = require('./rbx');

function png(w, h, rgb) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0;
    rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  }
  const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = b => { let c = 0xffffffff; for (const x of b) c = crcTable[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
    return Buffer.concat([len, td, c]);
  };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

// Views: screen x/y and depth (bigger = nearer) from a world point.
const VIEWS = [
  ['front +Z', v => [v[0], v[1], v[2]]],
  ['side +X', v => [-v[2], v[1], v[0]]],
  ['back -Z', v => [-v[0], v[1], -v[2]]],
  ['top', v => [v[0], -v[2], v[1]]],
];

// TINT=1 colours each part differently, to check how a mesh was split.
const TINTS = [[1.6, 0.6, 0.6], [0.6, 1.6, 0.6], [0.6, 0.6, 1.8], [1.6, 1.6, 0.5], [1.5, 0.6, 1.6], [0.6, 1.5, 1.6]];

(async () => {
  const [target, outFile, pxArg] = process.argv.slice(2);
  const px = Number(pxArg || 360);
  const code = fs.readFileSync(path.join(__dirname, 'meshdump.luau'), 'utf8').replace('local root = TARGET', `local root = ${target}`);
  const s = await session();
  const r = await s.call('execute_luau', { code, datamodel_type: 'Edit' });
  if (r.isError) throw new Error(r.text);
  let text = '';
  for (let i = 1; i <= Number(r.text.trim()); i++) {
    text += (await s.call('execute_luau', { code: `return game.ServerStorage.MeshDump["${i}"].Value`, datamodel_type: 'Edit' })).text;
  }
  await s.call('execute_luau', { code: 'game.ServerStorage.MeshDump:Destroy() return 0', datamodel_type: 'Edit' });
  s.close();
  const meshes = text.trim().split('\n').filter(Boolean).map(line => {
    const [name, vs, ts] = line.split('|');
    return { name, verts: vs.split(';').map(v => v.split(',').map(Number)), tris: ts.split(';').map(t => t.split(',').map(Number)) };
  });
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
  for (const m of meshes) for (const v of m.verts) for (let i = 0; i < 3; i++) { mn[i] = Math.min(mn[i], v[i]); mx[i] = Math.max(mx[i], v[i]); }
  const centre = mn.map((a, i) => (a + mx[i]) / 2);
  const span = Math.max(mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]) * 1.08;
  const W = px * VIEWS.length, H = px;
  const img = Buffer.alloc(W * H * 3, 40);
  const depth = new Float32Array(W * H).fill(-1e9);
  VIEWS.forEach(([, proj], vi) => {
    meshes.forEach((m, mi) => {
      const tint = process.env.TINT ? TINTS[mi % TINTS.length] : [1, 1, 1];
      const sv = m.verts.map(v => {
        const p = proj([v[0] - centre[0], v[1] - centre[1], v[2] - centre[2]]);
        return [vi * px + px / 2 + (p[0] / span) * px, px / 2 - (p[1] / span) * px, p[2], v];
      });
      for (const t of m.tris) {
        const a = sv[t[0]], b = sv[t[1]], c = sv[t[2]];
        if (!a || !b || !c) continue;
        // World normal for simple shading (light from the viewer and above).
        const u = [b[3][0] - a[3][0], b[3][1] - a[3][1], b[3][2] - a[3][2]];
        const w = [c[3][0] - a[3][0], c[3][1] - a[3][1], c[3][2] - a[3][2]];
        const n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]];
        const nl = Math.hypot(...n) || 1;
        const nv = proj([n[0] / nl, n[1] / nl, n[2] / nl]);
        const shade = 0.45 + 0.55 * Math.min(1, Math.abs(nv[2]) * 0.8 + Math.max(0, nv[1]) * 0.3);
        const minX = Math.max(vi * px, Math.floor(Math.min(a[0], b[0], c[0])));
        const maxX = Math.min((vi + 1) * px - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
        const minY = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1])));
        const maxY = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
        const area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
        if (Math.abs(area) < 1e-9) continue;
        for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) {
          const w0 = ((b[0] - x) * (c[1] - y) - (b[1] - y) * (c[0] - x)) / area;
          const w1 = ((c[0] - x) * (a[1] - y) - (c[1] - y) * (a[0] - x)) / area;
          const w2 = 1 - w0 - w1;
          if (w0 < 0 || w1 < 0 || w2 < 0) continue;
          const z = w0 * a[2] + w1 * b[2] + w2 * c[2];
          const k = y * W + x;
          if (z <= depth[k]) continue;
          depth[k] = z;
          img[k * 3] = Math.min(255, t[3] * shade * tint[0]); img[k * 3 + 1] = Math.min(255, t[4] * shade * tint[1]); img[k * 3 + 2] = Math.min(255, t[5] * shade * tint[2]);
        }
      }
    });
  });
  fs.writeFileSync(outFile, png(W, H, img));
  console.log(`wrote ${outFile}: ${meshes.length} meshes, bounds ${mn.map(x => x.toFixed(2))} .. ${mx.map(x => x.toFixed(2))}`);
})().catch(e => { console.error(e.message); process.exit(2); });
