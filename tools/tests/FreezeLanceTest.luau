-- Playtest check for Frost Gale (cone + Freeze) and Plasma Lance (thrown spear).
--   node tools/rbx.js luau @tools/tests/FreezeLanceTest.luau Server
local Debug = game.ServerStorage:WaitForChild("RiftboundDebug")
local player = game.Players:GetPlayers()[1]
local root = player.Character.HumanoidRootPart
local out = {}

local function dummies()
	local list = {}
	for _, m in workspace.RiftEnemies:GetChildren() do
		if m.Name == "Training Dummy" and m.Humanoid.Health > 0 then
			table.insert(list, m)
		end
	end
	return list
end

local look = root.CFrame.LookVector
local dir = Vector3.new(look.X, 0, look.Z).Unit
local side = dir:Cross(Vector3.yAxis)
local floor = root.Position - Vector3.new(0, 2.9, 0)

-- Frost Gale: one dummy dead ahead, one 30 degrees off, one behind (must miss).
local spots = { dir * 10, (CFrame.Angles(0, math.rad(30), 0) * dir) * 16, -dir * 8 }
for i, m in dummies() do
	m.Humanoid.Health = m.Humanoid.MaxHealth
	m:PivotTo(CFrame.new(floor + spots[i] + Vector3.new(0, 2, 0)))
end
task.wait(0.3)
Debug:Invoke("Cast", player, "FrostGale", 1, floor + dir * 12)
task.wait(0.8)
for i, m in dummies() do
	table.insert(out, string.format("gale dummy%d hp=%d frozen=%s stunned=%s speed=%.1f", i, m.Humanoid.Health, tostring(m:GetAttribute("Status_Freeze")), tostring(m:GetAttribute("Stunned")), m.Humanoid.WalkSpeed))
end
task.wait(2.2)
for i, m in dummies() do
	table.insert(out, string.format("after 3s dummy%d frozen=%s slow=%s", i, tostring(m:GetAttribute("Status_Freeze")), tostring(m:GetAttribute("Status_Slow"))))
end

-- Plasma Lance: a dummy 30 studs ahead; the spear launches after the windup.
local d = dummies()[1]
d.Humanoid.Health = d.Humanoid.MaxHealth
d:PivotTo(CFrame.new(floor + dir * 30 + Vector3.new(0, 2, 0)))
for i = 2, #dummies() do
	dummies()[i]:PivotTo(CFrame.new(floor + side * 40 + Vector3.new(0, 2, 0)))
end
task.wait(0.3)
local t0 = os.clock()
Debug:Invoke("Cast", player, "PlasmaLance", 1, floor + dir * 30)
local hitAt
while os.clock() - t0 < 1.5 do
	if d.Humanoid.Health < d.Humanoid.MaxHealth then
		hitAt = os.clock() - t0
		break
	end
	task.wait()
end
table.insert(out, string.format("lance hit after %.2fs (windup 0.22 + 30/140 flight = %.2f)", hitAt or -1, 0.22 + 27.5 / 140))
task.wait(0.2)
table.insert(out, string.format("lance burn=%s shock=%s", tostring(d:GetAttribute("Status_Burn")), tostring(d:GetAttribute("Status_Shock"))))
return table.concat(out, "\n")
