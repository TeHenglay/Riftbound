-- Every player wears the classic blocky R15 body: avatar body parts, dynamic
-- heads and Rthro proportions are swapped for the standard Roblox ones, while
-- clothing, face, hair, accessories and skin colours are kept. Works with any
-- spawn path (NationService loads characters itself), since it runs on
-- CharacterAdded.
local Players = game:GetService("Players")

local BODY_PARTS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

local function classic(description)
	for _, part in BODY_PARTS do
		description[part] = 0
	end
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	description.HeadScale = 1
	return description
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	if not player:HasAppearanceLoaded() then
		local loaded = false
		task.delay(10, function()
			loaded = true
		end)
		local conn = player.CharacterAppearanceLoaded:Connect(function()
			loaded = true
		end)
		while not loaded do
			task.wait()
		end
		conn:Disconnect()
	end
	if player.Character ~= character or not humanoid.Parent then
		return
	end
	local ok, err = pcall(function()
		humanoid:ApplyDescription(classic(humanoid:GetAppliedDescription()))
	end)
	if not ok then
		warn("ClassicAvatar: " .. tostring(err))
	end
end

local function watch(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
