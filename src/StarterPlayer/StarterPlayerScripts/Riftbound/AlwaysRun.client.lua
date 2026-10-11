-- Always run, never walk: Roblox's Animate script blends a walk animation in
-- whenever you move slower than full speed (shield up, flask sip, foe slows).
-- This points the character's walk animation at its run animation, so moving
-- always looks like running. The Animate script reloads an animation as soon
-- as its id changes, and the swap is redone if the avatar loader resets it.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function firstAnimation(folder)
	return folder and folder:FindFirstChildWhichIsA("Animation")
end

local function hook(character)
	local animate = character:WaitForChild("Animate", 10)
	local walkFolder = animate and animate:WaitForChild("walk", 10)
	local runFolder = animate and animate:WaitForChild("run", 10)
	if not walkFolder or not runFolder then
		return
	end
	local function sync()
		local walk, run = firstAnimation(walkFolder), firstAnimation(runFolder)
		if walk and run and run.AnimationId ~= "" and walk.AnimationId ~= run.AnimationId then
			walk.AnimationId = run.AnimationId
		end
	end
	local function watch(folder)
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Animation") then
				child:GetPropertyChangedSignal("AnimationId"):Connect(sync)
				task.defer(sync)
			end
		end)
		for _, child in folder:GetChildren() do
			if child:IsA("Animation") then
				child:GetPropertyChangedSignal("AnimationId"):Connect(sync)
			end
		end
	end
	watch(walkFolder)
	watch(runFolder)
	sync()
end

player.CharacterAdded:Connect(hook)
if player.Character then
	task.spawn(hook, player.Character)
end
