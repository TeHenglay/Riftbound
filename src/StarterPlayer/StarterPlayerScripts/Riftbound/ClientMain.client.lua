-- Riftbound client entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Remotes")

local CameraRig = require(script.Parent:WaitForChild("CameraRig"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local Controls = require(script.Parent:WaitForChild("Controls"))

CameraRig.Init()
HUD.Init(Remotes)
Controls.Init(Remotes, HUD)
