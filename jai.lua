--[[
    Endware - ESP Box & Snap Line Güncellemesi
    Sağ Shift: Menü göster/gizle
    Unload Hub: Her şeyi sıfırla ve menüyü sil
--]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Drawing kütüphanesi (executor’a göre, yoksa nil)
local Drawing = nil
pcall(function()
    if getgenv and getgenv().Drawing then
        Drawing = getgenv().Drawing
    elseif Drawing ~= nil then
        -- zaten tanımlı
    elseif synapse and synapse.drawing then
        Drawing = synapse.drawing
    end
end)

local useESP = (Drawing ~= nil)

-- GUI (PlayerGui’de, stabil)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EndwareHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 250)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
Title.BorderSizePixel = 0
Title.Text = "Endware"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.Parent = MainFrame

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -30)
Content.Position = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.CanvasSize = UDim2.new(0, 0, 0, 200)
Content.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout", Content)
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Basit checkbox oluşturucu
local function createSetting(name, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 36)
    row.BackgroundTransparency = 1
    row.Parent = Content

    local checkbox = Instance.new("TextButton")
    checkbox.Size = UDim2.new(0, 28, 0, 28)
    checkbox.Position = UDim2.new(0, 8, 0, 4)
    checkbox.BackgroundColor3 = default and Color3.fromRGB(85, 170, 85) or Color3.fromRGB(255, 255, 255)
    checkbox.BorderSizePixel = 0
    checkbox.Text = default and "✔" or ""
    checkbox.Font = Enum.Font.SourceSansBold
    checkbox.TextSize = 18
    checkbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkbox.AutoButtonColor = false
    checkbox.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 45, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local state = default
    checkbox.MouseButton1Click:Connect(function()
        state = not state
        checkbox.BackgroundColor3 = state and Color3.fromRGB(85, 170, 85) or Color3.fromRGB(255, 255, 255)
        checkbox.Text = state and "✔" or ""
        callback(state)
    end)

    return { SetState = function(_, v) state = v; checkbox.BackgroundColor3 = v and Color3.fromRGB(85,170,85) or Color3.fromRGB(255,255,255); checkbox.Text = v and "✔" or ""; callback(v) end }
end

-- Unload butonu
local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(1, -20, 0, 36)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
UnloadBtn.BorderSizePixel = 0
UnloadBtn.Text = "Unload Hub"
UnloadBtn.TextColor3 = Color3.fromRGB(255,255,255)
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.TextSize = 16
UnloadBtn.Parent = Content

-- Özellik değişkenleri
local espEnabled = false
local snapEnabled = false
local untrapEnabled = false
local originalTeam = nil
local drawings = {}
local espLoop = nil

-- Yardımcı: düşman takım listesi
local function getEnemyTeams()
    local tv = LocalPlayer:FindFirstChild("TeamValue")
    if not tv then return {} end
    local t = tv.Value
    if t == "Police" then return {"Criminal", "Prisoner"}
    elseif t == "Criminal" or t == "Prisoner" then return {"Police"}
    else return {} end
end

