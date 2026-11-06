local M = {}

M.ID = "draw_your_sword"

local TEXT = {
    zh = {
        name = "亮出你的剑",
        rarity = "棱彩",
        description = "攻击距离不会超过2。获得24%攻击力、24%生命值、20%攻击速度、20%生命偷取和20%移动速度。每减少3攻击距离，上述每项属性额外提高3%。",
    },
    en = {
        name = "Draw Your Sword",
        rarity = "Prismatic",
        description = "Attack range cannot exceed 2. Gain 24% attack damage, 24% health, 20% attack speed, 20% lifesteal and 20% move speed. Each stat gains another 3% for every 3 attack range lost.",
    },
    ja = {
        name = "剣を抜け",
        rarity = "プリズマティック",
        description = "攻撃距離は2を超えない。攻撃力24%、体力24%、攻撃速度20%、ライフスティール20%、移動速度20%を得る。失った攻撃距離3ごとに各能力がさらに3%上がる。",
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
        atlas = "images/mercuryrunes/rune_draw_your_sword.xml",
        image = "rune_draw_your_sword.tex",
        tags = {},
    }
end

local HUD_IDS = { M.ID, "light_them_up", "dont_blink", "goliath", "agility_to_strength", "borrowed_time" }

function M.AppendHud(entries, has_rune)
    local copy, seen = {}, {}
    for index, entry in ipairs(entries or {}) do
        copy[index] = entry
        seen[entry.rune_id] = true
    end
    if type(has_rune) ~= "function" then return copy end
    for _, rune_id in ipairs(HUD_IDS) do
        if not seen[rune_id] and has_rune(rune_id) then
            copy[#copy + 1] = {
                rune_id = rune_id,
                remaining = nil,
                stacks = 0,
                order = 1000000,
            }
        end
    end
    return copy
end

function M.Install()
    local ok, defs = pcall(require, "mercury_rune_defs")
    if not ok or type(defs) ~= "table" or type(defs.Get) ~= "function" then
        print("[海克斯扩展] 未启用《海克斯符文系统》，亮出你的剑不会注册。")
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
