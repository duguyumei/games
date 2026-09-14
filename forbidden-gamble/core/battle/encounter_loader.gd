class_name EncounterLoader
extends RefCounted

# 从遭遇战配置装配双方战斗单位；UI 只加载配置，不手工拼战斗数据。
# JSON 读取统一走 DataRepo（缓存 + schema 校验）。
# 真气语法 v2（2026-09-14）：玩家侧 FighterDef（techniques/xinfa/deck＝**本命牌组**，
# 开局洗抽入丹田）；敌方侧对手卡（hand＝authored 起手、deck＝**主场气海配置**，
# 双方共吸）存入 FighterState.enemy_def，由 CombatState 构建气海与 EnemyBrain。
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
	return _build_enemy(data[enemy_id])

static func _build_player(data: Dictionary) -> FighterState:
	var fighter := FighterState.new(
		str(data.get("id", "player")),
		str(data.get("name", "独行武者")),
		int(data.get("max_hp", 30))
	)
	var techniques: Array = data.get("techniques", [])
	var technique_ids: Array[String] = []
	for technique in techniques:
		technique_ids.append(str(technique))
	fighter.techniques = technique_ids
	var xinfa: Array = data.get("xinfa", [])
	var xinfa_ids: Array[String] = []
	for xf in xinfa:
		xinfa_ids.append(str(xf))
	fighter.xinfa = xinfa_ids
	# 本命牌组：开局洗抽入丹田，战中不回流（真气语法 v2 §4）；丹田容量＝玩家缺省 8
	var index := 0
	for card_data in data.get("deck", []):
		index += 1
		fighter.destiny_pile.append(QiCard.new(
			str((card_data as Dictionary).get("id", "p_%d" % index)),
			str((card_data as Dictionary).get("attribute", "")),
			int((card_data as Dictionary).get("value", 3))))
	fighter.dantian_capacity = TurnManager.DANTIAN_SIZE
	return fighter

static func _build_enemy(data: Dictionary) -> FighterState:
	var fighter := FighterState.new(
		str(data.get("id", "enemy")),
		str(data.get("name", "无名武者")),
		int(data.get("max_hp", 30))
	)
	fill_enemy_body(fighter, data)
	return fighter


# 往 FighterState 里灌对手卡身体（enemy_def＋authored 起手）——加载与测试共用一口。
# 真气配置两种写法：显式卡列表（{attribute, value}）/ 简写串（"山4"）；
# 气海（deck）配置式 {属性: {数值: 张数}}。丹田容量＝起手张数（身体各有大小）；
# 功法表由梯级声明序填充（截牌选功法＝声明序第一个可付的）。
static func fill_enemy_body(fighter: FighterState, data: Dictionary) -> void:
	fighter.enemy_def = {
		"swap_policy": data.get("swap_policy", "all"),
		"ladder": data.get("ladder", []),
		"qi_sea": data.get("deck", {}),
	}
	var technique_ids: Array[String] = []
	for rule in data.get("ladder", []):
		var technique := str((rule as Dictionary).get("technique", ""))
		if technique.is_empty() or technique == "架势" or technique == "换牌":
			continue
		if not technique_ids.has(technique):
			technique_ids.append(technique)
	fighter.techniques = technique_ids
	var index := 0
	for entry in qi_pool(data):
		index += 1
		if entry.get("pile", "hand") == "hand":
			fighter.hand.append(QiCard.new(
				"%s_h%d" % [fighter.fighter_id, index],
				str(entry.get("attribute", "")),
				int(entry.get("value", 3))))
	# deck 条目不进任何私有堆——气海由 CombatState 从 qi_sea 统一展开
	fighter.dantian_capacity = maxi(fighter.hand.size(), 1)


# 气海构建（CombatState 装配时调用）：对手卡主场配置展开为共墙牌（确定性：同键序同展开）。
static func qi_sea_cards(enemy_def: Dictionary) -> Array:
	var cards: Array = []
	var index := 0
	for entry in _pile_entries(enemy_def.get("qi_sea", {}), "deck"):
		index += 1
		cards.append(QiCard.new("wall_%d" % index,
			str(entry.get("attribute", "")), int(entry.get("value", 3))))
	return cards


# 归一化的真气池条目（hand 顺序），配置式与显式列表统一解析：{attribute, value, pile}。
static func qi_pool(data: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	entries.append_array(_pile_entries(data.get("hand", []), "hand"))
	return entries


static func _pile_entries(pile, pile_name: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pile is Dictionary:
		# 配置式：{属性: {数值: 张数}}——按声明顺序、数值升序展开
		for attribute in pile:
			var values: Dictionary = pile[attribute]
			for value in range(QiCard.VALUE_MIN, QiCard.VALUE_MAX + 1):
				for _i in range(int(values.get(str(value), 0))):
					entries.append({"attribute": str(attribute), "value": value, "pile": pile_name})
		# 声明序里越界的数值自然丢弃（schema 拦截）
	elif pile is Array:
		for item in pile:
			if item is Dictionary:
				entries.append({
					"attribute": str(item.get("attribute", "")),
					"value": int(item.get("value", 3)),
					"pile": pile_name})
			elif item is String:
				var parsed := parse_qi_token(item)
				if not parsed.is_empty():
					parsed["pile"] = pile_name
					entries.append(parsed)
	return entries


# 简写真气串："山4" → {attribute: "山", value: 4}（属性＝首字，数值 2–8）
static func parse_qi_token(token: String) -> Dictionary:
	if token.length() != 2:
		return {}
	var value := int(token.substr(1))
	if not QiCard.value_valid(value):
		return {}
	return {"attribute": token.substr(0, 1), "value": value}
