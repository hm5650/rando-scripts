--bouncy ballz!! (@Curious_12344)
if getgenv and getgenv().BouncyBallzUnload then
	pcall(getgenv().BouncyBallzUnload)
end

-- service
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- cfg
local base = "https://raw.githubusercontent.com/hm5650/rando-scripts/refs/heads/main/YourStupidestScripts/BouncyBallz(%40Curious_12344)/assets/"
local folder = "BouncyBallz"
local ballcount = 4
local soundname = "bounce_ball.mp3"
local ballsize = 4
local bouncy = 0.85
local maxballs = 30
local kickpower = 2.2
local kicklift = 0.5
local kickcd = 0.25
local bouncemin = 10
local clickpad = 10
local holdtime = 0.45
local throwsp = 70

-- state
local connections = {}
local balls = {}
local ballid = 0
local assets = { imgs = {}, sound = nil }
local unloaded = false

local function log(msg)
	print("[BouncyBallz] " .. tostring(msg))
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "BouncyBallz", Text = tostring(msg), Duration = 5,
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
local function validBody(body, name)
	if not body or #body < 16 then return false end
	if name:sub(-4) == ".png" then
		return body:sub(2, 4) == "PNG"
	end
	return body:sub(1, 3) == "ID3" or body:byte(1) == 0xFF
end

local function download(name)
	local url = base .. name
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
			if validBody(body, name) then return body end
			return nil
		end
		task.wait(0.3)
	end
	return nil
end

local function fetchAsset(name)
	local body = download(name)
	if not body then
		warn("[BouncyBallz] download failed: " .. name)
		return nil
	end
	local ok, id = pcall(function()
		writefile(folder .. "/" .. name, body)
		return getcustomasset(folder .. "/" .. name)
	end)
	if not ok then
		warn("[BouncyBallz] writefile/getcustomasset failed for " .. name .. ": " .. tostring(id))
		return nil
	end
	return id
end

if not (writefile and getcustomasset and isfolder and makefolder) then
	log("Your executor is missing writefile/getcustomasset/makefolder, can't run.")
	return
end

log("Downloading balls... :p")
if not isfolder(folder) then makefolder(folder) end

local pending = ballcount + 1
local imgIds = {}
for i = 1, ballcount do
	task.spawn(function()
		imgIds[i] = fetchAsset("ball" .. i .. ".png")
		pending -= 1
	end)
end
task.spawn(function()
	assets.sound = fetchAsset(soundname)
	pending -= 1
end)
while pending > 0 do task.wait() end

for i = 1, ballcount do
	if imgIds[i] then table.insert(assets.imgs, imgIds[i]) end
end
if #assets.imgs == 0 then
	log("Couldn't download any ball images (check HttpGet/request support or the URL).")
	pcall(function() if isfolder(folder) then delfolder(folder) end end)
	return
end
if not assets.sound then log("bounce_ball.mp3 missing, balls will be silent") end

do
	local preloadGui = Instance.new("ScreenGui")
	preloadGui.Name = "BouncyBallzPreload"
	preloadGui.Enabled = false
	preloadGui.Parent = getGuiParent()
	local list = {}
	for _, id in ipairs(assets.imgs) do
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
log("Loaded " .. #assets.imgs .. " ball image(s) :D")

-- containers
local fxFolder = Instance.new("Folder")
fxFolder.Name = "BouncyBallzFX"
fxFolder.Parent = Workspace

-- balls
local function noCollideWithChar(part)
	local char = LocalPlayer.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local nc = Instance.new("NoCollisionConstraint")
			nc.Part0 = part
			nc.Part1 = d
			nc.Parent = part
		end
	end
end

local function removeBall(part, instant)
	local b = balls[part]
	if not b then return end
	balls[part] = nil
	if instant or not b.img.Parent then
		pcall(function() part:Destroy() end)
		return
	end
	part.Anchored = true
	local tw = TweenService:Create(b.img, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		ImageTransparency = 1,
		Size = UDim2.fromScale(1.3, 1.3),
		Position = UDim2.fromScale(-0.15, -0.15),
	})
	tw:Play()
	task.delay(0.2, function() pcall(function() part:Destroy() end) end)
end

