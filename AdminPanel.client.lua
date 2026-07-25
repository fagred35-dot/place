--[[
    Lightweight Test Admin Panel for Roblox
    Put this LocalScript into StarterPlayer > StarterPlayerScripts.

    It is intended for testing your own place. Most actions are client-side only
    and are not a replacement for a secure server-side admin system.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    -- Add your Roblox UserId here for live servers, for example: {123456789}
    AdminUserIds = {},

    -- In Studio the panel is available automatically for easy testing.
    AllowInStudio = true,

    -- In live games the owner of a user-owned place is allowed automatically.
    AllowPlaceOwner = true,

    -- If the place is owned by a group, players with this rank or higher are allowed.
    GroupMinimumRank = 200,

    TogglePanelKey = Enum.KeyCode.RightShift,

    -- The requested default: fly starts enabled and automatically turns noclip on too.
    StartWithFly = true,
    StartWithNoclip = true,
    AutoStartDelay = 1,

    BaseFlySpeed = 70,
}

local function arrayContains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function isAllowedAdmin()
    if CONFIG.AllowInStudio and RunService:IsStudio() then
        return true
    end

    if arrayContains(CONFIG.AdminUserIds, LocalPlayer.UserId) then
        return true
    end

    local ok, result = pcall(function()
        if CONFIG.AllowPlaceOwner and game.CreatorType == Enum.CreatorType.User then
            return game.CreatorId == LocalPlayer.UserId
        end

        if game.CreatorType == Enum.CreatorType.Group then
            return LocalPlayer:GetRankInGroup(game.CreatorId) >= CONFIG.GroupMinimumRank
        end

        return false
    end)

    return ok and result == true
end

if not isAllowedAdmin() then
    return
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3,
        })
    end)
end

local THEME = {
    Background = Color3.fromRGB(18, 20, 28),
    Panel = Color3.fromRGB(27, 30, 42),
    Top = Color3.fromRGB(34, 38, 54),
    Button = Color3.fromRGB(42, 47, 65),
    ButtonHover = Color3.fromRGB(55, 62, 86),
    Active = Color3.fromRGB(67, 162, 104),
    Warning = Color3.fromRGB(206, 82, 82),
    Text = Color3.fromRGB(238, 241, 247),
    Muted = Color3.fromRGB(168, 175, 194),
    Stroke = Color3.fromRGB(74, 84, 116),
    Accent = Color3.fromRGB(91, 143, 255),
}

local state = {
    fly = false,
    noclip = false,
    speedMultiplier = 1,
    jumpMultiplier = 1,
    infiniteJump = false,
    lowGravity = false,
    highGravity = false,
    fullbright = false,
    noFog = false,
    noShadows = false,
    cleanPostFx = false,
    highFov = false,
    cinematicFov = false,
    esp = false,
    nameTags = false,
    clickTeleport = false,
    autoHeal = false,
    invisible = false,
    freeze = false,
    antiAfk = false,
    coordsHud = true,
}

local runtime = {
    flySpeed = CONFIG.BaseFlySpeed,
    checkpoint = nil,
    dragging = false,
    fps = 0,
    lastVisualRefresh = 0,
    lastHudUpdate = 0,
}

local lightingDefaults = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
}

local defaultGravity = workspace.Gravity
local defaultFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70

local humanoidDefaults = setmetatable({}, { __mode = "k" })
local collisionDefaults = setmetatable({}, { __mode = "k" })
local invisibleDefaults = setmetatable({}, { __mode = "k" })
local disabledEffects = setmetatable({}, { __mode = "k" })

local flyConnection = nil
local noclipConnection = nil
local flyVelocity = nil
local flyGyro = nil
local flyRoot = nil
local clickTeleportConnection = nil

local keysDown = {}
local buttons = {}
local espObjects = {}
local nameTagObjects = {}

local localObjectsFolder = workspace:FindFirstChild("ArenaAdminLocalObjects")
if not localObjectsFolder then
    localObjectsFolder = Instance.new("Folder")
    localObjectsFolder.Name = "ArenaAdminLocalObjects"
    localObjectsFolder.Parent = workspace
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ArenaTestAdminPanel"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.AnchorPoint = Vector2.new(0, 0.5)
mainFrame.Position = UDim2.new(0, 20, 0.5, 0)
mainFrame.Size = UDim2.fromOffset(430, 560)
mainFrame.BackgroundColor3 = THEME.Panel
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = THEME.Stroke
mainStroke.Thickness = 1
mainStroke.Transparency = 0.25
mainStroke.Parent = mainFrame

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundColor3 = THEME.Top
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(16, 7)
titleLabel.Size = UDim2.new(1, -78, 0, 22)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Test Admin Panel"
titleLabel.TextColor3 = THEME.Text
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Position = UDim2.fromOffset(16, 28)
subtitleLabel.Size = UDim2.new(1, -78, 0, 18)
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextWrapped = false
subtitleLabel.Text = "RightShift - hide/show | Fly: WASD + Space/Ctrl"
subtitleLabel.TextColor3 = THEME.Muted
subtitleLabel.TextSize = 12
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = topBar

