local M = {}

M.ID = "goliath"

local TEXT = {
    zh = {
        name = "歌利亚巨人",
        rarity = "棱彩",
        description = "体型变大10%，获得35%生命值和15%适应之力。",
    },
    en = {
        name = "Goliath",
        rarity = "Prismatic",
        description = "Grow 10% larger and gain 35% health and 15% adaptive force. ",
    },
    ja = {
        name = "ゴリアテ",
        rarity = "プリズマティック",
        description = "体が10%大きくなり、体力35%と適応力15%を得る。",
    },
}

function M.Build(language)
    local text = TEXT[language] or TEXT.zh
    return {
        id = M.ID,
        name = text.name,
        rarity = "prismatic",
        rarity_name = text.rarity,
        description = text.description,
        atlas = "images/mercuryrunes/rune_goliath.xml",
        image = "rune_goliath.tex",
        tags = {},
    }
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，歌利亚巨人不会注册。")
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
