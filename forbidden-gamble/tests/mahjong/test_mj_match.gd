extends GutTest

# 对弈引擎（真气语法 v3.2 §3 统一循环）：摸牌开始打出结束、回气拍、功法＝打出、
# 守功法免费即时、截牌拍＝截＋弃 1、打出至上限、耗式不回填。
# 测试驱动器：_drive 用缺省应答推进到目标 phase；关键手牌直接改 fighter.hand（仅测试用）。


var match_: MJMatch


func before_each() -> void:
	match_ = MJMatch.new()
	match_.setup({"seed": 123})


func _t(suit: String, value: int) -> MJTile:
	return MJTile.make(suit, value)


func _set_hand(side: String, tiles: Array) -> void:
	var f := match_.fighter(side)
	f.hand.clear()
	for t in tiles:
		f.hand.append(t)


# 缺省应答：不发动、弃前三张、不截。
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


# 推进直到出现目标 phase 的请求（对齐 side 可选）；超步数返回空。
func _drive(wanted_phase: String, wanted_side: String = "", max_steps := 80) -> Dictionary:
	for _i in range(max_steps):
		var request := match_.next_request()
		if request.is_empty():
			return {}
		if String(request["phase"]) == wanted_phase and (wanted_side == "" or String(request["side"]) == wanted_side):
			return request
		match_.decide(_default_decide(request))
	return {}


# ---------- 开局与正常拍 ----------

func test_start_first_phase_is_free_fire_with_16() -> void:
	match_.start_battle()
	assert_eq(match_.fighter("enemy").hand.size(), 13, "敌方静息 13")
	var request := match_.next_request()
	assert_eq(String(request["phase"]), "free_fire", "摸牌环节自动完成后进入打出环节")
	assert_eq(String(request["side"]), "player")
	assert_eq((request["hand"] as Array).size(), 16, "13＋摸 3＝16")


func test_normal_turn_posture_to_cap_and_side_flips() -> void:
	match_.start_battle()
	match_.decide({"fire": []})                       # 不发功 → 打出走架势
	var posture_req := match_.next_request()
	assert_eq(String(posture_req["phase"]), "posture")
	assert_eq(int(posture_req["discard_count"]), 3, "打出至上限：超 3 弃 3")
	match_.decide({"discard_indexes": [0, 1, 2]})
	var claim_req := match_.next_request()
	assert_eq(String(claim_req["phase"]), "claim")
	assert_eq(String(claim_req["side"]), "enemy", "截牌窗开给对方")
	match_.decide({"claim": null})
	assert_eq(match_.river.size(), 3, "批次入气河")
	assert_eq(match_.fighter("player").gang_qi, 1, "架势 +1")
	assert_eq(match_.fighter("player").hand.size(), 13, "回到静息")
	var next := match_.next_request()
	assert_eq(String(next["phase"]), "free_fire")
	assert_eq(String(next["side"]), "enemy", "流向对方")


# ---------- 回气拍：摸后 ≤ 上限整拍跳过 ----------

func test_rest_beat_skips_when_below_cap() -> void:
	match_.start_battle()
	# 玩家首拍走完，敌方 free_fire 待应答
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(String(match_.next_request()["side"]), "enemy")
	# 玩家手牌压到 9：下拍摸 3 → 12 ≤ 13 → 回气
	_set_hand("player", [_t("万", 1), _t("万", 4), _t("万", 7), _t("筒", 2), _t("筒", 5),
		_t("筒", 8), _t("条", 3), _t("条", 6), _t("条", 9)])
	var beat_before := match_.beat
	# 敌方整拍走完：其架势窗放行 → 拍末 → 玩家回气（引擎内自动跳）→ 又轮敌方
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	var request := match_.next_request()
	assert_eq(String(request["side"]), "enemy", "玩家回气被跳过，直接又轮敌方")
	assert_eq(match_.fighter("player").hand.size(), 12, "摸 3 后 12 ≤ 上限 13")
	assert_true(match_.beat >= beat_before + 2, "回气也耗一拍")
	assert_true(match_.log.any(func(line: String): return line.contains("回气")), "日志记录回气")
	assert_true(match_.last_marker.begins_with("rest:player"), "marker 带拍号（连拍不吞演出）")