local hideButton = Instance.new("TextButton")
hideButton.Name = "HideButton"
hideButton.AnchorPoint = Vector2.new(1, 0.5)
hideButton.Position = UDim2.new(1, -14, 0.5, 0)
hideButton.Size = UDim2.fromOffset(34, 30)
hideButton.BackgroundColor3 = THEME.Button
hideButton.BorderSizePixel = 0
hideButton.AutoButtonColor = false
hideButton.Font = Enum.Font.GothamBold
hideButton.Text = "–"
hideButton.TextColor3 = THEME.Text
hideButton.TextSize = 22
hideButton.Parent = topBar

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 8)
hideCorner.Parent = hideButton

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "Actions"
scrollFrame.Position = UDim2.fromOffset(12, 62)
scrollFrame.Size = UDim2.new(1, -24, 1, -112)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 5
scrollFrame.ScrollBarImageColor3 = THEME.Stroke
scrollFrame.CanvasSize = UDim2.fromOffset(0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 7)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.AnchorPoint = Vector2.new(0.5, 1)
statusLabel.Position = UDim2.new(0.5, 0, 1, -12)
statusLabel.Size = UDim2.new(1, -24, 0, 34)
statusLabel.BackgroundColor3 = Color3.fromRGB(21, 24, 34)
statusLabel.BorderSizePixel = 0
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Loading admin tools..."
statusLabel.TextColor3 = THEME.Muted
statusLabel.TextSize = 12
statusLabel.TextWrapped = true
statusLabel.Parent = mainFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 9)
statusCorner.Parent = statusLabel

local coordsLabel = Instance.new("TextLabel")
coordsLabel.Name = "CoordinatesHud"
coordsLabel.AnchorPoint = Vector2.new(0, 1)
coordsLabel.Position = UDim2.new(0, 18, 1, -18)
coordsLabel.Size = UDim2.fromOffset(350, 64)
coordsLabel.BackgroundColor3 = Color3.fromRGB(14, 16, 23)
coordsLabel.BackgroundTransparency = 0.18
coordsLabel.BorderSizePixel = 0
coordsLabel.Font = Enum.Font.Code
coordsLabel.TextColor3 = Color3.fromRGB(230, 238, 255)
coordsLabel.TextSize = 14
coordsLabel.TextXAlignment = Enum.TextXAlignment.Left
coordsLabel.TextYAlignment = Enum.TextYAlignment.Center
coordsLabel.Text = ""
coordsLabel.Visible = state.coordsHud
coordsLabel.Parent = screenGui

local coordsPadding = Instance.new("UIPadding")
coordsPadding.PaddingLeft = UDim.new(0, 10)
coordsPadding.PaddingRight = UDim.new(0, 10)
coordsPadding.Parent = coordsLabel

local coordsCorner = Instance.new("UICorner")
coordsCorner.CornerRadius = UDim.new(0, 8)
coordsCorner.Parent = coordsLabel

local function setStatus(text, isWarning)
    statusLabel.Text = text
    statusLabel.TextColor3 = isWarning and Color3.fromRGB(255, 193, 193) or THEME.Muted
end

local function getCharacter(waitForIt)
    local character = LocalPlayer.Character
    if character or waitForIt == false then
        return character
    end
    return LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid(waitForIt)
    local character = getCharacter(waitForIt)
    if not character then
        return nil
    end

    if waitForIt == false then
        return character:FindFirstChildOfClass("Humanoid")
    end

    return character:WaitForChild("Humanoid", 5)
end

local function getRoot(waitForIt)
    local character = getCharacter(waitForIt)
    if not character then
        return nil
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if root or waitForIt == false then
        return root
    end

    return character:WaitForChild("HumanoidRootPart", 5)
end

local function getHumanoidDefaults(humanoid)
    local saved = humanoidDefaults[humanoid]
    if saved then
        return saved
    end

    saved = {
        WalkSpeed = humanoid.WalkSpeed,
        JumpPower = humanoid.JumpPower,
        JumpHeight = humanoid.JumpHeight,
    }

    humanoidDefaults[humanoid] = saved
    return saved
