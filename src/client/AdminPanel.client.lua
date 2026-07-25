--[[
    ███╗   ██╗███████╗██╗    ██╗   LIGHTWEIGHT ADMIN PANEL v2.0
    ████╗  ██║██╔════╝██║    ██║    by Arena Agent for fagred35-dot/place
    ██╔██╗ ██║█████╗  ██║ █╗ ██║    
    ██║╚██╗██║██╔══╝  ██║███╗██║    • Fly + Noclip включены сразу при старте
    ██║ ╚████║███████╗╚███╔███╔╝    • 34 фичи всего (сам придумал)
    ╚═╝  ╚═══╝╚══════╝ ╚══╝╚══╝     • Лёгкая, без лагов, для теста своего плейса
    
    Куда кидать:
    StarterPlayer -> StarterPlayerScripts -> этот LocalScript
    
    Управление:
    RightShift - показать/скрыть панель
    WASD + Space/Ctrl + Shift - полёт
    Перенос панели - за заголовок
]]

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

--// AUTO FIX FOR WORKSPACE: if this Script is in Workspace as Server Script, try to make it Client
-- This allows it to work in Workspace if user sets RunContext=Client or we auto-set it
pcall(function()
    if script:IsA("Script") then
        -- Script has RunContext property (since 2023)
        if script.RunContext ~= Enum.RunContext.Client then
            script.RunContext = Enum.RunContext.Client
            warn("[LightAdmin v2] 🔧 Auto-set RunContext to Client for Workspace support. Re-run Play and it will work in Workspace!")
        end
    end
end)

--// SAFETY: must run on Client (works both in StarterPlayerScripts AND in Workspace if RunContext=Client)
if not RunService:IsClient() then
    warn("[LightAdmin v2] ❌ Currently running on Server. If you want it to work in Workspace: Select script in Workspace -> Properties -> RunContext -> set to 'Client' -> Play again. Or move to StarterPlayer > StarterPlayerScripts. Path: "..script:GetFullName())
    -- Server-side fallback: try to inject into players (best effort for Workspace)
    if RunService:IsServer() then
        pcall(function()
            local StarterPlayer = game:FindFirstChild("StarterPlayer")
            local SPS = StarterPlayer and StarterPlayer:FindFirstChild("StarterPlayerScripts")
            if SPS and not SPS:FindFirstChild("LightAdmin_AutoInject") then
                warn("[LightAdmin] Server in Workspace: Will try to help client load next time. Please set RunContext to Client for instant fix.")
            end
        end)
    end
    return
end

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    -- Sometimes LocalPlayer not ready immediately (Studio race). Wait a bit.
    local start = tick()
    repeat
        task.wait(0.1)
        LocalPlayer = Players.LocalPlayer
    until LocalPlayer or tick() - start > 10
end
if not LocalPlayer then
    warn("[LightAdmin v2] ❌ LocalPlayer is nil - are you running this as Server Script? Put it in StarterPlayerScripts as LocalScript!")
    return
end

local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
    warn("[LightAdmin v2] PlayerGui not found, waiting for CharacterAdded")
    LocalPlayer.CharacterAdded:Wait()
    PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
end

local Camera = workspace.CurrentCamera or workspace:WaitForChild("CurrentCamera", 5) or nil
-- fallback if camera nil early
if not Camera then
    RunService.RenderStepped:Wait()
    Camera = workspace.CurrentCamera
end

--// CONFIG
local CONFIG = {
    AdminIds = {}, -- сюда свои ID: {12345678, 87654321}
    AllowStudio = true,
    AllowOwner = true,
    GroupRank = 200,
    ToggleKey = Enum.KeyCode.RightShift,
    StartFly = true,      -- ТВОЕ ТРЕБОВАНИЕ: полёт сразу
    StartNoclip = true,   -- ТВОЕ ТРЕБОВАНИЕ: ноуклип сразу с полётом
    AutoDelay = 0.7,
    FlySpeed = 80,
    FastFlyMultiplier = 2.5,
}

--// ADMIN CHECK
local function isAdmin()
    if CONFIG.AllowStudio and RunService:IsStudio() then return true end
    for _, id in ipairs(CONFIG.AdminIds) do if id == LocalPlayer.UserId then return true end end
    local ok, res = pcall(function()
        if CONFIG.AllowOwner and game.CreatorType == Enum.CreatorType.User then
            return game.CreatorId == LocalPlayer.UserId
        end
        if game.CreatorType == Enum.CreatorType.Group then
            return LocalPlayer:GetRankInGroup(game.CreatorId) >= CONFIG.GroupRank
        end
        return false
    end)
    return ok and res
end
if not isAdmin() then return end

