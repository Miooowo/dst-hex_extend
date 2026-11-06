local Calc = require("drawsword_calc")

local M = {}
local ID = "draw_your_sword"

local function PlayerHasRune(inst)
    local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
    if runes ~= nil and runes.HasRune ~= nil then
        return runes:HasRune(ID)
    end
    local nets = inst._mercury_rune_net
    if type(nets) ~= "table" then return false end
    for _, netvar in pairs(nets) do
        if netvar ~= nil and netvar.value ~= nil and netvar:value() == ID then
            return true
        end
    end
    return false
end

local function UncappedRange(inst)
    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat == nil then return nil end
    local fn = combat._drawsword_uncapped_attack or combat.GetAttackRange
    if type(fn) ~= "function" then return nil end
    local ok, range = pcall(fn, combat)
    if not ok or type(range) ~= "number" then return nil end
    return range
end

local function VitalsCap()
    local ok, defs = pcall(require, "mercury_stat_anvil_defs")
    if ok and type(defs) == "table" and type(defs.GetVitalsCap) == "function" then
        return defs.GetVitalsCap()
    end
    return math.huge
end

local function PublishHealth(inst, health, previous, bonus, target)
    health.maxhealth = target
    if previous == bonus then return end
    local current = math.min(health.currenthealth or target, target)
    if health.SetVal ~= nil then
        health:SetVal(current, "draw_your_sword")
    end
    if health.ForceUpdateHUD ~= nil then
        health:ForceUpdateHUD(true)
    end
end

local function RememberOffset(inst, runes, bonus, maximum)
    runes._tank_health_applied = (tonumber(runes._tank_health_applied) or 0) + bonus
    local anvil = inst.components.mercurystatanvil
    if anvil ~= nil and anvil.applied ~= nil then
        anvil.applied.max_health = runes._tank_health_applied
    end
    local lol = inst._mercury_lol_health
    if lol ~= nil then
        lol.applied = (tonumber(lol.applied) or 0) + bonus
        lol.maximum = maximum
    end
    inst._drawsword_health_applied = bonus
end

local function ForgetOffset(inst, runes, previous, maximum)
    if type(runes._tank_health_applied) == "number" then
        runes._tank_health_applied = runes._tank_health_applied - previous
    end
    local anvil = inst.components.mercurystatanvil
    if anvil ~= nil and anvil.applied ~= nil then
        anvil.applied.max_health = runes._tank_health_applied
    end
    local lol = inst._mercury_lol_health
    if lol ~= nil then
        if type(lol.applied) == "number" then
            lol.applied = lol.applied - previous
        end
        lol.maximum = maximum
    end
    inst._drawsword_health_applied = 0
end

local function SameHealth(left, right)
    return type(left) == "number" and type(right) == "number" and math.abs(left - right) < 0.0001
end

function M.ApplyHealth(inst)
    if inst == nil or inst._drawsword_applying then return end
    local health = inst.components ~= nil and inst.components.health or nil
    local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
    if health == nil or runes == nil or type(health.maxhealth) ~= "number" then return end
    inst._drawsword_applying = true
    local stored = inst._drawsword_health_applied or 0
    local owned = stored ~= 0 and SameHealth(health.maxhealth, inst._drawsword_health_result)
    local previous = 0
    if owned then
        health.maxhealth = health.maxhealth - stored
        ForgetOffset(inst, runes, stored, health.maxhealth)
        previous = stored
    else
        inst._drawsword_health_applied = 0
    end
    local draw_percent = 0
    if inst._drawsword_force_clear ~= true
        and not runes._removing
        and runes.HasRune ~= nil
        and runes:HasRune(ID) then
        draw_percent = Calc.Bonuses(UncappedRange(inst)).health
    end
    local goliath = inst._drawsword_force_clear ~= true
        and not runes._removing
        and runes.HasRune ~= nil
        and runes:HasRune("goliath")
    local percent = require("goliath_calc").HealthPercent(draw_percent, goliath)
    if percent <= 0 then
        if owned then
            PublishHealth(inst, health, previous, 0, health.maxhealth)
        end
        inst._drawsword_health_result = health.maxhealth
        inst._drawsword_applying = false
        return
    end
    local base = health.maxhealth
    local target = Calc.HealthTarget(base, percent, VitalsCap())
    local bonus = target - base
    RememberOffset(inst, runes, bonus, target)
    inst._drawsword_health_result = target
    if not SameHealth(health.maxhealth, target) or (previous ~= bonus and (health.currenthealth or 0) > target) then
        PublishHealth(inst, health, previous, bonus, target)
    end
    inst._drawsword_applying = false
