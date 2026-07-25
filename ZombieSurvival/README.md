# 🧟 Zombie Survival Map + 10 Weapons - Полный функционал

Целая карта с зомби-волнами и 10 видами оружия, всё работает из коробки. Сделано для твоего плейса `fagred35-dot/place`.

## 📁 Структура

```
ZombieSurvival/
├── Map/
│   └── MapBuilder.server.lua      - Строит карту процедурно (база, стены, 8 спавнов зомби, магазин оружия)
├── Core/
│   ├── GameManager.server.lua     - Лидерборд Cash/Kills/Waves
│   └── Zombie/
│       ├── ZombieConfig.module.lua - 5 типов зомби (Walker, Runner, Tank, Crawler, Exploder)
│       └── ZombieSpawner.server.lua - Волны, AI, поиск ближайшего игрока
├── Weapons/
│   ├── WeaponConfig.module.lua    - 10 пушек конфиг
│   ├── WeaponBuilder.server.lua   - Создает 10 Tools в StarterPack и ReplicatedStorage
│   ├── WeaponHandler.server.lua   - Серверный урон, взрывы, огонь, мили
│   └── WeaponClient.client.lua    - Клиентские эффекты, трейсеры, перезарядка
└── UI/
    └── WaveHUD.client.lua         - HUD волны, HP, патроны, кэш
```

Также продублировано в `src/` для Rojo:
- `src/server/ZombieGame/` - сервер
- `src/client/ZombieGame/` - клиент
- `src/shared/ZombieGame/` - конфиги

## 🗺️ Карта

Процедурно генерируется при старте сервера:

- **База 800x800** плита, 4 стены по периметру высота 30
- **SafeHouse** 50x50 в центре (дом с дверью, крыша) + Player Spawn
- **WeaponShop** 60x30 рядом с домом, 10 неоновых падов с ценой и ProximityPrompt [E] Buy
- **8 Zombie Spawns** по углам и краям карты, с красной подсветкой и надписью SPAWN
- **12 crate** укрытий рандомно
- **Атмосферное освещение**: ночь, туман 50-350, ambient темный

Строится скриптом `MapBuilder.server.lua` — не нужен .rbxl

## 🧟 Зомби система

**5 типов:**
1. Walker - 100 HP, 10 speed, 18 dmg (обычный)
2. Runner - 65 HP, 18 speed, 12 dmg (быстрый)
3. Tank - 350 HP, 8 speed, 35 dmg (толстый серый)
4. Crawler - 70 HP, 12 speed, 10 dmg (маленький)
5. Exploder - 80 HP, 11 speed, 60 взрыв урон

- Волны: 1 волна 6 зомби + 2.5 за волну, максимум 35 живых одновременно, задержка 0.8с
- Интермиссия 12 сек между волнами, босс каждые 5 волн
- AI: ищет ближайшего игрока, MoveTo, наносит урон в радиусе 6, Exploder взрывается
- При смерти даёт Cash (15-60) и Kills, трупы удаляются через 5 сек + чистка каждые 60 сек
- Сложность растет: HP * (1 + wave*0.12)

## 🔫 10 видов оружия (все с функционалом)

| # | Название | Урон | Магазин | Темп | Тип | Фишка |
|---|----------|------|---------|------|-----|-------|
|1|🔫 Pistol|24|12|0.35|Gun|Стартовый, хедшот x2.2|
|2|💥 Shotgun|14x8 дробинок|6|0.9|Shotgun|8 пуль с разбросом 8°, ваншот вблизи|
|3|🔥 AK-47|28|30|0.13|Rifle|Автомат, автоматический|
|4|⚡ Uzi|16|32|0.07|SMG|Самый быстрый, 0.07 сек|
|5|🎯 Sniper|120|5|1.2|Sniper|Ваншот + пробивает 3 зомби, хед x3|
|6|💣 RPG|180|1|1.8|Explosive|Взрыв радиус 14, урон по площади|
|7|🏏 Bat|38|INF|0.6|Melee|Ближний, отбрасывание 20|
|8|⚔️ Katana|55|INF|0.45|Melee|Ближний, рывок вперед 8 стадов|
|9|🔥 Flamethrower|8 per tick|150|0.05|Flame|Огнемет: DoT 3 сек горение, конус 70 дальность|
|10|👽 RayGun|75|10|0.5|Laser|Лазер пробивает 5 зомби|

**Как работает:**
- Builder создает 10 Tools с атрибутами (WeaponName, Damage, etc) и Handle (цвет по типу)
- Pistol и Bat даются сразу в StarterPack
- Остальные покупаются в WeaponShop за Cash (от 150 до 5000) через ProximityPrompt
- Client (WeaponClient) ловит Tool.Equipped/Activated, делает raycast с камеры, создает трейсеры, вспышки, звуки, отправляет RemoteEvent WeaponFire на сервер
- Server (WeaponHandler) валидирует, делает урон: raycast для обычных, 8 лучей для дробовика, пробивание для снайпера/raygun, взрыв для RPG, конус для огнемета, радиус для мили
- Перезарядка на R, авто-перезарядка когда 0, бесконечные патроны у мили
- Ammo хранится на сервере per player

## 🎮 Установка (2 варианта)

### Вариант 1 - Rojo (рекомендовано, у тебя уже GitHub привязан)
1. Сделай Pull в Roblox Studio (ветка arena/019f96f7-place)
2. Если Rojo: `rojo serve` и Sync — карта появится сама
3. Если GitHubSync Plugin: включи Rojo Mode, сделай Pull
4. Play — карта построится, зомби начнут спавниться, в рюкзаке Pistol + Bat

### Вариант 2 - Ручная (без Rojo, чистый Studio)
1. Скопируй файлы из `ZombieSurvival/` в Studio:
   - `MapBuilder.server.lua` → ServerScriptService
   - `GameManager.server.lua` → ServerScriptService
   - `ZombieSpawner.server.lua` + `ZombieConfig` → ServerScriptService
   - `WeaponBuilder.server.lua` + `WeaponConfig`, `WeaponHandler.server.lua` → ServerScriptService
   - `WeaponClient.client.lua` + `WaveHUD.client.lua` → StarterPlayerScripts
2. Play — всё построится

### Вариант 3 - Один файл (самый простой)
Скопируй `ZombieSurvival/AllInOne.server.lua` (я создам ниже) в ServerScriptService — он сам создаст всё.

## 🕹️ Управление
- WASD - бегать
- Mouse1 - стрелять / бить
- R - перезарядка
- E возле WeaponPad - купить оружие (нужен Cash)
- RightShift - админ панель (если из прошлого)
- Чат команды серверной версии зомби: !fly, !noclip

## 💰 Экономика
- Старт 500 Cash
- За зомби: 15-60 Cash
- Оружие от 150 (Bat) до 5000 (RayGun)
- Лидерборд Cash / Kills / Waves

## 🔧 Технические фишки
- Никаких GetDebugId, TextXAlignment фиксов - всё пофикшено v2.3.1
- Сервер контролирует зомби через Heartbeat + MoveTo, без PathfindingService для легкости (можно заменить на Pathfinding если надо)
- Зомби модель R6 упрощенная процедурная, не требует Toolbox ассетов
- Оружие без нужды в Tool.Source - центральный обработчик
- MapBuilder создает ReplicatedStorage папки Weapons и ZombieRemotes с RemoteEvents
- Всё в отдельных папках, не мешает AdminPanel

Enjoy! Если надо добавить боссов или еще оружия - скажи.