--// THEME
local C = {
    BG = Color3.fromRGB(16,18,27),
    Panel = Color3.fromRGB(26,28,40),
    Top = Color3.fromRGB(32,36,52),
    Btn = Color3.fromRGB(40,44,66),
    BtnHov = Color3.fromRGB(52,58,88),
    On = Color3.fromRGB(71,209,108),
    Off = Color3.fromRGB(40,44,66),
    Red = Color3.fromRGB(230,78,78),
    Blue = Color3.fromRGB(99,132,255),
    Text = Color3.fromRGB(235,237,245),
    Dim = Color3.fromRGB(145,152,176),
    Stroke = Color3.fromRGB(68,76,110),
}

--// STATE - 34 ФИЧИ
local S = {
    -- 1-2 core
    Fly = false,
    Noclip = false,
    -- 3-10 movement
    InfiniteJump = false,
    Speed = 1,
    JumpPower = 1,
    LowGrav = false,
    HighJump = false,
    Sprint = false,
    Freeze = false,
    FastFly = false,
    -- 11-20 teleport/world
    ClickTP = false,
    Checkpoint = nil,
    Platform = nil,
    SafePlatform = false,
    -- 21-28 visual
    Fullbright = false,
    NoFog = false,
    NoShadows = false,
    NoPostFx = false,
    ESP = false,
    Tracers = false,
    NameTags = false,
    Freecam = false,
    -- 29-34 char/utility
    God = false,
    Invisible = false,
    AntiAFK = false,
    Coords = true,
    Spectating = nil,
}

local Runtime = {
    FlySpeed = CONFIG.FlySpeed,
    FOV = Camera and Camera.FieldOfView or 70,
    FPS = 0,
    Dragging = false,
    Keys = {},
}

local Saved = {
    WalkSpeed = 16,
    JumpPower = 50,
    JumpHeight = 7.2,
    Gravity = workspace.Gravity,
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    Shadows = Lighting.GlobalShadows,
    ClockTime = Lighting.ClockTime,
    FOV = Runtime.FOV,
}

local Connections = {}
local ESPCache = {}
local TagCache = {}
local PostFxCache = {}
local CollisionCache = {}
local FlyBV, FlyBG

--// UTILS
local function Notify(t, txt, d)
    pcall(function() StarterGui:SetCore("SendNotification", {Title=t, Text=txt, Duration=d or 3}) end)
end
local function GetChar(b) return b and LocalPlayer.Character or LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function GetRoot(b)
    local c = GetChar(b)
    if not c then return nil end
    return b==false and c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart",3)
end
local function GetHum(b)
    local c = GetChar(b)
    if not c then return nil end
    return b==false and c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid",3)
end

--// UI CREATION
local Gui = Instance.new("ScreenGui")
Gui.Name = "LightAdmin_v2"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(440, 580)
Main.Position = UDim2.new(0, 20, 0.5, -290)
Main.BackgroundColor3 = C.Panel
Main.BorderSizePixel = 0
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)
local MS = Instance.new("UIStroke", Main); MS.Color=C.Stroke; MS.Thickness=1; MS.Transparency=0.3

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1,0,0,50)
Top.BackgroundColor3 = C.Top
Top.BorderSizePixel=0
Top.Parent=Main
Instance.new("UICorner", Top).CornerRadius=UDim.new(0,14)
local TopFix = Instance.new("Frame", Top); TopFix.Size=UDim2.new(1,0,0,14); TopFix.Position=UDim2.new(0,0,1,-14); TopFix.BackgroundColor3=C.Top; TopFix.BorderSizePixel=0; TopFix.ZIndex=0

local Title = Instance.new("TextLabel", Top)
Title.BackgroundTransparency=1
Title.Position=UDim2.fromOffset(14,6)
Title.Size=UDim2.new(1,-90,0,20)
Title.Font=Enum.Font.GothamBold
Title.Text="LIGHT ADMIN v2 • 34 features • FLY+NOCLIP ON START"
Title.TextColor3=C.Text
Title.TextSize=13
Title.TextXAlignment=Left

local Sub = Instance.new("TextLabel", Top)
Sub.BackgroundTransparency=1
Sub.Position=UDim2.fromOffset(14,26)
Sub.Size=UDim2.new(1,-90,0,16)
Sub.Font=Enum.Font.Gotham
Sub.Text="RightShift - hide | WASD Space Ctrl Shift (fast) | lightweight"
Sub.TextColor3=C.Dim
Sub.TextSize=11
Sub.TextXAlignment=Left

local HideBtn = Instance.new("TextButton", Top)
HideBtn.Size=UDim2.fromOffset(32,30); HideBtn.AnchorPoint=Vector2.new(1,0.5); HideBtn.Position=UDim2.new(1,-12,0.5,0)
HideBtn.BackgroundColor3=C.Btn; HideBtn.Text="–"; HideBtn.Font=Enum.Font.GothamBold; HideBtn.TextSize=20; HideBtn.TextColor3=C.Text
Instance.new("UICorner", HideBtn).CornerRadius=UDim.new(0,8)
HideBtn.MouseButton1Click:Connect(function() Main.Visible=false end)