end

local function applyMovementSettings()
    local humanoid = getHumanoid(false)
    if not humanoid then
        return
    end

    local defaults = getHumanoidDefaults(humanoid)

    if state.speedMultiplier ~= 1 then
        humanoid.WalkSpeed = math.max(1, defaults.WalkSpeed * state.speedMultiplier)
    end

    if state.jumpMultiplier ~= 1 then
        pcall(function()
            if humanoid.UseJumpPower then
                humanoid.JumpPower = math.max(1, defaults.JumpPower * state.jumpMultiplier)
            else
                humanoid.JumpHeight = math.max(1, defaults.JumpHeight * state.jumpMultiplier)
            end
        end)
    end
end

local function resetMovementSettings()
    local humanoid = getHumanoid(false)
    if not humanoid then
        return
    end

    local defaults = getHumanoidDefaults(humanoid)
    humanoid.WalkSpeed = defaults.WalkSpeed
    pcall(function()
        humanoid.JumpPower = defaults.JumpPower
        humanoid.JumpHeight = defaults.JumpHeight
    end)
end

local function applyGravity()
    if state.lowGravity then
        workspace.Gravity = 50
    elseif state.highGravity then
        workspace.Gravity = 300
    else
        workspace.Gravity = defaultGravity
    end
end

local function applyLighting()
    Lighting.Brightness = state.fullbright and 3 or lightingDefaults.Brightness
    Lighting.ClockTime = state.fullbright and 14 or lightingDefaults.ClockTime
    Lighting.Ambient = state.fullbright and Color3.fromRGB(255, 255, 255) or lightingDefaults.Ambient
    Lighting.OutdoorAmbient = state.fullbright and Color3.fromRGB(255, 255, 255) or lightingDefaults.OutdoorAmbient
    Lighting.FogStart = state.noFog and 0 or lightingDefaults.FogStart
    Lighting.FogEnd = state.noFog and 1000000 or lightingDefaults.FogEnd
    Lighting.GlobalShadows = state.noShadows and false or lightingDefaults.GlobalShadows
end

local function isPostEffect(instance)
    return instance:IsA("BlurEffect")
        or instance:IsA("BloomEffect")
        or instance:IsA("ColorCorrectionEffect")
        or instance:IsA("DepthOfFieldEffect")
        or instance:IsA("SunRaysEffect")
end

local function applyPostFx()
    for _, child in ipairs(Lighting:GetChildren()) do
        if isPostEffect(child) then
            if state.cleanPostFx then
                if disabledEffects[child] == nil then
                    disabledEffects[child] = child.Enabled
                end
                child.Enabled = false
            elseif disabledEffects[child] ~= nil then
                child.Enabled = disabledEffects[child]
                disabledEffects[child] = nil
            end
        end
    end
end

local function applyFov()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    if state.highFov then
        camera.FieldOfView = 100
    elseif state.cinematicFov then
        camera.FieldOfView = 40
    else
        camera.FieldOfView = defaultFov
    end
end

local function refreshButtons()
    for _, entry in ipairs(buttons) do
        local active = entry.isActive and entry.isActive() or false
        entry.button.BackgroundColor3 = active and THEME.Active or THEME.Button
        entry.button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or THEME.Text
    end
end

