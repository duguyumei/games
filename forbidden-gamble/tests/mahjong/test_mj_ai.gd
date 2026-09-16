extends GutTest

# 敌方 AI（真气语法 v3 §6）：贪心启发式——留牌价值（搭子×门权重）、截牌倾向、连发、防御血线。


func _t(suit: String, value: int) -> MJTile:
	return MJTile.make(suit, value)


func test_posture_keeps_triplet_and_pair() -> void:
	var ai := MJAI.new()
	var hand: Array = [
		_t("条", 5), _t("条", 5), _t("条", 5),  # 刻线（价值最高）
		_t("万", 1), _t("万", 2),                # 顺线搭子
		_t("筒", 9), _t("条", 1), _t("筒", 4),   # 孤张
	]
	var request := {"phase": "posture", "hand": hand, "discard_count": 3}
	var decision := ai.decide(request)
	var discard: Array = decision["discard_indexes"]
	assert_eq(discard.size(), 3)
	for idx in discard:
		assert_true(int(idx) >= 3, "条5×3 的索引 0-2 必须保留")


func test_posture_discards_isolated_tiles_first() -> void:
	var ai := MJAI.new()
	var hand: Array = [
		_t("条", 5), _t("条", 5),   # 对子
		_t("万", 1), _t("万", 2),   # 搭子
		_t("筒", 9),                # 孤张（价值最低）
	]
	var decision := ai.decide({"phase": "posture", "hand": hand, "discard_count": 1})
	assert_eq(int(decision["discard_indexes"][0]), 4, "先弃孤张筒9")


func test_claim_takes_all_options() -> void:
	var ai := MJAI.new()
	var options: Array = [
		{"type": "pon", "batch_index": 0, "symbol": "崩"},
		{"type": "pon", "batch_index": 1, "symbol": "撼"},
	]
	var decision := ai.decide({"phase": "claim", "claim_options": options})
	var indexes: Array = decision["claim_indexes"]
	assert_true(indexes.has(0) and indexes.has(1), "能截的批位全要（一次按钮多截）")


func test_claim_declines_when_nothing_claimable() -> void:
	var ai := MJAI.new()
	var decision := ai.decide({"phase": "claim", "claim_options": []})
	assert_true(decision["claim"] == null, "无选项放行")


func test_claim_dedupes_same_batch_index() -> void:
	var ai := MJAI.new()
	# 同一牌位碰/杠并列（手里三张）——批位只取一次，碰/杠由引擎按张数自动判定
	var options: Array = [
		{"type": "kan", "batch_index": 0, "symbol": "崩"},
		{"type": "pon", "batch_index": 0, "symbol": "崩"},
	]
	var decision := ai.decide({"phase": "claim", "claim_options": options})
	assert_eq((decision["claim_indexes"] as Array).size(), 1, "同批位去重")


func test_fire_picks_strongest_usable() -> void:
	var ai := MJAI.new()
	var techniques: Array = [
		{"id": "tie_bu_shan", "kind": "defense", "can_use": false, "gang_qi_cost": 3, "summary": "铁布衫（护体·罡气3）"},
		{"id": "dian_xue", "kind": "attack", "can_use": true, "power": 200, "summary": "点穴式（点×1·200%）"},
		{"id": "fake_heavy", "kind": "attack", "can_use": true, "power": 120, "summary": "测试用低倍功法"},
	]
	var decision := ai.decide({"phase": "free_fire", "techniques": techniques})
	var fire: Array = decision["fire"]
	assert_eq(fire.size(), 1)
	assert_eq(String(fire[0]), "dian_xue", "倍率大者优先（直读 power% 字段）")


func test_defense_engages_under_threat() -> void:
	var ai := MJAI.new()
	var decision := ai.decide({
		"phase": "free_fire", "hp": 15, "max_hp": 60, "gang_qi": 4,
		"opp_pending": [{"tech_id": "dian_xue", "power": 200}],
		"techniques": [{"id": "tie_bu_shan", "kind": "defense", "can_use": true, "gang_qi_cost": 3}],
	})
	assert_eq(String(decision.get("defense", "")), "tie_bu_shan", "血线 25%＋在途倍率 200% ≥ 阈值 150 → 附带护体")


func test_defense_skips_when_healthy() -> void:
	var ai := MJAI.new()
	var decision := ai.decide({
		"phase": "free_fire", "hp": 57, "max_hp": 60, "gang_qi": 5,
		"opp_pending": [{"tech_id": "dian_xue", "power": 200}],
		"techniques": [{"id": "tie_bu_shan", "kind": "defense", "can_use": true, "gang_qi_cost": 3}],
	})
	assert_false(decision.has("defense"), "血线健康不护体")


func test_ankan_taken_greedily() -> void:
	var ai := MJAI.new()
	var decision := ai.decide({"phase": "free_fire", "techniques": [],
		"ankan_options": [{"key": "万5", "suit": "万"}]})
	assert_eq(String(decision.get("ankan", "")), "万5", "能暗杠先暗杠（重式经济）")


func test_decisions_deterministic() -> void:
	var ai_a := MJAI.new()
	var ai_b := MJAI.new()
	var hand: Array = [_t("万", 5), _t("万", 5), _t("万", 6), _t("筒", 9)]
	for _i in range(5):
		var a := ai_a.decide({"phase": "posture", "hand": hand, "discard_count": 1})
		var b := ai_b.decide({"phase": "posture", "hand": hand, "discard_count": 1})
		assert_eq(int(a["discard_indexes"][0]), int(b["discard_indexes"][0]))
