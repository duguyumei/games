extends GutTest

# 挑战层引擎缝＋内容件（代码设计 v1.4 §4.5–§4.7）：TILE_DRAWN 四 reason（含破绽拍）、
# base_jing 摸牌派生、血量带入、TECH_FIRE.tiles、draw_bonus_next 消费、四牌灵、
# 破甲/连环/金钟/运筹/洗练。单元直挂 hooks＋同种子双局集成（先探牌再绑灵）。


var match_: MJMatch
var _draw_events: Array = []      # {side, reason, keys}
var _fire_tiles: Array = []


func before_each() -> void:
	_draw_events.clear()
	_fire_tiles.clear()
	match_ = MJMatch.new()
	match_.setup({"seed": 77})
	match_.hooks.on(MJHooks.TILE_DRAWN, self, func(input: Dictionary) -> Dictionary:
		var keys: Array = []
		for t in input.get("tiles", []):
			keys.append((t as MJTile).key())
		_draw_events.append({"side": input.get("side"), "reason": input.get("reason"), "keys": keys})
		return {})
	match_.hooks.on(MJHooks.TECH_FIRE, self, func(input: Dictionary) -> Dictionary:
		var keys: Array = []
		for t in input.get("tiles", []):
			keys.append((t as MJTile).key())
		_fire_tiles.append(keys)
		return {})


func _t(suit: String, value: int) -> MJTile:
	return MJTile.make(suit, value)


func _default_decide(request: Dictionary) -> Dictionary:
	match String(request.get("phase", "")):
		"free_fire":
			return {"fire": []}
		"posture":
			var count := int(request.get("discard_count", 0))
			var indexes: Array[int] = []
			for i in range(count):
				indexes.append(i)
			return {"discard_indexes": indexes}
		"claim":
			return {"claim": null}
	return {}


func _player_beats(count: int) -> void:
	# 推进 count 个玩家拍（缺省应答一路放行）
	var seen := 0
	for _i in range(200):
		var request := match_.next_request()
		if request.is_empty():
			return
		match_.decide(_default_decide(request))
		if String(request["phase"]) == "posture" and String(request["side"]) == "player":
			seen += 1
			if seen >= count:
				return


# —— 引擎缝 ——

func test_base_jing_derives_draw_count() -> void:
	assert_eq(match_.fighter("player").draw_count(), 3, "缺省 精力1→摸3")
	var m2 := MJMatch.new()
	m2.setup({"seed": 7, "player_base_jing": 2})
	assert_eq(m2.fighter("player").draw_count(), 4, "卡组 精力2→摸4")


func test_start_hp_carried_in() -> void:
	var m := MJMatch.new()
	m.setup({"seed": 7, "player_start_hp_fp": 5500})
	assert_eq(m.fighter("player").hp_fp, 5500, "血量带入")
	assert_eq(m.fighter("enemy").hp_fp, 10000, "敌方恒满血")


func test_tile_drawn_reasons_and_sizes() -> void:
	match_.start_battle()
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	var player_draws: Array = _draw_events.filter(func(e: Dictionary) -> bool: return e["side"] == "player")
	assert_false(player_draws.is_empty())
	assert_eq(String(player_draws[0]["reason"]), "draw")
	assert_eq((player_draws[0]["keys"] as Array).size(), 3, "首拍摸 3")


func test_tile_drawn_flaw_beat() -> void:
	match_.fighter("player").flawed = true
	match_.start_battle()  # 首拍即破绽拍：只自然摸牌（draw 在 start_battle 内发生）
	var flaw_draws: Array = _draw_events.filter(func(e: Dictionary) -> bool:
		return e["side"] == "player" and String(e["reason"]) == "flaw")
	assert_eq(flaw_draws.size(), 1, "破绽拍摸牌以 reason=flaw 发出")
	assert_eq((flaw_draws[0]["keys"] as Array).size(), 3)


