package.path = "scripts/?.lua;" .. package.path

local calc = require("dontblink_calc")
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

near(calc.BonusPercent(5, 4, false), 8, "one point ahead")
near(calc.BonusPercent(5.5, 4, false), 12, "one and a half points")
near(calc.BonusPercent(4, 4, false), 0, "equal speed")
near(calc.BonusPercent(3, 6, false), 0, "slower than the target")
near(calc.BonusPercent(8, 0, false), 64, "target stands still")
near(calc.BonusPercent(8, 0, true), 0, "buildings get nothing")
near(calc.BonusPercent(nil, nil, false), 0, "missing speeds")

local function entity(tags, locomotor)
    return {
        components = { locomotor = locomotor },
        HasTag = function(_, tag)
            return tags[tag] == true
        end,
    }
end

check(calc.IsBuilding(entity({ structure = true })) == true, "structure")
check(calc.IsBuilding(entity({ wall = true })) == true, "wall")
check(calc.IsBuilding(entity({})) == false, "creature")
near(calc.WalkSpeed(entity({}, { GetWalkSpeed = function() return 6.5 end })), 6.5, "reported walk speed")
near(calc.WalkSpeed(entity({}, { walkspeed = 4, GetSpeedMultiplier = function() return 1.25 end })), 5, "base times multiplier")
near(calc.WalkSpeed(entity({})), 0, "no locomotor")
near(calc.BonusFor(entity({}, { GetWalkSpeed = function() return 6 end }), entity({})), 48, "creature without locomotor")
near(calc.BonusFor(entity({}, { GetWalkSpeed = function() return 6 end }), entity({ structure = true })), 0, "structure is skipped")
near(calc.BonusFor(entity({}, { GetWalkSpeed = function() return 6 end }), nil), 0, "no target")

local rune = require("dontblink_rune")
local built = rune.Build("zh")
check(built.id == "dont_blink" and built.rarity == "silver", "rune id")
check(built.name == "唯快不破" and built.atlas == "images/mercuryrunes/rune_dont_blink.xml", "rune presentation")
check(built.image == "rune_dont_blink.tex", "rune image")
check(string.find(built.description, "8%", 1, true) ~= nil, "description")

if fails > 0 then
    io.stderr:write(fails .. " failed\n")
    os.exit(1)
end
print("ok")