local function setNoclip(enabled)
    state.noclip = enabled

    if enabled then
        if noclipConnection then
            noclipConnection:Disconnect()
        end

        noclipConnection = RunService.Stepped:Connect(function()
            local character = getCharacter(false)
            if not character then
                return
            end

            for _, descendant in ipairs(character:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    if collisionDefaults[descendant] == nil then
                        collisionDefaults[descendant] = descendant.CanCollide
                    end
                    descendant.CanCollide = false
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end

        for part, canCollide in pairs(collisionDefaults) do
            if part and part.Parent then
                part.CanCollide = canCollide
            end
        end
        collisionDefaults = setmetatable({}, { __mode = "k" })
    end

    refreshButtons()
end

local function destroyFlyObjects()
    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end

    if flyGyro then
        flyGyro:Destroy()
        flyGyro = nil
    end

    flyRoot = nil
end

local function ensureFlyObjects(root)
    if flyRoot == root and flyVelocity and flyGyro and flyVelocity.Parent and flyGyro.Parent then
        return
    end

    destroyFlyObjects()

    flyRoot = root

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "ArenaAdminFlyVelocity"
    flyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
    flyVelocity.P = 25000
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = root

    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "ArenaAdminFlyGyro"
    flyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
    flyGyro.P = 25000
    flyGyro.CFrame = root.CFrame
    flyGyro.Parent = root
end

local function getFlyDirection(camera)
    local direction = Vector3.zero

    if keysDown[Enum.KeyCode.W] then
        direction += camera.CFrame.LookVector
    end
    if keysDown[Enum.KeyCode.S] then
        direction -= camera.CFrame.LookVector
    end
    if keysDown[Enum.KeyCode.A] then
        direction -= camera.CFrame.RightVector
    end
    if keysDown[Enum.KeyCode.D] then
        direction += camera.CFrame.RightVector
    end
    if keysDown[Enum.KeyCode.Space] or keysDown[Enum.KeyCode.E] then
        direction += Vector3.yAxis
    end
    if keysDown[Enum.KeyCode.LeftControl] or keysDown[Enum.KeyCode.Q] then
        direction -= Vector3.yAxis
    end

    if direction.Magnitude > 0 then
        return direction.Unit
    end

    return Vector3.zero
end

local function setFly(enabled)
    state.fly = enabled

    if enabled then
        setNoclip(true)

        if flyConnection then
            flyConnection:Disconnect()
        end

        flyConnection = RunService.RenderStepped:Connect(function()
            local root = getRoot(false)
            local humanoid = getHumanoid(false)
            local camera = workspace.CurrentCamera

            if not root or not humanoid or not camera then
                return
            end

            ensureFlyObjects(root)

            pcall(function()
                humanoid.PlatformStand = true
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            end)

            local direction = getFlyDirection(camera)
            flyVelocity.Velocity = direction * runtime.flySpeed
            flyGyro.CFrame = camera.CFrame
        end)

        setStatus("Fly ON. Noclip is also ON. Controls: WASD + Space/E + Ctrl/Q")
    else
        if flyConnection then
            flyConnection:Disconnect()
            flyConnection = nil
        end

        destroyFlyObjects()

        local humanoid = getHumanoid(false)
        local root = getRoot(false)
        if humanoid then
            humanoid.PlatformStand = false
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            end)
        end
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        setStatus("Fly OFF. Noclip stays as it is.")
    end

    refreshButtons()
end

local function clearEsp()
    for player, highlight in pairs(espObjects) do
        if highlight then
            highlight:Destroy()
        end
        espObjects[player] = nil
    end
end

local function updateEsp()
    if not state.esp then
        clearEsp()
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local existing = espObjects[player]

            if character then
                if not existing or existing.Adornee ~= character or not existing.Parent then
                    if existing then
                        existing:Destroy()
                    end

                    local highlight = Instance.new("Highlight")
                    highlight.Name = "ArenaAdminESP_" .. player.Name
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillColor = Color3.fromRGB(0, 170, 255)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.78
                    highlight.OutlineTransparency = 0
                    highlight.Adornee = character
                    highlight.Parent = screenGui
                    espObjects[player] = highlight
                end
            elseif existing then
                existing:Destroy()
                espObjects[player] = nil
            end
        end
    end

    for player, highlight in pairs(espObjects) do
        if not player.Parent or player == LocalPlayer then
            highlight:Destroy()
            espObjects[player] = nil
        end
    end
end

local function clearNameTags()
    for player, tag in pairs(nameTagObjects) do
        if tag then
            tag:Destroy()
        end
        nameTagObjects[player] = nil
    end
end

local function createNameTag(player, character)
    local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not adornee then
        return nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ArenaAdminNameTag_" .. player.Name
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Size = UDim2.fromOffset(190, 44)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.Adornee = adornee
    billboard.Parent = screenGui

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
    label.BackgroundTransparency = 0.18
    label.BorderSizePixel = 0
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.55
    label.TextSize = 13
    label.TextWrapped = true
    label.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label

    return billboard
end

local function updateNameTags()
    if not state.nameTags then
        clearNameTags()
        return
    end

    local localRoot = getRoot(false)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local tag = nameTagObjects[player]
            if character then
                if not tag or not tag.Parent then
                    tag = createNameTag(player, character)
                    nameTagObjects[player] = tag
                end

                if tag then
                    local theirRoot = character:FindFirstChild("HumanoidRootPart")
                    local label = tag:FindFirstChild("Label")
                    local distanceText = "?"
                    if localRoot and theirRoot then
                        distanceText = tostring(math.floor((localRoot.Position - theirRoot.Position).Magnitude)) .. " studs"
                    end
                    if label and label:IsA("TextLabel") then
                        label.Text = player.DisplayName .. "\n@" .. player.Name .. " • " .. distanceText
                    end
                end
            elseif tag then
                tag:Destroy()
                nameTagObjects[player] = nil
            end
        end
    end

    for player, tag in pairs(nameTagObjects) do
        if not player.Parent or player == LocalPlayer then
            tag:Destroy()
            nameTagObjects[player] = nil
        end
    end
end

local function setClickTeleport(enabled)
    state.clickTeleport = enabled

    if clickTeleportConnection then
        clickTeleportConnection:Disconnect()
        clickTeleportConnection = nil
    end

    if enabled then
        local mouse = LocalPlayer:GetMouse()
        clickTeleportConnection = mouse.Button1Down:Connect(function()
            if not state.clickTeleport or UserInputService:GetFocusedTextBox() then
                return
            end

            if not mouse.Target then
                return
            end

            local root = getRoot(false)
            if root then
                root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 4, 0))
                setStatus("Teleported to clicked point.")
            end
        end)
    end

    refreshButtons()
