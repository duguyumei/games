extends GutTest

# 数据定义层 schema 校验：真数据全绿；损坏数据被 validate_pack 抓住（纯函数喂坏例）。
# 真气语法 v2.2：数值 2–8、牌型 KEZI/SHUNZI、架势地板；截牌钩 schema 已随钩子系统退役。

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

# 敌方校验用的最小功法包（梯级引用存在的条目由这些承载）
func _techs() -> Dictionary:
	return {
		"点星式": {"level": 1, "patterns": ["SHUNZI"], "effects": [{"type": "damage", "base": 2, "scale": 1}]},
		"重盾式": {"level": 1, "patterns": ["KEZI"], "effects": [{"type": "guard_cover", "base": 6, "scale": 1}]},
	}

func _enemy_def(extra: Dictionary = {}) -> Dictionary:
	var def := {
		"id": "shan", "name": "山匪", "max_hp": 10,
		"hand": ["山4"],
		"deck": {"风": {"3": 2}},
		"ladder": [{"technique": "点星式"}, {"technique": "架势"}],
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
		{}, {}, {"万剑归宗": {"level": 5, "patterns": ["KEZI"],
			"effects": [{"type": "apply_status", "status": "bleed"}]}}, {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的状态")), "apply_status 引用不存在状态应被抓")

func test_catches_unknown_pattern() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {}, {"旧式": {"level": 1, "patterns": ["ONE_QI"],
			"effects": [{"type": "damage", "base": 2}]}}, {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知牌型")), "旧牌型（一气）应被抓")

# ---------- 敌方对手卡（真气语法 v2.2） ----------

func test_catches_ladder_dangling_technique() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [{"technique": "不存在的招"}, {"technique": "架势"}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的功法")), "梯级引用不存在功法应被抓")

func test_catches_empty_ladder() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": []})}, _techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("行为链梯为空")), "空行为链梯应被抓")

func test_catches_unknown_ladder_condition_key() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [
			{"technique": "点星式", "when": {"心情好": 1}}, {"technique": "架势"}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知条件键")), "未知条件键应被抓")

func test_catches_floor_with_conditions() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [
			{"technique": "点星式"},
			{"technique": "架势", "when": {"guard_lt": 3}}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("架势地板不得带自况条件")), "带条件的地板应被抓")

func test_catches_old_floor_name_rejected() -> void:
	# 旧地板名"换牌"已随改名退役：不再被认作合法梯级
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"ladder": [
			{"technique": "点星式"}, {"technique": "换牌"}]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("不存在的功法")), "旧地板名应被抓（换牌→架势）")

func test_catches_bad_swap_policy() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"swap_policy": "随缘"})}, _techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知换手策略")), "未知换手策略应被抓")

func test_catches_empty_qi_sea() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"deck": {}})}, _techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("气海配置")), "气海为空应被抓")

func test_catches_bad_deck_spec_attribute_and_value() -> void:
	# 配置式气海：未知属性/数值越界都应被抓
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"deck": {"雷": {"4": 2}, "风": {"1": 1}}})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知属性")), "未知属性应被抓")
	assert_true(errs.any(func(e: String) -> bool: return e.contains("越界")), "数值越界应被抓")

func test_catches_bad_hand_token() -> void:
	# 简写串起手："山44"长度不对、属性不在白名单——都应被抓
	var errs := DataRepo.validate_pack(_pack(
		{}, {"shan": _enemy_def({"hand": ["山44", "雷4"]})},
		_techs(), {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("无法解析的真气简写")), "坏简写应被抓")

func test_valid_minimal_pack_passes() -> void:
	var errs := DataRepo.validate_pack(_pack(
		{"dan": {"id": "dan", "name": "丹", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 1,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "heal", "amount": 5}]}}},
		{"shan": _enemy_def()},
		_techs(),
		{"poison": {"name": "毒", "scope": "battle", "on": "swap", "phase": "post", "priority": 0, "action": "hp_loss", "amount": "stacks", "decay": 1}}))
	assert_eq(errs, [], "合法最小数据包应通过：%s" % [errs])

