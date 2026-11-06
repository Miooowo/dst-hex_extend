# 海克斯扩展：点亮他们！

日期：2026-10-22  
状态：设计已在对话中确认，待审阅本规格后再写实现计划。

## 目标

为创意工坊模组《海克斯符文系统》（`workshop-3807808423`）做一个独立本地扩展。扩展加入白银符文「点亮他们！」。不修改创意工坊目录里的文件。

玩家装备该符文后，每第 4 次普通攻击向当前目标发射 4 枚飞弹。4 枚合计造成一份位面伤害，每枚分到四分之一。

## 非目标

- 不改创意工坊模组本体，不加注册接口。
- 不让飞弹吃暴击、攻击力加成、铁砧属性，也不让飞弹触发其他普攻符文或增加攻击计数。
- 不做自定义 TEX 图标。图标复用本体的 `images/mercuryrunes/rune_shockwave.xml`。
- 不在本规格里加入第二张符文。目录按可再加符文来放，这次只做这一张。

## 模组位置

- 目录：`Don't Starve Together/mods/mercury_hex_extend`
- 显示名：海克斯扩展
- 必须和《海克斯符文系统》同时启用。本体未启用时，扩展打印一行提示并什么都不做。

## 符文

| 项 | 值 |
| --- | --- |
| id | `light_them_up` |
| 名称 | 点亮他们！ |
| 稀有度 | 白银 |
| 限制 | 无。所有角色可抽到、可装备 |
| 图标 | 本体冲击波符文图 |

说明文案（随本体语言选项，在世界加载、语言已设定之后生成）：

- 中文：每第4次普通攻击发射4枚飞弹。4枚合计造成位面伤害：44–320（世界第1天为44，第999天及以后为320，中间按天数线性）+140%武器物理攻击力+76%武器位面伤害。
- English: Every 4th basic attack fires 4 missiles. Together they deal planar damage: 44–320 (44 on day 1, 320 on day 999 and after, linear in between) + 140% weapon physical damage + 76% weapon planar damage.
- 日本語：4回目の通常攻撃ごとに弾を4発放つ。4発合計の平面ダメージ：44–320（1日目は44、999日目以降は320、その間は日数で線形）+武器物理攻撃力の140%+武器平面ダメージの76%。

## 挂接

世界初始化之后（客户端和主机都执行）包装 `mercury_rune_defs` 上的函数，不改本体文件，也不往本体的内部表里插入：

- `Get`：id 为 `light_them_up` 时返回本符文。
- `GetAll`：返回包含本符文的新列表，不改原表。
- `GetByRarity`：白银列表返回一份拷贝并附上本符文，避免重复插入，也避免被「需要英雄联盟武器」的过滤漏掉。
- `IsValidForTier`：白银槽位接受 `light_them_up`。

本体对未知、非锤子限定 id 的 `IsAvailableForPlayer` 返回真，本符文不另改这条。

## 伤害

世界日 = `TheWorld.state.cycles + 1`（游戏里显示的天数）。

```
t = clamp((day - 1) / 998, 0, 1)
flat = 44 + (320 - 44) * t
total = flat + weapon_physical * 1.40 + weapon_planar * 0.76
each = total / 4
```

- 第 1 天 flat = 44。第 999 天及以后 flat = 320。
- `weapon_physical`：手持武器 `weapon:GetDamage(玩家)` 的第一个数字返回值；没有则用 `weapon.damage`。空手为 0。
- `weapon_planar`：手持武器 `planardamage` 组件的 `GetDamage()`。没有该组件时，才采用 `GetDamage` 第二个返回值里的 `planar`。两处都有时只取组件，不重复加。空手为 0。
- 不计入人物位面伤害、铁砧、暴击、伤害倍率、吸血。
- 每枚飞弹造成 `each` 点位面伤害。4 枚之和等于 `total`。

## 攻击计数

主机侧玩家组件 `lightemup` 监听 `onattackother`。

计入一次，当且仅当：

- 当前装备了 `light_them_up`。
- 这次不是飞行物落地（`data.projectile == nil`）。
- 武器上的 `_mercury_damage_action_id` 为空，或属于本体的普通攻击（`generic`、`hammer`、`cannon`）。技能 id 不计数。

计数到 4 时清零并发射，然后从 0 再计。卸下或换掉符文时计数归零。计数写入玩家存档，读档恢复。死亡不额外清零。

## 飞弹

预制物 `lightemup_missile`。外观用游戏自带的 `staff_projectile` 动画。从攻击者飞向这次攻击的目标。4 枚相对瞄准方向的偏角为 -12°、-4°、+4°、+12°，发射延迟为 0、0.05、0.10、0.15 秒。

命中且目标仍有效时，按位面伤害结算 `each`（减去目标位面防御，忽略护甲），击杀归属攻击者。目标在到达前失效，该枚不造成伤害并移除。

结算不经过玩家的 `DoAttack`。飞弹不带本体的伤害来源标签，也不写 `_mercury_damage_action_id`，因此不会走进本体 `OnHitOther` 里其他符文的结算。

## 文件

- `modinfo.lua`：显示名、版本、`api_version = 10`、`all_clients_require_mod = true`。
- `modmain.lua`：注册预制物，在模拟初始化时挂接符文表，给玩家加组件。
- `scripts/lightemup_rune.lua`：符文定义、文案、对 `mercury_rune_defs` 的包装。
- `scripts/components/lightemup.lua`：计数、存档、发射。
- `scripts/prefabs/lightemup_missile.lua`：飞弹预制物。

## 失败与边界

- `require("mercury_rune_defs")` 失败：提示缺少《海克斯符文系统》，不注册符文、不挂组件逻辑。
- 包装只做一次。
- 没有攻击目标时不发射。
- `each` 小于等于 0 时不发射。

## 测试

在同时启用两个模组的世界里手工验证：

1. 白银抽取池和符文界面能看到「点亮他们！」，说明与上表一致。
2. 装备后第 4 次普通攻击发出 4 枚飞弹；前 3 次不发。技能、飞弹落地不增加计数。
3. 用已知武器伤害核对：合计约等于天数基数 + 140% 武器物理 + 76% 武器位面；每枚约为合计的四分之一，并且记为位面伤害。
4. 空手时仍按天数基数发射。
5. 卸下符文后计数归零。读档后计数还在。
6. 关闭本体模组时，扩展不报错堆栈，只提示未启用。