-- ESP sistemi (Drawing varsa)
if useESP then
    -- Oyuncunun 2D sınırlayıcı kutusunu hesaplar
    local function getCharacterBoundingBox(character)
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local found = false
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                -- RootPart'ı hariç tutabiliriz, ayaklar vb. daha iyi kutu verir
                local pos = Camera:WorldToViewportPoint(part.Position)
                if pos.Z > 0 then  -- kamera önünde
                    found = true
                    if pos.X < minX then minX = pos.X end
                    if pos.Y < minY then minY = pos.Y end
                    if pos.X > maxX then maxX = pos.X end
                    if pos.Y > maxY then maxY = pos.Y end
                end
            end
        end
        if not found then return nil end
        return Vector2.new(minX, minY), Vector2.new(maxX, maxY)
    end

    -- ESP objeleri oluşturma
    local function addESP(player)
        if drawings[player] then return end
        local text = Drawing.new("Text")
        text.Size = 14; text.Center = true; text.Outline = true; text.Color = Color3.new(1,1,1); text.Visible = false

        local line = Drawing.new("Line")
        line.Thickness = 1; line.Color = Color3.new(1,1,1); line.Visible = false

        local box
        -- Square destekleniyorsa kullan, yoksa dört çizgi çiz
        pcall(function()
            box = Drawing.new("Square")
            box.Thickness = 2
            box.Filled = false
            box.Color = Color3.new(1,1,1)
            box.Visible = false
        end)
        if not box then
            -- Fallback: dört Line
            local topLine = Drawing.new("Line"); topLine.Thickness = 2; topLine.Color = Color3.new(1,1,1); topLine.Visible = false
            local bottomLine = Drawing.new("Line"); bottomLine.Thickness = 2; bottomLine.Color = Color3.new(1,1,1); bottomLine.Visible = false
            local leftLine = Drawing.new("Line"); leftLine.Thickness = 2; leftLine.Color = Color3.new(1,1,1); leftLine.Visible = false
            local rightLine = Drawing.new("Line"); rightLine.Thickness = 2; rightLine.Color = Color3.new(1,1,1); rightLine.Visible = false
            box = {Type = "Lines", top = topLine, bottom = bottomLine, left = leftLine, right = rightLine}
        end
        drawings[player] = {Text = text, Line = line, Box = box}
    end

    local function removeESP(player)
        local d = drawings[player]
        if not d then return end
        d.Text:Remove()
        d.Line:Remove()
        if d.Box then
            if d.Box.Type == "Lines" then
                d.Box.top:Remove(); d.Box.bottom:Remove(); d.Box.left:Remove(); d.Box.right:Remove()
            else
                d.Box:Remove()
            end
        end
        drawings[player] = nil
    end

    -- Güncelleme fonksiyonu
    local function updateESP()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            local tv = plr:FindFirstChild("TeamValue")
            if not tv then
                if drawings[plr] then removeESP(plr) end
                continue
            end
            local team = tv.Value
            local enemies = getEnemyTeams()
            local isEnemy = false
            for _, e in ipairs(enemies) do if team == e then isEnemy = true break end end
            if not isEnemy then
                if drawings[plr] then
                    drawings[plr].Text.Visible = false
                    drawings[plr].Line.Visible = false
                    local box = drawings[plr].Box
                    if box then
                        if box.Type == "Lines" then
                            box.top.Visible = false; box.bottom.Visible = false; box.left.Visible = false; box.right.Visible = false
                        else
                            box.Visible = false
                        end
                    end
                end
                continue
            end

            local char = plr.Character
            if not char or not char:FindFirstChild("Head") then
                if drawings[plr] then
                    drawings[plr].Text.Visible = false
                    drawings[plr].Line.Visible = false
                    local box = drawings[plr].Box
                    if box then
                        if box.Type == "Lines" then
                            box.top.Visible = false; box.bottom.Visible = false; box.left.Visible = false; box.right.Visible = false
                        else
                            box.Visible = false
                        end
                    end
                end
                continue
            end

            -- Renk seçimi
            local color = team == "Criminal" and Color3.fromRGB(255,0,0) or
                          team == "Prisoner" and Color3.fromRGB(255,165,0) or
                          Color3.fromRGB(0,120,255)

            -- ESP objelerini oluştur
            if not drawings[plr] then addESP(plr) end
            local d = drawings[plr]

            -- Karakter merkezi (head)
            local head = char.Head
            local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            local distance = (Camera.CFrame.Position - head.Position).Magnitude

            -- Text (isim + mesafe)
            d.Text.Text = string.format("%s [%.0fm]", plr.Name, distance)
            d.Text.Position = Vector2.new(headPos.X, headPos.Y - 30) -- geçici, kutuya göre ayarlanacak
            d.Text.Color = color

            -- 2D sınırlayıcı kutu
            local topLeft, bottomRight = getCharacterBoundingBox(char)
            if topLeft and bottomRight then
                local box = d.Box
                local boxWidth = bottomRight.X - topLeft.X
                local boxHeight = bottomRight.Y - topLeft.Y
                if boxWidth > 0 and boxHeight > 0 then
                    if box.Type == "Lines" then
                        -- Dört çizgi
                        box.top.From = topLeft
                        box.top.To = Vector2.new(bottomRight.X, topLeft.Y)
                        box.bottom.From = Vector2.new(topLeft.X, bottomRight.Y)
                        box.bottom.To = bottomRight
                        box.left.From = topLeft
                        box.left.To = Vector2.new(topLeft.X, bottomRight.Y)
                        box.right.From = Vector2.new(bottomRight.X, topLeft.Y)
                        box.right.To = bottomRight
                        box.top.Visible = true; box.bottom.Visible = true; box.left.Visible = true; box.right.Visible = true
                        box.top.Color = color; box.bottom.Color = color; box.left.Color = color; box.right.Color = color
                    else
                        -- Square objesi
                        box.Position = topLeft
                        box.Size = Vector2.new(boxWidth, boxHeight)
                        box.Color = color
                        box.Visible = true
                    end
                    -- Text'i kutunun üstüne yerleştir
                    d.Text.Position = Vector2.new(topLeft.X + boxWidth/2, topLeft.Y - 8)
                else
                    -- Boyut geçersizse kutuyu gizle
                    if box.Type == "Lines" then
                        box.top.Visible = false; box.bottom.Visible = false; box.left.Visible = false; box.right.Visible = false
                    else
                        box.Visible = false
                    end
                end
            else
                -- Kutuyu gizle
                local box = d.Box
                if box.Type == "Lines" then
                    box.top.Visible = false; box.bottom.Visible = false; box.left.Visible = false; box.right.Visible = false
                else
                    box.Visible = false
                end
                d.Text.Position = Vector2.new(headPos.X, headPos.Y - 30)
            end

            -- Snap line (ekranın üstünden)
            if snapEnabled and team ~= "Prisoner" then
                d.Line.From = Vector2.new(headPos.X, 0)
                d.Line.To = Vector2.new(headPos.X, headPos.Y)
                d.Line.Color = color
                d.Line.Visible = true
            else
                d.Line.Visible = false
            end

            d.Text.Visible = true
        end
    end

    -- Render döngüsü
    local function startESP()
        if espLoop then return end
        espLoop = RunService.RenderStepped:Connect(function()
            if not espEnabled then
                -- ESP kapalıysa her şeyi gizle
                for _, d in pairs(drawings) do
                    d.Text.Visible = false
                    d.Line.Visible = false
                    local box = d.Box
                    if box then
                        if box.Type == "Lines" then
                            box.top.Visible = false; box.bottom.Visible = false; box.left.Visible = false; box.right.Visible = false
                        else
                            box.Visible = false
                        end
                    end
                end
                return
            end
            updateESP()
        end)
    end

    local function stopESP()
        if espLoop then espLoop:Disconnect(); espLoop = nil end
        for _, d in pairs(drawings) do
            d.Text:Remove()
            d.Line:Remove()
            local box = d.Box
            if box then
                if box.Type == "Lines" then
                    box.top:Remove(); box.bottom:Remove(); box.left:Remove(); box.right:Remove()
                else
                    box:Remove()
                end
            end
        end
        drawings = {}
    end

    setESPEnabled = function(state)
        espEnabled = state
        if state then
            local tv = LocalPlayer:FindFirstChild("TeamValue")
            if tv then
                originalTeam = tv.Value
                local opp = originalTeam == "Police" and "Criminal" or
                            originalTeam == "Criminal" and "Police" or
                            originalTeam == "Prisoner" and "Criminal" or "Criminal"
                tv.Value = opp
            end
            startESP()
        else
            local tv = LocalPlayer:FindFirstChild("TeamValue")
            if tv and originalTeam then tv.Value = originalTeam; originalTeam = nil end
            stopESP()
        end
    end