# ---------- 守功法：免费即时（不顶替摸牌） ----------

func test_defense_free_instant() -> void:
	match_.start_battle()
	match_.fighter("player").gang_qi = 3
	var hand_before := match_.fighter("player").hand.size()
	assert_true(match_.try_defense("player", "tie_bi"))
	var f := match_.fighter("player")
	assert_eq(f.guard, 8, "护境覆盖制：置 8")
	assert_eq(f.gang_qi, 0)
	assert_eq(f.hand.size(), hand_before, "守功法免费：手牌不动、不顶替摸牌")
	assert_eq(String(match_.next_request()["phase"]), "free_fire", "拍照常继续")


# ---------- 守功法窗口（v3.4：行动期间＝自己摸牌后、出牌前） ----------

func test_defense_window_own_beat_only() -> void:
	match_.start_battle()
	match_.fighter("player").gang_qi = 3
	assert_true(match_.try_defense("player", "tie_bi"), "摸牌后出牌前＝窗口内")
	match_.decide({"fire": []})
	match_.fighter("player").gang_qi = 3
	assert_true(match_.try_defense("player", "tie_bi"), "架势确认前＝出牌前，仍是窗口")
	match_.decide({"discard_indexes": [0, 1, 2]})
	# 截牌窗（敌方应答）：双方都无窗口
	match_.fighter("player").gang_qi = 3
	match_.fighter("enemy").gang_qi = 3
	assert_false(match_.try_defense("player", "tie_bi"), "自己开出的截牌窗中无窗口")
	assert_false(match_.try_defense("enemy", "tie_bi"), "截牌决定期无窗口")
	match_.decide({"claim": null})
	# 敌方 free_fire：玩家无窗口、敌方有
	match_.fighter("player").gang_qi = 3
	match_.fighter("enemy").gang_qi = 3
	assert_false(match_.try_defense("player", "tie_bi"), "对方回合无窗口")
	assert_true(match_.try_defense("enemy", "tie_bi"), "行动方有窗口")


func test_defense_window_on_claim_beat() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 1), _t("万", 4), _t("万", 7),
		_t("筒", 2), _t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6), _t("条", 9), _t("万", 8), _t("筒", 6)])
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 弃条5＋万3＋万5 开窗
	match_.fighter("enemy").gang_qi = 3
	assert_false(match_.try_defense("enemy", "tie_bi"), "截牌决定期无窗口（截牌＝摸牌环节，还没到打出）")
	match_.decide({"claim": {"type": "pon", "batch_index": 0}})
	assert_eq(String(match_.next_request()["phase"]), "posture", "截牌拍归截者打出")
	match_.fighter("enemy").gang_qi = 3
	assert_true(match_.try_defense("enemy", "tie_bi"), "截牌后的打出阶段＝窗口内")


# ---------- 截牌拍：截 1 ＋ 打出至上限（通常 1 张），不能发功 ----------

func test_claim_pon_discard_one_and_chain() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 1), _t("万", 2), _t("万", 4),
		_t("筒", 3), _t("筒", 6), _t("筒", 7), _t("条", 1), _t("条", 9), _t("万", 8), _t("筒", 5), _t("万", 6)])
	# 玩家已拍内摸 3：手 16 张（首三张为将弃的批次）
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 弃条5＋万3＋万5
	var claim_req := match_.next_request()
	var options: Array = claim_req["claim_options"]
	assert_eq(options.size(), 1, "只有条5可碰")
	match_.decide({"claim": {"type": "pon", "batch_index": 0}})
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.melds.size(), 1)
	assert_eq(String(enemy.melds[0]["symbol"]), "撼", "条重＝撼")
	assert_eq(enemy.gang_qi, 2, "碰 +2（占位）")
	assert_eq(match_.fighter("player").hp, 40 - 4, "明式基本招：撼伤 4")
	# 截牌拍：截者（敌方）立即打出至上限＝1 张，开窗给玩家
	var posture := match_.next_request()
	assert_eq(String(posture["side"]), "enemy", "截牌拍归截者")
	assert_eq(String(posture["phase"]), "posture")
	assert_eq(int(posture["discard_count"]), 1, "碰后恰好弃 1（麻将原生）")
	match_.decide({"discard_indexes": [0]})
	var window := match_.next_request()
	assert_eq(String(window["phase"]), "claim")
	assert_eq(String(window["side"]), "player", "截者的打出开窗给对方")
	match_.decide({"claim": null})
	assert_eq(match_.river.size(), 3, "批次余 2＋截者弃 1")
	var next := match_.next_request()
	assert_eq(String(next["side"]), "player", "流向对方")
	assert_eq(match_.fighter("enemy").gang_qi, 3, "碰+2 架势+1")


