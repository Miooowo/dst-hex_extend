local M = {}

M.FLAT = 15
M.PER_SPEED = 0.6
M.KEEP_SPEED = 9
M.WILSON_RUN_SPEED = 6

local function Finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function M.BonusPercent(current, keep)
    if not Finite(current) then
        current = 0
    end
    if not Finite(keep) then
        keep = M.KEEP_SPEED
    end
    local extra = current - keep
    if extra < 0 then
        extra = 0
    end
    return M.FLAT + extra * M.PER_SPEED
end

function M.CurrentRunSpeed(inst)
    local locomotor = inst ~= nil and inst.components ~= nil and inst.components.locomotor or nil
    if locomotor == nil then
        return 0
    end
    local run = 0
    if type(locomotor.RunSpeed) == "function" then
        local ok, value = pcall(locomotor.RunSpeed, locomotor)
        if ok and Finite(value) then
            run = value
        end
    elseif Finite(locomotor.runspeed) then
        run = locomotor.runspeed
    end
    local throttle = locomotor.throttle
    if not Finite(throttle) or throttle < 0 then
        throttle = 1
    end
    local multiplier = 1
    if throttle == 0 then
        if type(locomotor.ExternalSpeedMultiplier) == "function" then
            local ok, value = pcall(locomotor.ExternalSpeedMultiplier, locomotor)
            if ok and Finite(value) then
                multiplier = value
            end
        end
        local ground = locomotor.groundspeedmultiplier
        if type(locomotor.TempGroundSpeedMultiplier) == "function" then
            local ok, value = pcall(locomotor.TempGroundSpeedMultiplier, locomotor)
            if ok and Finite(value) then
                ground = value
            end
        end
        if Finite(ground) then
            multiplier = multiplier * ground
        end
    else
        local multiplier_fn = locomotor._agility_raw_speed_multiplier
        if type(multiplier_fn) ~= "function" then
            multiplier_fn = locomotor.GetSpeedMultiplier
        end
        if type(multiplier_fn) == "function" then
            local ok, value = pcall(multiplier_fn, locomotor)
            if ok and Finite(value) then
                multiplier = value / throttle
            end
        end
    end
    return run * multiplier
end

function M.DefaultRunSpeed(inst)
    local speedmult = inst ~= nil and inst.components ~= nil and inst.components.playerspeedmult or nil
    local classified = speedmult ~= nil and speedmult.classified or nil
    local net = classified ~= nil and classified.psm_basespeed or nil
    if net ~= nil and type(net.value) == "function" then
        local ok, value = pcall(net.value, net)
        if ok and Finite(value) and value > 0 then
            return value
        end
    end
    if TUNING ~= nil and Finite(TUNING.WILSON_RUN_SPEED) and TUNING.WILSON_RUN_SPEED > 0 then
        return TUNING.WILSON_RUN_SPEED
    end
    return M.WILSON_RUN_SPEED
end

function M.BonusFor(inst)
    return M.BonusPercent(M.CurrentRunSpeed(inst), M.KEEP_SPEED)
end

function M.SpeedMultiplier(run, raw_mult, throttle, default)
    if not Finite(raw_mult) then
        return raw_mult
    end
    if not Finite(throttle) or throttle < 0 then
        throttle = 1
    end
    if throttle == 0 or not Finite(run) or run <= 0 or not Finite(default) then
        return raw_mult
    end
    local speed = run * (raw_mult / throttle)
    if speed <= default then
        return raw_mult
    end
    return (default / run) * throttle
end

function M.ShownAttackMultiplier(shown, percent)
    if not Finite(shown) then
        return shown
    end
    if not Finite(percent) then
        percent = 0
    end
    return shown * (1 + percent / 100)
end

function M.CappedRunSpeed(speed, throttle, default)
    if not Finite(speed) then
        return speed
    end
    if not Finite(throttle) or throttle < 0 then
        throttle = 1
    end
    if throttle == 0 or not Finite(default) then
        return speed
    end
    local moving = speed / throttle
    if moving <= default then
        return speed
    end
    return default * throttle
end

return M
