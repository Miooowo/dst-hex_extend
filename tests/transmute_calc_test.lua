package.path = "scripts/?.lua;" .. package.path

local calc = require("transmute_calc")
local gold_rune = require("transmute_gold_rune")
local prismatic_rune = require("transmute_prismatic_rune")
local registry = require("lightemup_rune")
local fails = 0

local function check(condition, name)
    if not condition then
        fails = fails + 1
        io.stderr:write("FAIL " .. name .. "\n")
    end
end

local tier, rune = calc.Resolve(1, "light_them_up", function()
    return "should_not_roll"
end)
check(tier == 1 and rune == "light_them_up", "ordinary rune stays")

tier, rune = calc.Resolve(1, calc.GOLD_ID, function(target)
    check(target == calc.TIER.GOLD, "silver asks for gold")
    return "giant_slayer"
end)
check(tier == calc.TIER.GOLD and rune == "giant_slayer", "silver becomes a gold rune")

local rolls = { [calc.TIER.GOLD] = calc.PRISMATIC_ID, [calc.TIER.PRISMATIC] = "draw_your_sword" }
tier, rune = calc.Resolve(1, calc.GOLD_ID, function(target)
    return rolls[target]
end)
check(tier == calc.TIER.PRISMATIC and rune == "draw_your_sword", "silver chains into prismatic")

tier, rune = calc.Resolve(1, calc.GOLD_ID, function()
    return nil
end)
check(tier == 1 and rune == calc.GOLD_ID, "no gold candidate keeps the silver transmute")

tier, rune = calc.Resolve(1, calc.GOLD_ID, function(target)
    if target == calc.TIER.GOLD then return calc.PRISMATIC_ID end
    return nil
end)
check(tier == calc.TIER.GOLD and rune == calc.PRISMATIC_ID, "failed second step keeps the gold transmute")

tier, rune = calc.Resolve(2, calc.PRISMATIC_ID, function(target)
    check(target == calc.TIER.PRISMATIC, "gold asks for prismatic")
    return "draw_your_sword"
end)
check(tier == calc.TIER.PRISMATIC and rune == "draw_your_sword", "gold becomes a prismatic rune")

local calls = 0
tier, rune = calc.Resolve(1, calc.GOLD_ID, function(target)
    calls = calls + 1
    if target == calc.TIER.GOLD then return calc.PRISMATIC_ID end
    return calc.GOLD_ID
end)
check(calls <= 4 and tier ~= nil and rune ~= nil, "a loop of transmutes stops")

local component = {}

local function fake_runes(start_tier, start_rune, rolled)
    return setmetatable({
        slots = { head = start_rune },
        slot_tiers = { head = start_tier },
        calls = 0,
        results = {},
        GetRandomRuneForTier = function(self, target, slot)
            self.calls = self.calls + 1
            self.last_slot = slot
            return rolled[target]
        end,
    }, { __index = component })
end

