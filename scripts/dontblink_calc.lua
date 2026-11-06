local M = {}

local function Finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function M.IsBuilding(inst)
    return inst ~= nil
        and inst.HasTag ~= nil
        and (inst:HasTag("structure") or inst:HasTag("wall"))
end

function M.WalkSpeed(inst)
    local locomotor = inst ~= nil and inst.components ~= nil and inst.components.locomotor or nil
    if locomotor == nil then
        return 0
    end
    if type(locomotor.GetWalkSpeed) == "function" then
        local ok, speed = pcall(locomotor.GetWalkSpeed, locomotor)
        if ok and Finite(speed) then
            return speed
        end
    end
    if not Finite(locomotor.walkspeed) then
        return 0
    end
    local multiplier = 1
    if type(locomotor.GetSpeedMultiplier) == "function" then
        local ok, value = pcall(locomotor.GetSpeedMultiplier, locomotor)
        if ok and Finite(value) then
            multiplier = value
        end
    end
    return locomotor.walkspeed * multiplier
end

function M.BonusPercent(attacker_speed, target_speed, is_building)
    if is_building then
        return 0
    end
    if not Finite(attacker_speed) then
        attacker_speed = 0
    end
    if not Finite(target_speed) then
        target_speed = 0
    end
    local ahead = attacker_speed - target_speed
    if ahead <= 0 then
        return 0
    end
    return ahead * 8
end

function M.BonusFor(attacker, target)
    if target == nil or M.IsBuilding(target) then
        return 0
    end
    return M.BonusPercent(M.WalkSpeed(attacker), M.WalkSpeed(target), false)
end

return M