local Search = Instance.new("TextBox", Main)
Search.PlaceholderText="Поиск фичи... (напр. fly, esp, god)"
Search.Position=UDim2.fromOffset(12,60)
Search.Size=UDim2.new(1,-24,0,28)
Search.BackgroundColor3=Color3.fromRGB(21,23,35)
Search.TextColor3=C.Text; Search.PlaceholderColor3=C.Dim
Search.Font=Enum.Font.Gotham; Search.TextSize=12; Search.Text=""
Instance.new("UICorner", Search).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke", Search).Color=C.Stroke

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Position=UDim2.fromOffset(10,94)
Scroll.Size=UDim2.new(1,-20,1,-144)
Scroll.BackgroundTransparency=1
Scroll.BorderSizePixel=0
Scroll.ScrollBarThickness=4
Scroll.ScrollBarImageColor3=C.Stroke
Scroll.CanvasSize=UDim2.fromOffset(0,0)
Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
local LL = Instance.new("UIListLayout", Scroll); LL.Padding=UDim.new(0,6); LL.SortOrder=Enum.SortOrder.LayoutOrder

local Status = Instance.new("TextLabel", Main)
Status.Position=UDim2.new(0,12,1,-44)
Status.Size=UDim2.new(1,-24,0,32)
Status.BackgroundColor3=Color3.fromRGB(20,22,34)
Status.TextColor3=C.Dim; Status.Font=Enum.Font.Gotham; Status.TextSize=11
Status.TextWrapped=true; Status.Text="Init..."
Instance.new("UICorner", Status).CornerRadius=UDim.new(0,8)

local CoordsHud = Instance.new("TextLabel", Gui)
CoordsHud.Name="CoordsHUD"
CoordsHud.Position=UDim2.new(0,16,1,-74)
CoordsHud.Size=UDim2.fromOffset(320,52)
CoordsHud.BackgroundColor3=Color3.fromRGB(14,16,24); CoordsHud.BackgroundTransparency=0.15
CoordsHud.Font=Enum.Font.Code; CoordsHud.TextSize=13; CoordsHud.TextColor3=Color3.fromRGB(220,230,255)
CoordsHud.TextXAlignment=Left; CoordsHud.Text=""
Instance.new("UICorner", CoordsHud).CornerRadius=UDim.new(0,8)
local CP = Instance.new("UIPadding", CoordsHud); CP.PaddingLeft=UDim.new(0,10); CP.PaddingRight=UDim.new(0,10)

local function SetStatus(t, warn)
    Status.Text = t
    Status.TextColor3 = warn and Color3.fromRGB(255,180,180) or C.Dim
end

--// BUTTON FACTORY
local AllButtons = {}
local function MakeCategory(name)
    local l = Instance.new("TextLabel", Scroll)
    l.Size=UDim2.new(1,-6,0,20)
    l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold; l.TextColor3=C.Blue; l.TextSize=12; l.TextXAlignment=Left
    l.Text="  "..name:upper()
    l.Name="CAT_"..name
    return l
end
local function MakeBtn(text, getActive, cb)
    local b = Instance.new("TextButton", Scroll)
    b.Size=UDim2.new(1,-6,0,34)
    b.BackgroundColor3=C.Btn
    b.AutoButtonColor=false
    b.Font=Enum.Font.GothamSemibold
    b.Text="  "..text
    b.TextSize=13
    b.TextColor3=C.Text
    b.TextXAlignment=Left
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
    local s = Instance.new("UIStroke", b); s.Color=C.Stroke; s.Transparency=0.6
    b.MouseEnter:Connect(function() if not (getActive and getActive()) then b.BackgroundColor3=C.BtnHov end end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = (getActive and getActive()) and C.On or C.Btn; b.TextColor3 = (getActive and getActive()) and Color3.new(1,1,1) or C.Text end)
    b.Activated:Connect(function()
        local ok,err=pcall(cb)
        if not ok then SetStatus("Error: "..tostring(err), true); warn(err) end
        for _,v in ipairs(AllButtons) do
            local act = v.getActive and v.getActive()
            v.btn.BackgroundColor3 = act and C.On or C.Btn
            v.btn.TextColor3 = act and Color3.new(1,1,1) or C.Text
        end
    end)
    table.insert(AllButtons,{btn=b,getActive=getActive,text=text:lower()})
    -- active refresh
    task.defer(function()
        local act = getActive and getActive()
        b.BackgroundColor3 = act and C.On or C.Btn
    end)
    return b
end

--// FEATURES LOGIC

