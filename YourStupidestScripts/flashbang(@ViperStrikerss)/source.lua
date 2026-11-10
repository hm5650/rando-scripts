--wowowiw it's a flashbang!!1!1 (@ViperStrikerss)
if getgenv and getgenv().FlashbangUnload then
	pcall(getgenv().FlashbangUnload)
end

-- service
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- cfg
local imgs = "https://raw.githubusercontent.com/hm5650/rando-scripts/refs/heads/main/YourStupidestScripts/flashbang(%40ViperStrikerss)/imgs/"
local folder = "flashbang"
local thetoolname = "flashbang"
local frames = 40
local spinframes = 12
local throwsp = 80
local throwup = 18
local fuse = 1.5
local bounce = 0.7
local flashrad = 50
local exploionsize = 45
local soundid = "rbxassetid://73829807478960"
local throwsoundid = "rbxassetid://7346575921"
local flashsoundid = "rbxassetid://8321372048"
local flashimgname = "thinkfastchucklenuts.png"
local impacts = {
	{ state = "black", time = 0.7 },
	{ state = "white", time = 0.06 },
	{ state = "white", time = 0.06 },
	{ state = "black", time = 0.05 },
	{ state = "white", time = 0.05 },
	{ state = "black", time = 0.04 },
	{ state = "white", time = 0.04 },
}

-- state
local connections = {}
local thrown = {}
local assets = { frames = {} }
local unloaded = false

local function log(msg)
	print("[Flashbang] " .. tostring(msg))
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Flashbang", Text = tostring(msg), Duration = 5,
		})
	end)
end

local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function getGuiParent()
	local ok, ui = pcall(function()
		return (gethui and gethui()) or game:GetService("CoreGui")
	end)
	if ok and ui then return ui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- assets
local function download(name)
	local url = imgs .. name
	for _ = 1, 3 do
		local body
		local ok = pcall(function()
			local req = (syn and syn.request) or (http and http.request) or http_request or request
			if req then
				local res = req({ Url = url, Method = "GET" })
				body = res and res.Body
			else
				body = game:HttpGet(url)
			end
		end)
		if ok then
			if body and #body > 8 and body:sub(2, 4) == "PNG" then
				return body
			end
			return nil
		end
		task.wait(0.3)
	end
	return nil
end

local function fetchAsset(name, quiet)
	local path = folder .. "/" .. name
	local body = download(name)
	if not body then
		if not quiet then warn("[Flashbang] download failed: " .. name) end
		return nil
	end
	local ok, id = pcall(function()
		writefile(path, body)
		return getcustomasset(path)
	end)
	if not ok then
		warn("[Flashbang] writefile/getcustomasset failed for " .. name .. ": " .. tostring(id))
		return nil
	end
	return id
end

if not (writefile and getcustomasset and isfolder and makefolder) then
	log("Your executor is missing writefile/getcustomasset/makefolder, can't run.")
	return
end
log("Downloading images... :p")
if not isfolder(folder) then makefolder(folder) end
local pending = 3 + frames
local frameIds = {}
local function fetchAsync(name, quiet, store, key)
	task.spawn(function()
		store[key] = fetchAsset(name, quiet)
		pending -= 1
	end)
end
fetchAsync("hold.png", false, assets, "hold")
fetchAsync("land.png", false, assets, "land")
fetchAsync(flashimgname, false, assets, "flash")
for i = 1, frames do
	fetchAsync("frame" .. i .. ".png", true, frameIds, i)
end
while pending > 0 do task.wait() end

if not assets.hold then
	log("Failed to download hold.png (check HttpGet/request support or the URL).")
	pcall(function() if isfolder(folder) then delfolder(folder) end end)
	return
end
if not assets.land then log("land.png missing, continuing without it") end
if not assets.flash then log(flashimgname .. " missing, continuing without the flash image") end

assets.frames[1] = assets.hold
for i = 1, frames do
	if not frameIds[i] then break end
	table.insert(assets.frames, frameIds[i])
