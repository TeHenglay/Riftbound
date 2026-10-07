// Minimal Studio MCP client. Usage:
//   node rbx.js <tool> '<json args>'        (studio_id is filled in automatically)
//   node rbx.js <tool> @file.json
//   node rbx.js luau @file.luau [Edit|Server|Client]
const { spawn } = require('child_process');
const fs = require('fs');

function connect() {
  const p = spawn('cmd.exe', ['/c', process.env.LOCALAPPDATA + '\\Roblox\\mcp.bat']);
  let buf = '';
  const pending = {};
  let id = 0;
  p.stdout.on('data', d => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
      if (!line) continue;
      try { const m = JSON.parse(line); if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; } } catch {}
    }
  });
  const send = (method, params, notify) => {
    const msg = { jsonrpc: '2.0', method, params };
    if (!notify) msg.id = ++id;
    p.stdin.write(JSON.stringify(msg) + '\n');
    if (!notify) return new Promise(r => (pending[msg.id] = r));
  };
  return { p, send };
}

async function session() {
  const c = connect();
  await c.send('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'riftbound-builder', version: '1' } });
  c.send('notifications/initialized', {}, true);
  let studio;
  for (let t = 0; t < 30 && !studio; t++) {
    const r = await c.send('tools/call', { name: 'list_roblox_studios', arguments: {} });
    const s = JSON.parse(r.result.content[0].text).studios;
    if (s.length) studio = s[0].id; else await new Promise(r => setTimeout(r, 1500));
  }
  if (!studio) throw new Error('No Roblox Studio instance connected');
  const call = async (name, args) => {
    const r = await c.send('tools/call', { name, arguments: { ...args, studio_id: studio } });
    if (r.error) return { isError: true, text: JSON.stringify(r.error) };
    const text = (r.result.content || []).map(x => x.type === 'text' ? x.text : `[${x.type} ${x.mimeType || ''}]`).join('\n');
    return { isError: !!r.result.isError, text, raw: r.result };
  };
  return { call, close: () => c.p.kill() };
}

module.exports = { session };

if (require.main === module) {
  (async () => {
    const [tool, argSrc, dm] = process.argv.slice(2);
    const s = await session();
    let args;
    if (tool === 'luau') {
      const code = argSrc.startsWith('@') ? fs.readFileSync(argSrc.slice(1), 'utf8') : argSrc;
      args = { code, datamodel_type: dm || 'Edit' };
    } else {
      const raw = !argSrc ? '{}' : argSrc.startsWith('@') ? fs.readFileSync(argSrc.slice(1), 'utf8') : argSrc;
      args = JSON.parse(raw);
    }
    const r = await s.call(tool === 'luau' ? 'execute_luau' : tool, args);
    if (r.raw && tool === 'screen_capture') {
      for (const c of r.raw.content) if (c.type === 'image') fs.writeFileSync(process.env.SHOT || 'shot.png', Buffer.from(c.data, 'base64'));
    }
    console.log((r.isError ? 'ERROR: ' : '') + r.text);
    s.close(); process.exit(r.isError ? 1 : 0);
  })().catch(e => { console.error(e.message); process.exit(2); });
  setTimeout(() => { console.error('TIMEOUT'); process.exit(3); }, Number(process.env.RBX_TIMEOUT || 240000));
}