func test_claim_kan_rinshan_and_wildcard() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("筒", 2), _t("筒", 2), _t("筒", 2), _t("万", 1), _t("万", 2),
		_t("万", 4), _t("筒", 3), _t("筒", 6), _t("筒", 7), _t("条", 1), _t("条", 9), _t("万", 8), _t("筒", 5)])
	_set_hand("player", [_t("筒", 2), _t("万", 3), _t("万", 5), _t("万", 6), _t("万", 7),
		_t("条", 4), _t("条", 5), _t("条", 6), _t("筒", 8), _t("筒", 9), _t("万", 9), _t("条", 7), _t("条", 8),
		_t("条", 1), _t("条", 9), _t("万", 1)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 弃筒2＋...
	match_.decide({"claim": {"type": "kan", "batch_index": 0}})
	var enemy := match_.fighter("enemy")
	assert_eq(String(enemy.melds[0]["type"]), "KAN")
	assert_eq(enemy.hand.size(), 13 - 3 + 1, "岭上摸 1：11＝上限10＋待弃1")
	assert_eq(match_.fighter("player").hp, 40 - 4, "杠明式基本招（重式计）伤 4")
	# 截牌拍打出至上限＝1
	var posture := match_.next_request()
	assert_eq(int(posture["discard_count"]), 1)
	match_.decide({"discard_indexes": [0]})
	match_.decide({"claim": null})
	# 万能式（隔离验证）：筒杠可付筒轻/筒重，一杠只付一个
	var dummy := MJFighter.new()
	dummy.melds.append({"tiles": [_t("筒", 2), _t("筒", 2), _t("筒", 2), _t("筒", 2)], "type": "KAN", "suit": "筒", "symbol": ""})
	assert_false(match_._plan_recipe(dummy, {"刺": 1}).is_empty(), "KAN 本门万能式可付筒轻")
	assert_false(match_._plan_recipe(dummy, {"劈": 1}).is_empty(), "KAN 也可付筒重")
	assert_true(match_._plan_recipe(dummy, {"刺": 1, "劈": 1}).is_empty(), "一杠不能同时付两个符号")


# ---------- 功法＝打出：耗式不回填、每拍一门、超发回气 ----------

func test_fire_is_the_play_no_refill_rest_beat_follows() -> void:
	match_.start_battle()
	# 玩家手：万5×3＋万6×3（两个暗刻＝崩×2）＋散牌（16＝拍内摸后状态）
	_set_hand("player", [_t("万", 5), _t("万", 5), _t("万", 5), _t("万", 6), _t("万", 6),
		_t("万", 6), _t("筒", 1), _t("筒", 4), _t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8), _t("万", 9),
		_t("条", 3), _t("条", 6), _t("条", 9)])
	match_.decide({"fire": ["beng_shan"]})  # 发功＝打出：引擎在 decide 内直接收拍
	var player := match_.fighter("player")
	assert_eq(player.hand.size(), 10, "耗 6 不回填：16−6＝10（上限13−坑3）")
	assert_eq(match_.fighter("enemy").hp, 40 - 8, "两个暗崩基本招：4×2")
	assert_eq(match_.river.size(), 6, "耗式 6 张入气河")
	assert_eq(player.pending.size(), 1, "崩山式在途（延迟＝式数 2）")
	# 敌拍（拍2）→ 玩家拍摸后 13=上限 → 回气（拍3）：在途不解算
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(match_.fighter("enemy").hp, 40 - 8, "回气拍不解算在途（v3.3 暂定）")
	assert_true(match_.last_marker.begins_with("rest:player"))
	# 敌拍（拍4）→ 玩家可行动拍开头：在途自动结算，先于打出选择
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(match_.fighter("enemy").hp, 40 - 8 - 10, "可行动拍开头在途结算：崩山式伤 10")
	assert_eq(player.pending.size(), 0)
	var request := match_.next_request()
	assert_eq(String(request["side"]), "player")
	assert_eq((request["hand"] as Array).size(), 16, "回气补满后恢复正常拍")


func test_fire_once_per_beat() -> void:
	match_.start_battle()
	# 万5×3＋万6×3（崩×2）；筒5×3（劈）＋筒678（刺）——崩山式与断势斩皆可付
	_set_hand("player", [_t("万", 5), _t("万", 5), _t("万", 5), _t("万", 6), _t("万", 6),
		_t("万", 6), _t("筒", 5), _t("筒", 5), _t("筒", 5), _t("筒", 6), _t("筒", 7), _t("筒", 8), _t("万", 9),
		_t("条", 1), _t("条", 4), _t("条", 7)])
	var request := match_.next_request()
	var usable_ids: Array[String] = []
	for tech in request["techniques"]:
		if String(tech["kind"]) == "attack" and bool(tech["can_use"]):
			usable_ids.append(String(tech["id"]))
	assert_eq(usable_ids.size(), 2)
	match_.decide({"fire": [usable_ids[0], usable_ids[1]]})
	assert_eq(match_.fighter("player").pending.size(), 1, "每拍至多一门：清单只取第一发")


# ---------- 断势：击碎对方在途 ----------

func test_duan_shi_breaks_enemy_pending() -> void:
	match_.start_battle()
	# 玩家 16 张（拍内摸后）：筒5×3（劈）＋筒678（刺）＋散牌
	_set_hand("player", [_t("筒", 5), _t("筒", 5), _t("筒", 5), _t("筒", 6), _t("筒", 7),
		_t("筒", 8), _t("筒", 9), _t("条", 1), _t("条", 4), _t("条", 6), _t("条", 7), _t("万", 1), _t("万", 2),
		_t("万", 3), _t("万", 4), _t("万", 5)])
	# 敌方在途崩山式＋手牌压 7（敌拍恒回气 ×2 → 其在途只能被断，不会自行结算）
	_set_hand("enemy", [_t("万", 1), _t("万", 4), _t("万", 7), _t("筒", 2), _t("筒", 5),
		_t("筒", 8), _t("条", 3)])
	match_.fighter("enemy").pending.append({"tech_id": "beng_shan"})
	match_.decide({"fire": ["duan_shi_zhan"]})
	# 引擎内自动链：拍1 收拍 → 敌回气(拍2) → 玩家回气(拍3) → 敌回气(拍4) →
	# 玩家可行动拍开头在途结算：伤 4＋断势清敌在途 → free_fire
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.pending.size(), 0, "断势：敌方在途被击碎（崩山式永不结算）")
	assert_eq(enemy.hp, 40 - 4 - 2 - 4, "暗式基本招劈4＋刺2，断势斩在途结算伤 4")
	assert_eq(match_.fighter("player").hp, 40, "敌方被断的崩山式未造成伤害")
	assert_eq(String(match_.next_request()["side"]), "player")


