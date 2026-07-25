-- ZombieSurvival / WaveHUD.client.lua
-- Показывает волну, зомби осталось, патроны, хп

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local remotes = RS:WaitForChild("ZombieRemotes")
local waveEvent = remotes:WaitForChild("WaveUpdate")
local fireEvent = remotes:WaitForChild("WeaponFire")

-- UI
local screen = Instance.new("ScreenGui")
screen.Name = "ZombieHUD"
screen.ResetOnSpawn = false
screen.Parent = PlayerGui

local topFrame = Instance.new("Frame", screen)
topFrame.Size = UDim2.fromOffset(400, 80)
topFrame.Position = UDim2.new(0.5, -200, 0, 10)
topFrame.BackgroundColor3 = Color3.fromRGB(20,20,30)
topFrame.BackgroundTransparency = 0.2
Instance.new("UICorner", topFrame).CornerRadius = UDim.new(0,12)
local stroke = Instance.new("UIStroke", topFrame); stroke.Color=Color3.fromRGB(255,50,50); stroke.Thickness=2

local waveLabel = Instance.new("TextLabel", topFrame)
waveLabel.Size = UDim2.new(1, -20, 0.5, 0)
waveLabel.Position = UDim2.fromOffset(10,5)
waveLabel.BackgroundTransparency=1
waveLabel.Font=Enum.Font.GothamBold
waveLabel.Text="Wave: 0"
waveLabel.TextColor3=Color3.new(1,1,1)
waveLabel.TextSize=20
waveLabel.TextXAlignment=Enum.TextXAlignment.Left

local zombieLabel = Instance.new("TextLabel", topFrame)
zombieLabel.Size = UDim2.new(1,-20,0.5,-5)
zombieLabel.Position = UDim2.new(0,10,0.5,0)
zombieLabel.BackgroundTransparency=1
zombieLabel.Font=Enum.Font.Gotham
zombieLabel.Text="Zombies: 0 | Intermission"
zombieLabel.TextColor3=Color3.fromRGB(200,200,200)
zombieLabel.TextSize=16
zombieLabel.TextXAlignment=Left

local bottomFrame = Instance.new("Frame", screen)
bottomFrame.Size = UDim2.fromOffset(300, 60)
bottomFrame.Position = UDim2.new(0,10,1,-70)
bottomFrame.BackgroundColor3 = Color3.fromRGB(20,20,30)
bottomFrame.BackgroundTransparency=0.3
Instance.new("UICorner", bottomFrame).CornerRadius=UDim.new(0,10)

local hpLabel = Instance.new("TextLabel", bottomFrame)
hpLabel.Size = UDim2.new(1,-10,0.5,0)
hpLabel.Position=UDim2.fromOffset(10,5)
hpLabel.BackgroundTransparency=1
hpLabel.Font=Enum.Font.GothamBold
hpLabel.Text="HP: 100"
hpLabel.TextColor3=Color3.fromRGB(100,255,100)
hpLabel.TextSize=16
hpLabel.TextXAlignment=Left

local ammoLabel = Instance.new("TextLabel", bottomFrame)
ammoLabel.Size=UDim2.new(1,-10,0.5,0)
ammoLabel.Position=UDim2.new(0,10,0.5,0)
ammoLabel.BackgroundTransparency=1
ammoLabel.Font=Enum.Font.Code
ammoLabel.Text="Ammo: -"
ammoLabel.TextColor3=Color3.new(1,1,1)
ammoLabel.TextSize=14
ammoLabel.TextXAlignment=Left

-- Wave update
waveEvent.OnClientEvent:Connect(function(wave, zombiesOrCountdown)
    if zombiesOrCountdown < 0 then
        waveLabel.Text = "Wave "..wave.." completed!"
        zombieLabel.Text = "Next wave in "..math.abs(zombiesOrCountdown).."s"
    else
        waveLabel.Text = "🧟 Wave "..wave
        zombieLabel.Text = "Zombies to kill: "..zombiesOrCountdown
    end
end)

-- HP update
local function hookChar(char)
    local hum = char:WaitForChild("Humanoid",5)
    if not hum then return end
    local function updateHP()
        hpLabel.Text = "HP: "..math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
        local pct = hum.Health/hum.MaxHealth
        if pct>0.6 then hpLabel.TextColor3=Color3.fromRGB(100,255,100)
        elseif pct>0.3 then hpLabel.TextColor3=Color3.fromRGB(255,200,50)
        else hpLabel.TextColor3=Color3.fromRGB(255,50,50) end
    end
    hum.HealthChanged:Connect(updateHP)
    hum:GetPropertyChangedSignal("MaxHealth"):Connect(updateHP)
    updateHP()
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("WeaponName") then
            local function updAmmo()
                local a = child:GetAttribute("Ammo")
                if a then
                    ammoLabel.Text = child.Name..": "..(a==-1 and "INF" or a)
                else
                    ammoLabel.Text = child.Name..": -"
                end
            end
            child:GetAttributeChangedSignal("Ammo"):Connect(updAmmo)
            updAmmo()
            child.Equipped:Connect(updAmmo)
        end
    end)
end

if LocalPlayer.Character then hookChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(hookChar)

-- Cash display top right
local cashFrame = Instance.new("Frame", screen)
cashFrame.Size=UDim2.fromOffset(200,40)
cashFrame.Position=UDim2.new(1,-210,0,10)
cashFrame.BackgroundColor3=Color3.fromRGB(20,30,20)
cashFrame.BackgroundTransparency=0.2
Instance.new("UICorner", cashFrame).CornerRadius=UDim.new(0,10)
local cashLabel = Instance.new("TextLabel", cashFrame)
cashLabel.Size=UDim2.fromScale(1,1)
cashLabel.BackgroundTransparency=1
cashLabel.Font=Enum.Font.GothamBold
cashLabel.TextColor3=Color3.fromRGB(100,255,100)
cashLabel.TextSize=18
cashLabel.Text="Cash: 500"

local function updateCash()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    if cash then
        cashLabel.Text="💰 Cash: "..cash.Value
        cash.Changed:Connect(function() cashLabel.Text="💰 Cash: "..cash.Value end)
    end
end
LocalPlayer.ChildAdded:Connect(function(child) if child.Name=="leaderstats" then updateCash() end end)
if LocalPlayer:FindFirstChild("leaderstats") then updateCash() else task.wait(1); updateCash() end

print("[WaveHUD] Loaded")
