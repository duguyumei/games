extends GutTest

# 数据定义层 schema 校验：真数据全绿；损坏数据被 validate_pack 抓住（纯函数喂坏例）。

func test_real_data_passes_validation() -> void:
	assert_eq(DataRepo.validate_all(), [], "数据应通过全部校验")

func _pack(items: Dictionary, enemies: Dictionary = {}, techniques: Dictionary = {},
		statuses: Dictionary = {}) -> Dictionary:
	return {
		"items.json": items,
		"enemies.json": enemies,
		"techniques.json": techniques,
		"statuses.json": statuses,
	}

# 敌方校验用的最小功法包（梯级/钩子引用存在的条目由这些承载）
func _techs() -> Dictionary:
	return {
		"点星式": {"level": 1, "patterns": ["ONE_QI"], "effects": [{"type": "damage", "base": 6, "scale": 3}]},
		"窥隙脚": {"level": 1, "patterns": ["ONE_QI"], "effects": [{"type": "damage", "base": 2, "scale": 1}]},
	}

func _enemy_def(extra: Dictionary = {}) -> Dictionary:
	var def := {
		"id": "shan", "name": "山匪", "max_hp": 10,
		"ladder": [{"technique": "点星式"}, {"technique": "调息"}],
	}
	def.merge(extra, true)
	return def

func test_catches_bad_rarity() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "rarity": "epic", "value": 1},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知稀有度")), "未知稀有度应被抓")

func test_catches_id_key_mismatch() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "other", "name": "丹", "rarity": "common", "value": 1},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("与键不一致")), "id 与键不一致应被抓")

func test_catches_dangling_apply_status() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {}, {"万剑归宗": {"level": 5, "patterns": ["MIX_2"],
			"effects": [{"type": "apply_status", "status": "bleed"}]}}, {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的状态")), "apply_status 引用不存在状态应被抓")

# ---------- 敌方对手卡（敌方系统 v2） ----------

func test_catches_ladder_dangling_technique() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [{"technique": "不存在的招"}, {"technique": "调息"}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的功法")), "梯级引用不存在功法应被抓")

func test_catches_empty_ladder() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": []})}, _techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("行为链梯为空")), "空行为链梯应被抓")

func test_catches_unknown_ladder_condition_key() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [
			{"technique": "点星式", "when": {"心情好": 1}}, {"technique": "调息"}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知条件键")), "未知条件键应被抓")

func test_catches_ladder_dangling_status() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [
			{"technique": "点星式", "when": {"status_gte": {"怒气": 3}}}, {"technique": "调息"}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的状态")), "条件引用不存在状态应被抓")

func test_catches_floor_with_conditions() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [
			{"technique": "点星式"},
			{"technique": "调息", "when": {"guard_lt": 3}}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("调息地板不得带自况条件")), "带条件的地板应被抓")

func test_catches_bad_breathe_policy() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"breathe_policy": "随缘"})}, _techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知调息策略")), "未知调息策略应被抓")

func test_catches_unknown_hook_event() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"hooks": [
			{"kind": "应", "on": "玩家眨眼", "technique": "窥隙脚", "cooldown": 1}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知事件")), "未知钩子事件应被抓")

func test_catches_hook_dangling_technique() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"hooks": [
			{"kind": "乱", "on": "guard_broken", "technique": "夺命脚", "cooldown": 1}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的功法")), "钩子引用不存在功法应被抓")

func test_catches_bad_enemy_card_grade() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"hand": [{"id": "c1", "attribute": "山", "grade": "极品"}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知品级")), "未知品级应被抓")

func test_catches_negative_hook_cooldown() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"hooks": [
			{"kind": "乱", "on": "guard_broken", "technique": "窥隙脚", "cooldown": -1}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("非负整数")), "负冷却应被抓")

func test_valid_minimal_pack_passes() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{"dan": {"id": "dan", "name": "丹", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 1,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "heal", "amount": 5}]}}},
		{"shan": _enemy_def({"hooks": [
			{"kind": "乱", "on": "guard_broken", "technique": "点星式", "cooldown": 2}]})},
		_techs(),
		{"poison": {"name": "毒", "scope": "battle", "on": "breath", "phase": "post", "priority": 0, "action": "hp_loss", "amount": "stacks", "decay": 1}}))
	assert_eq(errs, [], "合法最小数据包应通过：%s" % [errs])

func test_catches_unknown_item_type() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "type": "wuxing", "rarity": "common", "value": 1},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知大类")), "未知物品大类应被抓")
