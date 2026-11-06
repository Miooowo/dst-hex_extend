package.path = "scripts/?.lua;" .. package.path

local calc = require("lightemup_calc")
local rune = require("lightemup_rune")
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

near(calc.FlatDamage(calc.WorldDay(0)), 44, "day 1")
near(calc.FlatDamage(calc.WorldDay(998)), 320, "day 999")
near(calc.FlatDamage(calc.WorldDay(999)), 320, "day 1000")
near(calc.FlatDamage(500), 44 + (320 - 44) * (499 / 998), "day 500")
near(calc.TotalDamage(1, 10, 5), 44 + 14 + 3.8, "total")
near(calc.EachDamage(1, 10, 5), (44 + 14 + 3.8) / 4, "each")
near(calc.EachDamage(1, 0, 0) * 4, calc.TotalDamage(1, 0, 0), "split sums")

local preferred = {
    components = {
        weapon = { GetDamage = function() return 10, { planar = 5 } end },
        planardamage = { GetDamage = function() return 7 end },
    },
}
local physical, planar = calc.ReadWeapon(preferred, {})
near(physical, 10, "physical")
near(planar, 7, "component planar wins")

local fallback = { components = { weapon = { GetDamage = function() return 3, { planar = 2 } end } } }
physical, planar = calc.ReadWeapon(fallback, {})
near(physical, 3, "fallback physical")
near(planar, 2, "fallback planar")

local broken = { components = { weapon = { GetDamage = function() error("nope") end, damage = 4 } } }
physical, planar = calc.ReadWeapon(broken, {})
near(physical, 4, "damage field")
near(planar, 0, "no planar")
physical, planar = calc.ReadWeapon(nil, nil)
near(physical, 0, "unarmed physical")
near(planar, 0, "unarmed planar")

check(calc.ShouldCount(false, nil, nil) == false, "rune off")
check(calc.ShouldCount(true, {}, nil) == false, "projectile impact")
check(calc.ShouldCount(true, nil, nil) == true, "unset action")
check(calc.ShouldCount(true, nil, "") == true, "empty action")
check(calc.ShouldCount(true, nil, "generic_attack") == true, "generic")
check(calc.ShouldCount(true, nil, "hammer_attack") == true, "hammer")
check(calc.ShouldCount(true, nil, "cannon_attack") == true, "cannon")
check(calc.ShouldCount(true, nil, "overcharge") == false, "skill")
check(calc.ShouldCount(true, nil, "block_counter_attack") == false, "counter")

local count, fire = calc.Advance(0)
check(count == 1 and fire == false, "first swing")
count, fire = calc.Advance(2)
check(count == 3 and fire == false, "third swing")
count, fire = calc.Advance(3)
check(count == 0 and fire == true, "fourth swing")

local built = rune.Build("zh")
check(built.id == "light_them_up" and built.rarity == "silver", "rune id")
check(built.name == "点亮他们！" and built.atlas == "images/mercuryrunes/rune_light_them_up.xml", "rune presentation")
check(string.find(built.description, "140%", 1, true) ~= nil, "description")

local store = {
    { id = "nimble", rarity = "silver", tags = {} },
    { id = "lol", rarity = "silver", tags = { lol_only = true } },
}
local defs = {
    RARITY = { SILVER = "silver" },
    GetTierRarity = function(tier) return tier == 1 and "silver" or "gold" end,
}
function defs.Get(id)
    for _, definition in ipairs(store) do
        if definition.id == id then return definition end
    end
end
function defs.GetAll() return store end
function defs.GetByRarity(rarity)
    local list = {}
    for _, definition in ipairs(store) do
        if definition.rarity == rarity and not definition.tags.lol_only then
            list[#list + 1] = definition
        end
    end
    return list
end
function defs.IsValidForTier() return false end

check(rune.InstallInto(defs, built) == true, "install")
check(rune.InstallInto(defs, built) == true, "install once")
check(defs.Get("light_them_up") == built, "get")
check(#store == 2, "original list untouched")
local silver = defs.GetByRarity("silver")
check(#silver == 2 and silver[2].id == "light_them_up", "silver pool")
check(#defs.GetByRarity("silver") == 2, "no duplicate")
check(defs.GetByRarity("gold")[1] == nil, "other rarity")
check(defs.IsValidForTier(1, "light_them_up") == true, "silver slot")
check(defs.IsValidForTier(2, "light_them_up") == false, "gold slot")
check(defs.IsValidForTier(1, "nimble") == false, "old validator")

if fails > 0 then
    io.stderr:write(fails .. " failed\n")
    os.exit(1)
end
print("ok")