func test_tech_fire_carries_tiles() -> void:
	match_.start_battle()
	var f := match_.fighter("player")
	f.hand.clear()
	f.hand.append_array([_t("万", 5), _t("万", 6), _t("万", 7),
		_t("筒", 1), _t("筒", 4), _t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8),
		_t("万", 9), _t("筒", 3), _t("筒", 6), _t("条", 9)])
	match_.decide({"fire": ["dian_xue"]})
	assert_eq(_fire_tiles.size(), 1, "TECH_FIRE 已发")
	var keys := (_fire_tiles[0] as Array).duplicate()
	keys.sort()
	assert_eq(keys, ["万5", "万6", "万7"], "tiles＝本次耗式（点＝万顺）")


func test_draw_bonus_consumed_once() -> void:
	match_.start_battle()          # 首拍已摸 3
	match_.decide({"fire": []})    # 普攻打出 → 洗练诀类词条的挂点
	match_.fighter("player").draw_bonus_next = 1
	match_.decide(_default_decide(match_.next_request()))  # 首拍打出
	match_.decide({"claim": null})
	# 敌拍走完回到玩家：第二拍摸 3+1
	for _i in range(10):
		var request := match_.next_request()
		if String(request.get("phase", "")) == "free_fire" and String(request.get("side", "")) == "player":
			break
		match_.decide(_default_decide(request))
	var player_draws: Array = _draw_events.filter(func(e: Dictionary) -> bool: return e["side"] == "player")
	assert_eq((player_draws[0]["keys"] as Array).size(), 3, "首拍 3")
	assert_eq((player_draws[1]["keys"] as Array).size(), 4, "加成生效")
	assert_eq(match_.fighter("player").draw_bonus_next, 0, "消费即清")


# —— 牌灵（单元直挂 hooks）——

func _out_of(results: Array) -> Dictionary:
	assert_eq(results.size(), 1)
	return results[0]["out"]


func test_ling_gang_unit() -> void:
	var hooks := MJHooks.new()
	var ling := MJPaiLing.make("ling_gang", "万", 5)
	ling.register(hooks, "player")
	assert_eq(_out_of(hooks.emit_event(MJHooks.TILE_DRAWN,
		{"side": "player", "tiles": [_t("万", 5)], "reason": "draw"})), {"gang_qi": 1})
	assert_eq(_out_of(hooks.emit_event(MJHooks.TILE_DRAWN,
		{"side": "player", "tiles": [_t("筒", 5)], "reason": "topup"})), {})
	assert_eq(_out_of(hooks.emit_event(MJHooks.TILE_DRAWN,
		{"side": "enemy", "tiles": [_t("万", 5)], "reason": "draw"})), {}, "owner 过滤")


func test_ling_gang_integration_same_seed() -> void:
	# 同种子双局：先探首拍玩家摸到的三张，再绑其一验证罡气进账（+1 摸牌基粮 +1 灵罡）
	var probe_keys: Array = []
	var probe := MJMatch.new()
	probe.setup({"seed": 2024})
	probe.hooks.on(MJHooks.TILE_DRAWN, self, func(input: Dictionary) -> Dictionary:
		if String(input.get("side")) == "player" and String(input.get("reason")) == "draw":
			for t in input.get("tiles", []):
				probe_keys.append((t as MJTile).key())
		return {})
	probe.start_battle()
	probe.decide({"fire": []})
	assert_eq(probe_keys.size(), 3)
	var bound := MJTile.make(String(probe_keys[0]).substr(0, 1), int(String(probe_keys[0]).substr(1)))
	match_ = MJMatch.new()
	match_.setup({"seed": 2024, "player_pailing": [
		{"id": "ling_gang", "suit": bound.suit, "value": bound.value}]})
	match_.start_battle()
	match_.decide({"fire": []})
	assert_eq(match_.fighter("player").gang_qi, 2, "摸牌+1 ＋ 灵罡+1")