end

local function setInvisible(enabled)
    state.invisible = enabled
    local character = getCharacter(false)

    if not character then
        return
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.LocalTransparencyModifier = enabled and 1 or 0
        elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
            if enabled then
                if invisibleDefaults[descendant] == nil then
                    invisibleDefaults[descendant] = descendant.Transparency
                end
                descendant.Transparency = 1
            elseif invisibleDefaults[descendant] ~= nil then
                descendant.Transparency = invisibleDefaults[descendant]
                invisibleDefaults[descendant] = nil
            end
        end
    end

    refreshButtons()
end

local function setFreeze(enabled)
    state.freeze = enabled
    local root = getRoot(false)
    if root then
        root.Anchored = enabled
    end
    refreshButtons()
end

local function findSpawnLocation()
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("SpawnLocation") then
            return descendant
        end
    end
    return nil
end

local function teleportToSpawn()
    local spawnLocation = findSpawnLocation()
    local root = getRoot(false)

    if spawnLocation and root then
        root.CFrame = spawnLocation.CFrame + Vector3.new(0, 6, 0)
        setStatus("Teleported to SpawnLocation.")
    else
        setStatus("SpawnLocation or character root was not found.", true)
    end
end

local function createLocalPlatform()
    local root = getRoot(false)
    if not root then
        setStatus("No HumanoidRootPart found.", true)
        return
    end

    local part = Instance.new("Part")
    part.Name = "AdminLocalPlatform"
    part.Anchored = true
    part.CanCollide = true
    part.Size = Vector3.new(18, 1, 18)
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(76, 128, 255)
    part.Transparency = 0.25
    part.CFrame = root.CFrame * CFrame.new(0, -4, 0)
    part.Parent = localObjectsFolder

    setStatus("Created a local platform under you.")
end

local function deleteLocalPlatforms()
    local removed = 0
    for _, child in ipairs(localObjectsFolder:GetChildren()) do
        if child.Name == "AdminLocalPlatform" then
            child:Destroy()
            removed += 1
        end
    end
    setStatus("Deleted local platforms: " .. removed)
end

local function healCharacter()
    local humanoid = getHumanoid(false)
    if humanoid then
        humanoid.Health = humanoid.MaxHealth
        setStatus("Healed to MaxHealth.")
    else
        setStatus("Humanoid not found.", true)
    end
end

local function copyPositionToOutput()
    local root = getRoot(false)
    if not root then
        setStatus("No HumanoidRootPart found.", true)
        return
    end

    local p = root.Position
    local text = string.format("CFrame.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
    print("[AdminPanel position] " .. text)
    setStatus("Position printed to Output: " .. text)
end

local function rejoinServer()
    setStatus("Trying to rejoin this server...")
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)

    if not ok then
        setStatus("Rejoin failed: " .. tostring(err), true)
    end
end

local function resetAllFeatures()
    setFly(false)
    setNoclip(false)
    setClickTeleport(false)
    setInvisible(false)
    setFreeze(false)

    state.speedMultiplier = 1
    state.jumpMultiplier = 1
    state.infiniteJump = false
    state.lowGravity = false
    state.highGravity = false
    state.fullbright = false
    state.noFog = false
    state.noShadows = false
    state.cleanPostFx = false
    state.highFov = false
    state.cinematicFov = false
    state.esp = false
    state.nameTags = false
    state.autoHeal = false
    state.antiAfk = false
    state.coordsHud = false

    resetMovementSettings()
    applyGravity()
    applyLighting()
    applyPostFx()
    applyFov()
    clearEsp()
    clearNameTags()
    coordsLabel.Visible = false

    local root = getRoot(false)
    if root then
        root.Anchored = false
    end

    setStatus("All admin panel features reset.")
    refreshButtons()
