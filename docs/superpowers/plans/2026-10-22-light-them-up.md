# 点亮他们！ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在独立扩展模组里加入白银符文「点亮他们！」，每第 4 次普通攻击发射 4 枚飞弹，合计造成一份按天数和武器计算的位面伤害。

**Architecture:** 纯计算放在 `scripts/lightemup_calc.lua`。`scripts/lightemup_rune.lua` 在模拟初始化后包装本体的 `Get`、`GetAll`、`GetByRarity`、`IsValidForTier`。主机玩家组件计数并发射 `lightemup_missile`。不修改创意工坊目录。

**Tech Stack:** Don't Starve Together API 10，Lua。纯函数测试用系统 Lua 运行 `tests/lightemup_calc_test.lua`。

**Spec:** `docs/superpowers/specs/2026-10-22-light-them-up-design.md`

## Global Constraints

- 模组目录是 `Don't Starve Together/mods/mercury_hex_extend`，显示名「海克斯扩展」。
- 不修改 `workshop-3807808423`。
- 不创建 git 提交，除非用户明确要求。
- 符文 id 为 `light_them_up`，稀有度为白银，图标复用 `images/mercuryrunes/rune_shockwave.xml`。
- 第 1 天基数 44，第 999 天及以后 320，天数 = `cycles + 1`，`t = clamp((day - 1) / 998, 0, 1)`。
- 合计 = 基数 + 140% 武器物理 + 76% 武器位面。每枚 = 合计 / 4。
- 武器位面优先取 `planardamage` 组件；没有组件时才用 `GetDamage` 的 `planar`。
- 飞弹偏角 -12、-4、+4、+12 度，延迟 0、0.05、0.10、0.15 秒。
- 飞弹不走玩家 `DoAttack`，不触发其他普攻符文。
- 本体缺失时只打印一行提示。

---

### Task 1: 纯计算与符文包装

**Files:**
- Create: `scripts/lightemup_calc.lua`
- Create: `scripts/lightemup_rune.lua`
- Test: `tests/lightemup_calc_test.lua`

**Interfaces:**
- Consumes: 无
- Produces: `FlatDamage(day)`、`TotalDamage(day, physical, planar)`、`EachDamage(day, physical, planar)`、`WorldDay(cycles)`、`ReadWeapon(weapon, owner)`、`ShouldCount(has_rune, projectile, action_id)`、`Advance(count)`、`Build(language)`、`InstallInto(defs, rune)`、`Install()`

- [ ] **Step 1: Write the failing test**

从模组根目录运行 `lua tests/lightemup_calc_test.lua`，确认因缺少模块而失败。

- [ ] **Step 2: Implement calc and rune install**

按规格实现上述函数。`InstallInto` 每次返回新列表，不改本体原表，重复调用不叠两层。

- [ ] **Step 3: Run the test**

Expected: `ok`，退出码 0。

### Task 2: 飞弹、计数组件、modmain

**Files:**
- Create: `scripts/prefabs/lightemup_missile.lua`
- Create: `scripts/components/lightemup.lua`
- Create: `modinfo.lua`
- Create: `modmain.lua`

**Interfaces:**
- Consumes: Task 1 的计算、`Install`、`ShouldCount`、`Advance`、`ReadWeapon`、`EachDamage`
- Produces: 预制物 `lightemup_missile` 的 `LaunchAt(attacker, target, damage, angle_offset)`；组件 `lightemup`

- [ ] **Step 1: Prefab**

`staff_projectile` 的 `fire_spin_loop`。出生点沿偏角错开 1.1，然后 `Throw` 追踪目标。命中时用 `GetAttacked(..., { planar = amount })` 结算；生命值没有下降时，再按位面防御扣一次 `health:DoDelta(..., ignore_absorb = true)`，并在击杀时推送 `killed`。

- [ ] **Step 2: Component**

近战在下一帧读取武器上刚写好的 `_mercury_damage_action_id`（本体在 `onattackother` 之后的 `CalcDamage` 里才写入）。远程挥击在出手时计数，不读取可能过期的 id。`projectile ~= nil` 的落地不计数。卸下或重新装备符文时计数归零；读档且仍然装备时保留计数。

- [ ] **Step 3: modinfo 与 modmain**

`api_version = 10`，`all_clients_require_mod = true`。`AddSimPostInit` 调用 `Install`。仅主机 `AddComponent("lightemup")`。

- [ ] **Step 4: Re-run the pure test**

Expected: `ok`，退出码 0。