local function spawnBall(pos, vel, imgId, kickDelay)
	if unloaded then return end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root and not pos then return end

	local count, oldest, oldestId = 0, nil, math.huge
	for p, b in pairs(balls) do
		count += 1
		if b.id < oldestId then oldest, oldestId = p, b.id end
	end
	if count >= maxballs and oldest then removeBall(oldest, true) end

	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	pos = pos or (root.Position + look * 6 + Vector3.new(0, 4, 0))
	vel = vel or (look * 20 + Vector3.new(0, 15, 0))
	imgId = imgId or assets.imgs[math.random(#assets.imgs)]
	local part = Instance.new("Part")
	part.Name = "BouncyBall"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(ballsize, ballsize, ballsize)
	part.Transparency = 1
	part.CanCollide = true
	part.CanTouch = false
	part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, bouncy, 1, 1)
	part.Position = pos
	part.Parent = fxFolder

	local bb = Instance.new("BillboardGui")
	bb.Name = "BallImage"
	bb.Adornee = part
	bb.Size = UDim2.new(ballsize, 0, ballsize, 0)
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = part
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = imgId
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	local snd
	if assets.sound then
		snd = Instance.new("Sound")
		snd.SoundId = assets.sound
		snd.RollOffMaxDistance = 120
		snd.Parent = part
	end

	noCollideWithChar(part)
	part.AssemblyLinearVelocity = vel

	ballid += 1
	balls[part] = {
		id = ballid, img = img, sound = snd, imgId = imgId,
		lastVel = part.AssemblyLinearVelocity,
		kickT = kickDelay and (os.clock() + kickDelay) or 0, bounceT = 0, rot = 0,
	}
end

track(RunService.Heartbeat:Connect(function(dt)
	if unloaded then return end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local cam = Workspace.CurrentCamera
	local now = os.clock()
	for part, b in pairs(balls) do
		if not part.Parent or part.Position.Y < Workspace.FallenPartsDestroyHeight + 5 then
			removeBall(part, true)
		else
			local vel = part.AssemblyLinearVelocity
			local kicked = false
			if root and hum and now - b.kickT > kickcd then
				local md = hum.MoveDirection
				if md.Magnitude > 0.1 then
					local off = part.Position - root.Position
					local flat = Vector3.new(off.X, 0, off.Z).Magnitude
					if flat < ballsize / 2 + 2.2 and math.abs(off.Y) < ballsize / 2 + 3.5 then
						local dir = Vector3.new(md.X, 0, md.Z).Unit
						local ws = hum.WalkSpeed
						vel = dir * ws * kickpower + Vector3.new(0, ws * kicklift, 0)
						part.AssemblyLinearVelocity = vel
						b.kickT = now
						kicked = true
					end
				end
			end
			if not kicked then
				local delta = (vel - b.lastVel).Magnitude
				if delta > bouncemin and now - b.bounceT > 0.06 then
					b.bounceT = now
					if b.sound then
						b.sound.Volume = math.clamp(delta / 60, 0.15, 1)
						b.sound.PlaybackSpeed = 0.9 + math.random() * 0.2
						b.sound:Play()
					end
				end
			end
			b.lastVel = vel
			if cam then
				b.rot += math.deg(vel:Dot(cam.CFrame.RightVector) / (ballsize / 2)) * dt
				b.rot %= 360
				b.img.Rotation = b.rot
			end
		end
	end
end))

pcall(function() Mouse.TargetFilter = fxFolder end)
local held = {}
local toolRef, toolImg
local suppressThrow = false

local countGui = Instance.new("ScreenGui")
countGui.Name = "BouncyBallzCount"
countGui.ResetOnSpawn = false
countGui.Enabled = false
countGui.Parent = getGuiParent()
local countFrame = Instance.new("Frame")
countFrame.Size = UDim2.fromOffset(110, 36)
countFrame.Position = UDim2.new(0.5, -55, 1, -130)
countFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
countFrame.Parent = countGui
local countIcon = Instance.new("ImageLabel")
countIcon.BackgroundTransparency = 1
countIcon.Size = UDim2.fromOffset(28, 28)
countIcon.Position = UDim2.fromOffset(6, 4)
countIcon.ScaleType = Enum.ScaleType.Fit
countIcon.Parent = countFrame
local countLabel = Instance.new("TextLabel")
countLabel.BackgroundTransparency = 1
countLabel.Size = UDim2.new(1, -40, 1, 0)
countLabel.Position = UDim2.fromOffset(38, 0)
countLabel.TextColor3 = Color3.new(1, 1, 1)
countLabel.Font = Enum.Font.GothamBold
countLabel.TextSize = 14
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = countFrame

local function refreshHeld()
	local n = #held
	countGui.Enabled = n > 0
	countLabel.Text = "Balls: " .. n
	countIcon.Image = held[n] or ""
	if toolImg then toolImg.Image = held[n] or "" end
end

local function destroyTool()
	if toolRef then pcall(function() toolRef:Destroy() end) end
	toolRef, toolImg = nil, nil
end

local function throwBall(handle)
	if unloaded or suppressThrow or #held == 0 then return end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin = handle.Position + Vector3.new(0, 0.5, 0)
	local target = Mouse.Hit and Mouse.Hit.Position or (root.Position + root.CFrame.LookVector * 50)
	local off = target - origin
	local dir = off.Magnitude > 0 and off.Unit or root.CFrame.LookVector
	local lift = math.clamp(off.Magnitude * 0.12, 2, 25)
	local id = table.remove(held)
	spawnBall(origin + dir * 3, dir * throwsp + Vector3.new(0, lift, 0) + root.AssemblyLinearVelocity, id, 0.5)
	refreshHeld()
	if #held == 0 then destroyTool() end
end

local function giveTool()
	if unloaded or #held == 0 then return end
	if toolRef and toolRef.Parent then return end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")
	local tool = Instance.new("Tool")
	tool.Name = "Bouncy Ball"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "js throw me gng 🥀🥀"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local bb = Instance.new("BillboardGui")
	bb.Adornee = handle
	bb.Size = UDim2.new(2, 0, 2, 0)
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = handle
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = held[#held] or ""
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = bb

	track(tool.Activated:Connect(function() throwBall(handle) end))
	toolRef, toolImg = tool, img
	tool.Parent = backpack
	task.defer(function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and tool.Parent == backpack then
			pcall(function() hum:EquipTool(tool) end)
		end
	end)
end

local function grabBall(part)
	local b = balls[part]
	if not b then return end
	table.insert(held, b.imgId)
	removeBall(part, true)
	refreshHeld()
	giveTool()
end

local function ballAtScreen(pos)
	local cam = Workspace.CurrentCamera
	if not cam then return nil end
	local vp = Vector2.new(pos.X, pos.Y) + GuiService:GetGuiInset()
	local pxPerStud = cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
	local best, bestDepth = nil, math.huge
	for part in pairs(balls) do
		local sp, onScreen = cam:WorldToViewportPoint(part.Position)
		if onScreen and sp.Z > 0 then
			local radius = (ballsize / 2) * pxPerStud / sp.Z + clickpad
			if (Vector2.new(sp.X, sp.Y) - vp).Magnitude <= radius and sp.Z < bestDepth then
				best, bestDepth = part, sp.Z
			end
		end
	end
	return best
end
local function holdInput(input)
	suppressThrow = true
	input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			task.delay(0.15, function() suppressThrow = false end)
		end
	end)
end

track(UserInputService.InputBegan:Connect(function(input, processed)
	if unloaded or processed then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		local part = ballAtScreen(input.Position)
		if part then
			holdInput(input)
			removeBall(part)
		end
	elseif t == Enum.UserInputType.MouseButton2 then
		local part = ballAtScreen(input.Position)
		if part then grabBall(part) end
	elseif t == Enum.UserInputType.Touch then
		local part = ballAtScreen(input.Position)
		if not part then return end
		holdInput(input)
		local done = false
		task.delay(holdtime, function()
			if done or unloaded then return end
			done = true
			if input.UserInputState == Enum.UserInputState.End then return end
			if balls[part] and ballAtScreen(input.Position) == part then
				grabBall(part)
			end
		end)
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState ~= Enum.UserInputState.End then return end
			conn:Disconnect()
			if done then return end
			done = true
			if balls[part] then removeBall(part) end
		end)
	end
end))