# ---------- 交互轮：碰杠并列、付法变体、牌河分敌我 ----------

func test_claim_options_list_pon_and_kan() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("条", 5), _t("万", 1), _t("万", 4), _t("万", 7),
		_t("筒", 2), _t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6), _t("条", 9), _t("万", 8)])
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 弃条5＋万3＋万5 开窗
	var claim_req := match_.next_request()
	var types: Array[String] = []
	for option in claim_req["claim_options"]:
		types.append(String(option["type"]))
	assert_true(types.has("pon") and types.has("kan"), "手里三张：碰/杠并列可选（杠占推荐位）")
	match_.decide({"claim": {"type": "pon", "batch_index": 0}})
	assert_eq(String(match_.fighter("enemy").melds[0]["type"]), "PON", "选碰成碰（不被杠绑架）")


func test_fire_variant_picks_displayed_plan() -> void:
	match_.start_battle()
	# 三个万刻（万4/万5/万6）——崩山式（崩×2）付法 ≥3 种：04+05／04+06／05+06
	_set_hand("player", [_t("万", 4), _t("万", 4), _t("万", 4), _t("万", 5), _t("万", 5),
		_t("万", 5), _t("万", 6), _t("万", 6), _t("万", 6), _t("筒", 1), _t("筒", 4), _t("筒", 7),
		_t("条", 2), _t("条", 5), _t("条", 8), _t("条", 9)])
	var request := match_.next_request()
	var plans: Array = []
	for tech in request["techniques"]:
		if String(tech["id"]) == "beng_shan":
			plans = tech["plans"]
	assert_true(plans.size() >= 3, "三刻选二：付法 ≥3 种（枚举顺序确定性）")
	# 变体 2＝吃 万5＋万6，万4 刻完整保留（UI 展示哪组、引擎就吃哪组）
	match_.decide({"fire": ["beng_shan"], "fire_variant": 2})
	var kept_wan4 := 0
	for t in match_.fighter("player").hand:
		if (t as MJTile).same(_t("万", 4)):
			kept_wan4 += 1
	assert_eq(kept_wan4, 3, "变体 2 不动万4 刻（付法清单与执行一致）")