-- Fly System (modern + legacy support)
local function DestroyFly()
    if FlyBV then FlyBV:Destroy(); FlyBV=nil end
    if FlyBG then FlyBG:Destroy(); FlyBG=nil end
    if Connections.Fly then Connections.Fly:Disconnect(); Connections.Fly=nil end
end
local function EnsureFly(root)
    if FlyBV and FlyBV.Parent and FlyBG and FlyBG.Parent then return end
    DestroyFly()
    FlyBV = Instance.new("BodyVelocity")
    FlyBV.MaxForce=Vector3.new(1e9,1e9,1e9); FlyBV.P=12500; FlyBV.Velocity=Vector3.zero; FlyBV.Parent=root
    FlyBG = Instance.new("BodyGyro")
    FlyBG.MaxTorque=Vector3.new(1e9,1e9,1e9); FlyBG.P=12500; FlyBG.CFrame=root.CFrame; FlyBG.Parent=root
end
local function GetCurrentCamera()
    return workspace.CurrentCamera or Camera
end
local function GetMoveDir(cam)
    cam = cam or GetCurrentCamera()
    if not cam then return Vector3.zero end
    local dir=Vector3.zero
    local K=Runtime.Keys
    if K[Enum.KeyCode.W] then dir+=cam.CFrame.LookVector end
    if K[Enum.KeyCode.S] then dir-=cam.CFrame.LookVector end
    if K[Enum.KeyCode.A] then dir-=cam.CFrame.RightVector end
    if K[Enum.KeyCode.D] then dir+=cam.CFrame.RightVector end
    if K[Enum.KeyCode.Space] or K[Enum.KeyCode.E] then dir+=Vector3.yAxis end
    if K[Enum.KeyCode.LeftControl] or K[Enum.KeyCode.Q] then dir-=Vector3.yAxis end
    if dir.Magnitude>0 then return dir.Unit else return Vector3.zero end
end
local function SetFly(v)
    S.Fly=v
    if v then
        SetNoclip(true)
        if Connections.Fly then Connections.Fly:Disconnect() end
        Connections.Fly = RunService.RenderStepped:Connect(function()
            local root=GetRoot(false); local hum=GetHum(false); local cam=GetCurrentCamera()
            if not root or not hum or not cam then return end
            EnsureFly(root)
            pcall(function() hum.PlatformStand=true end)
            local speed = Runtime.FlySpeed * (S.FastFly or Runtime.Keys[Enum.KeyCode.LeftShift] and CONFIG.FastFlyMultiplier or 1)
            FlyBV.Velocity = GetMoveDir(cam)*speed
            FlyBG.CFrame = cam.CFrame
        end)
        SetStatus("FLY ON (+NOCLIP ON) | Shift = быстрый полет")
    else
        DestroyFly()
        local hum=GetHum(false); if hum then hum.PlatformStand=false; pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
        local root=GetRoot(false); if root then root.AssemblyLinearVelocity=Vector3.zero end
        SetStatus("FLY OFF")
    end
end

-- Noclip
function SetNoclip(v)
    S.Noclip=v
    if v then
        if Connections.Noclip then Connections.Noclip:Disconnect() end
        Connections.Noclip = RunService.Stepped:Connect(function()
            local char=GetChar(false)
            if not char then return end
            for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    if CollisionCache[p]==nil then CollisionCache[p]=true end
                    p.CanCollide=false
                end
            end
        end)
    else
        if Connections.Noclip then Connections.Noclip:Disconnect(); Connections.Noclip=nil end
        for part,_ in pairs(CollisionCache) do if part and part.Parent then part.CanCollide=true end end
        CollisionCache={}
    end
end

-- Movement multipliers
local function ApplySpeed()
    local hum=GetHum(false); if not hum then return end
    if not Saved.WalkSpeed then Saved.WalkSpeed=hum.WalkSpeed end
    hum.WalkSpeed = Saved.WalkSpeed * S.Speed * (S.Sprint and 1.8 or 1)
end
local function ApplyJump()
    local hum=GetHum(false); if not hum then return end
    if hum.UseJumpPower then
        hum.JumpPower = Saved.JumpPower * S.JumpPower * (S.HighJump and 2 or 1)
    else
        hum.JumpHeight = Saved.JumpHeight * S.JumpPower * (S.HighJump and 2 or 1)
    end
end
local function ApplyGravity()
    workspace.Gravity = S.LowGrav and 35 or Saved.Gravity
end

