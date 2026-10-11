-- Dumps the triangles of every MeshPart under TARGET (world space) with a colour
-- sampled from each part's texture, for tools/meshview.js to render offline.
-- TARGET is substituted by meshview.js.
local AS = game:GetService("AssetService")
local root = TARGET
local out = {}
local images = {}

local function texture(id)
	if id == "" then
		return nil
	end
	if images[id] == nil then
		local ok, img = pcall(function()
			return AS:CreateEditableImageAsync(Content.fromUri(id))
		end)
		images[id] = if ok then { img, img.Size, img:ReadPixelsBuffer(Vector2.zero, img.Size) } else false
	end
	return images[id] or nil
end

local function sample(tex, uv)
	if not tex then
		return 180, 180, 180
	end
	local size = tex[2]
	local x = math.clamp(math.floor((uv.X % 1) * size.X), 0, size.X - 1)
	local y = math.clamp(math.floor((uv.Y % 1) * size.Y), 0, size.Y - 1)
	local i = (y * size.X + x) * 4
	return buffer.readu8(tex[3], i), buffer.readu8(tex[3], i + 1), buffer.readu8(tex[3], i + 2)
end

local parts = if root:IsA("BasePart") then { root } else root:GetDescendants()
for _, p in parts do
	if p:IsA("MeshPart") and p.Transparency < 1 then
		local ok, em = pcall(function()
			return AS:CreateEditableMeshAsync(Content.fromUri(p.MeshId))
		end)
		if ok then
			local tex = texture(p.TextureID)
			local scale = p.Size / p.MeshSize
			local idx = {}
			local verts = {}
			local n = 0
			for _, vid in em:GetVertices() do
				n += 1
				idx[vid] = n - 1
				local w = p.CFrame * (em:GetPosition(vid) * scale)
				table.insert(verts, string.format("%.3f,%.3f,%.3f", w.X, w.Y, w.Z))
			end
			local tris = {}
			for _, fid in em:GetFaces() do
				local vs = em:GetFaceVertices(fid)
				local uvs = em:GetFaceUVs(fid)
				local uv = Vector2.zero
				for _, u in uvs do
					uv += em:GetUV(u)
				end
				uv /= math.max(#uvs, 1)
				local r, g, b = sample(tex, uv)
				table.insert(tris, string.format("%d,%d,%d,%d,%d,%d", idx[vs[1]], idx[vs[2]], idx[vs[3]], r, g, b))
			end
			table.insert(out, p.Name .. "|" .. table.concat(verts, ";") .. "|" .. table.concat(tris, ";"))
		end
	end
end
local text = table.concat(out, "\n")
-- Results over ~100k characters are cut off, so hand them back in chunks.
local old = game:GetService("ServerStorage"):FindFirstChild("MeshDump")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "MeshDump"
local n = 0
for i = 1, #text, 90000 do
	n += 1
	local v = Instance.new("StringValue")
	v.Name = tostring(n)
	v.Value = text:sub(i, i + 89999)
	v.Parent = folder
end
folder.Parent = game:GetService("ServerStorage")
return n