end

local function makeSection(title)
    local label = Instance.new("TextLabel")
    label.Name = "Section_" .. title
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -8, 0, 22)
    label.Font = Enum.Font.GothamBold
    label.Text = title
    label.TextColor3 = THEME.Accent
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = scrollFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 4)
    padding.Parent = label
end

local function makeButton(title, isActive, callback)
    local button = Instance.new("TextButton")
    button.Name = "Button_" .. title:gsub("%W", "")
    button.Size = UDim2.new(1, -8, 0, 34)
    button.BackgroundColor3 = THEME.Button
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamSemibold
    button.Text = title
    button.TextColor3 = THEME.Text
    button.TextSize = 13
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = scrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Stroke
    stroke.Thickness = 1
    stroke.Transparency = 0.7
    stroke.Parent = button

    button.MouseEnter:Connect(function()
        if not (isActive and isActive()) then
            button.BackgroundColor3 = THEME.ButtonHover
        end
    end)

    button.MouseLeave:Connect(function()
        refreshButtons()
    end)

    button.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            setStatus("Error: " .. tostring(err), true)
            warn("[AdminPanel] " .. tostring(err))
        end
        refreshButtons()
    end)

    table.insert(buttons, {
        button = button,
        isActive = isActive,
    })

    return button
end

makeSection("Movement")
makeButton("Fly toggle (auto noclip)", function() return state.fly end, function()
    setFly(not state.fly)
end)
makeButton("Noclip toggle", function() return state.noclip end, function()
    setNoclip(not state.noclip)
    setStatus(state.noclip and "Noclip ON." or "Noclip OFF.")
end)
makeButton("Fly speed +20", nil, function()
    runtime.flySpeed += 20
    setStatus("Fly speed: " .. runtime.flySpeed)
end)
makeButton("Fly speed -20", nil, function()
    runtime.flySpeed = math.max(20, runtime.flySpeed - 20)
    setStatus("Fly speed: " .. runtime.flySpeed)
end)
makeButton("Speed x2", function() return state.speedMultiplier == 2 end, function()
    state.speedMultiplier = state.speedMultiplier == 2 and 1 or 2
    applyMovementSettings()
    setStatus("Walk speed multiplier: x" .. state.speedMultiplier)
end)
makeButton("Speed x4", function() return state.speedMultiplier == 4 end, function()
    state.speedMultiplier = state.speedMultiplier == 4 and 1 or 4
    applyMovementSettings()
    setStatus("Walk speed multiplier: x" .. state.speedMultiplier)
end)
makeButton("Reset speed", nil, function()
    state.speedMultiplier = 1
    resetMovementSettings()
    applyMovementSettings()
    setStatus("Speed reset.")
end)
makeButton("Jump x2", function() return state.jumpMultiplier == 2 end, function()
    state.jumpMultiplier = state.jumpMultiplier == 2 and 1 or 2
    applyMovementSettings()
    setStatus("Jump multiplier: x" .. state.jumpMultiplier)
end)
makeButton("Jump x4", function() return state.jumpMultiplier == 4 end, function()
    state.jumpMultiplier = state.jumpMultiplier == 4 and 1 or 4
    applyMovementSettings()
    setStatus("Jump multiplier: x" .. state.jumpMultiplier)
end)
makeButton("Reset jump", nil, function()
    state.jumpMultiplier = 1
    resetMovementSettings()
    applyMovementSettings()
    setStatus("Jump reset.")
end)
makeButton("Infinite jump", function() return state.infiniteJump end, function()
    state.infiniteJump = not state.infiniteJump
    setStatus(state.infiniteJump and "Infinite jump ON." or "Infinite jump OFF.")
end)
makeButton("Low gravity", function() return state.lowGravity end, function()
    state.lowGravity = not state.lowGravity
    if state.lowGravity then
        state.highGravity = false
    end
    applyGravity()
    setStatus(state.lowGravity and "Low gravity ON." or "Gravity reset.")
end)
makeButton("High gravity", function() return state.highGravity end, function()
    state.highGravity = not state.highGravity
    if state.highGravity then
        state.lowGravity = false
    end
    applyGravity()
    setStatus(state.highGravity and "High gravity ON." or "Gravity reset.")
end)
makeButton("Reset gravity", nil, function()
    state.lowGravity = false
    state.highGravity = false
    applyGravity()
    setStatus("Gravity reset to " .. tostring(defaultGravity) .. ".")
end)
makeButton("Freeze / unfreeze", function() return state.freeze end, function()
    setFreeze(not state.freeze)
    setStatus(state.freeze and "Character frozen." or "Character unfrozen.")
end)