-- Lighting
local function ApplyLighting()
    Lighting.Brightness = S.Fullbright and 3 or Saved.Brightness
    Lighting.ClockTime = S.Fullbright and 13 or Saved.ClockTime
    Lighting.Ambient = S.Fullbright and Color3.new(1,1,1) or Saved.Ambient
    Lighting.OutdoorAmbient = S.Fullbright and Color3.new(1,1,1) or Saved.OutdoorAmbient
    Lighting.FogStart = S.NoFog and 0 or Saved.FogStart
    Lighting.FogEnd = S.NoFog and 1e6 or Saved.FogEnd
    Lighting.GlobalShadows = not S.NoShadows and Saved.Shadows or false
    -- postfx
    for _,v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") then
            if S.NoPostFx then
                if PostFxCache[v]==nil then PostFxCache[v]=v.Enabled end
                v.Enabled=false
            else
                if PostFxCache[v]~=nil then v.Enabled=PostFxCache[v]; PostFxCache[v]=nil end
            end
        end
    end
end

-- ESP
local function ClearESP()
    for _,h in pairs(ESPCache) do if h then h:Destroy() end end
    ESPCache={}
end
local function UpdateESP()
    if not S.ESP then ClearESP(); return end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character then
            if not ESPCache[plr] or not ESPCache[plr].Parent then
                if ESPCache[plr] then ESPCache[plr]:Destroy() end
                local hl=Instance.new("Highlight")
                hl.FillColor=Color3.fromRGB(0,170,255); hl.OutlineColor=Color3.new(1,1,1)
                hl.FillTransparency=0.7; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee=plr.Character; hl.Parent=Gui
                ESPCache[plr]=hl
            else
                ESPCache[plr].Adornee=plr.Character
            end
        end
    end
end

-- NameTags + Tracers (billboard)
local function ClearTags() for _,v in pairs(TagCache) do if v then v:Destroy() end end; TagCache={} end
local function UpdateTags()
    if not (S.NameTags or S.Tracers) then ClearTags(); return end
    local myRoot=GetRoot(false)
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
            local exist=TagCache[plr]
            if not exist or not exist.Parent then
                local bb=Instance.new("BillboardGui"); bb.Size=UDim2.fromOffset(200,50); bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true; bb.Adornee=plr.Character.Head; bb.Parent=Gui
                local tx=Instance.new("TextLabel",bb); tx.Size=UDim2.fromScale(1,1); tx.BackgroundTransparency=0.2; tx.BackgroundColor3=Color3.fromRGB(12,14,22); tx.Font=Enum.Font.GothamBold; tx.TextSize=12; tx.TextColor3=Color3.new(1,1,1); tx.TextStrokeTransparency=0.5
                Instance.new("UICorner",tx).CornerRadius=UDim.new(0,6)
                TagCache[plr]=bb
                exist=bb
            end
            local hum=plr.Character:FindFirstChildOfClass("Humanoid")
            local hp=hum and math.floor(hum.Health).."/"..math.floor(hum.MaxHealth) or "?"
            local dist=myRoot and plr.Character:FindFirstChild("HumanoidRootPart") and math.floor((myRoot.Position-plr.Character.HumanoidRootPart.Position).Magnitude) or 0
            local label=exist:FindFirstChildOfClass("TextLabel")
            if label then
                label.Text = plr.DisplayName.." @"..plr.Name.."\nHP:"..hp.." | "..dist.." studs"..(S.Tracers and " ◉" or "")
            end
        end
    end
end

-- Invisibility
local InvisTrans={}
local function SetInvisible(v)
    S.Invisible=v
    local char=GetChar(false); if not char then return end
    for _,d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then d.LocalTransparencyModifier = v and 1 or 0
        elseif d:IsA("Decal") or d:IsA("Texture") then
            if v then InvisTrans[d]=d.Transparency; d.Transparency=1 else if InvisTrans[d] then d.Transparency=InvisTrans[d]; InvisTrans[d]=nil end end
        end
    end
end

-- Platform
local function CreatePlatform()
    local root=GetRoot(false); if not root then return end
    if S.Platform then S.Platform:Destroy() end
    local p=Instance.new("Part")
    p.Name="LightAdmin_Platform"; p.Anchored=true; p.Size=Vector3.new(20,1,20); p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(100,140,255); p.Transparency=0.2
    p.CFrame=root.CFrame*CFrame.new(0,-4,0); p.Parent=workspace
    S.Platform=p
    SetStatus("Платформа создана под тобой")
end
local function DeletePlatform()
    if S.Platform then S.Platform:Destroy(); S.Platform=nil; SetStatus("Платформа удалена") end
    local c=0
    for _,v in ipairs(workspace:GetChildren()) do if v.Name=="LightAdmin_Platform" then v:Destroy(); c+=1 end end
    if c>0 then SetStatus("Удалено платформ: "..c) end
end