else
    setESPEnabled = function(state)
        espEnabled = state
        if state then
            local tv = LocalPlayer:FindFirstChild("TeamValue")
            if tv then
                originalTeam = tv.Value
                tv.Value = originalTeam == "Police" and "Criminal" or
                           originalTeam == "Criminal" and "Police" or
                           originalTeam == "Prisoner" and "Criminal" or "Criminal"
            end
        else
            local tv = LocalPlayer:FindFirstChild("TeamValue")
            if tv and originalTeam then tv.Value = originalTeam; originalTeam = nil end
        end
    end
end

setSnapEnabled = function(state) snapEnabled = state end

-- Untrap sistemi
local trapsOriginal = {}
setUntrap = function(state)
    untrapEnabled = state
    local paths = {
        workspace:FindFirstChild("Banks") and workspace.Banks.Bank.Layout["01UpperManagement"].Lasers,
        workspace:FindFirstChild("Casino"),
        workspace:FindFirstChild("MansionRobbery") and workspace.MansionRobbery.LaserTraps,
        workspace:FindFirstChild("Museum"),
        workspace:FindFirstChild("OilRig")
    }
    for _, container in ipairs(paths) do
        if container then
            for _, part in ipairs(container:GetDescendants()) do
                if part:IsA("BasePart") then
                    if state then
                        if not trapsOriginal[part] then
                            trapsOriginal[part] = {Transparency = part.Transparency, CanCollide = part.CanCollide, CanTouch = part.CanTouch}
                        end
                        part.Transparency = 1
                        part.CanCollide = false
                        part.CanTouch = false
                    else
                        local orig = trapsOriginal[part]
                        if orig then
                            part.Transparency = orig.Transparency
                            part.CanCollide = orig.CanCollide
                            part.CanTouch = orig.CanTouch
                        end
                    end
                end
            end
        end
    end
    if not state then trapsOriginal = {} end
end

-- Unload fonksiyonu
local function unloadHub()
    if espEnabled then setESPEnabled(false) end
    if untrapEnabled then setUntrap(false) end
    snapEnabled = false
    ScreenGui:Destroy()
end

-- Checkbox'ları oluştur
local espCheckbox = createSetting("Team ESP & Box", false, setESPEnabled)
local snapCheckbox = createSetting("Snap Line ESP", false, setSnapEnabled)
local untrapCheckbox = createSetting("Untrap (Lazers Off)", false, setUntrap)

UnloadBtn.MouseButton1Click:Connect(unloadHub)

-- Right Shift toggle
UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

-- Oyuncu ayrıldığında ESP temizliği
Players.PlayerRemoving:Connect(function(player)
    if useESP and drawings[player] then
        removeESP(player)
    end
end)

-- Menü başlangıçta görünür
ScreenGui.Enabled = true
