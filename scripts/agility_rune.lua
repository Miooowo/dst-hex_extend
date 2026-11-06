local M = {}

M.ID = "agility_to_strength"

local TEXT = {
    zh = {
        name = "敏捷转力量",
        rarity = "银色",
        description = "获得15%攻击倍率。奔跑速度超过9的部分会被移除，每点转为0.6%攻击倍率。",
    },
    en = {
        name = "Agility to Strength",
        rarity = "Silver",
        description = "Gain 15% attack damage. Run speed above 9 is removed, and each removed point adds 0.6% attack damage. ",
    },
    ja = {
        name = "敏捷を力に",
        rarity = "シルバー",
        description = "攻撃倍率15%を得る。走行速度が9を超えた分は失われ、1ごとに攻撃倍率0.6%になる。",
    },
}

function M.Build(language)
    local text = TEXT[language] or TEXT.zh
    return {
        id = M.ID,
        name = text.name,
        rarity = "silver",
        rarity_name = text.rarity,
        description = text.description,
        atlas = "images/mercuryrunes/rune_agility_to_strength.xml",
        image = "rune_agility_to_strength.tex",
        tags = {},
    }
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，敏捷转力量不会注册。")
        return false
    end
    local language = "zh"
    local i18n_ok, i18n = pcall(require, "mercury_i18n")
    if i18n_ok and type(i18n) == "table" and type(i18n.GetLanguage) == "function" then
        language = i18n.GetLanguage()
    end
    return require("lightemup_rune").InstallInto(defs, M.Build(language))
end

return M
