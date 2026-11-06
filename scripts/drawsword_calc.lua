local M = {}

M.RANGE_CAP = 2
M.ATTACK = 24
M.HEALTH = 24
M.ATTACK_SPEED = 20
M.LIFESTEAL = 20
M.MOVE_SPEED = 20

function M.CappedRange(original)
    if type(original) ~= "number" or original ~= original then
        return original
    end
    if original > M.RANGE_CAP then
        return M.RANGE_CAP
    end
    return original
end

function M.LostRange(original)
    if type(original) ~= "number" or original ~= original or original <= M.RANGE_CAP then
        return 0
    end
    return original - M.RANGE_CAP
end

local function Extra(original)
    return M.LostRange(original) / 3 * 3
end

function M.Bonuses(original)
    local extra = Extra(original)
    return {
        attack = M.ATTACK + extra,
        health = M.HEALTH + extra,
        attack_speed = M.ATTACK_SPEED + extra,
        lifesteal = M.LIFESTEAL + extra,
        move_speed = M.MOVE_SPEED + extra,
    }
end

function M.Heal(damage, percent, scale)
    if type(damage) ~= "number" or damage ~= damage or damage <= 0 then
        return 0
    end
    if type(percent) ~= "number" or percent ~= percent or percent <= 0 then
        return 0
    end
    if scale == nil then
        scale = 1
    end
    if type(scale) ~= "number" or scale ~= scale or scale <= 0 then
        return 0
    end
    return damage * percent / 100 * scale
end

function M.Qualifies(is_attack, is_hero, scale)
    if scale ~= nil and (type(scale) ~= "number" or scale ~= scale or scale <= 0) then
        return false
    end
    return is_attack == true or is_hero == true
end

function M.HealthTarget(base, percent, cap)
    if type(base) ~= "number" or base ~= base or base <= 0 then
        return base
    end
    local target = base * (1 + (tonumber(percent) or 0) / 100)
    if type(cap) == "number" and cap == cap and cap > 0 and cap < math.huge then
        target = math.min(cap, target)
    end
    if target < 1 then
        target = 1
    end
    return target
end

return M
