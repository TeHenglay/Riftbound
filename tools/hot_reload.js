const fs = require('fs');
const { session } = require('./rbx');

(async () => {
  const filePath = process.argv[2] || 'src/StarterPlayer/StarterPlayerScripts/Riftbound/Crafting.client.lua';
  const src = fs.readFileSync(filePath, 'utf8');
  const s = await session();
  
  const luau = `
    local p = game.Players.LocalPlayer
    local oldGui = p.PlayerGui:FindFirstChild("RiftboundCrafting")
    if oldGui then
      oldGui:Destroy()
    end
    
    local sc = p.PlayerScripts.Riftbound:FindFirstChild("Crafting")
    if sc then
      sc.Enabled = false
      sc.Source = [====[${src}]====]
      task.wait(0.1)
      sc.Enabled = true
      task.wait(0.3)
      local newGui = p.PlayerGui:FindFirstChild("RiftboundCrafting")
      if newGui then
        newGui.Enabled = true
      end
      return "Successfully reloaded Crafting! New length = " .. #sc.Source .. ", GUI visible = " .. tostring(newGui and newGui.Enabled)
    end
    return "Crafting script not found in PlayerScripts.Riftbound"
  `;

  const r = await s.call('execute_luau', { code: luau, datamodel_type: 'Client' });
  console.log(r.text);
  
  // Also sync to StarterPlayerScripts in Server datamodel so it persists if player respawns
  const serverLuau = `
    local sc = game.StarterPlayer.StarterPlayerScripts.Riftbound:FindFirstChild("Crafting")
    if sc then
      sc.Source = [====[${src}]====]
      return "Also updated StarterPlayerScripts! Length = " .. #sc.Source
    end
    return "StarterPlayer script not found"
  `;
  const sr = await s.call('execute_luau', { code: serverLuau, datamodel_type: 'Server' });
  console.log(sr.text);
  
  s.close();
  process.exit(0);
})().catch(e => {
  console.error(e);
  process.exit(1);
});
