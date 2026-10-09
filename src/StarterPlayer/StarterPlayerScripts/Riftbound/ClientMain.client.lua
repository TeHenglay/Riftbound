-- Riftbound client entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Remotes")

local CameraRig = require(script.Parent:WaitForChild("CameraRig"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local EnemyAnimator = require(script.Parent:WaitForChild("EnemyAnimator"))
local SkillVFX = require(script.Parent:WaitForChild("SkillVFX"))
local CastAnimator = require(script.Parent:WaitForChild("CastAnimator"))
local StatusVFX = require(script.Parent:WaitForChild("StatusVFX"))
local LobbyMenu = require(script.Parent:WaitForChild("LobbyMenu"))

CameraRig.Init()
CastAnimator.Init()
SkillVFX.Init(Remotes, CameraRig)
task.spawn(EnemyAnimator.Init)
task.spawn(StatusVFX.Init)
HUD.Init(Remotes)
Controls.Init(Remotes, HUD)
LobbyMenu.Init(Remotes, HUD)