function component:SetSlotResult(slot, next_tier, next_rune)
    self.results = self.results or {}
    self.results[#self.results + 1] = { slot, next_tier, next_rune }
    self.slots[slot] = next_rune
    self.slot_tiers[slot] = next_tier
end
function component:ApplySlotAction()
    self:SetSlotResult("head", 1, calc.GOLD_ID)
    return true, "ok", 1, 0, calc.GOLD_ID, 1
end
function component:OnLoad(data, immediate)
    local function restore()
        self.slots = { head = data.rune }
        self.slot_tiers = { head = data.tier }
        self.restored = true
    end
    if immediate == true then
        restore()
    else
        self.inst:DoTaskInTime(0, restore)
    end
end

check(calc.InstallOn(component) == true, "hooks install")
check(calc.InstallOn(component) == true, "hooks install once")

local placed = fake_runes(1, nil, { [calc.TIER.GOLD] = "giant_slayer" })
placed:SetSlotResult("head", 1, calc.GOLD_ID)
check(placed.slots.head == "giant_slayer" and placed.slot_tiers.head == calc.TIER.GOLD, "placing silver transmute replaces it")
check(placed.calls == 1, "placing rolls once")
check(placed.last_slot == "head", "roll uses the changing slot")

local action = fake_runes(1, nil, { [calc.TIER.GOLD] = "giant_slayer" })
local success, reason, free, refund, result_rune, result_tier = action:ApplySlotAction("session", "head")
check(success == true and reason == "ok" and free == 1 and refund == 0, "station result keeps the receipt")
check(result_rune == "giant_slayer" and result_tier == calc.TIER.GOLD, "station result is the final rune")
check(action.calls == 1, "station rolls once")

local saved = fake_runes(1, nil, { [calc.TIER.GOLD] = "giant_slayer" })
local tasks = {}
saved.inst = {
    DoTaskInTime = function(_, _, fn)
        tasks[#tasks + 1] = fn
    end,
}
saved._removing = false
saved:OnLoad({ rune = calc.GOLD_ID, tier = 1 }, false)
check(saved.calls == 0, "load waits until the save is restored")
for _, fn in ipairs(tasks) do
    fn()
end
check(saved.restored == true, "restore runs")
check(saved.slots.head == "giant_slayer" and saved.slot_tiers.head == calc.TIER.GOLD, "loaded transmute resolves after restore")

local immediate = fake_runes(2, calc.PRISMATIC_ID, { [calc.TIER.PRISMATIC] = "draw_your_sword" })
immediate.inst = { DoTaskInTime = function() end }
immediate:OnLoad({ rune = calc.PRISMATIC_ID, tier = 2 }, true)
check(immediate.slots.head == "draw_your_sword" and immediate.slot_tiers.head == calc.TIER.PRISMATIC, "immediate load resolves now")

local stuck = fake_runes(1, calc.GOLD_ID, {})
stuck:SetSlotResult("head", 1, calc.GOLD_ID)
check(stuck.slots.head == calc.GOLD_ID and stuck.slot_tiers.head == 1, "no candidate leaves the transmute")
check(#stuck.results == 1, "no candidate does not write a second result")

local silver = gold_rune.Build("zh")
local prismatic = prismatic_rune.Build("zh")
check(silver.id == "transmute_gold" and silver.rarity == "silver", "silver id")
check(silver.name == "质变：黄金阶", "silver name")
check(silver.atlas == "images/mercuryrunes/rune_transmute_gold.xml", "silver atlas")
check(silver.image == "rune_transmute_gold.tex", "silver image")
check(string.find(silver.description, "黄金阶", 1, true) ~= nil, "silver description")
check(prismatic.id == "transmute_prismatic" and prismatic.rarity == "gold", "gold id")
check(prismatic.name == "质变：棱彩阶", "gold name")
check(prismatic.atlas == "images/mercuryrunes/rune_transmute_prismatic.xml", "gold atlas")
check(prismatic.image == "rune_transmute_prismatic.tex", "gold image")
check(string.find(prismatic.description, "棱彩阶", 1, true) ~= nil, "gold description")

local defs = {
    Get = function() return nil end,
    GetAll = function() return {} end,
    GetByRarity = function() return {} end,
    IsValidForTier = function() return false end,
    GetTierRarity = function(tier)
        if tier == 1 then return "silver" end
        if tier == 2 then return "gold" end
        if tier == 3 then return "prismatic" end
    end,
}
check(registry.InstallInto(defs, silver) == true, "install silver")
check(registry.InstallInto(defs, prismatic) == true, "install gold")
check(defs.Get("transmute_gold").id == "transmute_gold", "lookup silver")
check(defs.Get("transmute_prismatic").rarity == "gold", "lookup gold")
local golds = defs.GetByRarity("gold")
check(#golds == 1 and golds[1].id == "transmute_prismatic", "gold pool")
local silvers = defs.GetByRarity("silver")
check(#silvers == 1 and silvers[1].id == "transmute_gold", "silver pool")
check(defs.IsValidForTier(1, "transmute_gold") == true, "silver fits silver")
check(defs.IsValidForTier(2, "transmute_gold") == false, "silver does not fit gold")
check(defs.IsValidForTier(2, "transmute_prismatic") == true, "gold fits gold")
check(defs.IsValidForTier(3, "transmute_prismatic") == false, "gold does not fit prismatic")

if fails > 0 then
    io.stderr:write(fails .. " failed\n")
    os.exit(1)
end
print("ok")
