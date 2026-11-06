local M = {}

M.ID = "transmute_prismatic"

local TEXT = {
    zh = {
        name = "质变：棱彩阶",
        rarity = "金色",
        description = "移除此海克斯，将槽位更改为棱彩阶，并获得随机棱彩阶海克斯。",
    },
    en = {
        name = "Transmute: Prismatic",
        rarity = "Gold",
        description = "Remove this Hex, change the slot to Prismatic, and gain a random Prismatic Hex.",
    },
    ja = {
        name = "変成：プリズマティック",
        rarity = "ゴールド",
        description = "このヘックスを取り除き、枠をプリズマティックにして、ランダムなプリズマティックヘックスを得る。",
    },
}

function M.Build(language)
    local text = TEXT[language] or TEXT.zh
    return {
        id = M.ID,
        name = text.name,
        rarity = "gold",
        rarity_name = text.rarity,
        description = text.description,
        atlas = "images/mercuryrunes/rune_transmute_prismatic.xml",
        image = "rune_transmute_prismatic.tex",
        tags = {},
    }
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，质变：棱彩阶不会注册。")
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
