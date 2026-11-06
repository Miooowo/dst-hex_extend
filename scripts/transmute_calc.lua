local M = {}

M.GOLD_ID = "transmute_gold"
M.PRISMATIC_ID = "transmute_prismatic"

M.TIER = {
    SILVER = 1,
    GOLD = 2,
    PRISMATIC = 3,
}

local TARGET = {
    [M.GOLD_ID] = M.TIER.GOLD,
    [M.PRISMATIC_ID] = M.TIER.PRISMATIC,
}

function M.Resolve(tier, rune_id, roll)
    local guard = 0
    while TARGET[rune_id] ~= nil and guard < 4 do
        guard = guard + 1
        local next_tier = TARGET[rune_id]
        local next_rune = roll(next_tier)
        if next_rune == nil or next_rune == "" then
            return tier, rune_id
        end
        tier = next_tier
        rune_id = next_rune
    end
    return tier, rune_id
end

function M.Apply(runes, slot)
    if runes == nil or runes._transmute_applying or runes._removing then
        return false
    end
    if type(runes.slots) ~= "table" then
        return false
    end
    local rune_id = runes.slots[slot]
    if TARGET[rune_id] == nil then
        return false
    end
    local tier = type(runes.slot_tiers) == "table" and runes.slot_tiers[slot] or nil
    local next_tier, next_rune = M.Resolve(tier, rune_id, function(target_tier)
        if type(runes.GetRandomRuneForTier) ~= "function" then
            return nil
        end
        return runes:GetRandomRuneForTier(target_tier, slot)
    end)
    if next_tier == tier and next_rune == rune_id then
        return false
    end
    if type(runes.SetSlotResult) ~= "function" then
        return false
    end
    runes._transmute_applying = true
    local ok, err = pcall(runes.SetSlotResult, runes, slot, next_tier, next_rune)
    runes._transmute_applying = false
    if not ok then
        error(err)
    end
    return true
end

function M.ResolveAll(runes)
    if runes == nil or runes._removing then
        return
    end
    local ok, defs = pcall(require, "mercury_rune_defs")
    local slots = ok and type(defs) == "table" and defs.SLOTS or nil
    if type(slots) == "table" then
        for _, slot in ipairs(slots) do
            M.Apply(runes, slot)
        end
        return
    end
    for slot in pairs(runes.slots or {}) do
        M.Apply(runes, slot)
    end
end

function M.InstallOn(component)
    if type(component) ~= "table" or type(component.SetSlotResult) ~= "function" then
        return false
    end
    if component._transmute_installed then
        return true
    end
    component._transmute_installed = true

    local old_set = component.SetSlotResult
    function component:SetSlotResult(slot, tier, rune_id)
        old_set(self, slot, tier, rune_id)
        if self._transmute_applying then
            return
        end
        M.Apply(self, slot)
    end

    if type(component.ApplySlotAction) == "function" then
        local old_action = component.ApplySlotAction
        function component:ApplySlotAction(session_id, slot, ...)
            local success, reason, free, refund, result_rune, result_tier =
                old_action(self, session_id, slot, ...)
            if success and type(self.slots) == "table" then
                local actual = self.slots[slot]
                local actual_tier = type(self.slot_tiers) == "table" and self.slot_tiers[slot] or nil
                if actual ~= nil and actual ~= "" and (actual ~= result_rune or actual_tier ~= result_tier) then
                    return success, reason, free, refund, actual, actual_tier
                end
            end
            return success, reason, free, refund, result_rune, result_tier
        end
    end

    if type(component.OnLoad) == "function" then
        local old_load = component.OnLoad
        function component:OnLoad(data, immediate)
            old_load(self, data, immediate)
            if immediate == true then
                M.ResolveAll(self)
                return
            end
            local inst = self.inst
            if inst ~= nil and inst.DoTaskInTime ~= nil then
                inst:DoTaskInTime(0, function()
                    M.ResolveAll(self)
                end)
            end
        end
    end
    return true
end

function M.InstallHooks()
    local ok, component = pcall(require, "components/mercuryrunes")
    if not ok then
        return false
    end
    return M.InstallOn(component)
end

return M