func test_river_records_origin_side() -> void:
	match_.start_battle()
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})  # 敌方放行 → 3 张入河
	for i in range(3):
		assert_eq(match_.river.side_at(i), "player", "我打出的牌记来源")
	match_.decide({"fire": []})  # 敌方拍
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	for i in range(3, 6):
		assert_eq(match_.river.side_at(i), "enemy", "对方打出的牌记来源")


# ---------- 暗杠（2026-09-16 用户拍板：手里四张自晒） ----------

func test_ankan_meld_rinshan_and_basic() -> void:
	match_.start_battle()
	_set_hand("player", [_t("万", 5), _t("万", 5), _t("万", 5), _t("万", 5), _t("筒", 1), _t("筒", 4),
		_t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8), _t("万", 9), _t("筒", 3), _t("筒", 6),
		_t("条", 9), _t("万", 2), _t("万", 7)])
	var wall_before := match_.wall.live_left()
	var request := match_.next_request()
	assert_eq((request["ankan_options"] as Array).size(), 1, "手里万5×4 → 暗杠选项浮现")
	assert_eq(String((request["ankan_options"] as Array)[0]["key"]), "万5")
	match_.decide({"ankan": "万5", "fire": []})
	var p := match_.fighter("player")
	assert_eq(String(p.melds[0]["type"]), "KAN", "四张入副露＝本门万能式")
	assert_eq(p.hand.size(), 16 - 4 + 1, "岭上摸 1：手 13")
	assert_eq(match_.wall.live_left(), wall_before - 1, "岭上消耗一张墙牌")
	assert_eq(p.gang_qi, 2, "暗杠 罡气+2（占位）")
	assert_eq(match_.fighter("enemy").hp, 40 - 4, "重式基本招随暗杠触发")
	assert_eq(p.hand.size() + 3 * p.melds.size(), 16, "静息不变量：13＋3×1＝16（拍内）")
	assert_eq(String(match_.next_request()["phase"]), "posture", "暗杠后照常打出（13＞上限10 弃3）")
	assert_false(match_._plan_recipe(p, {"崩": 1}).is_empty(), "暗杠成的万能式可付本门重式")


func test_ankan_out_of_window_rejected() -> void:
	match_.start_battle()
	match_.decide({"fire": []})
	# 架势阶段（posture）与对方回合都不是暗杠窗口
	assert_false(match_.try_ankan("player", "万5"), "架势阶段不可暗杠")
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_false(match_.try_ankan("player", "万5"), "对方回合不可暗杠")


