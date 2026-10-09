// Pushes everything under src/ into the open Roblox Studio place through the
// Studio MCP server. File naming follows Rojo conventions:
//   Name.server.lua -> Script, Name.client.lua -> LocalScript, Name.lua -> ModuleScript
// src/<Service>/<Folder...>/<file> maps to game.<Service>.<Folder...>.<Name>.
//
// Usage: node tools/sync.js [files...]   (needs Studio open with the MCP server enabled)
//   With file paths, only those files are pushed.
const fs = require('fs');
const path = require('path');
const { session } = require('./rbx');

const SRC = path.join(__dirname, '..', 'src');

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (/\.(lua|luau)$/.test(entry.name)) out.push(full);
  }
  return out;
}

function longString(s) {
  let eq = '=';
  while (s.includes(']' + eq + ']')) eq += '=';
  return '[' + eq + '[' + s + ']' + eq + ']';
}

function toLuau(files) {
  const lines = [
    'local function ensure(parent, name)',
    '  local c = parent:FindFirstChild(name)',
    '  if not c then c = Instance.new("Folder") c.Name = name c.Parent = parent end',
    '  return c',
    'end',
    'local out = {}',
  ];
  for (const file of files) {
    const rel = path.relative(SRC, file).split(path.sep);
    const base = rel.pop();
    const m = base.match(/^(.*?)(\.server|\.client)?\.luau?$/);
    const name = m[1];
    const cls = m[2] === '.server' ? 'Script' : m[2] === '.client' ? 'LocalScript' : 'ModuleScript';
    const [service, ...folders] = rel;
    const source = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
    lines.push('do');
    lines.push(`  local parent = game:GetService(${JSON.stringify(service)})`);
    for (const f of folders) lines.push(`  parent = parent:FindFirstChild(${JSON.stringify(f)}) or ensure(parent, ${JSON.stringify(f)})`);
    lines.push(`  local s = parent:FindFirstChild(${JSON.stringify(name)})`);
    lines.push(`  if s and s.ClassName ~= ${JSON.stringify(cls)} then s:Destroy() s = nil end`);
    lines.push(`  if not s then s = Instance.new(${JSON.stringify(cls)}) s.Name = ${JSON.stringify(name)} s.Parent = parent end`);
    lines.push(`  s.Source = ${longString(source)}`);
    lines.push(`  table.insert(out, s:GetFullName())`);
    lines.push('end');
  }
  lines.push('return "Synced " .. #out .. " scripts:\\n" .. table.concat(out, "\\n")');
  return lines.join('\n');
}

(async () => {
  const files = process.argv.length > 2 ? process.argv.slice(2).map(f => path.resolve(f)) : walk(SRC);
  const s = await session();
  const r = await s.call('execute_luau', { code: toLuau(files), datamodel_type: 'Edit' });
  console.log((r.isError ? 'ERROR: ' : '') + r.text);
  s.close();
  process.exit(r.isError ? 1 : 0);
})().catch(e => { console.error(e.message); process.exit(2); });
