-- Every player wears the classic blocky R15 body: avatar body parts and Rthro
-- proportions are swapped for the standard Roblox ones and 3D (layered)
-- clothing is taken off, while the player's own head (dynamic heads included),
-- classic shirt and pants, face, hats and skin colours stay. Works with any
-- spawn path (NationService loads characters itself), since it runs on
-- CharacterAdded.
local Players = game:GetService("Players")

local BODY_PARTS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
-- Widest a head may be, in studs (the classic torso is 2 wide).
local MAX_HEAD_WIDTH = 1.7

local function classic(description)
	for _, part in BODY_PARTS do
		description[part] = 0
	end
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	-- Classic 2D clothing only: drop layered (3D) clothing, keep rigid accessories.
	local kept = {}
	for _, accessory in description:GetAccessories(true) do
		if not accessory.IsLayered then
			table.insert(kept, accessory)
		end
	end
	description:SetAccessories(kept, true)
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
		-- Big dynamic heads dwarf the classic body: shrink any head wider than the cap.
		local head = character:FindFirstChild("Head")
		local width = head and math.max(head.Size.X, head.Size.Z) or 0
		if width > MAX_HEAD_WIDTH then
			local description = humanoid:GetAppliedDescription()
			description.HeadScale *= MAX_HEAD_WIDTH / width
			humanoid:ApplyDescription(description)
		end
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
