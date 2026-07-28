--// Endware Hub - Persistent, Wall-Check Aimbot, ESP, Hitbox Expander, Always Daytime, Friendly List, Scooter TP, Bank TP, Seed Buyer
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Durum değişkenleri
local aimbotEnabled = false
local namesEnabled = false
local daytimeEnabled = false
local hitboxEnabled = false
local fovValue = 200
local hitboxMultiplier = 1.5
local friendlyPlayers = {}  -- [player] = true şeklinde

-- Bağlantı ve depolama
local allConnections = {}
local aimbotConnection = nil
local daytimeConnection = nil
local espConnection = nil
local espBillboardGuis = {}
local hitboxConnections = {}

-- Güvenli ışınlanma fonksiyonu (zemin algılamalı, no‑clip kullanılmaz)
local function safeTeleport(targetCFrame)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end

	local root = char.HumanoidRootPart
	local rayOrigin = targetCFrame.Position + Vector3.new(0, 20, 0) -- Yukarıdan ışın başlat
	local rayDirection = Vector3.new(0, -50, 0) -- Aşağı doğru

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {char}
	rayParams.RespectCanCollide = true

	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
	if rayResult then
		local groundPos = rayResult.Position
		-- Zeminden 3 stud yukarıya, aynı açıyla yerleştir
		local newPos = Vector3.new(targetCFrame.Position.X, groundPos.Y + 3, targetCFrame.Position.Z)
		root.CFrame = CFrame.new(newPos) * (targetCFrame - targetCFrame.Position)
	else
		-- Zemin bulunamazsa eski yöntemle (5 stud yukarı)
		root.CFrame = targetCFrame + Vector3.new(0, 5, 0)
	end
	root.Velocity = Vector3.zero
	root.RotVelocity = Vector3.zero
end