track(LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	if unloaded then return end
	for part in pairs(balls) do noCollideWithChar(part) end
	giveTool()
end))

-- ui
local uiGui = Instance.new("ScreenGui")
uiGui.Name = "BouncyBallzUI"
uiGui.ResetOnSpawn = false
uiGui.Parent = getGuiParent()

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(150, 92)
frame.Position = UDim2.new(1, -170, 0, 70)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Parent = uiGui

local function makeBtn(text, y)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 34)
	btn.Position = UDim2.new(0, 8, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = text
	btn.Parent = frame
	return btn
end
local spawnBtn = makeBtn("Spawn Ball", 8)
local unloadBtn = makeBtn("Unload BouncyBallz", 50)
unloadBtn.TextSize = 12

do
	local dragging, dragStart, startPos
	track(frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
end

local function unload()
	if unloaded then return end
	unloaded = true
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	table.clear(balls)
	pcall(function() fxFolder:Destroy() end)
	pcall(function() uiGui:Destroy() end)
	pcall(function() countGui:Destroy() end)
	pcall(destroyTool)
	pcall(function()
		if isfolder(folder) then delfolder(folder) end
	end)
	if getgenv then getgenv().BouncyBallzUnload = nil end
end

if getgenv then getgenv().BouncyBallzUnload = unload end
track(spawnBtn.MouseButton1Click:Connect(function() spawnBall() end))
track(unloadBtn.MouseButton1Click:Connect(unload))
spawnBall()