# ---------- 一次按钮多截（2026-09-16 用户定案："弹窗默认全选，点碰一次执行"） ----------

func test_multi_claim_one_button() -> void:
	match_.start_battle()
	# 敌方手里 条5×2＋万3×3：一批弃 [条5, 万3, 万5]——claim_indexes 一次两截：碰条5＋杠万3
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 3), _t("万", 3), _t("万", 3), _t("万", 1),
		_t("万", 4), _t("万", 7), _t("筒", 2), _t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6)])
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 弃 条5＋万3＋万5 开窗
	match_.decide({"claim_indexes": [0, 1]})  # 一次按钮：两个批位一起截
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.melds.size(), 2, "一次应答两截")
	var types := {}
	for meld in enemy.melds:
		types[String(meld["type"])] = true
	assert_true(types.has("PON") and types.has("KAN"), "条5×2→碰；万3×3→自动按杠（无需指定）")
	assert_eq(enemy.gang_qi, 4, "每截 +2")
	assert_eq(match_.fighter("player").hp, 40 - 4 - 4, "两发重式基本招（撼＋崩）")
	assert_eq(match_.river.size(), 1, "余牌 万5 入河")
	# 账目：手 13−2−3＋岭上1＝9，两副露 → 上限 7，弃 2
	var posture_req := match_.next_request()
	assert_eq(String(posture_req["phase"]), "posture", "截后截者接续打出")
	assert_eq(int(posture_req["discard_count"]), 2, "账目：手 9＋坑 6，超 2 弃 2")


func test_claim_pass_still_ends_window() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 1), _t("万", 4), _t("万", 7),
		_t("筒", 2), _t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6), _t("条", 9), _t("万", 8)])
	_set_hand("player", [_t("条", 5), _t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [3, 4, 5]})  # 弃 万5＋万7＋筒4（留住条5对）→ 敌方无对子
	match_.decide({"claim": null})  # 敌方放行 → 敌方拍
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 敌方弃 条5＋万3＋万5 → 玩家能碰 条5
	var claim_req := match_.next_request()
	assert_eq(String(claim_req["side"]), "player")
	assert_true((claim_req["claim_options"] as Array).size() >= 1, "玩家有碰的选项")
	match_.decide({"claim": null})  # 但选放行
	assert_eq(match_.fighter("player").melds.size(), 0, "放行＝整批关闭（第一次放行即死不变）")
	assert_eq(match_.river.size(), 6, "双方各弃 3 全入河")


# ---------- 罡气上限与胜负 ----------

func test_gang_qi_cap() -> void:
	var f := MJFighter.new()
	f.add_gang_qi(10)
	assert_eq(f.gang_qi, 6)


func test_win_on_hp_zero() -> void:
	match_.start_battle()
	match_.fighter("enemy").hp = 3
	match_._deal_damage("player", 10, "测试")
	assert_eq(match_.state, "over")
	assert_eq(match_.winner, "player")


# ---------- 气河循环 ----------

func test_draw_recycles_river_when_dry() -> void:
	match_.start_battle()
	match_.river.add([_t("万", 1), _t("筒", 2), _t("条", 3), _t("条", 4), _t("条", 5)])
	match_.wall.live.clear()
	var drawn := match_._draw_with_recycle(3)
	assert_eq(drawn.size(), 3, "干涸→气河洗回后照摸")
	assert_true(match_.wall.live_left() >= 2)


# ---------- 破绽：跳过一拍 ----------

func test_flaw_skips_turn() -> void:
	match_.fighter("player").flawed = true
	match_.start_battle()
	var request := match_.next_request()
	assert_eq(String(request["side"]), "enemy", "破绽：玩家错失一拍，首请求直接归敌方")
	assert_eq(match_.fighter("player").hand.size(), 13, "破绽拍不摸牌")
	assert_false(match_.fighter("player").flawed, "破绽消耗不叠加")
	assert_true(match_.last_marker.begins_with("flaw:player"), "破绽拍留演出标记")
