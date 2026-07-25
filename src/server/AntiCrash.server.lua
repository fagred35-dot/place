-- Если AdminPanel.client.lua по ошибке попал в Workspace как Script,
-- этот сервер-скрипт покажет понятную ошибку вместо "attempt to index nil"

print("[LightAdmin] Server loader started. Checking for misplaced AdminPanel...")

local function findMisplaced()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("adminpanel") and obj:IsA("LuaSourceContainer") then
            warn("❌ [LightAdmin] Нашел "..obj:GetFullName().." в Workspace! Он должен быть в StarterPlayer > StarterPlayerScripts как LocalScript. Удали его из Workspace, оставь только в StarterPlayerScripts.")
        end
    end
end

task.delay(2, findMisplaced)
workspace.DescendantAdded:Connect(function(obj)
    if obj.Name:lower():find("adminpanel") and obj.Parent == workspace then
        warn("⚠️ [LightAdmin] AdminPanel добавлен в Workspace! Перемести в StarterPlayerScripts!")
    end
end)
