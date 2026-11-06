local Calc = require("agility_calc")

local M = {}
local ID = "agility_to_strength"

local function HasRune(inst)
    local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
    if runes ~= nil and not runes._removing and runes.HasRune ~= nil then
        return runes:HasRune(ID)
    end
    local nets = inst._mercury_rune_net
    if type(nets) ~= "table" then
        return false
    end
    for _, netvar in pairs(nets) do
        if netvar ~= nil and netvar.value ~= nil and netvar:value() == ID then
            return true
        end
    end
    return false
end

function M.InstallSpeed(inst)
    local locomotor = inst.components ~= nil and inst.components.locomotor or nil
    if locomotor == nil or type(locomotor.GetSpeedMultiplier) ~= "function" then
        return
    end
    if locomotor.GetSpeedMultiplier == locomotor._agility_speed_wrap then
        return
    end
    local previous = locomotor.GetSpeedMultiplier
    if type(locomotor._agility_raw_speed_multiplier) ~= "function" then
        locomotor._agility_raw_speed_multiplier = previous
    end
    local function wrapped(self, ...)
        local mult = previous(self, ...)
        if not HasRune(inst) then
            return mult
        end
        local run = 0
        if type(self.RunSpeed) == "function" then
            local ok, value = pcall(self.RunSpeed, self)
            if ok and type(value) == "number" then
                run = value
            end
        elseif type(self.runspeed) == "number" then
            run = self.runspeed
        end
        return Calc.SpeedMultiplier(run, mult, self.throttle, Calc.KEEP_SPEED)
    end
    locomotor._agility_speed_wrap = wrapped
    locomotor.GetSpeedMultiplier = wrapped
end

function M.InstallPanel()
    if M._panel_wrapped then
        return
    end
    local ok, all_attri = pcall(require, "core_lol_wp/data/ui_attri")
    if not ok or type(all_attri) ~= "table" or type(all_attri.atkmulti) ~= "table" then
        return
    end
    local fetch = all_attri.atkmulti.server_fetch
    if type(fetch) ~= "function" then
        return
    end
    M._panel_wrapped = true
    all_attri.atkmulti.server_fetch = function(player)
        local val = fetch(player)
        if type(val) ~= "number" or player == nil or not HasRune(player) then
            return val
        end
        return Calc.ShownAttackMultiplier(val, Calc.BonusFor(player))
    end
end

function M.Install(inst)
    M.InstallSpeed(inst)
    if TheWorld ~= nil and TheWorld.ismastersim then
        M.InstallPanel()
    end
    if inst._agility_installed then
        return
    end
    inst._agility_installed = true
    inst:ListenForEvent("mercury_runes_changed", function()
        M.InstallSpeed(inst)
    end)
    inst:DoPeriodicTask(0.5, function()
        if inst:IsValid() then
            M.InstallSpeed(inst)
        end
    end)
end

return M