makeSection("Teleport & map tools")
makeButton("Click teleport", function() return state.clickTeleport end, function()
    setClickTeleport(not state.clickTeleport)
    setStatus(state.clickTeleport and "Click teleport ON. Click a point in the world." or "Click teleport OFF.")
end)
makeButton("Teleport +50 studs up", nil, function()
    local root = getRoot(false)
    if root then
        root.CFrame = root.CFrame + Vector3.new(0, 50, 0)
        setStatus("Teleported 50 studs up.")
    end
end)
makeButton("Teleport to SpawnLocation", nil, teleportToSpawn)
makeButton("Save checkpoint", nil, function()
    local root = getRoot(false)
    if root then
        runtime.checkpoint = root.CFrame
        setStatus("Checkpoint saved.")
    else
        setStatus("No HumanoidRootPart found.", true)
    end
end)
makeButton("Teleport to checkpoint", nil, function()
    local root = getRoot(false)
    if root and runtime.checkpoint then
        root.CFrame = runtime.checkpoint + Vector3.new(0, 3, 0)
        setStatus("Teleported to checkpoint.")
    else
        setStatus("Save a checkpoint first.", true)
    end
end)
makeButton("Create local platform", nil, createLocalPlatform)
makeButton("Delete local platforms", nil, deleteLocalPlatforms)
makeButton("Print position to Output", nil, copyPositionToOutput)

makeSection("Visual")
makeButton("Fullbright", function() return state.fullbright end, function()
    state.fullbright = not state.fullbright
    applyLighting()
    setStatus(state.fullbright and "Fullbright ON." or "Fullbright OFF.")
end)
makeButton("No fog", function() return state.noFog end, function()
    state.noFog = not state.noFog
    applyLighting()
    setStatus(state.noFog and "No fog ON." or "No fog OFF.")
end)
makeButton("No shadows", function() return state.noShadows end, function()
    state.noShadows = not state.noShadows
    applyLighting()
    setStatus(state.noShadows and "No shadows ON." or "No shadows OFF.")
end)
makeButton("Clean post effects", function() return state.cleanPostFx end, function()
    state.cleanPostFx = not state.cleanPostFx
    applyPostFx()
    setStatus(state.cleanPostFx and "Post effects disabled locally." or "Post effects restored.")
end)
makeButton("High FOV", function() return state.highFov end, function()
    state.highFov = not state.highFov
    if state.highFov then
        state.cinematicFov = false
    end
    applyFov()
    setStatus(state.highFov and "High FOV ON." or "FOV reset.")
end)
makeButton("Cinematic FOV", function() return state.cinematicFov end, function()
    state.cinematicFov = not state.cinematicFov
    if state.cinematicFov then
        state.highFov = false
    end
    applyFov()
    setStatus(state.cinematicFov and "Cinematic FOV ON." or "FOV reset.")
end)
makeButton("Reset FOV", nil, function()
    state.highFov = false
    state.cinematicFov = false
    applyFov()
    setStatus("FOV reset.")
end)
makeButton("Player ESP highlights", function() return state.esp end, function()
    state.esp = not state.esp
    updateEsp()
    setStatus(state.esp and "Player ESP ON." or "Player ESP OFF.")
end)
makeButton("Player name tags", function() return state.nameTags end, function()
    state.nameTags = not state.nameTags
    updateNameTags()
    setStatus(state.nameTags and "Name tags ON." or "Name tags OFF.")
end)
makeButton("Coordinates HUD", function() return state.coordsHud end, function()
    state.coordsHud = not state.coordsHud
    coordsLabel.Visible = state.coordsHud
    setStatus(state.coordsHud and "Coordinates HUD ON." or "Coordinates HUD OFF.")
end)

makeSection("Character")
makeButton("Heal", nil, healCharacter)
makeButton("Auto-heal / god test", function() return state.autoHeal end, function()
    state.autoHeal = not state.autoHeal
    setStatus(state.autoHeal and "Auto-heal ON." or "Auto-heal OFF.")
end)
makeButton("Sit / unsit", nil, function()
    local humanoid = getHumanoid(false)
    if humanoid then
        humanoid.Sit = not humanoid.Sit
        setStatus(humanoid.Sit and "Sitting." or "Standing.")
    end
end)
makeButton("Local invisibility", function() return state.invisible end, function()
    setInvisible(not state.invisible)
    setStatus(state.invisible and "Local invisibility ON." or "Local invisibility OFF.")
end)
makeButton("Reset character", nil, function()
    local humanoid = getHumanoid(false)
    if humanoid then
        humanoid.Health = 0
        setStatus("Character reset.")
    end
end)

