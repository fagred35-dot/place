-- ZombieSurvival / GameManager.server.lua
-- Лидерборд, кэш, волны

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local function setupLeaderstats(plr)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = plr

    local cash = Instance.new("IntValue", ls)
    cash.Name = "Cash"
    cash.Value = 500

    local kills = Instance.new("IntValue", ls)
    kills.Name = "Kills"
    kills.Value = 0

    local waves = Instance.new("IntValue", ls)
    waves.Name = "Waves"
    waves.Value = 0
end

Players.PlayerAdded:Connect(setupLeaderstats)
for _,plr in ipairs(Players:GetPlayers()) do setupLeaderstats(plr) end

-- Clean up zombie corpses periodically
task.spawn(function()
    while true do
        task.wait(60)
        local count=0
        for _,obj in ipairs(workspace:GetChildren()) do
            if obj.Name:match("Zombie_") and obj:FindFirstChildOfClass("Humanoid") and obj.Humanoid.Health<=0 then
                obj:Destroy()
                count+=1
            end
        end
        if count>0 then print("[GameManager] Cleaned "..count.." corpses") end
    end
end)

print("[GameManager] Leaderstats ready")