end
log("Loaded " .. (#assets.frames - 1) .. " spin frames + hold + land :D\none sec plz")

do
	local preloadGui = Instance.new("ScreenGui")
	preloadGui.Name = "FlashbangPreload"
	preloadGui.Enabled = false
	preloadGui.Parent = getGuiParent()
	local list = {}
	local all = { assets.land, assets.flash }
	for _, f in ipairs(assets.frames) do table.insert(all, f) end
	for _, id in ipairs(all) do
		local img = Instance.new("ImageLabel")
		img.Image = id
		img.Parent = preloadGui
		table.insert(list, img)
	end
	local done = false
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync(list) end)
		done = true
	end)
	local t = os.clock()
	while not done and os.clock() - t < 4 do task.wait() end
	task.delay(10, function() preloadGui:Destroy() end)
end

-- containers
local fxFolder = Instance.new("Folder")
fxFolder.Name = "FlashbangFX"
fxFolder.Parent = Workspace

local flashGui = Instance.new("ScreenGui")
flashGui.Name = "FlashbangFlash"
flashGui.IgnoreGuiInset = true
flashGui.ResetOnSpawn = false
flashGui.DisplayOrder = 2147483647
flashGui.Parent = getGuiParent()

local flashImage = Instance.new("ImageLabel")
flashImage.Name = "FlashbangMeme"
flashImage.Size = UDim2.fromScale(1, 1)
flashImage.BackgroundTransparency = 1
flashImage.Image = assets.flash or ""
flashImage.ScaleType = Enum.ScaleType.Fit
flashImage.ImageTransparency = 1
flashImage.ZIndex = 2
flashImage.Parent = flashGui

local flashSound = Instance.new("Sound")
flashSound.Name = "FlashbangFlashSound"
flashSound.SoundId = flashsoundid
flashSound.Volume = 1
flashSound.Parent = SoundService

local function playSoundAt(pos, id)
	if id == "" then return end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = pos
	holder.Parent = fxFolder
	local s = Instance.new("Sound")
	s.SoundId = id
	s.RollOffMaxDistance = 150
	s.Parent = holder
	s.Ended:Once(function() pcall(function() holder:Destroy() end) end)
	s:Play()
	task.delay(15, function() pcall(function() holder:Destroy() end) end)
end

-- lighting
local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)
local lightingstuf = {
	"Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom",
	"ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows",
}
local states = {
	white = {
		cc = { Brightness = 0.5, Contrast = 8, Saturation = -1, TintColor = white },
		bloom = { Intensity = 4, Size = 56, Threshold = 0.6 },
		light = {
			Brightness = 6, Ambient = white, OutdoorAmbient = white,
			ColorShift_Top = white, ColorShift_Bottom = white,
			ExposureCompensation = 1.5, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1,
			GlobalShadows = true,
		},
	},
	black = {
		cc = { Brightness = -0.45, Contrast = 8, Saturation = -1, TintColor = white },
		bloom = { Intensity = 2, Size = 40, Threshold = 0.9 },
		light = {
			Brightness = 0, Ambient = black, OutdoorAmbient = black,
			ColorShift_Top = black, ColorShift_Bottom = black,
			ExposureCompensation = -1.5, EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0,
			GlobalShadows = true,
		},
	},
	hold = {
		cc = { Brightness = 0.85, Contrast = 8, Saturation = -1, TintColor = white },
		bloom = { Intensity = 8, Size = 56, Threshold = 0.4 },
		light = {
			Brightness = 8, Ambient = white, OutdoorAmbient = white,
			ColorShift_Top = white, ColorShift_Bottom = white,
			ExposureCompensation = 2.5, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1,
			GlobalShadows = true,
		},
	},
}

local function setProp(inst, prop, val)
	pcall(function() inst[prop] = val end)
end

local impactCC = Instance.new("ColorCorrectionEffect")
impactCC.Name = "FlashbangImpactCC"
impactCC.Enabled = false
impactCC.Parent = Lighting

local impactBloom = Instance.new("BloomEffect")
impactBloom.Name = "FlashbangImpactBloom"
impactBloom.Enabled = false
impactBloom.Intensity = 0
impactBloom.Parent = Lighting

local savedLighting
local savedAtmo = {}
local impactTweens = {}
local impactToken = 0

local function saveLighting()
	if savedLighting then return end
	savedLighting = {}
	for _, p in ipairs(lightingstuf) do
		local ok, v = pcall(function() return Lighting[p] end)
		if ok then savedLighting[p] = v end
	end
	for _, a in ipairs(Lighting:GetChildren()) do
		if a:IsA("Atmosphere") then
			savedAtmo[a] = { Density = a.Density, Haze = a.Haze }
		end
	end
