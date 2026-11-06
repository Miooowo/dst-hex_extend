package.path = "scripts/?.lua;" .. package.path

local calc = require("borrowtime_calc")
local rune = require("borrowtime_rune")
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

local scale = 60 / 150

near(calc.MissingUnits({ { have = 0, need = 2 } }), 2, "two grass missing")
near(calc.MissingUnits({ { have = 1, need = 2 }, { have = 3, need = 1 } }), 1, "only the shortage counts")
near(calc.HealthLoss(60, 1), 4, "one material costs 4 health")
near(calc.HealthLoss(120, 1), 8, "one material still costs 4 years when health is doubled")

local function shown(amount)
    return math.ceil(amount * scale)
end

for missing = 1, 20 do
    local rows = { { type = "cutgrass", have = 0, need = missing } }
    local plan = calc.SubstitutionPlan(rows, 200, 60, false, scale)
    near(plan.age, missing * 4, "age for " .. missing)
    near(plan.loss, missing * 4, "health for " .. missing)
    check(shown(plan.health_amount) == plan.age, "recipe shows the age for " .. missing)
    check(plan.health_amount % 5 == 0, "health cost is a multiple of 5 for " .. missing)
    local slow = calc.SubstitutionPlan(rows, 200, 60, true, scale)
    near(slow.age, missing * 2, "slow age for " .. missing)
    near(slow.loss, missing * 2, "slow health for " .. missing)
    check(shown(slow.health_amount) == slow.age, "recipe shows the halved age for " .. missing)
    check(slow.health_amount % 5 == 0, "halved health cost is a multiple of 5 for " .. missing)
end

local plan = calc.SubstitutionPlan({
    { type = "cutgrass", have = 1, need = 2 },
    { type = "twigs", have = 0, need = 1 },
}, 60, 60, false, scale)
check(plan.missing == 2 and plan.age == 8 and plan.enough, "two shortages become 8 age")
check(#plan.kept == 1 and plan.kept[1].type == "cutgrass" and plan.kept[1].amount == 1, "owned grass stays on the recipe")

plan = calc.SubstitutionPlan({ { type = "cutgrass", have = 0, need = 2 } }, 60, 60, true, scale)
check(plan.age == 4 and plan.loss == 4 and plan.enough, "slow time halves two missing materials to 4 age")

plan = calc.SubstitutionPlan({ { type = "cutgrass", have = 0, need = 1 } }, 4, 60, false, scale)
check(plan ~= nil and plan.enough == false and plan.age == 4, "four health cannot pay four age")

plan = calc.SubstitutionPlan({ { type = "cutgrass", have = 2, need = 2 } }, 60, 60, false, scale)
check(plan == nil, "complete materials are not rewritten")

plan = calc.SubstitutionPlan({ { type = "cutgrass", have = 0, need = 1 } }, 9, 120, false, scale)
check(plan.age == 4 and plan.loss == 8 and plan.enough, "four age costs eight health when the maximum is doubled")
check(shown(plan.health_amount) == 4, "the recipe still shows four age")

plan = calc.SubstitutionPlan({ { type = "cutgrass", have = 0, need = 1 } }, 8, 120, false, scale)
check(plan.enough == false, "eight health cannot pay four age at a doubled maximum")

local built = rune.Build("zh")
check(built.id == "borrowed_time" and built.rarity == "prismatic", "rune id")
check(built.name == "预借时间", "rune name")
check(built.character == "wanda", "wanda exclusive")
check(built.image == "rune_borrowed_time.tex", "rune image")
check(string.find(built.description, "4", 1, true) ~= nil, "age cost text")
check(string.find(built.description, "岁月慢行", 1, true) ~= nil, "slow time link text")
check(string.find(built.description, "一半", 1, true) ~= nil, "half cost text")
check(string.find(built.description, "配方", 1, true) ~= nil, "recipe display text")

local defs = {
    Get = function() return nil end,
    GetAll = function() return {} end,
    GetByRarity = function() return {} end,
    IsValidForTier = function() return false end,
    IsAvailableForPlayer = function() return true end,
    GetTierRarity = function(tier)
        if tier == 3 then return "prismatic" end
        return "silver"
    end,
}
check(registry.InstallInto(defs, built) == true, "install")
check(defs.IsValidForTier(3, "borrowed_time") == true, "prismatic slot")
check(defs.IsValidForTier(1, "borrowed_time") == false, "silver slot rejects it")
check(defs.IsAvailableForPlayer("borrowed_time", { prefab = "wanda" }) == true, "wanda can roll it")
check(defs.IsAvailableForPlayer("borrowed_time", { prefab = "wilson" }) == false, "wilson cannot roll it")
check(defs.IsAvailableForPlayer("borrowed_time", nil) == false, "no player cannot roll it")
check(defs.IsAvailableForPlayer("other", { prefab = "wilson" }) == true, "ordinary runes stay available")

if fails > 0 then
    io.stderr:write(fails .. " failed\n")
    os.exit(1)
end
print("ok")
