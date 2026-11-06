local M = {}

M.ID = "dont_blink"

local TEXT = {
    zh = {
        name = "唯快不破",
        rarity = "银色",
        description = "你每比攻击目标多1点行走速度，就获得8%额外伤害。",
    },
    en = {
        name = "Don't Blink",
        rarity = "Silver",
        description = "Gain 8% extra damage for each point of walk speed you have above the target. ",
    },
    ja = {
        name = "瞬きするな",
        rarity = "シルバー",
        description = "歩行速度が攻撃対象より1高いごとに追加ダメージ8%。",
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
        atlas = "images/mercuryrunes/rune_dont_blink.xml",
        image = "rune_dont_blink.tex",
        tags = {},
    }
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，唯快不破不会注册。")
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
