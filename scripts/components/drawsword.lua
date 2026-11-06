local Hooks = require("drawsword_hooks")

local DrawSword = Class(function(self, inst)
    self.inst = inst
    Hooks.Install(inst)
end)

function DrawSword:OnRemove()
    Hooks.Remove(self.inst)
end

return DrawSword