-- Freecam (noclip camera)
local FreecamCF=nil
local function SetFreecam(v)
    S.Freecam=v
    local cam = GetCurrentCamera()
    if not cam then SetStatus("Camera not ready", true); return end
    if v then
        FreecamCF = cam.CFrame
        cam.CameraType=Enum.CameraType.Scriptable
        if Connections.Freecam then Connections.Freecam:Disconnect() end
        Connections.Freecam=RunService.RenderStepped:Connect(function()
            local curCam = GetCurrentCamera()
            if not curCam then return end
            local move=GetMoveDir(curCam)*Runtime.FlySpeed*0.15
            FreecamCF = FreecamCF * CFrame.new(move)
            curCam.CFrame=FreecamCF
        end)
        SetStatus("Freecam ON - летаешь камерой")
    else
        if Connections.Freecam then Connections.Freecam:Disconnect(); Connections.Freecam=nil end
        cam.CameraType=Enum.CameraType.Custom
        local hum=GetHum(false)
        if hum then cam.CameraSubject=hum end
        SetStatus("Freecam OFF")
    end
end

--// BUILD UI - 34 FEATURES GROUPED

MakeCategory("🚀 Полёт и Мувмент (твое требование)")

MakeBtn("✈️ Fly - летать (WASD + Space/Ctrl + Shift)", function() return S.Fly end, function() SetFly(not S.Fly) end)
MakeBtn("🚧 Noclip - проходить сквозь стены", function() return S.Noclip end, function() SetNoclip(not S.Noclip) end)
MakeBtn("⚡ Fly Speed +20", nil, function() Runtime.FlySpeed+=20; SetStatus("Fly speed: "..Runtime.FlySpeed) end)
MakeBtn("🐢 Fly Speed -20", nil, function() Runtime.FlySpeed=math.max(20, Runtime.FlySpeed-20); SetStatus("Fly speed: "..Runtime.FlySpeed) end)
MakeBtn("💨 Fast Fly (Shift удержание)", function() return S.FastFly end, function() S.FastFly=not S.FastFly; SetStatus(S.FastFly and "FastFly ON" or "FastFly OFF") end)
MakeBtn("🏃 Sprint x1.8", function() return S.Sprint end, function() S.Sprint=not S.Sprint; ApplySpeed(); SetStatus(S.Sprint and "Sprint ON" or "Sprint OFF") end)
MakeBtn("🏃‍♂️ Speed x2", function() return S.Speed==2 end, function() S.Speed = S.Speed==2 and 1 or 2; ApplySpeed() end)
MakeBtn("🏎️ Speed x4", function() return S.Speed==4 end, function() S.Speed = S.Speed==4 and 1 or 4; ApplySpeed() end)
MakeBtn("🦘 Infinite Jump", function() return S.InfiniteJump end, function() S.InfiniteJump=not S.InfiniteJump end)
MakeBtn("🌙 Low Gravity (35)", function() return S.LowGrav end, function() S.LowGrav=not S.LowGrav; ApplyGravity() end)
MakeBtn("⬆️ High Jump x2", function() return S.HighJump end, function() S.HighJump=not S.HighJump; S.JumpPower = S.HighJump and 2 or 1; ApplyJump() end)
MakeBtn("🧊 Freeze / Unfreeze", function() return S.Freeze end, function() local r=GetRoot(false); if r then r.Anchored=not r.Anchored; S.Freeze=r.Anchored end end)

MakeCategory("📍 Телепорт и Мир - 8 фич")

MakeBtn("👆 Click Teleport - тп на клик", function() return S.ClickTP end, function()
    S.ClickTP=not S.ClickTP
    if Connections.ClickTP then Connections.ClickTP:Disconnect(); Connections.ClickTP=nil end
    if S.ClickTP then
        local mouse=LocalPlayer:GetMouse()
        Connections.ClickTP=mouse.Button1Down:Connect(function()
            if not S.ClickTP then return end
            if UserInputService:GetFocusedTextBox() then return end
            local root=GetRoot(false)
            if root and mouse.Hit then root.CFrame=CFrame.new(mouse.Hit.Position+Vector3.new(0,5,0)) end
        end)
        SetStatus("ClickTP ON - кликни по миру")
    else SetStatus("ClickTP OFF") end
end)
MakeBtn("⬆️ TP +80 studs вверх", nil, function() local r=GetRoot(false); if r then r.CFrame+=Vector3.new(0,80,0) end end)
MakeBtn("🏠 TP to SpawnLocation", nil, function()
    local sp=nil
    for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("SpawnLocation") then sp=v; break end end
    local r=GetRoot(false)
    if sp and r then r.CFrame=sp.CFrame+Vector3.new(0,5,0); SetStatus("TP to Spawn") else SetStatus("Spawn not found",true) end
end)
MakeBtn("💾 Save Checkpoint", nil, function() local r=GetRoot(false); if r then S.Checkpoint=r.CFrame; SetStatus("Checkpoint saved") end end)
MakeBtn("📥 Load Checkpoint", nil, function() local r=GetRoot(false); if r and S.Checkpoint then r.CFrame=S.Checkpoint+Vector3.new(0,3,0) else SetStatus("No checkpoint",true) end end)
MakeBtn("🧱 Create Platform (Btools)", nil, CreatePlatform)
MakeBtn("🗑️ Delete Platform", nil, DeletePlatform)
MakeBtn("🔒 Safe Anti-Fall Platform (auto)", function() return S.SafePlatform end, function() S.SafePlatform=not S.SafePlatform end)

