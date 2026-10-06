--!strict
-- Minimal loadout HUD and skill hit effects. Placeholder until the real UI milestone.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Fusions = require(Shared.Fusions)
local Types = require(Shared.Types)

local SLOT_ORDER: { Types.SlotId } = { "Attack", "Special", "Cast", "Dash" }
local SLOT_KEYS: { [Types.SlotId]: string } = {
	Attack = "LMB",
	Special = "RMB",
	Cast = "Q",
	Dash = "Space",
}

local HudController = {}

local label: TextLabel
local currentLoadout: Types.Loadout? = nil
local selected: Types.SlotId = "Attack"

local function describeSlot(slot: Types.SlotId, state: Types.SlotState): string
	local parts = {}
	if state.fusion then
		local fusion = Fusions.get(state.fusion)
		table.insert(parts, "[" .. (if fusion then fusion.displayName else state.fusion) .. "]")
	end
	for element, level in state.elements do
		table.insert(parts, element .. " " .. level)
	end
	local ready = Fusions.available(state)
	if #ready > 0 and not state.fusion then
		table.insert(parts, "(F: fuse " .. ready[1].displayName .. ")")
	end
	local marker = if slot == selected then "> " else "  "
	local body = if #parts > 0 then table.concat(parts, ", ") else "-"
	return string.format("%s%s [%s]: %s", marker, slot, SLOT_KEYS[slot], body)
end

local function render()
	if not currentLoadout then
		return
	end
	local lines = { "LOADOUT  (1-6 infuse, Tab slot, F fuse)" }
	for _, slot in SLOT_ORDER do
		table.insert(lines, describeSlot(slot, currentLoadout[slot]))
	end
	label.Text = table.concat(lines, "\n")
end

function HudController.setLoadout(loadout: Types.Loadout)
	currentLoadout = loadout
	render()
end

function HudController.setSelected(slot: Types.SlotId)
	selected = slot
	render()
end

-- Expanding, fading sphere where a skill landed.
function HudController.playSkillFx(position: Vector3, radius: number, color: Color3)
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = color
	sphere.Transparency = 0.4
	sphere.Size = Vector3.one * 1
	sphere.Position = position
	sphere.Parent = workspace

	local tween = TweenService:Create(sphere, TweenInfo.new(0.25), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(sphere, 0.3)
end

function HudController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadoutHud"
	gui.ResetOnSpawn = false

	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 16, 1, -16)
	label.Size = UDim2.fromOffset(460, 130)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.4
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Code
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "Loading loadout..."
	label.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return HudController