end

local function cancelImpactTweens()
	for _, t in ipairs(impactTweens) do pcall(function() t:Cancel() end) end
	table.clear(impactTweens)
end

local function restoreLighting()
	cancelImpactTweens()
	if savedLighting then
		for p, v in pairs(savedLighting) do setProp(Lighting, p, v) end
		for a, v in pairs(savedAtmo) do
			if a.Parent then
				setProp(a, "Density", v.Density)
				setProp(a, "Haze", v.Haze)
			end
		end
	end
	savedLighting = nil
	table.clear(savedAtmo)
	impactCC.Enabled = false
	impactBloom.Enabled = false
	impactBloom.Intensity = 0
	impactCC.Brightness, impactCC.Contrast, impactCC.Saturation = 0, 0, 0
	impactCC.TintColor = white
end

local function applyState(name)
	local s = states[name]
	impactCC.Enabled = true
	impactBloom.Enabled = true
	for k, v in pairs(s.cc) do setProp(impactCC, k, v) end
	for k, v in pairs(s.bloom) do setProp(impactBloom, k, v) end
	for k, v in pairs(s.light) do setProp(Lighting, k, v) end
	for a in pairs(savedAtmo) do
		if a.Parent then
			setProp(a, "Density", 0)
			setProp(a, "Haze", 0)
		end
	end
end

local flashImageTween
local function doFlash()
	impactToken += 1
	local my = impactToken
	cancelImpactTweens()
	if flashImageTween then
		flashImageTween:Cancel()
		flashImageTween = nil
	end
	flashSound.TimePosition = 0
	flashSound:Play()
	saveLighting()
	flashImage.ImageTransparency = 1
	task.spawn(function()
		for _, step in ipairs(impacts) do
			if my ~= impactToken or unloaded then return end
			applyState(step.state)
			task.wait(step.time)
		end
		if my ~= impactToken or unloaded then return end
		applyState("hold")
		if assets.flash then flashImage.ImageTransparency = 0 end
		task.wait(1.2)
		if my ~= impactToken or unloaded then return end
		local info = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local function tween(inst, goal)
			local t = TweenService:Create(inst, info, goal)
			table.insert(impactTweens, t)
			t:Play()
			return t
		end
		tween(impactCC, { Brightness = 0, Contrast = 0, Saturation = 0 })
		tween(impactBloom, { Intensity = 0 })
		local lightGoal = {}
		for p, v in pairs(savedLighting or {}) do
			if p ~= "GlobalShadows" then lightGoal[p] = v end
		end
		tween(Lighting, lightGoal)
		for a, v in pairs(savedAtmo) do
			if a.Parent then tween(a, { Density = v.Density, Haze = v.Haze }) end
		end
		flashImageTween = TweenService:Create(flashImage, info, { ImageTransparency = 1 })
		flashImageTween:Play()
		task.wait(3 + 0.1)
		if my ~= impactToken or unloaded then return end
		restoreLighting()
	end)
end

local function flashNear(pos)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local charDist = root and (root.Position - pos).Magnitude or math.huge
	local cam = Workspace.CurrentCamera
	local camDist = cam and (cam.CFrame.Position - pos).Magnitude or math.huge
	if charDist <= flashrad or camDist <= flashrad then
		doFlash()
	end
end

-- camera shake
local shakenames = "evilflashbangshake"
local shakeIntensity = 0
local shakeEndTime = 0
local shakeBound = false

local function stopShake()
	shakeIntensity = 0
	shakeEndTime = 0
	if shakeBound then
		shakeBound = false
		pcall(function() RunService:UnbindFromRenderStep(shakenames) end)
	end
end

local function shakeCamera(pos)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local dist = (cam.CFrame.Position - pos).Magnitude
	local maxDist = flashrad * 2.5
	if dist > maxDist then return end
	local falloff = 1 - (dist / maxDist)
	local intensity = 4 * falloff * falloff
	if intensity < 0.05 then return end
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeEndTime = os.clock() + 1.1
	if shakeBound then return end
	shakeBound = true
	RunService:BindToRenderStep(shakenames, Enum.RenderPriority.Camera.Value + 1, function()
		local c = Workspace.CurrentCamera
		if not c then return end
		if os.clock() >= shakeEndTime then
			stopShake()
			return
		end
		local remaining = (shakeEndTime - os.clock()) / 1.1
		local amp = shakeIntensity * remaining * remaining
		local rx = (math.random() - 0.5) * 2 * amp * 0.05
		local ry = (math.random() - 0.5) * 2 * amp * 0.05
		local rz = (math.random() - 0.5) * 2 * amp * 0.05
		c.CFrame = c.CFrame * CFrame.Angles(rx, ry, rz)
	end)
