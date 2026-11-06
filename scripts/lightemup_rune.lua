local M = {}

M.ID = "light_them_up"

local TEXT = {
    zh = {
        name = "点亮他们！",
        rarity = "银色",
        description = "每第4次普通攻击发射4枚飞弹。4枚合计造成位面伤害：44–320+140%手持武器物理攻击力+76%手持武器位面伤害。",
    },
    en = {
        name = "Light Them Up!",
        rarity = "Silver",
        description = "Every 4th basic attack fires 4 missiles. Together they deal planar damage: 44–320 (44 on day 1, 320 on day 999 and after, linear in between) + 140% of the held weapon's physical damage + 76% of the held weapon's planar damage.",
    },
    ja = {
        name = "灯をともせ！",
        rarity = "シルバー",
        description = "4回目の通常攻撃ごとに弾を4発放つ。4発合計の平面ダメージ：44–320（1日目は44、999日目以降は320、その間は日数で線形）+手持ち武器の物理攻撃力の140%+手持ち武器の平面ダメージの76%。",
    },
}

local installed = {}

function M.Build(language)
    local text = TEXT[language] or TEXT.zh
    return {
        id = M.ID,
        name = text.name,
        rarity = "silver",
        rarity_name = text.rarity,
        description = text.description,
        atlas = "images/mercuryrunes/rune_light_them_up.xml",
        image = "rune_light_them_up.tex",
        tags = {},
    }
end

function M.InstallInto(defs, rune)
    if type(defs) ~= "table" or type(defs.Get) ~= "function"
        or type(rune) ~= "table" or type(rune.id) ~= "string" then
        return false
    end
    local state = installed[defs]
    if state == nil then
        state = { runes = {} }
        installed[defs] = state
        local old_get = defs.Get
        local old_get_all = defs.GetAll
        local old_by_rarity = defs.GetByRarity
        local old_valid = defs.IsValidForTier

        function defs.Get(id)
            for _, extra in ipairs(state.runes) do
                if extra.id == id then return extra end
            end
            return old_get(id)
        end

        function defs.GetAll()
            local all = old_get_all() or {}
            local copy, seen = {}, {}
            for i, definition in ipairs(all) do
                copy[i] = definition
                seen[definition.id] = true
            end
            for _, extra in ipairs(state.runes) do
                if not seen[extra.id] then copy[#copy + 1] = extra end
            end
            return copy
        end

        function defs.GetByRarity(rarity)
            local list = old_by_rarity(rarity) or {}
            local copy, seen = {}, {}
            for i, definition in ipairs(list) do
                copy[i] = definition
                seen[definition.id] = true
            end
            for _, extra in ipairs(state.runes) do
                if extra.rarity == rarity and not seen[extra.id] then
                    copy[#copy + 1] = extra
                end
            end
            return copy
        end

        function defs.IsValidForTier(tier, rune_id)
            for _, extra in ipairs(state.runes) do
                if extra.id == rune_id then
                    return defs.GetTierRarity(tier) == extra.rarity
                end
            end
            return old_valid(tier, rune_id)
        end

        if type(defs.IsAvailableForPlayer) == "function" then
            local old_available = defs.IsAvailableForPlayer
            function defs.IsAvailableForPlayer(rune_or_id, player)
                local id = type(rune_or_id) == "table" and rune_or_id.id or rune_or_id
                for _, extra in ipairs(state.runes) do
                    if extra.id == id and extra.character ~= nil then
                        return player ~= nil and player.prefab == extra.character
                    end
                end
                return old_available(rune_or_id, player)
            end
        end
    end
    for _, extra in ipairs(state.runes) do
        if extra.id == rune.id then return true end
    end
    state.runes[#state.runes + 1] = rune
    return true
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，点亮他们！不会注册。")
        return false
    end
    local language = "zh"
    local i18n_ok, i18n = pcall(require, "mercury_i18n")
    if i18n_ok and type(i18n) == "table" and type(i18n.GetLanguage) == "function" then
        language = i18n.GetLanguage()
    end
    return M.InstallInto(defs, M.Build(language))
end

return M