makeSection("Utility")
makeButton("Anti-AFK", function() return state.antiAfk end, function()
    state.antiAfk = not state.antiAfk
    setStatus(state.antiAfk and "Anti-AFK ON." or "Anti-AFK OFF.")
end)
makeButton("Rejoin server", nil, rejoinServer)
makeButton("Panic reset all", nil, resetAllFeatures)

hideButton.Activated:Connect(function()
    mainFrame.Visible = false
    setStatus("Panel hidden. Press RightShift to show it again.")
end)

local dragStartPosition = nil
local frameStartPosition = nil

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        runtime.dragging = true
        dragStartPosition = input.Position
        frameStartPosition = mainFrame.Position
    end
end)

topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        runtime.dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if runtime.dragging and dragStartPosition and frameStartPosition and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPosition
        mainFrame.Position = UDim2.new(
            frameStartPosition.X.Scale,
            frameStartPosition.X.Offset + delta.X,
            frameStartPosition.Y.Scale,
            frameStartPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    keysDown[input.KeyCode] = true

    if input.KeyCode == CONFIG.TogglePanelKey and not gameProcessed then
        mainFrame.Visible = not mainFrame.Visible
        setStatus(mainFrame.Visible and "Panel shown." or "Panel hidden. Press RightShift to show it again.")
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        keysDown[input.KeyCode] = nil
    end
end)

UserInputService.JumpRequest:Connect(function()
    if not state.infiniteJump then
        return
    end

    local humanoid = getHumanoid(false)
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

LocalPlayer.Idled:Connect(function()
    if not state.antiAfk then
        return
    end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    setStatus("Anti-AFK activity sent.")
end)

Lighting.ChildAdded:Connect(function(child)
    if state.cleanPostFx and isPostEffect(child) then
        task.defer(applyPostFx)
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.25)
        updateEsp()
        updateNameTags()
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        espObjects[player]:Destroy()
        espObjects[player] = nil
    end
    if nameTagObjects[player] then
        nameTagObjects[player]:Destroy()
        nameTagObjects[player] = nil
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            task.wait(0.25)
            updateEsp()
            updateNameTags()
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.35)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        getHumanoidDefaults(humanoid)
    end

    applyMovementSettings()

    if state.invisible then
        setInvisible(true)
    end

    if state.freeze then
        setFreeze(true)
    end

    if state.fly then
        destroyFlyObjects()
    end
end)

RunService.Heartbeat:Connect(function()
    applyMovementSettings()

    if state.autoHeal then
        local humanoid = getHumanoid(false)
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = humanoid.MaxHealth
            pcall(function()
                humanoid.BreakJointsOnDeath = false
            end)
        end
    end

    if state.freeze then
        local root = getRoot(false)
        if root then
            root.Anchored = true
        end
    end

    if state.invisible then
        local character = getCharacter(false)
        if character then
            for _, descendant in ipairs(character:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    descendant.LocalTransparencyModifier = 1
                end
            end
        end
    end

    local now = os.clock()
    if now - runtime.lastVisualRefresh > 0.5 then
        runtime.lastVisualRefresh = now
        updateEsp()
        updateNameTags()
    end

    if now - runtime.lastHudUpdate > 0.15 then
        runtime.lastHudUpdate = now
        if state.coordsHud then
            local root = getRoot(false)
            if root then
                local p = root.Position
                coordsLabel.Text = string.format("XYZ: %.1f, %.1f, %.1f\nFly speed: %d • FPS: %d", p.X, p.Y, p.Z, runtime.flySpeed, runtime.fps)
            else
                coordsLabel.Text = "XYZ: character not loaded"
            end
        end
    end
end)

local frameCounter = 0
local frameTimer = 0
RunService.RenderStepped:Connect(function(dt)
    frameCounter += 1
    frameTimer += dt
    if frameTimer >= 1 then
        runtime.fps = math.floor(frameCounter / frameTimer + 0.5)
        frameCounter = 0
        frameTimer = 0
    end
end)

refreshButtons()
notify("Admin Panel", "Loaded. Fly + noclip will start automatically.", 4)
setStatus("Loaded. Fly + noclip will start automatically.")

task.delay(CONFIG.AutoStartDelay, function()
    if CONFIG.StartWithNoclip then
        setNoclip(true)
    end

    if CONFIG.StartWithFly then
        setFly(true)
    end

    refreshButtons()
end)
