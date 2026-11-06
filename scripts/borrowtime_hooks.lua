local Calc = require("borrowtime_calc")

local M = {}

local function OwnsRune(inst, id)
    local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
    if runes ~= nil and not runes._removing and runes.HasRune ~= nil then
        return runes:HasRune(id)
    end
    local nets = inst._mercury_rune_net
    if type(nets) ~= "table" then
        return false
    end
    for _, netvar in pairs(nets) do
        if netvar ~= nil and netvar.value ~= nil and netvar:value() == id then
            return true
        end
    end
    return false
end

local function HasRune(inst)
    if inst == nil or inst.prefab ~= Calc.CHARACTER then
        return false
    end
    return OwnsRune(inst, Calc.ID)
end

local function CountItem(inventory, prefab)
    if inventory == nil or type(inventory.Has) ~= "function" or type(prefab) ~= "string" then
        return 0
    end
    local _, count = inventory:Has(prefab, 999999, true)
    if type(count) == "number" then
        return count
    end
    return 0
end

local function HealthOf(inst)
    local health = inst.components ~= nil and inst.components.health or nil
    if health == nil and inst.replica ~= nil then
        health = inst.replica.health
    end
    if health == nil then
        return nil, nil
    end
    local function call(names)
        for _, name in ipairs(names) do
            if type(health[name]) == "function" then
                local ok, value = pcall(health[name], health)
                if ok and type(value) == "number" then
                    return value
                end
            end
        end
    end
    local current = health.currenthealth
    if type(current) ~= "number" then
        current = call({ "GetCurrent" })
    end
    local maxhealth = call({ "GetMaxWithPenalty", "MaxWithPenalty", "GetMax", "Max" })
    if type(maxhealth) ~= "number" then
        maxhealth = health.maxhealth
    end
    return current, maxhealth
end

local function InventoryOf(inst)
    if inst.components ~= nil and inst.components.inventory ~= nil then
        return inst.components.inventory
    end
    if inst.replica ~= nil then
        return inst.replica.inventory
    end
end

local function IngredientMod(builder)
    if type(builder.IngredientMod) == "function" then
        return builder:IngredientMod()
    end
    return builder.ingredientmod or 1
end

local function RoundUp(value)
    if RoundBiasedUp ~= nil then
        return RoundBiasedUp(value)
    end
    return value
end

local function RecipeOf(value)
    if type(value) == "table" then
        return value
    end
    if type(value) ~= "string" then
        return nil
    end
    if GetValidRecipe ~= nil then
        return GetValidRecipe(value)
    end
    if AllRecipes ~= nil then
        return AllRecipes[value]
    end
end

local function AgeScale()
    if TUNING ~= nil and type(TUNING.OLDAGE_HEALTH_SCALE) == "number" and TUNING.OLDAGE_HEALTH_SCALE > 0 then
        return TUNING.OLDAGE_HEALTH_SCALE
    end
    return 60 / 150
end

local function ShallowCopy(recipe)
    local view = {}
    for key, value in pairs(recipe) do
        view[key] = value
    end
    local meta = getmetatable(recipe)
    if meta ~= nil then
        setmetatable(view, meta)
    end
    return view
end

local function CloneIngredient(ingredient, amount)
    local copy = {}
    for key, value in pairs(ingredient) do
        copy[key] = value
    end
    local meta = getmetatable(ingredient)
    if meta ~= nil then
        setmetatable(copy, meta)
    end
    copy.amount = amount
    return copy
end

function M.Substitution(builder, recipe)
    local inst = builder ~= nil and builder.inst or nil
    if not HasRune(inst) or type(recipe) ~= "table" then
        return nil
    end
    local inventory = InventoryOf(inst)
    local rows = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        rows[#rows + 1] = {
            type = ingredient.type,
            need = Calc.Required(ingredient.amount, IngredientMod(builder), RoundUp),
            have = CountItem(inventory, ingredient.type),
        }
    end
    local current, maxhealth = HealthOf(inst)
    return Calc.SubstitutionPlan(rows, current, maxhealth, OwnsRune(inst, Calc.SLOW_TIME_ID), AgeScale())
end

