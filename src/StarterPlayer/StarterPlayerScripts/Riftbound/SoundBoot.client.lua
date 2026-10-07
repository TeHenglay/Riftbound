-- Starts the game's sound (StarterPlayerScripts.Riftbound.SoundFX). It runs on
-- its own so it needs no changes to ClientMain.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Riftbound"):WaitForChild("Remotes")
local SoundFX = require(script.Parent:WaitForChild("SoundFX"))

SoundFX.Init(Remotes)