MakeCategory("👁️ Визуал - 8 фич")

MakeBtn("☀️ Fullbright - всегда день", function() return S.Fullbright end, function() S.Fullbright=not S.Fullbright; ApplyLighting() end)
MakeBtn("🌫️ No Fog - убрать туман", function() return S.NoFog end, function() S.NoFog=not S.NoFog; ApplyLighting() end)
MakeBtn("◼️ No Shadows", function() return S.NoShadows end, function() S.NoShadows=not S.NoShadows; ApplyLighting() end)
MakeBtn("✨ Clear Post FX (Blur/Bloom)", function() return S.NoPostFx end, function() S.NoPostFx=not S.NoPostFx; ApplyLighting() end)
MakeBtn("👀 ESP - подсветка игроков", function() return S.ESP end, function() S.ESP=not S.ESP; UpdateESP() end)
MakeBtn("🎯 Tracers + NameTags HP + дист", function() return S.NameTags end, function() S.NameTags=not S.NameTags; S.Tracers=S.NameTags; UpdateTags() end)
MakeBtn("📷 Freecam - свободная камера", function() return S.Freecam end, function() SetFreecam(not S.Freecam) end)
MakeBtn("🔭 FOV +10 (широкий обзор)", nil, function() local cam=GetCurrentCamera(); if cam then cam.FieldOfView=math.min(120,cam.FieldOfView+10); SetStatus("FOV: "..cam.FieldOfView) end end)
MakeBtn("🔬 FOV -10 (узкий)", nil, function() local cam=GetCurrentCamera(); if cam then cam.FieldOfView=math.max(30,cam.FieldOfView-10); SetStatus("FOV: "..cam.FieldOfView) end end)
MakeBtn("🎥 Reset FOV", nil, function() local cam=GetCurrentCamera(); if cam then cam.FieldOfView=Saved.FOV end end)
MakeBtn("📍 Coords HUD", function() return S.Coords end, function() S.Coords=not S.Coords; CoordsHud.Visible=S.Coords end)

MakeCategory("🧍 Персонаж и Утилиты - 10 фич")

MakeBtn("❤️ Heal - вылечить", nil, function() local h=GetHum(false); if h then h.Health=h.MaxHealth; SetStatus("Healed") end end)
MakeBtn("♾️ GodMode - авто-хил", function() return S.God end, function() S.God=not S.God; SetStatus(S.God and "God ON" or "God OFF") end)
MakeBtn("👻 Invisible local", function() return S.Invisible end, function() SetInvisible(not S.Invisible) end)
MakeBtn("💺 Sit / Stand", nil, function() local h=GetHum(false); if h then h.Sit=not h.Sit end end)
MakeBtn("🔄 Reset Character (die)", nil, function() local h=GetHum(false); if h then h.Health=0 end end)
MakeBtn("📋 Copy CFrame в Output (F9)", nil, function() local r=GetRoot(false); if r then print("[Admin CFrame] CFrame.new("..(math.floor(r.Position.X*100)/100)..", "..(math.floor(r.Position.Y*100)/100)..", "..(math.floor(r.Position.Z*100)/100)..")"); SetStatus("CFrame скопирован в Output") end end)
MakeBtn("👁️ Spectate - смотреть за игроками (рандом)", nil, function()
    local list={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") then table.insert(list,p) end end
    if #list==0 then SetStatus("Нет игроков для спектатора",true); return end
    local idx = math.random(1,#list)
    local target=list[idx]
    local cam = GetCurrentCamera()
    if not cam then return end
    if S.Spectating==target then
        S.Spectating=nil; cam.CameraSubject=GetHum(false); SetStatus("Spectate OFF")
    else
        S.Spectating=target; cam.CameraSubject=target.Character.Humanoid; SetStatus("Spectate: "..target.Name.." (нажми снова чтобы выкл)")
    end
end)
MakeBtn("😴 Anti-AFK - не кикает", function() return S.AntiAFK end, function() S.AntiAFK=not S.AntiAFK end)
MakeBtn("🔁 Rejoin Server", nil, function() pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end) end)
MakeBtn("🌐 Server Hop", nil, function() pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end)
MakeBtn("💥 Panic - сбросить всё", nil, function()
    SetFly(false); SetNoclip(false); SetFreecam(false); if Connections.ClickTP then Connections.ClickTP:Disconnect() end
    S.Speed=1; S.Sprint=false; S.HighJump=false; S.JumpPower=1; S.LowGrav=false; S.InfiniteJump=false; S.Freeze=false; S.FastFly=false
    S.ClickTP=false; S.SafePlatform=false; DeletePlatform()
    S.Fullbright=false; S.NoFog=false; S.NoShadows=false; S.NoPostFx=false; S.ESP=false; S.NameTags=false; S.Tracers=false
    S.God=false; S.Invisible=false; S.AntiAFK=false
    ApplySpeed(); ApplyJump(); ApplyGravity(); ApplyLighting(); ClearESP(); ClearTags(); SetInvisible(false)
    local r=GetRoot(false); if r then r.Anchored=false end
    local h=GetHum(false); if h then h.PlatformStand=false end
    SetStatus("PANIC RESET DONE")
end)

--// SEARCH
Search:GetPropertyChangedSignal("Text"):Connect(function()
    local q=Search.Text:lower()
    for _,e in ipairs(AllButtons) do
        e.btn.Visible = q=="" or string.find(e.text,q,1,true)~=nil
    end
    for _,child in ipairs(Scroll:GetChildren()) do if child:IsA("TextLabel") and child.Name:match("CAT_") then child.Visible=true end end
end)

--// DRAG
local dragStart, startPos
Top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then Runtime.Dragging=true; dragStart=i.Position; startPos=Main.Position end end)
Top.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then Runtime.Dragging=false end end)
UserInputService.InputChanged:Connect(function(i) if Runtime.Dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) and dragStart and startPos then local d=i.Position-dragStart; Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

