class_name EncounterLoader
extends RefCounted

# 从遭遇战配置装配双方战斗单位；UI 只加载配置，不手工拼战斗数据。
# JSON 读取统一走 DataRepo（缓存 + schema 校验）。
# 敌我非同源（敌方系统 v1）：玩家侧 FighterDef（techniques/xinfa/deck），
# 敌方侧招式表定义（moves/script/mechanisms）存入 FighterState.enemy_def，
# 由 CombatState 构建剧本执行器。
static func load(path: String) -> CombatState:
	var parsed := DataRepo.load_json(path)
	if parsed.is_empty():
		return null
	var player := _build_player(parsed.get("player", {}))
	var enemy := _build_enemy(parsed.get("enemy", {}))
	var state := CombatState.new(player, enemy)
	state.battle_seed = int(parsed.get("seed", 12345))
	return state

# 玩家配置与敌人表分开存放时，按敌人 id 组装一场战斗。
# data/player.json 根即玩家 FighterDef；兼容整包遭遇文件的 {"player": {...}} 形态。
static func load_player(path: String) -> FighterState:
	var data := DataRepo.load_json(path)
	if data.has("player"):
		data = data.get("player", {})
	return _build_player(data)

static func load_enemy(path: String, enemy_id: String) -> FighterState:
	var data: Dictionary = DataRepo.load_json(path)
	if not data.has(enemy_id):
		push_error("敌人表中没有该敌人: " + enemy_id)
		return null
	return _build_enemy(data.get(enemy_id, {}))

# 玩家：功法/心法/真气牌库齐装（真气引擎完整）。
static func _build_player(data: Dictionary) -> FighterState:
	var fighter := FighterState.new(
		str(data.get("id", "")),
		str(data.get("name", "")),
		int(data.get("max_hp", 1))
	)
	fighter.techniques.assign(data.get("techniques", []))
	fighter.xinfa.assign(data.get("xinfa", []))
	for card_data in data.get("deck", []):
		fighter.draw_pile.append(_build_card(card_data))
	for card_data in data.get("hand", []):
		fighter.hand.append(_build_card(card_data))
	return fighter

# 敌人（同核对手卡，敌方系统 v2）：与玩家同一身体语法——真气手牌（起手 authored）、
# 牌库；脑（行为链梯＋钩子＋调息策略）存入 FighterState.enemy_def，由 CombatState
# 构建 EnemyBrain。敌人行动只有发动功法与调息（无道具）。
static func _build_enemy(data: Dictionary) -> FighterState:
	var fighter := FighterState.new(
		str(data.get("id", "")),
		str(data.get("name", "")),
		int(data.get("max_hp", 1))
	)
	fill_enemy_body(fighter, data)
	return fighter


# 往 FighterState 里灌对手卡身体（enemy_def＋起手手牌＋牌库）——加载与测试共用一口，
# 三处手抄的构建循环收编于此。
static func fill_enemy_body(fighter: FighterState, data: Dictionary) -> void:
	fighter.enemy_def = {
		"breathe_policy": data.get("breathe_policy", "all"),
		"ladder": data.get("ladder", []),
		"hooks": data.get("hooks", []),
	}
	for card_data in data.get("hand", []):
		fighter.hand.append(_build_card(card_data))
	for card_data in data.get("deck", []):
		fighter.draw_pile.append(_build_card(card_data))

static func _build_card(card_data: Dictionary) -> QiCard:
	return QiCard.new(
		str(card_data.get("id", "")),
		str(card_data.get("attribute", "")),
		QiCard.grade_from_name(str(card_data.get("grade", "下品")))
	)
