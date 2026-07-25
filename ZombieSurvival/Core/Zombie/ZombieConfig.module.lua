-- ZombieSurvival / ZombieConfig
-- Настройка типов зомби

local ZombieConfig = {
    -- Основные типы
    Types = {
        Walker = {
            Name = "Walker",
            Health = 100,
            Damage = 18,
            WalkSpeed = 10,
            Scale = 1,
            Color = Color3.fromRGB(85, 170, 85),
            Points = 10,
            Cash = 15,
        },
        Runner = {
            Name = "Runner",
            Health = 65,
            Damage = 12,
            WalkSpeed = 18,
            Scale = 0.95,
            Color = Color3.fromRGB(255, 200, 100),
            Points = 20,
            Cash = 25,
        },
        Tank = {
            Name = "Tank",
            Health = 350,
            Damage = 35,
            WalkSpeed = 8,
            Scale = 1.35,
            Color = Color3.fromRGB(120, 120, 120),
            Points = 50,
            Cash = 60,
        },
        Crawler = {
            Name = "Crawler",
            Health = 70,
            Damage = 10,
            WalkSpeed = 12,
            Scale = 0.7,
            Color = Color3.fromRGB(70, 90, 70),
            Points = 15,
            Cash = 20,
        },
        Exploder = {
            Name = "Exploder",
            Health = 80,
            Damage = 60, -- взрыв
            WalkSpeed = 11,
            Scale = 1.1,
            Color = Color3.fromRGB(200, 50, 50),
            Points = 40,
            Cash = 50,
            Explodes = true,
        }
    },

    WaveConfig = {
        StartingZombies = 6,
        ZombiesPerWaveGrowth = 2.5,
        Intermission = 12,
        MaxAlive = 35,
        SpawnDelay = 0.8,
        BossEvery = 5, -- каждая 5 волна босс
    },

    -- Мутации по волнам
    GetDifficultyMultiplier = function(wave)
        return 1 + (wave-1)*0.12
    end,

    GetRandomType = function(wave)
        local pool = {"Walker","Walker","Walker","Runner"}
        if wave >= 3 then table.insert(pool,"Crawler") end
        if wave >= 4 then table.insert(pool,"Tank") end
        if wave >= 5 then table.insert(pool,"Exploder") end
        if wave >= 8 then
            -- больше танков и ранеров на поздних волнах
            table.insert(pool,"Tank")
            table.insert(pool,"Runner")
        end
        return pool[math.random(1,#pool)]
    end
}

return ZombieConfig
