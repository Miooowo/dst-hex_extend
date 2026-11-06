PrefabFiles = {
    "lightemup_missile",
}

Assets = {
    Asset("IMAGE", "images/mercuryrunes/rune_light_them_up.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_light_them_up.xml"),
    Asset("IMAGE", "images/mercuryrunes/rune_draw_your_sword.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_draw_your_sword.xml"),
    Asset("IMAGE", "images/mercuryrunes/rune_dont_blink.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_dont_blink.xml"),
    Asset("IMAGE", "images/mercuryrunes/rune_transmute_gold.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_transmute_gold.xml"),
    Asset("IMAGE", "images/mercuryrunes/rune_transmute_prismatic.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_transmute_prismatic.xml"),
    Asset("IMAGE", "images/mercuryrunes/rune_goliath.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_goliath.xml"),
    Asset("IMAGE", "images/mercuryrunes/rune_agility_to_strength.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_agility_to_strength.xml"),
    Asset("IMAGE", "images/mercuryrunes/rune_borrowed_time.tex"),
    Asset("ATLAS", "images/mercuryrunes/rune_borrowed_time.xml"),
    Asset("ANIM", "anim/staff_projectile.zip"),
}

AddClassPostConstruct("widgets/redux/craftingmenu_ingredients", function(self)
    GLOBAL.require("borrowtime_hooks").HookIngredients(self)
end)

AddSimPostInit(function()
    GLOBAL.require("lightemup_rune").Install()
    GLOBAL.require("drawsword_rune").Install()
    GLOBAL.require("dontblink_rune").Install()
    GLOBAL.require("transmute_gold_rune").Install()
    GLOBAL.require("transmute_prismatic_rune").Install()
    GLOBAL.require("goliath_rune").Install()
    GLOBAL.require("agility_rune").Install()
    GLOBAL.require("borrowtime_rune").Install()
    GLOBAL.require("transmute_calc").InstallHooks()
    GLOBAL.require("borrowtime_hooks").Install()
end)

AddPlayerPostInit(function(inst)
    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        inst:DoTaskInTime(0, function()
            local runes = inst.components ~= nil and inst.components.mercuryrunes or nil
            if runes ~= nil then
                GLOBAL.require("transmute_calc").ResolveAll(runes)
            end
        end)
        if inst.components.lightemup == nil then
            inst:AddComponent("lightemup")
        end
        if inst.components.drawsword == nil then
            inst:AddComponent("drawsword")
        end
        GLOBAL.require("goliath_hooks").Install(inst)
        GLOBAL.require("agility_hooks").Install(inst)
    else
        GLOBAL.require("drawsword_hooks").Install(inst)
        GLOBAL.require("goliath_hooks").Install(inst)
        GLOBAL.require("agility_hooks").Install(inst)
    end
end)