function M.Spend(inst, loss)
    local oldager = inst ~= nil and inst.components ~= nil and inst.components.oldager or nil
    local health = inst ~= nil and inst.components ~= nil and inst.components.health or nil
    if oldager == nil or health == nil or type(health.DoDelta) ~= "function" then
        return false
    end
    if type(loss) ~= "number" or loss <= 0 then
        return false
    end
    oldager._taking_time_damage = true
    local paid, err = pcall(health.DoDelta, health, -loss, false, "borrowed_time", true, nil, true)
    oldager._taking_time_damage = false
    if not paid then
        error(err)
    end
    return true
end

function M.Preview(player, recipe)
    if player == nil or type(recipe) ~= "table" or Ingredient == nil or CHARACTER_INGREDIENT == nil then
        return nil, nil
    end
    local builder = nil
    if player.replica ~= nil and player.replica.builder ~= nil then
        builder = player.replica.builder
    elseif player.components ~= nil then
        builder = player.components.builder
    end
    if builder == nil then
        return nil, nil
    end
    local plan = M.Substitution(builder, recipe)
    if plan == nil then
        return nil, nil
    end
    local view = ShallowCopy(recipe)
    view.ingredients = {}
    local used = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if not used[ingredient.type] then
            for _, kept in ipairs(plan.kept) do
                if kept.type == ingredient.type and kept.amount > 0 then
                    used[ingredient.type] = true
                    view.ingredients[#view.ingredients + 1] = CloneIngredient(ingredient, kept.amount)
                end
            end
        end
    end
    view.character_ingredients = {}
    for _, ingredient in ipairs(recipe.character_ingredients or {}) do
        view.character_ingredients[#view.character_ingredients + 1] = ingredient
    end
    local segment = 5
    if type(CHARACTER_INGREDIENT_SEG) == "number" and CHARACTER_INGREDIENT_SEG > 0 then
        segment = CHARACTER_INGREDIENT_SEG
    end
    local time_cost = Ingredient(CHARACTER_INGREDIENT.HEALTH, segment)
    time_cost.amount = plan.health_amount
    time_cost._borrowtime = true
    time_cost._borrowtime_units = plan.units
    view.character_ingredients[#view.character_ingredients + 1] = time_cost
    if view.tech_ingredients == nil then
        view.tech_ingredients = {}
    end
    return view, plan
end

local function WithoutItems(recipe)
    local view = ShallowCopy(recipe)
    view.ingredients = {}
    if view.character_ingredients == nil then
        view.character_ingredients = {}
    end
    if view.tech_ingredients == nil then
        view.tech_ingredients = {}
    end
    return view
end

local function Tooltip(age)
    local language = "zh"
    local ok, i18n = pcall(require, "mercury_i18n")
    if ok and type(i18n) == "table" and type(i18n.GetLanguage) == "function" then
        language = i18n.GetLanguage()
    end
    local pattern = "预借时间 · 本次消耗年龄 %d"
    if language == "en" then
        pattern = "Borrowed Time · This craft costs %d age"
    elseif language == "ja" then
        pattern = "時間の前借り · 今回の消費年齢 %d"
    end
    return string.format(pattern, math.floor((age or 0) + 0.5))
end

function M.HookIngredients(widget)
    if widget == nil or widget._borrowtime_recipe or type(widget.SetRecipe) ~= "function" then
        return
    end
    widget._borrowtime_recipe = true
    local original = widget.SetRecipe
    widget.SetRecipe = function(self, recipe, ...)
        local preview_ok, view, plan = pcall(M.Preview, self.owner, recipe)
        if not preview_ok then
            print("[海克斯扩展] 预借时间无法显示配方年龄：" .. tostring(view))
            return original(self, recipe, ...)
        end
        if view == nil or plan == nil then
            return original(self, recipe, ...)
        end
        local builder = self.owner ~= nil and self.owner.replica ~= nil and self.owner.replica.builder or nil
        local previous_mod = builder ~= nil and builder.IngredientMod or nil
        if builder ~= nil then
            builder.IngredientMod = function()
                return 1
            end
        end
        local drawn, result = pcall(original, self, view, ...)
        if builder ~= nil then
            builder.IngredientMod = previous_mod
        end
        self.recipe = recipe
        if not drawn then
            error(result)
        end
        if type(self.SetTooltip) == "function" then
            self:SetTooltip(Tooltip(plan.age))
        end
        return result
    end
    if widget.recipe ~= nil then
        widget:SetRecipe(widget.recipe)
    end
end

local function WrapHasIngredients(class)
    if type(class) ~= "table" or type(class.HasIngredients) ~= "function" or class._borrowtime_has then
        return
    end
    class._borrowtime_has = true
    local previous = class.HasIngredients
    function class:HasIngredients(recipe, ...)
        if previous(self, recipe, ...) then
            return true
        end
        local resolved = RecipeOf(recipe)
        local plan = resolved ~= nil and M.Substitution(self, resolved) or nil
        if plan == nil or not plan.enough then
            return false
        end
        return previous(self, WithoutItems(resolved), ...)
    end
end

local function WrapCharacter(class)
    if type(class) ~= "table" or type(class.HasCharacterIngredient) ~= "function" or class._borrowtime_character then
        return
    end
    class._borrowtime_character = true
    local previous = class.HasCharacterIngredient
    function class:HasCharacterIngredient(ingredient, ...)
        if type(ingredient) == "table" and ingredient._borrowtime then
            local current, maxhealth = HealthOf(self.inst)
            local ok = select(1, Calc.CanPay(current, maxhealth, ingredient._borrowtime_units))
            return ok, current or 0
        end
        return previous(self, ingredient, ...)
    end
end

local function WrapGetIngredients(class)
    if type(class) ~= "table" or type(class.GetIngredients) ~= "function" or class._borrowtime_get then
        return
    end
    class._borrowtime_get = true
    local previous = class.GetIngredients
    function class:GetIngredients(recname, ...)
        local recipe = RecipeOf(recname)
        local plan = recipe ~= nil and M.Substitution(self, recipe) or nil
        local inventory = self.inst ~= nil and self.inst.components ~= nil and self.inst.components.inventory or nil
        if plan == nil or not plan.enough or inventory == nil or type(inventory.GetCraftingIngredient) ~= "function" then
            return previous(self, recname, ...)
        end
        local ingredients = {}
        local discounted = false
        local modifier = self.ingredientmod or 1
        for _, ingredient in ipairs(recipe.ingredients or {}) do
            if (ingredient.amount or 0) > 0 then
                local amount = Calc.Required(ingredient.amount, modifier, RoundUp)
                if amount < ingredient.amount then
                    discounted = true
                end
            end
        end
        for _, kept in ipairs(plan.kept) do
            ingredients[kept.type] = inventory:GetCraftingIngredient(kept.type, kept.amount)
        end
        return ingredients, discounted
    end
end

local function WrapRemoveIngredients(class)
    if type(class) ~= "table" or type(class.RemoveIngredients) ~= "function" or class._borrowtime_remove then
        return
    end
    class._borrowtime_remove = true
    local previous = class.RemoveIngredients
    function class:RemoveIngredients(ingredients, recname, ...)
        local recipe = RecipeOf(recname)
        local plan = recipe ~= nil and M.Substitution(self, recipe) or nil
        local loss = 0
        if plan ~= nil and plan.enough and not self.freebuildmode then
            loss = plan.loss
        end
        local result = previous(self, ingredients, recname, ...)
        if loss > 0 then
            M.Spend(self.inst, loss)
        end
        return result
    end
end

function M.Install()
    if M._installed then
        return true
    end
    local builder_ok, builder = pcall(require, "components/builder")
    local replica_ok, replica = pcall(require, "components/builder_replica")
    local found = false
    if builder_ok and type(builder) == "table" and type(builder.HasIngredients) == "function" then
        WrapHasIngredients(builder)
        WrapCharacter(builder)
        WrapGetIngredients(builder)
        WrapRemoveIngredients(builder)
        found = true
    end
    if replica_ok and type(replica) == "table" and type(replica.HasIngredients) == "function" then
        WrapHasIngredients(replica)
        WrapCharacter(replica)
        found = true
    end
    if found then
        M._installed = true
    end
    return found
end

return M
