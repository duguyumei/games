class_name EnemyPolicy
extends RefCounted

# 只负责选择，不读取玩家手牌；功法优先级来自敌人数据（ai_priority 字段）。
# 行动权模型（D-063）：无合法功法时优先提气（每口气限 1 次、让一拍换一张）；
# 提气不可用（已提或无牌可提）则调息换一手；三堆全空才纯过牌兜底（防卡死）。
static func choose_action(enemy: FighterState) -> Dictionary:
	for technique_id in enemy.ai_priority:
		var selection := TechniqueResolver.find_legal_selection(technique_id, enemy.hand, enemy)
		if not selection.is_empty():
			return {"technique": technique_id, "cards": selection}
	var piles_empty := enemy.draw_pile.is_empty() and enemy.discard_pile.is_empty()
	if enemy.lifts_this_breath < 1 + enemy.lift_allowance and not piles_empty:
		return {"action": "lift_qi"}
	if piles_empty and enemy.hand.is_empty():
		return {"action": "pass"}
	return {"action": "breathe"}
