-- ZombieSurvival / WeaponConfig
-- 10 видов оружия с полным функционалом

local WeaponConfig = {
    -- 1. Pistol - стартовый, точный
    Pistol = {
        Name = "Pistol",
        DisplayName = "🔫 Pistol",
        Damage = 24,
        HeadshotMultiplier = 2.2,
        FireRate = 0.35, -- сек между выстрелами
        Range = 400,
        Ammo = 12,
        ReloadTime = 1.3,
        Auto = false,
        Type = "Gun",
        BulletSpeed = 400,
        Color = Color3.fromRGB(50,50,50),
        SoundId = "rbxassetid://12222025", -- pistol
        Price = 0,
    },
    -- 2. Shotgun - огромный урон вблизи
    Shotgun = {
        Name = "Shotgun",
        DisplayName = "💥 Shotgun",
        Damage = 14, -- на дробинку
        Pellets = 8,
        Spread = 8, -- градусов
        FireRate = 0.9,
        Range = 80,
        Ammo = 6,
        ReloadTime = 2.8,
        Auto = false,
        Type = "Shotgun",
        Color = Color3.fromRGB(120,90,60),
        SoundId = "rbxassetid://12222030",
        Price = 400,
    },
    -- 3. AK47 - штурмовой автомат
    AK47 = {
        Name = "AK47",
        DisplayName = "🔥 AK-47",
        Damage = 28,
        HeadshotMultiplier = 1.8,
        FireRate = 0.13,
        Range = 500,
        Ammo = 30,
        ReloadTime = 2.0,
        Auto = true,
        Type = "Rifle",
        Color = Color3.fromRGB(90,50,20),
        SoundId = "rbxassetid://12222027",
        Price = 1200,
    },
    -- 4. Uzi - SMG очень быстрый
    Uzi = {
        Name = "Uzi",
        DisplayName = "⚡ Uzi",
        Damage = 16,
        FireRate = 0.07,
        Range = 250,
        Ammo = 32,
        ReloadTime = 1.6,
        Auto = true,
        Type = "SMG",
        Color = Color3.fromRGB(30,30,30),
        SoundId = "rbxassetid://12222105",
        Price = 800,
    },
    -- 5. Sniper - ваншот
    Sniper = {
        Name = "Sniper",
        DisplayName = "🎯 Sniper",
        Damage = 120,
        HeadshotMultiplier = 3,
        FireRate = 1.2,
        Range = 1000,
        Ammo = 5,
        ReloadTime = 2.5,
        Auto = false,
        Type = "Sniper",
        Color = Color3.fromRGB(60,80,60),
        SoundId = "rbxassetid://12222030",
        Price = 2000,
        Pierces = true,
    },
    -- 6. RPG - взрывчатка
    RPG = {
        Name = "RPG",
        DisplayName = "💣 RPG",
        Damage = 180,
        ExplosionRadius = 14,
        FireRate = 1.8,
        Range = 600,
        Ammo = 1,
        ReloadTime = 3.2,
        Auto = false,
        Type = "Explosive",
        Color = Color3.fromRGB(80,120,50),
        SoundId = "rbxassetid://12222030",
        Price = 3500,
    },
    -- 7. Bat - бита ближний бой
    Bat = {
        Name = "Bat",
        DisplayName = "🏏 Bat",
        Damage = 38,
        FireRate = 0.6,
        Range = 10,
        Ammo = -1, -- бесконеч
        ReloadTime = 0,
        Auto = false,
        Type = "Melee",
        Color = Color3.fromRGB(140,100,60),
        SoundId = "rbxassetid://12222030",
        Price = 150,
        Knockback = 20,
    },
    -- 8. Katana - быстрый меч
    Katana = {
        Name = "Katana",
        DisplayName = "⚔️ Katana",
        Damage = 55,
        FireRate = 0.45,
        Range = 12,
        Ammo = -1,
        Auto = false,
        Type = "Melee",
        Color = Color3.fromRGB(200,200,220),
        SoundId = "rbxassetid://12222030",
        Price = 900,
        Lunge = 8,
    },
    -- 9. Flamethrower - огнемет DoT
    Flamethrower = {
        Name = "Flamethrower",
        DisplayName = "🔥 Flamethrower",
        Damage = 8, -- за тик
        TickRate = 0.08,
        FireRate = 0.05,
        Range = 70,
        Ammo = 150,
        ReloadTime = 3.0,
        Auto = true,
        Type = "Flame",
        Color = Color3.fromRGB(200,50,0),
        SoundId = "rbxassetid://12222030",
        Price = 2800,
        BurnDuration = 3,
    },
    -- 10. RayGun - лазерный, пробивает
    RayGun = {
        Name = "RayGun",
        DisplayName = "👽 RayGun",
        Damage = 75,
        FireRate = 0.5,
        Range = 800,
        Ammo = 10,
        ReloadTime = 2.2,
        Auto = false,
        Type = "Laser",
        Color = Color3.fromRGB(100,255,255),
        SoundId = "rbxassetid://12222025",
        Price = 5000,
        Pierces = true,
        PiercesCount = 5,
    }
}

-- Порядок для магазина
WeaponConfig.Order = {"Pistol","Bat","Uzi","Shotgun","Katana","AK47","Sniper","Flamethrower","RPG","RayGun"}

return WeaponConfig
