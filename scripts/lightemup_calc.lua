local M = {}

local BASIC = {
    generic_attack = true,
    hammer_attack = true,
    cannon_attack = true,
}

function M.WorldDay(cycles)
    return (tonumber(cycles) or 0) + 1
end

function M.FlatDamage(day)
    local value = tonumber(day) or 1
    local t = (value - 1) / 998
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    return 44 + (320 - 44) * t
end

function M.TotalDamage(day, physical, planar)
    return M.FlatDamage(day) + (tonumber(physical) or 0) * 1.40 + (tonumber(planar) or 0) * 0.76
end

function M.EachDamage(day, physical, planar)
    return M.TotalDamage(day, physical, planar) / 4
end

function M.ReadWeapon(weapon, owner, target)
    if type(weapon) ~= "table" or type(weapon.components) ~= "table" or type(weapon.components.weapon) ~= "table" then
        return 0, 0
    end
    local weapon_component = weapon.components.weapon
    local physical, special = 0, nil
    if type(weapon_component.GetDamage) == "function" then
        local ok, amount, extra = pcall(weapon_component.GetDamage, weapon_component, owner, target)
        if ok then
            physical = tonumber(amount) or 0
            special = extra
        elseif type(weapon_component.damage) == "number" then
            physical = weapon_component.damage
        end
    elseif type(weapon_component.damage) == "number" then
        physical = weapon_component.damage
    end
    local planar = 0
    local planar_component = weapon.components.planardamage
    if type(planar_component) == "table" and type(planar_component.GetDamage) == "function" then
        local ok, amount = pcall(planar_component.GetDamage, planar_component)
        planar = ok and (tonumber(amount) or 0) or 0
    elseif type(special) == "table" then
        planar = tonumber(special.planar) or 0
    end
    return physical, planar
end

function M.ShouldCount(has_rune, projectile, action_id)
    if not has_rune or projectile ~= nil then
        return false
    end
    if action_id == nil or action_id == "" then
        return true
    end
    return BASIC[action_id] == true
end

function M.Advance(count)
    local next_count = (tonumber(count) or 0) + 1
    if next_count >= 4 then
        return 0, true
    end
    return next_count, false
end

return M
