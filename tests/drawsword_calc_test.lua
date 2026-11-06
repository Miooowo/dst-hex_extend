package.path = "scripts/?.lua;" .. package.path

local calc = require("drawsword_calc")
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

near(calc.CappedRange(8), 2, "cap a long weapon")
near(calc.CappedRange(2), 2, "range already 2")
near(calc.CappedRange(1.5), 1.5, "short weapon stays short")
check(calc.CappedRange(nil) == nil, "missing range")

near(calc.LostRange(8), 6, "lost six")
near(calc.LostRange(5), 3, "lost three")
near(calc.LostRange(4), 2, "lost a partial step")
near(calc.LostRange(2), 0, "nothing lost at the cap")
near(calc.LostRange(1), 0, "nothing lost below the cap")
near(calc.LostRange(nil), 0, "unknown range loses nothing")

local short = calc.Bonuses(2)
near(short.attack, 24, "base attack")
near(short.health, 24, "base health")
near(short.attack_speed, 20, "base attack speed")
near(short.lifesteal, 20, "base lifesteal")
near(short.move_speed, 20, "base move speed")

local long = calc.Bonuses(8)
near(long.attack, 30, "attack after losing 6")
near(long.health, 30, "health after losing 6")
near(long.attack_speed, 26, "attack speed after losing 6")
near(long.lifesteal, 26, "lifesteal after losing 6")
near(long.move_speed, 26, "move speed after losing 6")

local step = calc.Bonuses(5)
near(step.attack, 27, "one full step of range")
local partial = calc.Bonuses(4)
near(partial.attack, 26, "partial step stays proportional")
near(partial.lifesteal, 22, "partial lifesteal")

near(calc.Heal(100, 20, 1), 20, "twenty percent of the hit")
near(calc.Heal(100, 26, 1), 26, "raised lifesteal")
near(calc.Heal(100, 20, 0.2), 4, "bleed keeps its scale")
near(calc.Heal(100, 20, 0), 0, "a zero scale does not heal")
near(calc.Heal(0, 20, 1), 0, "no damage")
near(calc.Heal(-5, 20, 1), 0, "negative damage")

check(calc.Qualifies(true, false, 1) == true, "basic attack")
check(calc.Qualifies(false, true, 1) == true, "hero skill")
check(calc.Qualifies(false, false, 1) == false, "other damage")
check(calc.Qualifies(true, false, 0) == false, "clone or suppressed hit")
check(calc.Qualifies(true, false, nil) == true, "default scale")

near(calc.HealthTarget(150, 24, 10000), 186, "percent health")
near(calc.HealthTarget(100, 30, 100), 100, "already at the cap")
near(calc.HealthTarget(80, 30, 100), 100, "cap cuts the bonus")

local sword = require("drawsword_rune")
local registry = require("lightemup_rune")
local built = sword.Build("zh")
check(built.id == "draw_your_sword" and built.rarity == "prismatic", "rune id")
check(built.name == "亮出你的剑" and built.image == "rune_draw_your_sword.tex", "rune name")
check(built.atlas == "images/mercuryrunes/rune_draw_your_sword.xml", "rune atlas")
check(string.find(built.description, "24%", 1, true) ~= nil, "rune description")

local store = {
    { id = "nimble", rarity = "silver", tags = {} },
    { id = "shockwave", rarity = "prismatic", tags = {} },
}
local defs = {
    RARITY = { SILVER = "silver", PRISMATIC = "prismatic" },
    GetTierRarity = function(tier)
        if tier == 1 then return "silver" end
        if tier == 3 then return "prismatic" end
        return "gold"
    end,
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
        if definition.rarity == rarity then list[#list + 1] = definition end
    end
    return list
end
function defs.IsValidForTier() return false end

check(registry.InstallInto(defs, built) == true, "install sword")
check(registry.InstallInto(defs, built) == true, "install sword once")
check(defs.Get("draw_your_sword") == built, "get sword")
check(#store == 2, "original sword list untouched")
local prismatic = defs.GetByRarity("prismatic")
check(#prismatic == 2 and prismatic[2].id == "draw_your_sword", "prismatic pool")
check(#defs.GetByRarity("prismatic") == 2, "no duplicate sword")
check(#defs.GetByRarity("silver") == 1 and defs.GetByRarity("silver")[1].id == "nimble", "silver untouched")
check(defs.GetByRarity("gold")[1] == nil, "gold untouched")
check(defs.IsValidForTier(3, "draw_your_sword") == true, "prismatic slot")
check(defs.IsValidForTier(1, "draw_your_sword") == false, "silver slot rejects sword")
check(defs.IsValidForTier(3, "shockwave") == false, "old validator remains")

local shown = sword.AppendHud({
    { rune_id = "giant_slayer", remaining = nil, stacks = 0, order = 1 },
}, function(id) return id == "draw_your_sword" end)
check(#shown == 2 and shown[2].rune_id == "draw_your_sword" and shown[2].remaining == nil, "hud lists the sword")
local again = sword.AppendHud(shown, function(id) return id == "draw_your_sword" end)
check(#again == 2, "hud does not duplicate")
local hidden = sword.AppendHud(shown, function() return false end)
check(#hidden == 2 and hidden[2].rune_id == "draw_your_sword", "existing entry stays")

local absent = sword.AppendHud({
    { rune_id = "giant_slayer", remaining = nil, stacks = 0, order = 1 },
}, function() return false end)
check(#absent == 1 and absent[1].rune_id == "giant_slayer", "hud omits an unequipped sword")

if fails > 0 then
    io.stderr:write(fails .. " failed\n")
    os.exit(1)
end
print("ok")
