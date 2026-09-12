class_name EncounterLoader
extends RefCounted

# 从遭遇战配置装配双方战斗单位；UI 只加载配置，不手工拼战斗数据。
# JSON 读取统一走 DataRepo（缓存 + schema 校验）。
static func load(path: String) -> CombatState:
	var parsed := DataRepo.load_json(path)
	if parsed.is_empty():
		return null
	var player := _build_fighter(parsed.get("player", {}))
	var enemy := _build_fighter(parsed.get("enemy", {}))
	var state := CombatState.new(player, enemy)
	state.battle_seed = int(parsed.get("seed", 12345))
	return state

# 远征模式：玩家配置与敌人表分开存放，按敌人 id 组装一场战斗。
# data/player.json 根即玩家 FighterDef；兼容整包遭遇文件的 {"player": {...}} 形态。
static func load_player(path: String) -> FighterState:
	var data := DataRepo.load_json(path)
	if data.has("player"):
		data = data.get("player", {})
	return _build_fighter(data)

static func load_enemy(path: String, enemy_id: String) -> FighterState:
	var data: Dictionary = DataRepo.load_json(path)
	if not data.has(enemy_id):
		push_error("敌人表中没有该敌人: " + enemy_id)
		return null
	return _build_fighter(data.get(enemy_id, {}))

static func _build_fighter(data: Dictionary) -> FighterState:
	var fighter := FighterState.new(
		str(data.get("id", "")),
		str(data.get("name", "")),
		int(data.get("max_hp", 1))
	)
	fighter.weapon_school = str(data.get("school", ""))
	fighter.weapon_level = int(data.get("weapon_level", 0))
	fighter.tier = str(data.get("tier", "normal"))
	fighter.item_damage_reduction = float(data.get("item_damage_reduction", -1.0))
	fighter.techniques.assign(data.get("techniques", []))
	fighter.xinfa.assign(data.get("xinfa", []))
	fighter.ai_priority.assign(data.get("ai_priority", []))
	for card_data in data.get("deck", []):
		fighter.draw_pile.append(_build_card(card_data))
	for card_data in data.get("hand", []):
		fighter.hand.append(_build_card(card_data))
	return fighter

static func _build_card(card_data: Dictionary) -> QiCard:
	return QiCard.new(
		str(card_data.get("id", "")),
		str(card_data.get("attribute", "")),
		QiCard.grade_from_name(str(card_data.get("grade", "下品")))
	)
