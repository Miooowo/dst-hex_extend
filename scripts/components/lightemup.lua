local Calc = require("lightemup_calc")

local OFFSETS = { -12, -4, 4, 12 }
local DELAYS = { 0, 0.05, 0.10, 0.15 }

local function IsRanged(weapon)
    if weapon == nil or not weapon:IsValid() then return false end
    if weapon:HasTag("rangedweapon") or weapon:HasTag("projectile") or weapon:HasTag("mercury_cannon_form") then
        return true
    end
    local components = weapon.components
    return components ~= nil and (components.projectile ~= nil
        or (components.weapon ~= nil and components.weapon.projectile ~= nil))
end

local LightEmUp = Class(function(self, inst)
    self.inst = inst
    self.attacks = 0
    self._seen_rune = nil
    self._onattackother = function(_, data)
        self:OnAttackOther(data)
    end
    inst:ListenForEvent("onattackother", self._onattackother)
    inst:DoTaskInTime(0, function()
        if not inst:IsValid() then return end
        self._seen_rune = self:HasRune()
        if not self._seen_rune then self.attacks = 0 end
        self._onrunes = function() self:OnRunesChanged() end
        inst:ListenForEvent("mercury_runes_changed", self._onrunes)
    end)
end)

function LightEmUp:HasRune()
    local runes = self.inst.components ~= nil and self.inst.components.mercuryrunes or nil
    return runes ~= nil and runes.HasRune ~= nil and runes:HasRune("light_them_up")
end

function LightEmUp:OnRunesChanged()
    local has = self:HasRune()
    if self._seen_rune == nil then
        self._seen_rune = has
        if not has then self.attacks = 0 end
        return
    end
    if has ~= self._seen_rune then
        self.attacks = 0
        self._seen_rune = has
    end
end

function LightEmUp:EquippedWeapon()
    local inventory = self.inst.components ~= nil and self.inst.components.inventory or nil
    if inventory ~= nil and inventory.GetEquippedItem ~= nil and EQUIPSLOTS ~= nil then
        return inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end
end

function LightEmUp:Fire(target)
    local cycles = TheWorld ~= nil and TheWorld.state ~= nil and TheWorld.state.cycles or 0
    local weapon = self:EquippedWeapon()
    local physical, planar = Calc.ReadWeapon(weapon, self.inst, target)
    local each = Calc.EachDamage(Calc.WorldDay(cycles), physical, planar)
    if each <= 0 or target == nil or not target:IsValid() then
        return
    end
    local attacker = self.inst
    for index = 1, 4 do
        local delay = DELAYS[index]
        local angle = OFFSETS[index]
        attacker:DoTaskInTime(delay, function()
            if not attacker:IsValid() or target == nil or not target:IsValid() then return end
            local missile = SpawnPrefab("lightemup_missile")
            if missile ~= nil and missile.LaunchAt ~= nil then
                missile:LaunchAt(attacker, target, each, angle)
            elseif missile ~= nil then
                missile:Remove()
            end
        end)
    end
end

function LightEmUp:ResolveAttack(data, action_id)
    self:OnRunesChanged()
    if not Calc.ShouldCount(self:HasRune(), nil, action_id) then
        return
    end
    local count, fire = Calc.Advance(self.attacks)
    self.attacks = count
    if fire then
        self:Fire(data ~= nil and data.target or nil)
    end
end

function LightEmUp:OnAttackOther(data)
    if data ~= nil and data.projectile ~= nil then return end
    if not self:HasRune() then return end
    local weapon = data ~= nil and data.weapon or nil
    if weapon ~= nil and weapon:IsValid() and weapon:HasTag("lightemup_missile") then return end
    if IsRanged(weapon) then
        -- The launch itself is the attack. Impact arrives later with a projectile,
        -- and the action id is still the previous hit at this moment.
        self:ResolveAttack(data, nil)
        return
    end
    self.inst:DoTaskInTime(0, function()
        if not self.inst:IsValid() then return end
        local action_id = weapon ~= nil and weapon:IsValid() and weapon._mercury_damage_action_id or nil
        self:ResolveAttack(data, action_id)
    end)
end

function LightEmUp:OnSave()
    return { attacks = self.attacks }
end

function LightEmUp:OnLoad(data)
    local attacks = data ~= nil and tonumber(data.attacks) or 0
    if attacks < 0 or attacks > 3 then attacks = 0 end
    self.attacks = attacks
end

function LightEmUp:OnRemove()
    self.inst:RemoveEventCallback("onattackother", self._onattackother)
    if self._onrunes ~= nil then
        self.inst:RemoveEventCallback("mercury_runes_changed", self._onrunes)
    end
end

return LightEmUp
