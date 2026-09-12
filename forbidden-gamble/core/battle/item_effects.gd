class_name ItemEffects
extends RefCounted

# 战斗域道具效果执行器（纯逻辑，无 UI）：battle.gd 调用，GUT 直接测。
# - heal：玩家回复（上限截断）
# - damage：暗器直伤——绕过护体真气（guard 不参与），按敌人「道具伤害减免」打折
# - apply_status：走 FighterState.add_status（毒等战斗内状态，回合开始由管线结算）
# 减免缺省按敌人档次查表（听风辨器：normal 0% / veteran 20% / elite 35% / master 50%），
# 敌人定义可用 item_damage_reduction 覆写个别特例。

const TIER_ITEM_REDUCTION := {"normal": 0.0, "veteran": 0.2, "elite": 0.35, "master": 0.5}

# 结算一件道具的全部战斗效果，返回逐条效果文本（日志用）。
static func apply(use: Dictionary, player: FighterState, enemy: FighterState) -> Array[String]:
	var lines: Array[String] = []
	for effect in use.get("effects", []):
		match str((effect as Dictionary).get("kind", "")):
			"heal":
				var amount := int((effect as Dictionary).get("amount", 0))
				var before := player.hp
				player.hp = mini(player.hp + amount, player.max_hp)
				lines.append("气血回复 %d 点（%d/%d）。" % [player.hp - before, player.hp, player.max_hp])
			"damage":
				var raw := int((effect as Dictionary).get("amount", 0))
				var dealt := reduced_damage(raw, enemy)
				enemy.hp = maxi(enemy.hp - dealt, 0)
				lines.append("直取要害，造成 %d 点伤害。" % dealt)
			"apply_status":
				var status_id := str((effect as Dictionary).get("status", ""))
				var stacks := int((effect as Dictionary).get("stacks", 0))
				enemy.add_status(status_id, stacks)
				lines.append("%s 中了%s（×%d）。" % [enemy.display_name, StatusRuntime.status_name(status_id), stacks])
	return lines

# 道具直伤经减免：百分比向下取整；减免未配置时按敌人档次查缺省表。
static func reduced_damage(amount: int, enemy: FighterState) -> int:
	var reduction := enemy.item_damage_reduction
	if reduction < 0.0:
		reduction = float(TIER_ITEM_REDUCTION.get(enemy.tier, 0.0))
	return int(floor(amount * (1.0 - reduction)))