-- Yardımcı fonksiyonlar (yeni eklenen özellikler için)
local function findNearestScooterSpawn()
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	local rootPos = char.HumanoidRootPart.Position
	local nearestPos = nil
	local nearestDist = math.huge
	local modelFolder = Workspace:FindFirstChild("Model")
	if not modelFolder then return nil end
	for _, child in ipairs(modelFolder:GetChildren()) do
		if child:IsA("Model") then
			local baseParts = 0
			local subModels = 0
			local decalPart = nil
			for _, obj in ipairs(child:GetChildren()) do
				if obj:IsA("BasePart") then
					baseParts = baseParts + 1
					local decals = 0
					for _, decal in ipairs(obj:GetChildren()) do
						if decal:IsA("Decal") then
							decals = decals + 1
						end
					end
					if decals == 2 then
						decalPart = obj
					end
				elseif obj:IsA("Model") then
					subModels = subModels + 1
				end
			end
			if baseParts == 5 and subModels == 1 and decalPart then
				local pos = child:GetPivot().Position
				local dist = (pos - rootPos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestPos = pos
				end
			end
		end
	end
	return nearestPos
end

local function teleportToCFrame(cf)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = cf
	end
end

local function buySeeds(seedType, count)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local originalCFrame = char.HumanoidRootPart.CFrame
	local targetPos = Vector3.new(-1.484113, -388.618469, -632.553833)
	char.HumanoidRootPart.CFrame = CFrame.new(targetPos)
	task.wait(1)  -- Sadece 1 saniye bekleniyor
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("SeedDealer")
	if remote then
		-- Hiç ara vermeden hızlıca gönder
		for i = 1, count do
			remote:FireServer(seedType)
		end
	end
	if char and char:FindFirstChild("HumanoidRootPart") then
		safeTeleport(originalCFrame) -- Güvenli dönüş (no‑clip kullanılmaz)
	end
end

-- Tam temizlik
local function clearConnections()
	for _, conn in ipairs(allConnections) do conn:Disconnect() end
	allConnections = {}

	if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
	if daytimeConnection then daytimeConnection:Disconnect(); daytimeConnection = nil; Lighting.ClockTime = nil end
	if espConnection then espConnection:Disconnect(); espConnection = nil end

	-- Hitbox temizlik
	for plr, connTable in pairs(hitboxConnections) do
		if connTable.charConn then connTable.charConn:Disconnect() end
		if connTable.headConn then connTable.headConn:Disconnect() end
		if plr.Character and plr.Character:FindFirstChild("Head") then
			local head = plr.Character.Head
			local origSize = head:GetAttribute("OriginalSize")
			if origSize then head.Size = origSize; head:SetAttribute("OriginalSize", nil) end
			local origCC = head:GetAttribute("OriginalCanCollide")
			if origCC ~= nil then head.CanCollide = origCC; head:SetAttribute("OriginalCanCollide", nil) end
			local origML = head:GetAttribute("OriginalMassless")
			if origML ~= nil then head.Massless = origML; head:SetAttribute("OriginalMassless", nil) end
			local origPP = head:GetAttribute("OriginalCustomPhysicalProperties")
			if origPP then head.CustomPhysicalProperties = origPP; head:SetAttribute("OriginalCustomPhysicalProperties", nil)
			else head.CustomPhysicalProperties = PhysicalProperties.new(0.7,0.3,0.5) end
			local mesh = head:FindFirstChildOfClass("DataModelMesh") or head:FindFirstChild("Mesh")
			if mesh and head:GetAttribute("OriginalMeshScale") then
				mesh.Scale = head:GetAttribute("OriginalMeshScale")
				head:SetAttribute("OriginalMeshScale", nil)
			end
		end
		hitboxConnections[plr] = nil
	end

	for _, gui in pairs(espBillboardGuis) do gui:Destroy() end
	espBillboardGuis = {}
	friendlyPlayers = {}
end

-- Menüyü oluştur
local function createGUI()
	local oldGui = player.PlayerGui:FindFirstChild("Endware")
	if oldGui then oldGui:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Endware"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Ana Frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0,0,0,0)
	mainFrame.Position = UDim2.new(0.5,0,0.5,0)
	mainFrame.AnchorPoint = Vector2.new(0.5,0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local stroke = Instance.new("UIStroke", mainFrame)
	stroke.Color = Color3.fromRGB(0,170,255)
	stroke.Thickness = 2

	local corner = Instance.new("UICorner", mainFrame)
	corner.CornerRadius = UDim.new(0,12)

	-- Başlık
	local titleBar = Instance.new("Frame", mainFrame)
	titleBar.Size = UDim2.new(1,0,0,50)
	titleBar.BackgroundColor3 = Color3.fromRGB(20,20,20)
	titleBar.BorderSizePixel = 0
	local titleCorner = Instance.new("UICorner", titleBar)
	titleCorner.CornerRadius = UDim.new(0,12)

	local titleGradient = Instance.new("UIGradient", titleBar)
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0,170,255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150,0,255))
	})
	titleGradient.Rotation = 90

	local titleLabel = Instance.new("TextLabel", titleBar)
	titleLabel.Size = UDim2.new(1,-10,1,0)
	titleLabel.Position = UDim2.new(0,10,0,0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Endware"
	titleLabel.TextColor3 = Color3.fromRGB(255,255,255)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Scroll alanı (yeni öğeler için yükseklik artırıldı)
	local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
	scrollFrame.Size = UDim2.new(1,-10,1,-100)
	scrollFrame.Position = UDim2.new(0,5,0,55)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0,170,255)
	scrollFrame.CanvasSize = UDim2.new(0,0,0,800)

	local uiListLayout = Instance.new("UIListLayout", scrollFrame)
	uiListLayout.Padding = UDim.new(0,8)
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Unload butonu
	local unloadButton = Instance.new("TextButton", mainFrame)
	unloadButton.Size = UDim2.new(1,-20,0,35)
	unloadButton.Position = UDim2.new(0,10,1,-45)
	unloadButton.BackgroundColor3 = Color3.fromRGB(255,50,50)
	unloadButton.BorderSizePixel = 0
	unloadButton.Text = "Unload Hub"
	unloadButton.TextColor3 = Color3.fromRGB(255,255,255)
	unloadButton.Font = Enum.Font.GothamBold
	unloadButton.TextSize = 16
	Instance.new("UICorner", unloadButton).CornerRadius = UDim.new(0,8)

	-- Checkbox fonksiyonu
	local function createCheckbox(parent, text, layoutOrder)
		local frame = Instance.new("Frame", parent)
		frame.Size = UDim2.new(1,-10,0,35)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local label = Instance.new("TextLabel", frame)
		label.Size = UDim2.new(0.7,0,1,0)
		label.Position = UDim2.new(0,5,0,0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255,255,255)
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left

		local checkButton = Instance.new("TextButton", frame)
		checkButton.Size = UDim2.new(0,24,0,24)
		checkButton.Position = UDim2.new(1,-30,0.5,-12)
		checkButton.BackgroundColor3 = Color3.fromRGB(40,40,40)
		checkButton.BorderSizePixel = 0
		checkButton.Text = ""
		checkButton.Font = Enum.Font.GothamBold
		checkButton.TextSize = 18
		checkButton.TextColor3 = Color3.fromRGB(0,170,255)
		Instance.new("UICorner", checkButton).CornerRadius = UDim.new(0,4)
		return checkButton
	end

	-- Slider fonksiyonu
	local function createSlider(parent, text, min, max, default, layoutOrder)
		local frame = Instance.new("Frame", parent)
		frame.Size = UDim2.new(1,-10,0,60)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local label = Instance.new("TextLabel", frame)
		label.Size = UDim2.new(1,0,0,20)
		label.BackgroundTransparency = 1
		label.Text = text .. ": " .. tostring(default)
		label.TextColor3 = Color3.fromRGB(255,255,255)
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left

		local track = Instance.new("Frame", frame)
		track.Size = UDim2.new(1,-20,0,6)
		track.Position = UDim2.new(0,10,0,30)
		track.BackgroundColor3 = Color3.fromRGB(60,60,60)
		track.BorderSizePixel = 0
		Instance.new("UICorner", track).CornerRadius = UDim.new(0,3)

		local fill = Instance.new("Frame", track)
		fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
		fill.BackgroundColor3 = Color3.fromRGB(0,170,255)
		fill.BorderSizePixel = 0
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0,3)

		local thumb = Instance.new("TextButton", track)
		thumb.Size = UDim2.new(0,16,0,16)
		thumb.Position = UDim2.new((default-min)/(max-min),-8,0.5,-8)
		thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
		thumb.BorderSizePixel = 0
		thumb.Text = ""
		Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)

		local value = default
		local dragging = false

		local function updateDisplay()
			label.Text = text .. ": " .. tostring(math.floor(value*10)/10)
			fill.Size = UDim2.new((value-min)/(max-min),0,1,0)
			thumb.Position = UDim2.new((value-min)/(max-min),-8,0.5,-8)
		end

		thumb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
		end)

		local endConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end)
		table.insert(allConnections, endConn)

		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local mousePos = UserInputService:GetMouseLocation()
				local trackAbsPos = track.AbsolutePosition
				local trackSize = track.AbsoluteSize
				local percent = math.clamp((mousePos.X - trackAbsPos.X) / trackSize.X, 0, 1)
				value = min + percent * (max - min)
				updateDisplay()
			end
		end)
		table.insert(allConnections, moveConn)

		return {
			GetValue = function() return value end,
			SetValue = function(v) value = math.clamp(v,min,max); updateDisplay() end
		}, updateDisplay
	end

	-- UI elemanları
	local nameCheckButton = createCheckbox(scrollFrame, "Show Player Names (ESP)", 1)
	local aimbotCheckButton = createCheckbox(scrollFrame, "Aimbot (N)", 2)
	local fovSlider, fovUpdateDisplay = createSlider(scrollFrame, "FOV Radius", 50, 500, fovValue, 3)
	local daytimeCheckButton = createCheckbox(scrollFrame, "Always Daytime", 4)
	local hitboxCheckButton = createCheckbox(scrollFrame, "Hitbox Expander", 5)
	local hitboxSlider, hitboxUpdateDisplay = createSlider(scrollFrame, "Head Size", 1, 5, hitboxMultiplier, 6)

	-- ========== FRIENDLY COMBOBOX ==========
	local friendlyFrame = Instance.new("Frame", scrollFrame)
	friendlyFrame.Size = UDim2.new(1,-10,0,35)
	friendlyFrame.BackgroundTransparency = 1
	friendlyFrame.LayoutOrder = 7

	local friendlyLabel = Instance.new("TextLabel", friendlyFrame)
	friendlyLabel.Size = UDim2.new(0.5,0,1,0)
	friendlyLabel.Position = UDim2.new(0,5,0,0)
	friendlyLabel.BackgroundTransparency = 1
	friendlyLabel.Text = "Friendly Players"
	friendlyLabel.TextColor3 = Color3.fromRGB(255,255,255)
	friendlyLabel.Font = Enum.Font.Gotham
	friendlyLabel.TextSize = 14
	friendlyLabel.TextXAlignment = Enum.TextXAlignment.Left

	local dropButton = Instance.new("TextButton", friendlyFrame)
	dropButton.Size = UDim2.new(0,140,0,24)
	dropButton.Position = UDim2.new(1,-145,0.5,-12)
	dropButton.BackgroundColor3 = Color3.fromRGB(40,40,40)
	dropButton.BorderSizePixel = 0
	dropButton.Text = "▼ Select"
	dropButton.TextColor3 = Color3.fromRGB(255,255,255)
	dropButton.Font = Enum.Font.Gotham
	dropButton.TextSize = 14
	Instance.new("UICorner", dropButton).CornerRadius = UDim.new(0,4)

	local dropList = Instance.new("Frame", screenGui)
	dropList.Name = "FriendlyDropList"
	dropList.Size = UDim2.new(0,200,0,0)
	dropList.Position = UDim2.new(0,0,0,0)
	dropList.BackgroundColor3 = Color3.fromRGB(35,35,35)
	dropList.BorderSizePixel = 0
	dropList.Visible = false
	dropList.ClipsDescendants = true
	Instance.new("UICorner", dropList).CornerRadius = UDim.new(0,6)
	Instance.new("UIStroke", dropList).Color = Color3.fromRGB(0,170,255)

	local listScroller = Instance.new("ScrollingFrame", dropList)
	listScroller.Size = UDim2.new(1,-4,1,-4)
	listScroller.Position = UDim2.new(0,2,0,2)
	listScroller.BackgroundTransparency = 1
	listScroller.BorderSizePixel = 0
	listScroller.ScrollBarThickness = 3
	listScroller.CanvasSize = UDim2.new(0,0,0,0)
	local listLayout = Instance.new("UIListLayout", listScroller)
	listLayout.Padding = UDim.new(0,2)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.Name

	local dropdownOpen = false
	local function updateDropPosition()
		local btnPos = dropButton.AbsolutePosition
		local btnSize = dropButton.AbsoluteSize
		dropList.Position = UDim2.new(0, btnPos.X, 0, btnPos.Y + btnSize.Y + 2)
	end

	local function populateFriendList()
		for _, child in ipairs(listScroller:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		local ySize = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local entryFrame = Instance.new("Frame")
				entryFrame.Size = UDim2.new(1,-10,0,28)
				entryFrame.BackgroundTransparency = 1
				entryFrame.Name = plr.Name

				local entryButton = Instance.new("TextButton", entryFrame)
				entryButton.Size = UDim2.new(1,0,1,0)
				entryButton.BackgroundColor3 = Color3.fromRGB(50,50,50)
				entryButton.BorderSizePixel = 0
				entryButton.Text = plr.Name
				entryButton.TextColor3 = Color3.fromRGB(255,255,255)
				entryButton.Font = Enum.Font.Gotham
				entryButton.TextSize = 14
				Instance.new("UICorner", entryButton).CornerRadius = UDim.new(0,4)

				local checkMark = Instance.new("TextLabel", entryButton)
				checkMark.Size = UDim2.new(0,20,1,0)
				checkMark.Position = UDim2.new(1,-22,0,0)
				checkMark.BackgroundTransparency = 1
				checkMark.Text = friendlyPlayers[plr] and "✓" or ""
				checkMark.TextColor3 = Color3.fromRGB(0,255,0)
				checkMark.Font = Enum.Font.GothamBold
				checkMark.TextSize = 16
				checkMark.Name = "Check"

				entryButton.MouseButton1Click:Connect(function()
					friendlyPlayers[plr] = not friendlyPlayers[plr]
					checkMark.Text = friendlyPlayers[plr] and "✓" or ""
				end)

				entryFrame.Parent = listScroller
				ySize = ySize + 30
			end
		end
		listScroller.CanvasSize = UDim2.new(0,0,0,ySize)
	end

	dropButton.MouseButton1Click:Connect(function()
		dropdownOpen = not dropdownOpen
		if dropdownOpen then
			updateDropPosition()
			populateFriendList()
			dropList.Visible = true
			dropList.Size = UDim2.new(0,200,0,math.min(200, (#Players:GetPlayers()-1)*30 + 10))
		else
			dropList.Visible = false
		end
	end)

	local closeConnection = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if dropdownOpen then
				local mousePos = UserInputService:GetMouseLocation()
				local guiObjects = player.PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
				local inside = false
				for _, obj in ipairs(guiObjects) do
					if obj:IsDescendantOf(dropList) or obj == dropButton then
						inside = true
						break
					end
				end
				if not inside then
					dropdownOpen = false
					dropList.Visible = false
				end
			end
		end
	end)
	table.insert(allConnections, closeConnection)

	local function onPlayerChanged()
		if dropdownOpen then
			populateFriendList()
			dropList.Size = UDim2.new(0,200,0,math.min(200, (#Players:GetPlayers()-1)*30 + 10))
		end
		local current = {}
		for _, plr in ipairs(Players:GetPlayers()) do current[plr] = true end
		for plr, _ in pairs(friendlyPlayers) do
			if not current[plr] then friendlyPlayers[plr] = nil end
		end
	end

	local addConn = Players.PlayerAdded:Connect(onPlayerChanged)
	local removeConn = Players.PlayerRemoving:Connect(onPlayerChanged)
	table.insert(allConnections, addConn)
	table.insert(allConnections, removeConn)

	-- ========== YENİ ÖZELLİKLER ==========

	-- Closest Scooter butonu
	local scooterButton = Instance.new("TextButton", scrollFrame)
	scooterButton.Size = UDim2.new(1,-10,0,35)
	scooterButton.LayoutOrder = 8
	scooterButton.BackgroundColor3 = Color3.fromRGB(0,170,255)
	scooterButton.BorderSizePixel = 0
	scooterButton.Text = "Closest Scooter"
	scooterButton.TextColor3 = Color3.fromRGB(255,255,255)
	scooterButton.Font = Enum.Font.GothamBold
	scooterButton.TextSize = 16
	Instance.new("UICorner", scooterButton).CornerRadius = UDim.new(0,8)
	scooterButton.MouseButton1Click:Connect(function()
		local pos = findNearestScooterSpawn()
		if pos then
			teleportToCFrame(CFrame.new(pos))
		end
	end)
	table.insert(allConnections, scooterButton.MouseButton1Click)

	-- Bank TP butonu
	local bankButton = Instance.new("TextButton", scrollFrame)
	bankButton.Size = UDim2.new(1,-10,0,35)
	bankButton.LayoutOrder = 9
	bankButton.BackgroundColor3 = Color3.fromRGB(100,200,100)
	bankButton.BorderSizePixel = 0
	bankButton.Text = "Bank TP"
	bankButton.TextColor3 = Color3.fromRGB(255,255,255)
	bankButton.Font = Enum.Font.GothamBold
	bankButton.TextSize = 16
	Instance.new("UICorner", bankButton).CornerRadius = UDim.new(0,8)
	local bankCFrame = CFrame.new(-224.991882, 4.24963284, 91.6989136, 0.751183569, 2.96664702e-08, -0.660093367, 3.52389371e-08, 1, 8.50446042e-08, 0.660093367, -8.71450965e-08, 0.751183569)
	bankButton.MouseButton1Click:Connect(function()
		teleportToCFrame(bankCFrame)
	end)
	table.insert(allConnections, bankButton.MouseButton1Click)

	-- Seed Count TextBox
	local seedCountFrame = Instance.new("Frame", scrollFrame)
	seedCountFrame.Size = UDim2.new(1,-10,0,35)
	seedCountFrame.BackgroundTransparency = 1
	seedCountFrame.LayoutOrder = 10

	local seedCountLabel = Instance.new("TextLabel", seedCountFrame)
	seedCountLabel.Size = UDim2.new(0.4,0,1,0)
	seedCountLabel.BackgroundTransparency = 1
	seedCountLabel.Text = "Seed Count:"
	seedCountLabel.TextColor3 = Color3.fromRGB(255,255,255)
	seedCountLabel.Font = Enum.Font.Gotham
	seedCountLabel.TextSize = 14
	seedCountLabel.TextXAlignment = Enum.TextXAlignment.Left

	local seedCountInput = Instance.new("TextBox", seedCountFrame)
	seedCountInput.Size = UDim2.new(0.5,0,0,24)
	seedCountInput.Position = UDim2.new(0.45,0,0.5,-12)
	seedCountInput.BackgroundColor3 = Color3.fromRGB(40,40,40)
	seedCountInput.BorderSizePixel = 0
	seedCountInput.Text = "1"
	seedCountInput.TextColor3 = Color3.fromRGB(255,255,255)
	seedCountInput.Font = Enum.Font.Gotham
	seedCountInput.TextSize = 14
	seedCountInput.PlaceholderText = "Amount"
	Instance.new("UICorner", seedCountInput).CornerRadius = UDim.new(0,4)

	-- Seed Type seçimi (radio butonlar)
	local seedTypeFrame = Instance.new("Frame", scrollFrame)
	seedTypeFrame.Size = UDim2.new(1,-10,0,35)
	seedTypeFrame.BackgroundTransparency = 1
	seedTypeFrame.LayoutOrder = 11

	local seedTypeLabel = Instance.new("TextLabel", seedTypeFrame)
	seedTypeLabel.Size = UDim2.new(0.3,0,1,0)
	seedTypeLabel.BackgroundTransparency = 1
	seedTypeLabel.Text = "Seed Type:"
	seedTypeLabel.TextColor3 = Color3.fromRGB(255,255,255)
	seedTypeLabel.Font = Enum.Font.Gotham
	seedTypeLabel.TextSize = 14
	seedTypeLabel.TextXAlignment = Enum.TextXAlignment.Left

	local function createRadioButton(parent, text, isSelected, positionScaleX)
		local btnFrame = Instance.new("Frame", parent)
		btnFrame.Size = UDim2.new(0,100,0,24)
		btnFrame.Position = UDim2.new(positionScaleX,0,0.5,-12)
		btnFrame.BackgroundTransparency = 1

		local btn = Instance.new("TextButton", btnFrame)
		btn.Size = UDim2.new(0,24,0,24)
		btn.Position = UDim2.new(0,0,0,0)
		btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
		btn.BorderSizePixel = 0
		btn.Text = isSelected and "✓" or ""
		btn.TextColor3 = Color3.fromRGB(0,170,255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 18
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)

		local label = Instance.new("TextLabel", btnFrame)
		label.Size = UDim2.new(1,-30,1,0)
		label.Position = UDim2.new(0,28,0,0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255,255,255)
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left

		return btn
	end

	local mangoBtn = createRadioButton(seedTypeFrame, "Mango", true, 0.35)
	local hotchiliBtn = createRadioButton(seedTypeFrame, "Hotchili", false, 0.65)
	local selectedSeedType = "MangoSeed"

	mangoBtn.MouseButton1Click:Connect(function()
		if selectedSeedType ~= "MangoSeed" then
			selectedSeedType = "MangoSeed"
			mangoBtn.Text = "✓"
			hotchiliBtn.Text = ""
		end
	end)
	table.insert(allConnections, mangoBtn.MouseButton1Click)

	hotchiliBtn.MouseButton1Click:Connect(function()
		if selectedSeedType ~= "HotChilliSeed" then
			selectedSeedType = "HotChilliSeed"
			hotchiliBtn.Text = "✓"
			mangoBtn.Text = ""
		end
	end)
	table.insert(allConnections, hotchiliBtn.MouseButton1Click)

	-- Buy Seed butonu
	local buySeedButton = Instance.new("TextButton", scrollFrame)
	buySeedButton.Size = UDim2.new(1,-10,0,35)
	buySeedButton.LayoutOrder = 12
	buySeedButton.BackgroundColor3 = Color3.fromRGB(255,165,0)
	buySeedButton.BorderSizePixel = 0
	buySeedButton.Text = "Buy Seed"
	buySeedButton.TextColor3 = Color3.fromRGB(255,255,255)
	buySeedButton.Font = Enum.Font.GothamBold
	buySeedButton.TextSize = 16
	Instance.new("UICorner", buySeedButton).CornerRadius = UDim.new(0,8)
	buySeedButton.MouseButton1Click:Connect(function()
		local count = tonumber(seedCountInput.Text)
		if not count or count <= 0 then
			count = 1
			seedCountInput.Text = "1"
		else
			count = math.floor(count)
		end
		local seedType = selectedSeedType
		task.spawn(function()
			buySeeds(seedType, count)
		end)
	end)
	table.insert(allConnections, buySeedButton.MouseButton1Click)

	-- FOV dairesi
	local fovCircleFrame = Instance.new("Frame", screenGui)
	fovCircleFrame.Name = "FOVCircle"
	fovCircleFrame.Size = UDim2.new(0, fovValue*2, 0, fovValue*2)
	fovCircleFrame.Position = UDim2.new(0.5,0,0.5,0)
	fovCircleFrame.AnchorPoint = Vector2.new(0.5,0.5)
	fovCircleFrame.BackgroundTransparency = 1
	fovCircleFrame.Visible = aimbotEnabled
	Instance.new("UIStroke", fovCircleFrame).Color = Color3.fromRGB(0,170,255)
	Instance.new("UIStroke", fovCircleFrame).Thickness = 2
	Instance.new("UIStroke", fovCircleFrame).Transparency = 0.3
	Instance.new("UICorner", fovCircleFrame).CornerRadius = UDim.new(1,0)

	-- Menü animasyonu
	local menuOpen = false
	local menuTween = nil
	local function toggleMenu()
		menuOpen = not menuOpen
		if menuOpen then
			mainFrame.Visible = true
			if menuTween then menuTween:Cancel() end
			menuTween = TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 450, 0, 520)
			})
			menuTween:Play()
		else
			if menuTween then menuTween:Cancel() end
			menuTween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0,0,0,0)
			})
			menuTween:Play()
			menuTween.Completed:Connect(function()
				if not menuOpen then mainFrame.Visible = false end
			end)
		end
	end

	-- Aimbot (friendly kontrolü eklendi)
	local function applyAimbotState(state)
		aimbotEnabled = state
		aimbotCheckButton.Text = state and "✓" or ""
		fovCircleFrame.Visible = state
		if state then fovCircleFrame.Size = UDim2.new(0, fovValue*2, 0, fovValue*2) end
		if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
		if state then
			aimbotConnection = RunService.Heartbeat:Connect(function()
				if not aimbotEnabled then return end
				local camPos = camera.CFrame.Position
				local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
				local closestDist = fovValue
				local closestHeadPos = nil
				local myChar = player.Character

				for _, otherPlayer in ipairs(Players:GetPlayers()) do
					if otherPlayer ~= player and not friendlyPlayers[otherPlayer] then
						local char = otherPlayer.Character
						if char then
							local head = char:FindFirstChild("Head")
							local humanoid = char:FindFirstChild("Humanoid")
							if head and humanoid and humanoid.Health > 0 then
								local screenPoint, onScreen = camera:WorldToScreenPoint(head.Position)
								if onScreen and screenPoint.Z > 0 then
									local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude
									if dist < closestDist then
										local rayOrigin = camPos
										local rayDirection = (head.Position - rayOrigin)
										local rayLength = rayDirection.Magnitude
										rayDirection = rayDirection / rayLength

										local rayParams = RaycastParams.new()
										rayParams.FilterType = Enum.RaycastFilterType.Blacklist
										local ignoreList = {}
										if myChar then table.insert(ignoreList, myChar) end
										table.insert(ignoreList, char)
										rayParams.FilterDescendantsInstances = ignoreList
										rayParams.RespectCanCollide = true

										local rayResult = Workspace:Raycast(rayOrigin, rayDirection * rayLength, rayParams)
										if not rayResult then
											closestDist = dist
											closestHeadPos = head.Position
										end
									end
								end
							end
						end
					end
				end

				if closestHeadPos then
					camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camPos, closestHeadPos), 0.4)
				end
			end)
		end
	end

	-- ESP
	local function createESPBillboard(plr)
		if espBillboardGuis[plr] then return end
		local char = plr.Character
		if not char or not char:FindFirstChild("Head") then return end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ESPName"
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.new(0,200,0,30)
		billboard.StudsOffset = Vector3.new(0,3,0)
		billboard.MaxDistance = math.huge
		billboard.Adornee = char.Head
		billboard.Parent = char

		local label = Instance.new("TextLabel", billboard)
		label.Size = UDim2.new(1,0,1,0)
		label.BackgroundTransparency = 1
		label.Text = plr.Name
		label.TextColor3 = Color3.fromRGB(0,255,0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextStrokeTransparency = 0.3
		label.TextStrokeColor3 = Color3.fromRGB(0,0,0)

		espBillboardGuis[plr] = billboard
	end

	local function removeESPBillboard(plr)
		if espBillboardGuis[plr] then
			espBillboardGuis[plr]:Destroy()
			espBillboardGuis[plr] = nil
		end
	end

	local function applyNamesState(state)
		namesEnabled = state
		nameCheckButton.Text = state and "✓" or ""
		if state then
			if espConnection then espConnection:Disconnect() end
			espConnection = RunService.Heartbeat:Connect(function()
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= player then
						local char = plr.Character
						if char and char:FindFirstChild("Head") then
							if not espBillboardGuis[plr] then createESPBillboard(plr) end
						else
							if espBillboardGuis[plr] then removeESPBillboard(plr) end
						end
					end
				end
			end)
		else
			if espConnection then espConnection:Disconnect(); espConnection = nil end
			for plr, _ in pairs(espBillboardGuis) do removeESPBillboard(plr) end
		end
	end

	-- Hitbox
	local function applyHitboxToCharacter(plr, char, multiplier)
		if not char or not char:FindFirstChild("Head") or plr == player then return end
		local head = char.Head
		if not head:GetAttribute("OriginalSize") then
			head:SetAttribute("OriginalSize", head.Size)
			head:SetAttribute("OriginalCanCollide", head.CanCollide)
			head:SetAttribute("OriginalMassless", head.Massless)
			head:SetAttribute("OriginalCustomPhysicalProperties", head.CustomPhysicalProperties)
			local mesh = head:FindFirstChildOfClass("DataModelMesh") or head:FindFirstChild("Mesh")
			if mesh then head:SetAttribute("OriginalMeshScale", mesh.Scale) end
		end
		head.Size = head:GetAttribute("OriginalSize") * multiplier
		head.CanCollide = false
		head.Massless = true
		head.CustomPhysicalProperties = PhysicalProperties.new(0,0,0)
		local mesh = head:FindFirstChildOfClass("DataModelMesh") or head:FindFirstChild("Mesh")
		if mesh and head:GetAttribute("OriginalMeshScale") then
			mesh.Scale = head:GetAttribute("OriginalMeshScale") / multiplier
		end
	end

	local function removeHitboxFromCharacter(plr, char)
		if not char or not char:FindFirstChild("Head") then return end
		local head = char.Head
		local origSize = head:GetAttribute("OriginalSize")
		if origSize then head.Size = origSize; head:SetAttribute("OriginalSize", nil) end
		local origCC = head:GetAttribute("OriginalCanCollide")
		if origCC ~= nil then head.CanCollide = origCC; head:SetAttribute("OriginalCanCollide", nil) end
		local origML = head:GetAttribute("OriginalMassless")
		if origML ~= nil then head.Massless = origML; head:SetAttribute("OriginalMassless", nil) end
		local origPP = head:GetAttribute("OriginalCustomPhysicalProperties")
		if origPP then head.CustomPhysicalProperties = origPP; head:SetAttribute("OriginalCustomPhysicalProperties", nil)
		else head.CustomPhysicalProperties = PhysicalProperties.new(0.7,0.3,0.5) end
		local mesh = head:FindFirstChildOfClass("DataModelMesh") or head:FindFirstChild("Mesh")
		if mesh and head:GetAttribute("OriginalMeshScale") then
			mesh.Scale = head:GetAttribute("OriginalMeshScale")
			head:SetAttribute("OriginalMeshScale", nil)
		end
	end

	local function applyHitboxToAll(mult)
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then applyHitboxToCharacter(plr, plr.Character, mult) end
		end
	end

	local function removeHitboxFromAll()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then removeHitboxFromCharacter(plr, plr.Character) end
		end
	end

	local function applyHitboxState(state)
		hitboxEnabled = state
		hitboxCheckButton.Text = state and "✓" or ""
		for plr, ct in pairs(hitboxConnections) do
			if ct.charConn then ct.charConn:Disconnect() end
			if ct.headConn then ct.headConn:Disconnect() end
			hitboxConnections[plr] = nil
		end
		if state then
			applyHitboxToAll(hitboxMultiplier)
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= player then
					local charConn = plr.CharacterAdded:Connect(function(char)
						task.wait(0.1); if hitboxEnabled then applyHitboxToCharacter(plr, char, hitboxMultiplier) end
					end)
					local headConn
					if plr.Character and plr.Character:FindFirstChild("Head") then
						headConn = plr.Character.Head.Changed:Connect(function(prop)
							if prop == "Size" or prop == "MeshId" then
								if hitboxEnabled then applyHitboxToCharacter(plr, plr.Character, hitboxMultiplier) end
							end
						end)
					end
					hitboxConnections[plr] = {charConn = charConn, headConn = headConn}
				end
			end
			local newPlrConn = Players.PlayerAdded:Connect(function(plr)
				if plr ~= player then
					local charConn = plr.CharacterAdded:Connect(function(char)
						task.wait(0.1); if hitboxEnabled then applyHitboxToCharacter(plr, char, hitboxMultiplier) end
					end)
					local headConn
					if plr.Character and plr.Character:FindFirstChild("Head") then
						headConn = plr.Character.Head.Changed:Connect(function(prop)
							if prop == "Size" or prop == "MeshId" then
								if hitboxEnabled then applyHitboxToCharacter(plr, plr.Character, hitboxMultiplier) end
							end
						end)
					end
					hitboxConnections[plr] = {charConn = charConn, headConn = headConn}
				end
			end)
			table.insert(allConnections, newPlrConn)
		else
			removeHitboxFromAll()
		end
	end

	-- Always Daytime
	local function applyDaytimeState(state)
		daytimeEnabled = state
		daytimeCheckButton.Text = state and "✓" or ""
		if state then
			Lighting.ClockTime = 12
			if daytimeConnection then daytimeConnection:Disconnect() end
			daytimeConnection = RunService.Heartbeat:Connect(function() Lighting.ClockTime = 12 end)
		else
			if daytimeConnection then daytimeConnection:Disconnect(); daytimeConnection = nil end
			Lighting.ClockTime = nil
		end
	end

	-- Buton olayları
	nameCheckButton.MouseButton1Click:Connect(function() applyNamesState(not namesEnabled) end)
	table.insert(allConnections, nameCheckButton.MouseButton1Click)
	aimbotCheckButton.MouseButton1Click:Connect(function() applyAimbotState(not aimbotEnabled) end)
	table.insert(allConnections, aimbotCheckButton.MouseButton1Click)
	daytimeCheckButton.MouseButton1Click:Connect(function() applyDaytimeState(not daytimeEnabled) end)
	table.insert(allConnections, daytimeCheckButton.MouseButton1Click)
	hitboxCheckButton.MouseButton1Click:Connect(function() applyHitboxState(not hitboxEnabled) end)
	table.insert(allConnections, hitboxCheckButton.MouseButton1Click)

	-- Slider güncelleme (Bu bağlantı allConnections'a eklendi, Unload ile temizlenir)
	local sliderUpdateConnection = RunService.Heartbeat:Connect(function()
		local curFov = fovSlider.GetValue()
		if curFov ~= fovValue then
			fovValue = curFov
			if aimbotEnabled then fovCircleFrame.Size = UDim2.new(0, fovValue*2, 0, fovValue*2) end
		end
		local curHitbox = hitboxSlider.GetValue()
		if math.abs(curHitbox - hitboxMultiplier) > 0.01 then
			hitboxMultiplier = curHitbox
			hitboxUpdateDisplay()
			if hitboxEnabled then removeHitboxFromAll(); applyHitboxToAll(hitboxMultiplier) end
		end
	end)
	table.insert(allConnections, sliderUpdateConnection)

	-- Kısayollar
	local shiftConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end
	end)
	table.insert(allConnections, shiftConn)

	local nConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.N and not UserInputService:GetFocusedTextBox() then
			applyAimbotState(not aimbotEnabled)
		end
	end)
	table.insert(allConnections, nConn)

	unloadButton.MouseButton1Click:Connect(function()
		clearConnections()
		screenGui:Destroy()
	end)
	table.insert(allConnections, unloadButton.MouseButton1Click)

	-- Başlangıçta kapalı
	applyAimbotState(false)
	applyNamesState(false)
	applyDaytimeState(false)
	applyHitboxState(false)
	fovSlider.SetValue(fovValue)
	fovUpdateDisplay()
	hitboxSlider.SetValue(hitboxMultiplier)
	hitboxUpdateDisplay()
end

createGUI()