end

local function CapMethod(inst, object, name, record)
    local current = object[name]
    if type(current) ~= "function" then return end
    local marker = "_drawsword_capped_" .. name
    if current == object[marker] then return end
    local previous = current
    local function capped(self, ...)
        local original = previous(self, ...)
        if not PlayerHasRune(inst) then return original end
        return Calc.CappedRange(original)
    end
    object[marker] = capped
    if record then
        object._drawsword_uncapped_attack = function(self, ...)
            return previous(self, ...)
        end
    end
    object[name] = capped
end

function M.InstallRange(inst)
    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat ~= nil then
        CapMethod(inst, combat, "GetAttackRange", true)
        CapMethod(inst, combat, "GetHitRange", false)
    end
    local replica = inst.replica ~= nil and inst.replica.combat or nil
    if replica ~= nil then
        CapMethod(inst, replica, "GetAttackRangeWithWeapon", false)
    end
end

local function InstallWraps()
    local ok, runes = pcall(require, "components/mercuryrunes")
    if not ok or type(runes) ~= "table" or type(runes.GetDamageModifier) ~= "function" then
        return false
    end
    if not runes._drawsword_wrapped then
        runes._drawsword_wrapped = true
        local old_damage = runes.GetDamageModifier
        local old_speed = runes.GetUnrestrictedAttackSpeedPercent
        local old_move = runes.GetMovementSpeedPercent
        local old_health = runes.RefreshMaxHealth

        function runes:GetDamageModifier(target, ...)
            local percent = old_damage(self, target, ...)
            if not self._removing and self:HasRune(ID) then
                percent = percent + Calc.Bonuses(UncappedRange(self.inst)).attack
            end
            if not self._removing and self:HasRune("dont_blink") then
                percent = percent + require("dontblink_calc").BonusFor(self.inst, target)
            end
            if not self._removing and self:HasRune("agility_to_strength") then
                percent = percent + require("agility_calc").BonusFor(self.inst)
            end
            return percent
        end

        function runes:GetUnrestrictedAttackSpeedPercent(...)
            local percent = old_speed(self, ...)
            if self._removing or not self:HasRune(ID) then return percent end
            return percent + Calc.Bonuses(UncappedRange(self.inst)).attack_speed
        end

        function runes:GetMovementSpeedPercent(...)
            local percent = old_move(self, ...)
            if self._removing or not self:HasRune(ID) then return percent end
            return percent + Calc.Bonuses(UncappedRange(self.inst)).move_speed
        end

        function runes:RefreshMaxHealth(...)
            local result = old_health(self, ...)
            M.ApplyHealth(self.inst)
            return result
        end

        local old_entries = runes.GetRuneBuffEntries
        local hud = require("drawsword_rune")
        function runes:GetRuneBuffEntries(...)
            local entries = old_entries(self, ...)
            return hud.AppendHud(entries, function(rune_id)
                return not self._removing and self:HasRune(rune_id)
            end)
        end
    end

    local health_ok, lol = pcall(require, "mercury_lol_health")
    if health_ok and type(lol) == "table" and type(lol.Refresh) == "function" and not lol._drawsword_wrapped then
        lol._drawsword_wrapped = true
        local old_refresh = lol.Refresh
        function lol.Refresh(player, ...)
            local result = old_refresh(player, ...)
            M.ApplyHealth(player)
            return result
        end
    end
    return true
end

local function RefreshStats(inst)
    M.InstallRange(inst)
    local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
    if runes == nil or runes._removing then return end
    local range = UncappedRange(inst)
    local active = PlayerHasRune(inst)
    if inst._drawsword_stats_ready and range == inst._drawsword_seen_range and active == inst._drawsword_seen_rune then
        return
    end
    inst._drawsword_seen_range = range
    inst._drawsword_seen_rune = active
    inst._drawsword_stats_ready = true
    if runes.RefreshMovementSpeed ~= nil then runes:RefreshMovementSpeed() end
    if runes.RefreshAttackSpeed ~= nil then runes:RefreshAttackSpeed() end
    if runes.RefreshMaxHealth ~= nil then runes:RefreshMaxHealth() end