func test_catches_unknown_item_type() -> void:
	var errs := DataRepo.validate_pack(_pack({
		"dan": {"id": "dan", "name": "丹", "type": "wuxing", "rarity": "common", "value": 1},
	}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知大类")), "未知物品大类应被抓")

# ---------- 组挑战三份（mj_*，挑战层 v1.4 §3） ----------

func _mj_pack(decks := {}, opponents := {}, shop := {}) -> Dictionary:
	var pack := _pack({}, {}, {}, {})
	pack["mj_decks.json"] = decks
	pack["mj_opponents.json"] = opponents
	pack["mj_shop.json"] = shop
	return pack

func _deck_def(extra := {}) -> Dictionary:
	var def := {
		"id": "basic", "base_attack": 10, "base_defense": 0, "base_jing": 1, "base_max_hp": 100,
		"neili": {"jin": 1, "gu": 1, "qi": 1},
		"slots": {"gongfa": 1, "xinfa": 1, "hushen": 1},
		"loadout": {"gongfa": ["dian_xue"], "xinfa": ["zhao_jia_jue"], "hushen": ["tie_bu_shan"]},
	}
	def.merge(extra, true)
	return def

func _opp_def(extra := {}) -> Dictionary:
	var def := {
		"id": "grp1_x", "tier": "small", "base_attack": 10, "base_defense": 0, "base_jing": 1,
		"base_max_hp": 90, "neili": {"jin": 1, "gu": 1, "qi": 1},
		"techniques": ["dian_xue"], "defenses": [], "xinfa": [],
		"ai": {"suit_weights": {"万": 1.0}, "defense_hp_ratio": 0.35, "charge_threat_power": 150},
	}
	def.merge(extra, true)
	return def

func test_mj_real_data_passes() -> void:
	var errs := DataRepo.validate_all()
	assert_eq(errs, [], "真数据（含 mj_*）应通过：%s" % [errs])

func test_mj_catches_bad_deck_slots() -> void:
	var errs := DataRepo.validate_pack(_mj_pack(
		{"bad": _deck_def({"id": "bad", "slots": {"gongfa": 0, "xinfa": 1, "hushen": 1}})}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("slots.gongfa")), "槽位越界应被抓")

func test_mj_catches_loadout_overflow() -> void:
	var errs := DataRepo.validate_pack(_mj_pack(
		{"bad": _deck_def({"id": "bad",
			"loadout": {"gongfa": ["a", "b"], "xinfa": [], "hushen": []}})}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("超出槽位")), "起始件超槽应被抓")

func test_mj_catches_bad_tier_and_ratio() -> void:
	var errs := DataRepo.validate_pack(_mj_pack({},
		{"bad": _opp_def({"id": "bad", "tier": "elite"})}, {}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("tier")), "非法 tier 应被抓")
	errs = DataRepo.validate_pack(_mj_pack({},
		{"bad": _opp_def({"id": "bad",
			"ai": {"suit_weights": {"万": 1.0}, "defense_hp_ratio": 2.0, "charge_threat_power": 100}})}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("defense_hp_ratio")), "血线越界应被抓")

func test_mj_catches_bad_shop_fields() -> void:
	var errs := DataRepo.validate_pack(_mj_pack({}, {},
		{"wuxue_pool": [{"id": "x", "kind": "xifa", "price": 10}]}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("未知 kind")), "未知武学轨应被抓")
	errs = DataRepo.validate_pack(_mj_pack({}, {},
		{"heal_item": {"id": "h", "price": 10, "heal": 0}}))
	assert_true(errs.any(func(e: String) -> bool: return e.contains("heal_item")), "疗伤丹非法应被抓")

func test_mj_pools_and_opponents_ids_registered() -> void:
	# 池 id 与工厂注册一致性（代码设计 §6）：对手卡引用的武学/心法、货架池武学必须可被工厂制造
	var errs: Array[String] = []
	var opponents := DataRepo.mj_opponents()
	var shop := DataRepo.mj_shop()
	var known: Array[String] = []
	for id_str in MJTechniqueLibrary.attack_roster():
		known.append(id_str)
	for id_str in MJTechniqueLibrary.defense_roster():
		known.append(id_str)
	for id_str in MJTechniqueLibrary.xinfa_roster():
		known.append(id_str)
	for entry in shop.get("wuxue_pool", []):
		var id_str := str((entry as Dictionary).get("id", ""))
		if not known.has(id_str):
			errs.append("mj_shop.wuxue_pool 引用未注册武学: " + id_str)
	for key in opponents:
		var opp: Dictionary = opponents[key]
		for id_str in (opp.get("techniques", []) as Array) + (opp.get("defenses", []) as Array):
			if not MJTechniqueLibrary.attack_roster().has(str(id_str)) and not MJTechniqueLibrary.defense_roster().has(str(id_str)):
				errs.append("mj_opponents[%s] 引用未注册武学: %s" % [key, id_str])
		for id_str in opp.get("xinfa", []):
			if not MJTechniqueLibrary.xinfa_roster().has(str(id_str)):
				errs.append("mj_opponents[%s] 引用未注册心法: %s" % [key, id_str])
	assert_eq(errs, [], "池与对手卡引用必须全部可制造：%s" % [errs])