func test_ling_zhong_marks_and_resolves() -> void:
	var hooks := MJHooks.new()
	var ling := MJPaiLing.make("ling_zhong", "万", 7)
	ling.register(hooks, "player")
	assert_eq(_out_of(hooks.emit_event(MJHooks.TECH_FIRE,
		{"side": "player", "tech_id": "dian_xue", "tiles": [_t("万", 7)]})), {})
	assert_eq(_out_of(hooks.emit_event(MJHooks.TECH_RESOLVE,
		{"side": "player", "tech_id": "dian_xue"})), {"pct_bonus": 30})
	assert_eq(_out_of(hooks.emit_event(MJHooks.TECH_RESOLVE,
		{"side": "player", "tech_id": "dian_xue"})), {}, "一次性标记")


func test_ling_bian_on_posture() -> void:
	var hooks := MJHooks.new()
	var ling := MJPaiLing.make("ling_bian", "条", 3)
	ling.register(hooks, "player")
	assert_eq(_out_of(hooks.emit_event(MJHooks.POSTURE,
		{"side": "player", "batch": [_t("万", 2), _t("条", 3)], "kind": "normal"})), {"bian_charge": 1})
	assert_eq(_out_of(hooks.emit_event(MJHooks.POSTURE,
		{"side": "player", "batch": [_t("万", 2)], "kind": "xu"})), {})


func test_ling_jia_stacks_iron_bonus() -> void:
	var hooks := MJHooks.new()
	var ling := MJPaiLing.make("ling_jia", "筒", 9)
	ling.register(hooks, "player")
	assert_eq(_out_of(hooks.emit_event(MJHooks.TILE_DRAWN,
		{"side": "player", "tiles": [_t("筒", 9)], "reason": "draw"})), {"iron_bonus_next": 10})
	var f := MJFighter.new()
	f.iron_bonus_next = 10
	f.start_iron(80, 3)
	assert_eq(f.iron_reduction, 90, "灵甲进护体")
	assert_eq(f.iron_bonus_next, 0, "消费即清")


# —— 新武学（单元）——

func test_lianhuan_zhang_flaw_bonus() -> void:
	var tech := TechLianHuanZhang.new()
	assert_eq(tech.power, 130)
	assert_eq(tech._on_tech_resolve({"opp_flawed": true}), {"pct_bonus": 20, "notes": ["连环掌：对方露破绽 +20%"]})
	assert_eq(tech._on_tech_resolve({"opp_flawed": false}), {})


func test_po_jia_quan_and_gu_drop() -> void:
	var tech := TechPoJiaQuan.new()
	assert_eq(tech.power, 90)
	assert_eq(int(tech._on_tech_resolve({})["debuff_gu_next"]), 1)
	var foe := MJFighter.new()
	foe.base_defense = 0
	foe.gu_li = 3
	assert_eq(foe.defense_panel(), 3)
	foe.gu_drop_next = 1
	assert_eq(foe.defense_panel(), 2, "破甲减防生效")
	foe.gu_drop_next = 5
	assert_eq(foe.defense_panel(), 0, "防御不为负")


func test_jin_zhong_zhao_defense() -> void:
	var tech := TechJinZhongZhao.new()
	assert_eq(tech.gang_qi_cost, 3)
	var f := MJFighter.new()
	tech.apply_defense(f)
	assert_eq(f.iron_reduction, 70)
	assert_eq(f.iron_beats_left, 2)


func test_xinfa_yun_zhou_and_xi_lian() -> void:
	var f := MJFighter.new()
	var yun := MJXinfaYunZhouJue.new()
	yun.on_claim_done(f)
	assert_eq(f.gang_qi, 1)
	var xi := MJXinfaXiLianJue.new()
	xi.on_posture_played(f, "normal")
	assert_eq(f.draw_bonus_next, 1)
	xi.on_posture_played(f, "xu")
	assert_eq(f.draw_bonus_next, 1, "虚招不触发")


func test_pailing_registry_roundtrip() -> void:
	for id_str in MJPaiLing.roster():
		var ling := MJPaiLing.make(id_str, "万", 1)
		assert_not_null(ling, id_str + " 应可制造")
		assert_eq(ling.tile.key(), "万1")
	assert_null(MJPaiLing.make("ling_none", "万", 1))
