local M = {}

M.ID = "borrowed_time"

local TEXT = {
    zh = {
        name = "预借时间",
        rarity = "棱彩",
        description = "旺达专属。\n配方中缺少的材料会显示为年龄。\n每缺少1个材料扣除4年龄，并完成这次制作。\n拥有岁月慢行时，这个代价减少一半。",
    },
    en = {
        name = "Borrowed Time",
        rarity = "Prismatic",
        description = "Wanda only.\nMissing materials are shown on the recipe as age.\nEach missing material costs 4 age and completes the craft.\nTime Takes Its Time halves this cost.",
    },
    ja = {
        name = "時間の前借り",
        rarity = "プリズマティック",
        description = "ワンダ専用。\n不足している素材はレシピ上で年齢として表示される。\n素材1個につき4年齢を消費し、その製作を完成させる。\nゆっくり流れる歳月を持つと、この代償は半分になる。",
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
        atlas = "images/mercuryrunes/rune_borrowed_time.xml",
        image = "rune_borrowed_time.tex",
        tags = {},
        character = "wanda",
    }
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，预借时间不会注册。")
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
