package.path = "scripts/?.lua;" .. package.path

local calc = require("agility_calc")
local rune = require("agility_rune")
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

near(calc.BonusPercent(12, 9), 16.8, "three points above 9")
near(calc.BonusPercent(10.5, 9), 15.9, "one and a half points above 9")
near(calc.BonusPercent(9, 9), 15, "speed of 9 keeps the flat bonus")
near(calc.BonusPercent(4, 9), 15, "speed under 9 does not penalize")
near(calc.BonusPercent(nil, nil), 15, "missing speeds keep the flat bonus")

local function locomotor(runspeed, throttle, external, ground)
    local loco = {
        runspeed = runspeed,
        throttle = throttle,
        groundspeedmultiplier = ground,
    }
    function loco:RunSpeed()
        return self.runspeed
    end
    function loco:ExternalSpeedMultiplier()
        return external
    end
    function loco:GetSpeedMultiplier()
        return external * ground * self.throttle
    end
    function loco:GetRunSpeed()
        return self:RunSpeed() * self:GetSpeedMultiplier()
    end
    return loco
end

local function player(runspeed, throttle, external, ground, base)
    return {
        components = {
            locomotor = locomotor(runspeed, throttle, external, ground),
            playerspeedmult = {
                classified = {
                    psm_basespeed = { value = function() return base end },
                },
            },
        },
    }
end

near(calc.CurrentRunSpeed(player(6.6, 1, 1.2, 1, 6)), 7.92, "run speed includes skill and multiplier")
near(calc.CurrentRunSpeed(player(6.6, 0, 1.2, 1, 6)), 7.92, "standing still ignores throttle")
near(calc.CurrentRunSpeed(player(6, 0.5, 1, 1.3, 6)), 7.8, "partial throttle is divided out")
near(calc.DefaultRunSpeed(player(6.6, 1, 1, 1, 6)), 6, "default is the cached base")
near(calc.DefaultRunSpeed({ components = {} }), 6, "wilson base without a speed component")
near(calc.BonusFor(player(6.6, 1, 1.2, 1, 6)), 15, "speed under 9 does not convert")
near(calc.BonusFor(player(6, 0, 1, 1, 6)), 15, "standing under 9")
near(calc.CappedRunSpeed(7.92, 1, 6), 6, "extra run speed is removed")
near(calc.CappedRunSpeed(4, 1, 6), 4, "slow run speed stays")
near(calc.CappedRunSpeed(0, 0, 6), 0, "standing still stays stopped")
near(calc.CappedRunSpeed(3.9, 0.5, 6), 3, "throttle still scales the default speed")
near(calc.SpeedMultiplier(6, 2.8, 1, 9), 1.5, "speed above 9 is spent down to 9")
near(calc.SpeedMultiplier(6, 1.2, 1, 9), 1.2, "speed under 9 stays")
near(calc.SpeedMultiplier(6, 0, 0, 9), 0, "standing multiplier stays zero")

local shown = player(6, 1, 2.8, 1, 6)
shown.components.mercuryrunes = {
    HasRune = function(_, id)
        return id == "agility_to_strength"
    end,
}
require("agility_hooks").InstallSpeed(shown)
near(shown.components.locomotor:GetSpeedMultiplier(), 1.5, "panel keeps speed up to 9")
near(calc.BonusFor(shown), 15 + (6 * 2.8 - 9) * 0.6, "attack uses only the speed above 9")
near(calc.ShownAttackMultiplier(1, 15 + (6 * 2.8 - 9) * 0.6), 1 + (15 + (6 * 2.8 - 9) * 0.6) / 100, "panel attack multiplier")

package.loaded["core_lol_wp/data/ui_attri"] = {
    atkmulti = { server_fetch = function() return 1 end },
}
local hooks = require("agility_hooks")
hooks._panel_wrapped = false
hooks.InstallPanel()
near(package.loaded["core_lol_wp/data/ui_attri"].atkmulti.server_fetch(shown), 1 + (15 + (6 * 2.8 - 9) * 0.6) / 100, "weapon panel includes the conversion")

local built = rune.Build("zh")
check(built.id == "agility_to_strength" and built.rarity == "silver", "rune id")
check(built.name == "敏捷转力量", "rune name")
check(built.atlas == "images/mercuryrunes/rune_agility_to_strength.xml", "rune atlas")
check(built.image == "rune_agility_to_strength.tex", "rune image")
check(string.find(built.description, "15%", 1, true) ~= nil, "flat bonus text")
check(string.find(built.description, "0.6%", 1, true) ~= nil, "conversion text")
check(string.find(built.description, "9", 1, true) ~= nil, "keep speed text")

local defs = {
    Get = function() return nil end,
    GetAll = function() return {} end,
    GetByRarity = function() return {} end,
    IsValidForTier = function() return false end,
    GetTierRarity = function(tier)
        if tier == 1 then return "silver" end
        return "gold"
    end,
}
check(registry.InstallInto(defs, built) == true, "install")
check(defs.Get("agility_to_strength").rarity == "silver", "lookup")
check(#defs.GetByRarity("silver") == 1, "silver pool")
check(defs.IsValidForTier(1, "agility_to_strength") == true, "silver slot")
check(defs.IsValidForTier(2, "agility_to_strength") == false, "gold slot rejects it")

if fails > 0 then
    io.stderr:write(fails .. " failed\n")
    os.exit(1)
end
print("ok")