end

-- explosion
local function fxPart(shape, size, cf, transparency)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = white
	p.Transparency = transparency
	p.Parent = fxFolder
	return p
end

local function explosionFX(pos)
	local cf = CFrame.new(pos)
	local big = Vector3.new(1, 1, 1) * exploionsize
	local core = fxPart(Enum.PartType.Ball, Vector3.new(1, 1, 1), cf, 0)
	TweenService:Create(core, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = big }):Play()
	TweenService:Create(core, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	local shell = fxPart(Enum.PartType.Ball, Vector3.new(1, 1, 1), cf, 0.5)
	TweenService:Create(shell, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = big * 1.9, Transparency = 1 }):Play()
	local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.5, 1, 1), cf * CFrame.Angles(0, 0, math.rad(90)), 0)
	TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.5, exploionsize * 2.6, exploionsize * 2.6), Transparency = 1,
	}):Play()
	local light = Instance.new("PointLight")
	light.Color = white
	light.Brightness = 40
	light.Range = 60
	light.Shadows = false
	light.Parent = core
	TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 }):Play()
	local emitterPart = fxPart(Enum.PartType.Block, Vector3.new(1, 1, 1), cf, 1)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.25, 0.6)
	sparks.Speed = NumberRange.new(50, 110)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) })
	sparks.Color = ColorSequence.new(white)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Parent = emitterPart
	sparks:Emit(120)
	task.delay(1.5, function()
		for _, o in ipairs({ core, shell, ring, emitterPart }) do
			pcall(function() o:Destroy() end)
		end
	end)
end

local function smokeFX(pos)
	local smokePart = Instance.new("Part")
	smokePart.Anchored = true
	smokePart.CanCollide = false
	smokePart.CanTouch = false
	smokePart.CanQuery = false
	smokePart.Transparency = 1
	smokePart.Size = Vector3.new(1, 1, 1)
	smokePart.CFrame = CFrame.new(pos)
	smokePart.Parent = fxFolder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(2.5, 4)
	smoke.Speed = NumberRange.new(3, 8)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4),
		NumberSequenceKeypoint.new(0.3, 9),
		NumberSequenceKeypoint.new(1, 14),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.4, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 120))
	smoke.LightEmission = 0
	smoke.LightInfluence = 0.5
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Parent = smokePart
	smoke:Emit(50)
	task.delay(4.2, function()
		pcall(function() smokePart:Destroy() end)
	end)
end

-- grenade
local function makeStack(part, studs)
	local bb = Instance.new("BillboardGui")
	bb.Name = "FlashbangImage"
	bb.Adornee = part
	bb.Size = UDim2.new(studs, 0, studs, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = part
	local function label(image, visible)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = image or ""
		img.ScaleType = Enum.ScaleType.Fit
		img.ImageTransparency = visible and 0 or 1
		img.Parent = bb
		return img
	end
	local labels = {}
	for i, id in ipairs(assets.frames) do
		labels[i] = label(id, i == 2)
	end
	local idx = labels[2] and 2 or 1
	if idx == 1 then labels[1].ImageTransparency = 0 end
	local landImg = label(assets.land, false)
	return { bb = bb, labels = labels, landImg = landImg, idx = idx }
end

local function explode(part, st, conns)
	if part:GetAttribute("Landed") then return end
	part:SetAttribute("Landed", true)
	for _, c in ipairs(conns) do c:Disconnect() end
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	st.labels[st.idx].ImageTransparency = 1
	st.landImg.ImageTransparency = 0
	local pos = part.Position
	playSoundAt(pos, soundid)
	explosionFX(pos)
	smokeFX(pos)
	shakeCamera(pos)
	task.delay(0.02, function()
		if unloaded then return end
		flashNear(pos)
	end)
	task.delay(1.5, function()
		if unloaded or not part.Parent then return end
		local fadeInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(st.landImg, fadeInfo, { ImageTransparency = 1 }):Play()
		task.wait(1.6)
		thrown[part] = nil
		if part.Parent then part:Destroy() end
	end)
end

local function throwFlashbang(origin, target, inheritVel)
	local dir = target - origin
	dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, -1)
	local part = Instance.new("Part")
	part.Name = "FlashbangThrown"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.CanCollide = true
	part.CanTouch = false
	part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1, bounce, 1, 100)
	part.Position = origin + dir * 3
	part.Parent = Workspace
	thrown[part] = true
	local st = makeStack(part, 3)
	part.AssemblyLinearVelocity = dir * throwsp + Vector3.new(0, throwup, 0) + (inheritVel or Vector3.zero)
	part.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
	local conns = {}
	local t0 = os.clock()
	local acc = 0
	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		if part:GetAttribute("Landed") then return end
		if not part.Parent then
			thrown[part] = nil
			for _, c in ipairs(conns) do c:Disconnect() end
			return
		end
		if #st.labels > 1 then
			acc += dt
			local step = 1 / spinframes
			while acc >= step do
				acc -= step
				st.labels[st.idx].ImageTransparency = 1
				st.idx = st.idx % #st.labels + 1
				st.labels[st.idx].ImageTransparency = 0
			end
		end
		if os.clock() - t0 >= fuse then
			explode(part, st, conns)
		end
	end))
	playSoundAt(origin, throwsoundid)