end

function M.OnHit(inst, data)
    if not PlayerHasRune(inst) or data == nil then return end
    local damage = tonumber(data.damageresolved) or 0
    if damage <= 0 then return end
    local stats = inst.components ~= nil and inst.components.mercurycombatstats or nil
    if stats == nil then return end
    local hit = stats._lifesteal_hit or stats._native_lifesteal
    if hit == nil or data.target ~= hit.target or data.weapon ~= hit.weapon or data.stimuli ~= hit.stimuli then
        return
    end
    local proc = hit.proc
    local skills_ok, skills = pcall(require, "mercury_skill_defs")
    if not skills_ok or type(skills) ~= "table" or type(skills.HasTag) ~= "function" then return end
    local scale = proc ~= nil and proc.lifesteal_scale or nil
    local action_id = proc ~= nil and proc.action_id or nil
    if not Calc.Qualifies(skills.HasTag(action_id, skills.TAG.ATTACK), skills.HasTag(action_id, skills.TAG.HERO_SKILL), scale) then
        return
    end
    local amount = Calc.Heal(damage, Calc.Bonuses(UncappedRange(inst)).lifesteal, scale)
    local health = inst.components ~= nil and inst.components.health or nil
    if amount > 0 and health ~= nil and health.DoDelta ~= nil and (health.IsDead == nil or not health:IsDead()) then
        health:DoDelta(amount, false, "draw_your_sword")
    end
end

function M.Install(inst)
    if inst._drawsword_installed then
        M.InstallRange(inst)
        return
    end
    inst._drawsword_installed = true
    M.InstallRange(inst)
    if TheWorld == nil or not TheWorld.ismastersim then
        inst._drawsword_task = inst:DoPeriodicTask(0.5, function()
            if inst:IsValid() then M.InstallRange(inst) end
        end)
        return
    end
    InstallWraps()
    inst._drawsword_on_hit = function(_, data) M.OnHit(inst, data) end
    inst._drawsword_on_change = function()
        inst._drawsword_stats_ready = nil
        RefreshStats(inst)
        local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
        if runes ~= nil and runes.SyncBuffNet ~= nil then
            runes:SyncBuffNet()
        end
    end
    inst:ListenForEvent("onhitother", inst._drawsword_on_hit)
    inst:ListenForEvent("equip", inst._drawsword_on_change)
    inst:ListenForEvent("unequip", inst._drawsword_on_change)
    inst:ListenForEvent("mercury_runes_changed", inst._drawsword_on_change)
    inst._drawsword_task = inst:DoPeriodicTask(0.5, function()
        if inst:IsValid() then RefreshStats(inst) end
    end)
    inst:DoTaskInTime(0, function()
        if inst:IsValid() then
            inst._drawsword_stats_ready = nil
            RefreshStats(inst)
            local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
            if runes ~= nil and runes.SyncBuffNet ~= nil then
                runes:SyncBuffNet()
            end
        end
    end)
end

function M.Remove(inst)
    inst._drawsword_force_clear = true
    if TheWorld ~= nil and TheWorld.ismastersim then
        pcall(M.ApplyHealth, inst)
    end
    inst._drawsword_force_clear = nil
    if inst._drawsword_task ~= nil then
        inst._drawsword_task:Cancel()
        inst._drawsword_task = nil
    end
    if inst._drawsword_on_hit ~= nil then
        inst:RemoveEventCallback("onhitother", inst._drawsword_on_hit)
        inst._drawsword_on_hit = nil
    end
    if inst._drawsword_on_change ~= nil then
        inst:RemoveEventCallback("equip", inst._drawsword_on_change)
        inst:RemoveEventCallback("unequip", inst._drawsword_on_change)
        inst:RemoveEventCallback("mercury_runes_changed", inst._drawsword_on_change)
        inst._drawsword_on_change = nil
    end
    inst._drawsword_installed = nil
end

return M
