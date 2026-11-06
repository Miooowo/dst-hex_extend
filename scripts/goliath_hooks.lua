local Calc = require("goliath_calc")

local M = {}
local SOURCE = "goliath"

local function HasRune(inst)
    local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
    if runes ~= nil and not runes._removing and runes.HasRune ~= nil then
        return runes:HasRune(Calc.ID)
    end
    local nets = inst._mercury_rune_net
    if type(nets) ~= "table" then
        return false
    end
    for _, netvar in pairs(nets) do
        if netvar ~= nil and netvar.value ~= nil and netvar:value() == Calc.ID then
            return true
        end
    end
    return false
end

local function HeldWeapon(inst)
    local inventory = inst.components ~= nil and inst.components.inventory or nil
    if inventory == nil or inventory.GetEquippedItem == nil or EQUIPSLOTS == nil then
        return nil
    end
    return inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
end

function M.ApplyToHit(attacker, target, physical, special)
    if attacker == nil or not HasRune(attacker) then
        return physical, special
    end
    local zed = attacker.components ~= nil and attacker.components.mercuryechozed or nil
    if zed ~= nil and (zed.calculating_shadow or zed.calculating_snapshot) then
        return physical, special
    end
    local weapon = HeldWeapon(attacker)
    local armed = type(weapon) == "table"
        and weapon.components ~= nil
        and weapon.components.weapon ~= nil
    if not armed then
        return Calc.ScaleHit(physical, special, 0, 0, false)
    end
    local weapon_physical, weapon_planar = require("lightemup_calc").ReadWeapon(weapon, attacker, target)
    return Calc.ScaleHit(physical, special, weapon_physical, weapon_planar, true)
end

function M.ApplyScale(inst)
    if inst == nil then
        return
    end
    local active = HasRune(inst)
    if TheWorld ~= nil and TheWorld.ismastersim and inst.ApplyAnimScale ~= nil then
        inst:ApplyAnimScale(SOURCE, active and Calc.SCALE or 1)
        return
    end
    local anim = inst.AnimState
    if anim == nil or anim.GetScale == nil or anim.SetScale == nil then
        return
    end
    local want = active and Calc.SCALE or 1
    local previous = inst._goliath_client_scale or 1
    if previous == want then
        return
    end
    local x, y, z = anim:GetScale()
    x = (tonumber(x) or 1) / previous * want
    y = (tonumber(y) or 1) / previous * want
    z = (tonumber(z) or 1) / previous * want
    anim:SetScale(x, y, z)
    inst._goliath_client_scale = want
end

local function RefreshHealth(inst)
    local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
    if runes ~= nil and runes.RefreshMaxHealth ~= nil then
        runes:RefreshMaxHealth()
        return
    end
    require("drawsword_hooks").ApplyHealth(inst)
end

function M.InstallCombat(inst)
    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat == nil or type(combat.CalcDamage) ~= "function" then
        return
    end
    if combat.CalcDamage == combat._goliath_calc then
        return
    end
    local old = combat.CalcDamage
    local function wrapped(self, target, weapon, ...)
        local physical, special = old(self, target, weapon, ...)
        return M.ApplyToHit(self.inst, target, physical, special)
    end
    combat._goliath_calc = wrapped
    combat.CalcDamage = wrapped
end

function M.InstallDamage()
    local ok, stats = pcall(require, "mercury_combat_stats")
    if not ok or type(stats) ~= "table" or type(stats.ApplyDamageModifiers) ~= "function" then
        return false
    end
    if stats._goliath_wrapped then
        return true
    end
    stats._goliath_wrapped = true
    local old = stats.ApplyDamageModifiers
    function stats.ApplyDamageModifiers(attacker, physical, special, ...)
        local adjusted_physical, adjusted_special, critical = old(attacker, physical, special, ...)
        adjusted_physical, adjusted_special = M.ApplyToHit(attacker, select(2, ...), adjusted_physical, adjusted_special)
        return adjusted_physical, adjusted_special, critical
    end
    return true
end

function M.Install(inst)
    if inst._goliath_installed then
        M.ApplyScale(inst)
        return
    end
    inst._goliath_installed = true
    M.ApplyScale(inst)
    if TheWorld ~= nil and TheWorld.ismastersim then
        M.InstallCombat(inst)
        M.InstallDamage()
        inst:ListenForEvent("mercury_runes_changed", function()
            M.ApplyScale(inst)
            RefreshHealth(inst)
        end)
        inst:DoTaskInTime(0, function()
            if inst:IsValid() then
                M.InstallCombat(inst)
                M.ApplyScale(inst)
                RefreshHealth(inst)
            end
        end)
        return
    end
    inst:DoPeriodicTask(0.5, function()
        if inst:IsValid() then
            M.ApplyScale(inst)
        end
    end)
end

return M