--// INPUTS
UserInputService.InputBegan:Connect(function(input,gp)
    if input.UserInputType~=Enum.UserInputType.Keyboard then return end
    Runtime.Keys[input.KeyCode]=true
    if input.KeyCode==CONFIG.ToggleKey and not gp then Main.Visible=not Main.Visible; SetStatus(Main.Visible and "Panel shown" or "Panel hidden - RightShift") end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.Keyboard then Runtime.Keys[input.KeyCode]=nil end end)
UserInputService.JumpRequest:Connect(function() if S.InfiniteJump then local h=GetHum(false); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)

--// ANTI AFK
LocalPlayer.Idled:Connect(function() if S.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end); SetStatus("Anti-AFK click sent") end end)

--// MAIN LOOPS
Connections.Heartbeat = RunService.Heartbeat:Connect(function()
    -- speed always enforce
    if S.Speed>1 or S.Sprint then ApplySpeed() end
    if S.HighJump or S.JumpPower>1 then ApplyJump() end
    if S.God then local h=GetHum(false); if h and h.Health>0 then h.Health=h.MaxHealth end end
    if S.Invisible then local char=GetChar(false); if char then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier=1 end end end end
end)

local fpsT=0; local fpsC=0
Connections.Render = RunService.RenderStepped:Connect(function(dt)
    fpsC+=1; fpsT+=dt; if fpsT>=1 then Runtime.FPS=math.floor(fpsC/fpsT+0.5); fpsC=0; fpsT=0 end
    if tick()%0.6<0.1 then if S.ESP then UpdateESP() end; if S.NameTags then UpdateTags() end end
    if S.Coords then
        local r=GetRoot(false)
        if r then CoordsHud.Text=string.format("XYZ: %.1f, %.1f, %.1f | Fly:%d | FPS:%d | %s", r.Position.X, r.Position.Y, r.Position.Z, Runtime.FlySpeed, Runtime.FPS, S.Fly and "FLY ON" or "FLY OFF") else CoordsHud.Text="Character not loaded" end
    end
end)

--// CHARACTER RESPAWN HANDLING
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hum=char:WaitForChild("Humanoid",5)
    if hum then Saved.WalkSpeed=hum.WalkSpeed; Saved.JumpPower=hum:GetAttribute("JumpPower") or hum.JumpPower end
    if S.Invisible then task.wait(0.2); SetInvisible(true) end
    ApplySpeed(); ApplyJump()
    DestroyFly() -- will re-create if fly still on
end)

--// AUTO START - ТВОЕ ТРЕБОВАНИЕ
Notify("Light Admin v2", "Loaded! "..(CONFIG.StartFly and "Fly+Noclip auto-start..." or ""),3)
SetStatus("v2 Loaded! 34 features ready. Auto-start...")
task.delay(CONFIG.AutoDelay, function()
    if CONFIG.StartNoclip then SetNoclip(true) end
    if CONFIG.StartFly then SetFly(true) end
    for _,e in ipairs(AllButtons) do e.btn.BackgroundColor3 = (e.getActive and e.getActive()) and C.On or C.Btn end
    SetStatus("✅ Fly + Noclip включены сразу! RightShift - скрыть")
end)

print("[LightAdmin v2] Loaded with 34 features - Fly + Noclip auto ON - by Arena")
