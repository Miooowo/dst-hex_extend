local function ApplyPlanar(target, attacker, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 or target == nil or not target:IsValid() then
        return
    end
    local components = target.components
    local health = components ~= nil and components.health or nil
    if health == nil or (health.IsDead ~= nil and health:IsDead()) then
        return
    end
    local combat = components.combat
    if combat ~= nil and combat.GetAttacked ~= nil then
        local ok = pcall(combat.GetAttacked, combat, attacker, 0, nil, "light_them_up", { planar = amount })
        if ok then
            return
        end
    end
    local defense = 0
    local planar_defense = components.planardefense
    if planar_defense ~= nil and planar_defense.GetDefense ~= nil then
        defense = tonumber(planar_defense:GetDefense()) or 0
    end
    local dealt = amount - defense
    if dealt <= 0 then
        return
    end
    health:DoDelta(-dealt, false, "light_them_up", false, attacker, true)
    if health.IsDead ~= nil and health:IsDead() and attacker ~= nil and attacker:IsValid() then
        attacker:PushEvent("killed", { victim = target, attacker = attacker })
    end
end

local function OnHit(inst, attacker, target)
    ApplyPlanar(target, attacker or inst._lightemup_attacker, inst._lightemup_damage)
    if inst:IsValid() then
        inst:Remove()
    end
end

local function LaunchAt(inst, attacker, target, damage, angle_offset)
    inst._lightemup_damage = damage
    inst._lightemup_attacker = attacker
    if attacker == nil or not attacker:IsValid() or target == nil or not target:IsValid()
        or inst.components.projectile == nil then
        inst:Remove()
        return
    end
    local x, _, z = attacker.Transform:GetWorldPosition()
    local tx, _, tz = target.Transform:GetWorldPosition()
    local facing = attacker.GetAngleToPoint ~= nil and attacker:GetAngleToPoint(tx, 0, tz) or 0
    local rotation = facing + (angle_offset or 0)
    local radians = rotation * DEGREES
    inst.components.projectile:Throw(attacker, target, attacker)
    inst.Transform:SetPosition(x + math.cos(radians) * 1.1, 1.2, z - math.sin(radians) * 1.1)
    inst.Transform:SetRotation(rotation)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("projectile")
    inst.AnimState:SetBuild("staff_projectile")
    inst.AnimState:PlayAnimation("fire_spin_loop", true)
    inst.Transform:SetScale(2, 2, 2)

    inst:AddTag("projectile")
    inst:AddTag("lightemup_missile")
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.LaunchAt = LaunchAt

    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(18)
    inst.components.projectile:SetHoming(true)
    inst.components.projectile:SetHitDist(1.25)
    inst.components.projectile:SetOnHitFn(OnHit)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetOnThrownFn(function(missile)
        missile:DoTaskInTime(1.6, missile.Remove)
    end)
    -- The stock Hit runs the owner's DoAttack with this entity as the weapon.
    -- It has no weapon component, and that crashes CalcDamage.
    function inst.components.projectile:Hit(target)
        local attacker = self.owner
        self:Stop()
        if self.inst.Physics ~= nil then
            self.inst.Physics:Stop()
        end
        if self.onhit ~= nil then
            self.onhit(self.inst, attacker, target)
        end
        if self.inst:IsValid() then
            self.inst:Remove()
        end
    end

    return inst
end

return Prefab("lightemup_missile", fn)
