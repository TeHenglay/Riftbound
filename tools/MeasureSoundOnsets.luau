-- Measures how long each sound file is silent before it starts (leading silence).
-- Run during Play in the Client datamodel:
--   node tools/rbx.js luau @tools/MeasureSoundOnsets.luau Client
-- Prints "id onset peak" per sound; onset is seconds until the level first passes THRESHOLD.
local THRESHOLD = 0.02
local TIMEOUT = 2.5
local ids = { 9112752570,9112853422,9113074084,9113445305,9113520892,9113840096,9113840530,9113849375,9113980319,9113980644,9114171855,9114172114,9114224675,9114277338,9114277403,9114277601,9114444008,9114446277,9114446802,9114446852,9114554567,9114554766,9114855870,9114856749,9116274415,9116274992,9116275998,9116276946,9116394545,9116394876,9116395085,9116395089,9118598279,9118609396,9118612665,9118613208,9118614058,9118623491,9118661490,9118762653,9118882814,9118884046,9119072660,9119072674,9119447936,9119717523,9119717529,9119747138,9120021794,9120585252,9120589380,9120610106,9120769331,9120985853,9125550012,9125629904,9125645963,9125646252,9125646705,9125646712,9125646934,9125647857,9125647922,9125648134,9125648149,9125652949,9125869504,9125871203 }

local folder = Instance.new("Folder")
folder.Name = "OnsetProbe"
folder.Parent = workspace
local out = {}
for _, id in ids do
	local playerObj = Instance.new("AudioPlayer")
	playerObj.Asset = "rbxassetid://" .. id
	playerObj.Parent = folder
	local analyzer = Instance.new("AudioAnalyzer")
	analyzer.Parent = folder
	local wire = Instance.new("Wire")
	wire.SourceInstance = playerObj
	wire.TargetInstance = analyzer
	wire.Parent = folder
	local t0 = os.clock()
	while not playerObj.IsReady and os.clock() - t0 < 10 do
		task.wait()
	end
	local onset, peak = -1, 0
	if playerObj.IsReady then
		playerObj:Play()
		local start = os.clock()
		while os.clock() - start < TIMEOUT do
			task.wait()
			local level = analyzer.PeakLevel
			peak = math.max(peak, level)
			if onset < 0 and level > THRESHOLD then
				onset = os.clock() - start
			end
		end
		playerObj:Stop()
	end
	table.insert(out, string.format("%d %.3f %.3f%s", id, onset, peak, if playerObj.IsReady then "" else " NOT_READY"))
	playerObj:Destroy()
	analyzer:Destroy()
	wire:Destroy()
end
folder:Destroy()
print("ONSETS\n" .. table.concat(out, "\n"))
return table.concat(out, "\n")
