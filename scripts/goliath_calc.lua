local M = {}

M.ID = "goliath"
M.SCALE = 1.1
M.HEALTH = 35
M.BONUS = 15

function M.Channel(physical, planar)
    physical = tonumber(physical)
    planar = tonumber(planar)
    if physical == nil or planar == nil or physical ~= physical or planar ~= planar then
        return nil
    end
    if physical > planar then
        return "physical"
    end
    return "planar"
end

function M.HealthPercent(draw_percent, enabled)
    local factor = 1
    local percent = tonumber(draw_percent) or 0
    if percent == percent and percent > 0 then
        factor = factor * (1 + percent / 100)
    end
    if enabled then
        factor = factor * (1 + M.HEALTH / 100)
    end
    return (factor - 1) * 100
end

function M.ScaleHit(physical, special, weapon_physical, weapon_planar, armed)
    if not armed then
        return physical, special
    end
    local channel = M.Channel(weapon_physical, weapon_planar)
    local multiplier = 1 + M.BONUS / 100
    if channel == "physical" then
        return (tonumber(physical) or 0) * multiplier, special
    end
    if channel == "planar" and type(special) == "table" then
        local copy = {}
        for key, value in pairs(special) do
            if key == "planar" and type(value) == "number" then
                copy[key] = value * multiplier
            else
                copy[key] = value
            end
        end
        return physical, copy
    end
    return physical, special
end

return M
