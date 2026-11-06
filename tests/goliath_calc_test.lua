package.path = "scripts/?.lua;" .. package.path

local calc = require("goliath_calc")
local sword = require("drawsword_calc")
local rune = require("goliath_rune")
local registry = require("lightemup_rune")
local fails = 0

local function check(condition, name)
    if not condition then
        fails = fails + 1
        io.stderr:write("FAIL " .. name .. "\n")
    end
end

local function near(actual, expected, name)
    check(type(actual) == "number" and math.abs(actual - expected) < 1e-9, name
        .. " expected " .. tostring(expected) .. " got " .. tostring(actual))
end

check(calc.SCALE == 1.1, "body scale")
check(calc.Channel(100, 70) == "physical", "higher physical")
check(calc.Channel(70, 100) == "planar", "higher planar")
check(calc.Channel(80, 80) == "planar", "equal prefers planar")
check(calc.Channel(nil, 10) == nil, "missing weapon numbers")

local physical, special = calc.ScaleHit(100, { planar = 70, lunar = 3 }, 100, 70, true)
near(physical, 115, "physical damage grows")
near(special.planar, 70, "planar stays when physical is higher")
near(special.lunar, 3, "other special damage stays")

physical, special = calc.ScaleHit(124, { planar = 86.8 }, 100, 70, true)
near(physical, 124 * 1.15, "adaptive comes after other percents")
near(special.planar, 86.8, "the lower channel is not increased")

physical, special = calc.ScaleHit(80, { planar = 80 }, 80, 80, true)
near(physical, 80, "equal leaves physical")
near(special.planar, 92, "equal increases planar")

physical, special = calc.ScaleHit(40, { planar = 90 }, 40, 90, true)
near(physical, 40, "lower physical stays")
near(special.planar, 103.5, "higher planar grows")

local original = { planar = 70 }
physical, special = calc.ScaleHit(100, original, 0, 10, false)
near(physical, 100, "unarmed physical")
check(special == original and special.planar == 70, "unarmed does not change damage")

near(calc.HealthPercent(0, false), 0, "no health rune")
near(calc.HealthPercent(24, false), 24, "sword health only")
near(calc.HealthPercent(0, true), 35, "goliath health only")
near(calc.HealthPercent(24, true), (1.24 * 1.35 - 1) * 100, "health percents multiply")
near(sword.HealthTarget(100, calc.HealthPercent(24, true), math.huge), 100 * 1.24 * 1.35, "shared base multiplies")
near(sword.HealthTarget(100, calc.HealthPercent(24, true), 150), 150, "vitals cap still applies")

local built = rune.Build("zh")
check(built.id == "goliath" and built.rarity == "prismatic", "rune id")
check(built.name == "歌利亚巨人", "rune name")
check(built.atlas == "images/mercuryrunes/rune_goliath.xml", "rune atlas")
check(built.image == "rune_goliath.tex", "rune image")
check(string.find(built.description, "35%", 1, true) ~= nil, "health text")
check(string.find(built.description, "15%", 1, true) ~= nil, "adaptive text")

local defs = {
    Get = function() return nil end,
    GetAll = function() return {} end,
    GetByRarity = function() return {} end,
    IsValidForTier = function() return false end,
    GetTierRarity = function(tier)
        if tier == 3 then return "prismatic" end
        return "silver"
    end,
}
check(registry.InstallInto(defs, built) == true, "install")
check(defs.Get("goliath").rarity == "prismatic", "lookup")
check(#defs.GetByRarity("prismatic") == 1, "prismatic pool")
check(defs.IsValidForTier(3, "goliath") == true, "prismatic slot")
check(defs.IsValidForTier(2, "goliath") == false, "gold slot rejects it")

if fails > 0 then
    io.stderr:write(fails .. " failed\n")
    os.exit(1)
end
print("ok")
