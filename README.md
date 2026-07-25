# place — Light Admin Panel v2

Лёгкая админ-панель для тестирования своего плейса в Roblox Studio с GitHub синхронизацией.

### 📁 Установка в Roblox Studio
1. Открой `place.rbxl` в Roblox Studio
2. Скопируй `AdminPanel.client.lua` как **LocalScript** в:
   ```
   StarterPlayer > StarterPlayerScripts > AdminPanel
   ```
3. Нажми Play в Studio — панель появится автоматически.

> Работает только для владельца плейса / в Studio / по Rank в группе. Безопасно — все фичи клиентские.

### 🚀 Главное требование
**При старте сразу включается полёт + ноуклип** — как ты просил:
```lua
CONFIG.StartFly = true
CONFIG.StartNoclip = true
```

### 🎮 Управление
- **RightShift** — показать/скрыть панель
- **WASD + Space/E + Ctrl/Q** — летать
- **Shift (удерживать)** — быстрый полёт x2.5
- Перетаскивание за заголовок

### 📦 34 фичи внутри (сам придумал)

**🚀 Полёт и мувмент (12):**
1. Fly toggle (BodyVelocity + BodyGyro)
2. Noclip — сквозь стены
3. Fly Speed +20 / -20
4. Fast Fly — ускорение на Shift
5. Sprint x1.8
6. Speed x2 / x4
7. Infinite Jump — бесконечные прыжки
8. Low Gravity 35 — низкая гравитация
9. High Jump x2 — высокий прыжок
10. Freeze/Unfreeze — заморозка персонажа
11. Safe Anti-Fall платформер

**📍 Телепорт и мир (8):**
12. Click Teleport — телепорт по клику мыши
13. TP +80 studs вверх
14. TP to SpawnLocation
15. Save / Load Checkpoint
16. Create Platform (локальная неоновая платформа)
17. Delete Platform
18. Anti-Fall auto

**👁️ Визуал (11):**
19. Fullbright — всегда день
20. No Fog
21. No Shadows
22. Clear Post FX (Blur/Bloom/SunRays)
23. ESP — Highlight подсветка игроков
24. Tracers + NameTags + HP + дистанция
25. Freecam — свободная камера
26. FOV +10 / -10 / Reset
27. Coords HUD + FPS
28. Поиск по фичам

**🧍 Персонаж и утилиты (10):**
29. Heal — вылечить
30. GodMode — авто-хил (не умираешь)
31. Invisible local — локальная невидимость
32. Sit/Stand + Reset Character
33. Copy CFrame в Output (F9)
34. Spectate рандомного игрока, Anti-AFK, Rejoin, Server Hop, Panic Reset All

### ⚙️ Конфиг
Открой начало файла:
```lua
local CONFIG = {
    AdminIds = {}, -- добавь свои UserId
    AllowStudio = true,
    AllowOwner = true,
    GroupRank = 200,
    ToggleKey = Enum.KeyCode.RightShift,
    StartFly = true,
    StartNoclip = true,
    FlySpeed = 80,
}
```

### 🔗 GitHub -> Roblox Studio
Ты уже привязал GitHub к Studio, так что просто делай Pull в Studio — файл обновится.

Если используешь **GitHubSync Plugin**:
- В настройках плагина включи `Rojo Mode` или `Use .client.lua Suffix`
- Или вручную перемести файл после Pull

### 🏠 Как сделать чтобы работало в Workspace (твой запрос)

Тебе нужно чтобы панель работала прямо в **Workspace**, а не только в StarterPlayerScripts. Я сделал 2 варианта:

**Вариант A — Рекомендуемый (1 клик):**
1. Поставь `AdminPanelWorkspace.client.lua` в `Workspace`
2. Кликни по скрипту → в Properties найди `RunContext` → поменяй с `Legacy` на `Client`
3. Play — теперь панель и Fly+Noclip работают прямо из Workspace! ✅

Я добавил авто-фикс в код:
```lua
pcall(function()
  if script:IsA("Script") and script.RunContext ~= Enum.RunContext.Client then
    script.RunContext = Enum.RunContext.Client
  end
end)
```
Первый раз предупредит, второй Play уже будет работать.

**Вариант B — Чисто серверный (Legacy) для Workspace:**
Поставь `AdminPanel_Workspace_Server.server.lua` в Workspace как обычный Script (RunContext=Legacy):
- Работает даже без LocalScript
- Fly + Noclip авто-включаются
- Управление через чат: `!fly`, `!noclip`, `!speed 100`, `!heal`, `!pos`, `!tp spawn`, `!platform`, `!down` (вниз)
- Использует серверный BodyVelocity + MoveDirection (WASD + Space для вверх)

**Вариант C — Rojo:**
Используй `default.project.json` — я добавил маппинг Workspace:
- `src/client/AdminPanelWorkspace.client.lua` → Workspace с RunContext=Client
- `src/workspace/AdminPanel...server.lua` → Workspace серверный

После Pull выбери любой вариант.

### ❗ Фикс ошибки `attempt to index nil with 'WaitForChild' - Server - Line 18`
Была потому что файл в Workspace как Script. Теперь в v2.2:
- Не крашится, а пишет как пофиксить
- Авто ставит RunContext=Client
- Есть серверная версия для Workspace

### 🧪 Тест
После пула нажми Play — увидишь уведомление "Loaded! Fly+Noclip auto-start..." и сразу полетишь.

Made for testing own place only.
