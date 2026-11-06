local M = {}

M.ID = "transmute_gold"

local TEXT = {
    zh = {
        name = "质变：黄金阶",
        rarity = "银色",
        description = "移除此海克斯，将槽位更改为黄金阶，并获得随机黄金阶海克斯。",
    },
    en = {
        name = "Transmute: Gold",
        rarity = "Silver",
        description = "Remove this Hex, change the slot to Gold, and gain a random Gold Hex.",
    },
    ja = {
        name = "変成：ゴールド",
        rarity = "シルバー",
        description = "このヘックスを取り除き、枠をゴールドにして、ランダムなゴールドヘックスを得る。",
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
        atlas = "images/mercuryrunes/rune_transmute_gold.xml",
        image = "rune_transmute_gold.tex",
        tags = {},
    }
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，质变：黄金阶不会注册。")
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