end

-- tool
local function createTool()
	local tool = Instance.new("Tool")
	tool.Name = thetoolname
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "holy genericalism just a flashbang??????"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local bb = Instance.new("BillboardGui")
	bb.Name = "FlashbangImage"
	bb.Adornee = handle
	bb.Size = UDim2.new(2.5, 0, 2.5, 0)
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = handle
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = assets.hold
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	track(tool.Activated:Connect(function()
		if unloaded then return end
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local origin = handle.Position + Vector3.new(0, 0.5, 0)
		local target = Mouse.Hit and Mouse.Hit.Position or (root.Position + root.CFrame.LookVector * 50)
		throwFlashbang(origin, target, root.AssemblyLinearVelocity)
	end))
	return tool
end

local function giveTool()
	if unloaded then return end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")
	if backpack:FindFirstChild(thetoolname) then return end
	local char = LocalPlayer.Character
	if char and char:FindFirstChild(thetoolname) then return end
	local tool = createTool()
	tool.Parent = backpack
	log("tool haz been craeted!!!")
	task.defer(function()
		local c = LocalPlayer.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum and tool.Parent == backpack then
			pcall(function() hum:EquipTool(tool) end)
		end
	end)
end

local okGive, errGive = pcall(giveTool)
if not okGive then log("giveTool error: " .. tostring(errGive)) end
track(LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	giveTool()
end))

-- unload button
local uiGui = Instance.new("ScreenGui")
uiGui.Name = "FlashbangUI"
uiGui.ResetOnSpawn = false
uiGui.Parent = getGuiParent()

local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(130, 36)
btn.Position = UDim2.new(1, -150, 0, 70)
btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.Text = "Unload Flashbang"
btn.AutoButtonColor = true
btn.Parent = uiGui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local moved = false
do
	local dragging, dragStart, startPos
	track(btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, btn.Position
			moved = false
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			if d.Magnitude > 6 then moved = true end
			btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
end

local function unload()
	if unloaded then return end
	unloaded = true
	impactToken += 1
	stopShake()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	for p in pairs(thrown) do pcall(function() p:Destroy() end) end
	table.clear(thrown)
	local char = LocalPlayer.Character
	if char then
		local t = char:FindFirstChild(thetoolname)
		if t then t:Destroy() end
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		local t = backpack:FindFirstChild(thetoolname)
		if t then t:Destroy() end
	end
	pcall(restoreLighting)
	pcall(function() impactCC:Destroy() end)
	pcall(function() impactBloom:Destroy() end)
	pcall(function() fxFolder:Destroy() end)
	pcall(function() flashGui:Destroy() end)
	pcall(function() flashSound:Destroy() end)
	pcall(function() uiGui:Destroy() end)
	pcall(function()
		if isfolder(folder) then delfolder(folder) end
	end)
	if getgenv then getgenv().FlashbangUnload = nil end
end

if getgenv then getgenv().FlashbangUnload = unload end
track(btn.MouseButton1Click:Connect(function()
	if moved then moved = false return end
	unload()
end))
