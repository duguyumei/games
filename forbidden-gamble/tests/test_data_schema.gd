extends GutTest

# 数据定义层 schema 校验：真数据全绿；损坏数据被 validate_pack 抓住（纯函数喂坏例）。

func test_real_data_passes_validation() -> void:
	assert_eq(DataRepo.validate_all(), [], "六份数据应通过全部校验")

func _pack(items: Dictionary, enemies: Dictionary = {}, techniques: Dictionary = {},
		statuses: Dictionary = {}, config: Dictionary = {}) -> Dictionary:
	return {
		"location_qingfeng.json": config,
		"items.json": items,
		"enemies.json": enemies,
		"techniques.json": techniques,
		"statuses.json": statuses,
	}

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

func test_catches_missing_technique_ref() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{"dan": {"id": "dan", "name": "丹", "rarity": "common", "value": 1}},
		{"shan": {"id": "shan", "name": "山匪", "tier": "normal", "loot_chest": "wood",
			"max_hp": 10, "techniques": ["无影脚"], "ai_priority": [], "deck": [
				{"id": "c1", "attribute": "火", "grade": "下品"}]}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的功法")), "敌人引用不存在的功法应被抓")

func test_catches_dangling_apply_status() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {}, {"万剑归宗": {"level": 5, "school": "剑法", "patterns": ["MIX_2"],
			"effects": [{"type": "apply_status", "status": "bleed"}]}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的状态")), "apply_status 引用不存在状态应被抓")

func test_catches_empty_enemy_deck() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": {"id": "shan", "name": "山匪", "tier": "normal", "loot_chest": "wood",
			"max_hp": 10, "techniques": [], "ai_priority": [], "deck": []}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("牌组为空")), "空牌组应被抓")

func test_catches_scatter_table_dangling_item() -> void:
	var errs := DataRepo.validate_pack(_pack({}, {}, {}, {}, {
		"ap": {"start": 40}, "scatter_table": ["buxianzai"], "alert_levels": [], "pursuer_table": []}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("散落表引用了不存在的物品")), "散落表坏引用应被抓")

func test_valid_minimal_pack_passes() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{"dan": {"id": "dan", "name": "丹", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 1,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "heal", "amount": 5}]}}},
		{"shan": {"id": "shan", "name": "山匪", "tier": "normal", "loot_chest": "wood",
			"max_hp": 10, "techniques": [], "ai_priority": [], "deck": [
				{"id": "c1", "attribute": "火", "grade": "下品"}]}},
		{"点星式": {"level": 1, "school": "通用", "patterns": ["ONE_QI"], "effects": [{"type": "damage", "base": 6}]}},
		{"poison": {"name": "毒", "scope": "battle", "on": "breath", "phase": "post", "priority": 0, "action": "hp_loss", "amount": "stacks", "decay": 1}},
		{"ap": {"start": 40}, "scatter_table": ["dan"], "alert_levels": [], "pursuer_table": [],
			"chests": {"wood": {"ap_cost": 1, "table": ["dan"]}}}))
	assert_eq(errs, [], "合法最小数据包应通过：%s" % [errs])

func test_catches_unknown_item_type() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "type": "wuxing", "rarity": "common", "value": 1},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知大类")), "未知物品大类应被抓")

func test_catches_bad_consumable_subtype() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "type": "consumable", "subtype": "pill",
			"rarity": "common", "value": 1},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("消耗品未知小类")), "未知消耗品小类应被抓")

func test_catches_unknown_use_kind() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 1,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "revive"}]}},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知效果类型")), "未实现的 use 效果类型应被抓")

func test_catches_bad_use_scope() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 1,
			"use": {"scopes": ["camp"], "target": "self", "effects": [{"kind": "heal", "amount": 5}]}},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知可用场景")), "未知 use 场景应被抓")

func test_catches_item_apply_status_dangling() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{"biao": {"id": "biao", "name": "镖", "type": "consumable", "subtype": "hidden_weapon",
			"rarity": "common", "value": 1,
			"use": {"scopes": ["battle"], "target": "enemy", "effects": [
				{"kind": "apply_status", "status": "bleed", "stacks": 2}]}}},
		{}, {}, {"poison": {"name": "毒", "scope": "battle", "on": "breath", "action": "hp_loss", "amount": "stacks", "decay": 1}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("apply_status 引用了不存在的状态")), "道具状态坏引用应被抓")

func test_catches_bad_max_stack() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 1, "max_stack": 0},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("max_stack 应为正整数")), "非正堆叠上限应被抓")

func test_catches_reduction_out_of_range() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{},
		{"shan": {"id": "shan", "name": "山匪", "tier": "normal", "loot_chest": "wood",
			"max_hp": 10, "techniques": [], "ai_priority": [], "deck": [
				{"id": "c1", "attribute": "火", "grade": "下品"}],
			"item_damage_reduction": 1.5}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("item_damage_reduction 应在 0~1")), "越界减免应被抓")

func test_catches_bad_card_grade() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": {"id": "shan", "name": "山匪", "tier": "normal", "loot_chest": "wood",
			"max_hp": 10, "techniques": [], "ai_priority": [], "deck": [
				{"id": "c1", "attribute": "火", "grade": "极品"}]}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("品级不完整")), "未知品级应被抓")

func test_catches_unknown_pattern() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {}, {"无相功": {"level": 1, "school": "通用", "patterns": ["STRAIGHT"],
			"effects": [{"type": "damage", "base": 6}]}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知牌型")), "旧点数牌型应被抓")

func test_catches_damage_without_base() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {}, {"无相功": {"level": 1, "school": "通用", "patterns": ["ONE_QI"],
			"effects": [{"type": "damage", "scale": 3}]}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("缺少 base")), "缺基值应被抓")

func test_catches_unknown_tag() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {}, {"无相功": {"level": 1, "school": "通用", "patterns": ["ONE_QI"], "tags": ["连动"],
			"effects": [{"type": "damage", "base": 6}]}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知标签")), "旧连动标签应被抓")
