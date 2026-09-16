class_name MJAI
extends RefCounted

# 敌方 AI（真气语法 v3 §6 提案态：贪心启发式，无搜索）——我地麻 GreedyConfig 同构。
# 人格＝一份权重配置（全占位）：逐门权重、招架倾向、功法线（留牌贴配方）、防御血线。
# 决策全确定性（无随机）：同状态同决策，配合对局种子可复盘。
#
# 策略四则（v3.6 语境）：
# 1. posture：按"留牌价值"弃最差——价值＝搭子进度（对子→碰线、邻张→顺线）×门权重＋功法线需求加成
#    （打出张数＝max(1, 超额)：无超额时也弃 1 张＝虚招，AI 无感知差异）
# 2. claim（招架）：能截的批位全要（一次按钮多截；吃/碰/杠同族——选项由引擎给出，AI 贪心必截）
# 3. free_fire：配方可付→重击（倍率大者优先，一拍一门）
# 4. 护体：血线低于阈值且对方在途威胁大（倍率%）且罡气够 → 附带 defense（在途锁防御由引擎闸）
# 变招：暂不使用（AI 保持简单；机会自然累积不用不亏）。


# —— GreedyConfig（占位数值）——
var suit_weights: Dictionary = {"万": 1.0, "筒": 1.0, "条": 1.0}  # 留牌门倾向（架势弃牌用）
var defense_hp_ratio := 0.35   # 血线：hp/max_hp 低于此值考虑护体
var charge_threat_power := 150 # 对方在途倍率（%）超过此值视为大威胁


func decide(request: Dictionary) -> Dictionary:
	match String(request.get("phase", "")):
		"free_fire":
			var decision := _decide_fire(request)
			# 护体＝附属行为阶段免费即时：血线低＋对方在途威胁大＋罡气够 → 附带护体
			var defense := _defense_wanted(request)
			if defense != "":
				decision["defense"] = defense
			return decision
		"posture":
			var posture := _decide_posture(request)
			# 打出确认前也是行动窗口：血线低时同样附带护体
			var posture_defense := _defense_wanted(request)
			if posture_defense != "":
				posture["defense"] = posture_defense
			return posture
		"claim":
			return _decide_claim(request)
	return {}


# —— 护体判定：血线低＋对方在途威胁大＋罡气够 ——
func _defense_wanted(request: Dictionary) -> String:
	var hp := int(request.get("hp", 1))
	var max_hp := maxi(int(request.get("max_hp", 100)), 1)
	if float(hp) / float(max_hp) > defense_hp_ratio:
		return ""
	var threat := 0
	for charge in request.get("opp_pending", []):
		threat = maxi(threat, int(charge.get("power", 0)))
	if threat < charge_threat_power:
		return ""
	var gang_qi := int(request.get("gang_qi", 0))
	for tech in request.get("techniques", []):
		if String(tech.get("kind", "")) == "defense" and bool(tech.get("can_use", false)) \
				and gang_qi >= int(tech.get("gang_qi_cost", 99)):
			return String(tech["id"])
	return ""


# —— 重击：能暗杠先暗杠（万能式经济）；否则可付即发，倍率大者优先（直读 power%） ——
func _decide_fire(request: Dictionary) -> Dictionary:
	# 暗杠＝免费动作（四张自晒成万能式＋岭上＋罡气）：贪心必吃
	for option in request.get("ankan_options", []):
		return {"fire": [], "ankan": String(option["key"])}
	var fire: Array[String] = []
	# 一次决策只发一发（引擎会再次询问，形成"连发-收手"循环）
	var best_id := ""
	var best_power := -1
	for tech in request.get("techniques", []):
		if String(tech.get("kind", "")) == "attack" and bool(tech.get("can_use", false)):
			var power := int(tech.get("power", 0))
			if power > best_power:
				best_power = power
				best_id = String(tech["id"])
	if best_id != "":
		fire.append(best_id)
	return {"fire": fire}


# —— 打出弃牌：留价值高的，弃价值低的 ——
func _decide_posture(request: Dictionary) -> Dictionary:
	var hand: Array = request.get("hand", [])
	var discard_count := int(request.get("discard_count", 0))
	if discard_count <= 0:
		return {"discard_indexes": []}
	var focus := _focus_suit(request)
	var scores: Array[Dictionary] = []
	for i in range(hand.size()):
		scores.append({"index": i, "score": _tile_score(hand, i, focus)})
	scores.sort_custom(func(a, b) -> bool: return float(a["score"]) > float(b["score"]))
	var keep := scores.slice(0, hand.size() - discard_count)
	var discard: Array[int] = []
	for entry in scores:
		if not keep.has(entry):
			discard.append(int(entry["index"]))
	return {"discard_indexes": discard}


# 功法线聚焦门（留牌贴配方，v3 §6：贪心启发式的第一条）：取倍率最高的攻功法配方首符号的门。
func _focus_suit(request: Dictionary) -> String:
	var best_power := -1
	var best_suit := ""
	for tech in request.get("techniques", []):
		if String(tech.get("kind", "")) != "attack":
			continue
		var power := int(tech.get("power", 0))
		if power > best_power:
			var recipe: Dictionary = tech.get("recipe", {})
			if recipe.is_empty():
				continue
			best_power = power
			best_suit = MJShiki.suit_of(String(recipe.keys()[0]))
	return best_suit


# 单张留牌价值：对子进度（碰线）＋邻张进度（顺线）＋门权重（聚焦门加倍）。
func _tile_score(hand: Array, index: int, focus_suit: String = "") -> float:
	var self_tile := hand[index] as MJTile
	var same := 0
	var neighbors := 0
	for i in range(hand.size()):
		if i == index:
			continue
		var t := hand[i] as MJTile
		if t.same(self_tile):
			same += 1
		elif t.suit == self_tile.suit and absi(t.value - self_tile.value) <= 2:
			neighbors += 1
	var suit_w := float(suit_weights.get(self_tile.suit, 1.0))
	if self_tile.suit == focus_suit and focus_suit != "":
		suit_w *= 2.0  # 贴功法线：聚焦门留牌加倍
	# 对子→刻线权重高（招架全是重式经济）；邻张→顺线次之；孤张靠门权重兜底
	var score := (same * 3.0 + neighbors * 1.0) * suit_w
	return score


# —— 招架（一次按钮多截）：能截的批位全要（贪心——副露光环＋取消对方普攻双重收益）；无→放行 ——
func _decide_claim(request: Dictionary) -> Dictionary:
	var options: Array = request.get("claim_options", [])
	var indexes: Array[int] = []
	for option in options:
		var bi := int(option.get("batch_index", -1))
		if bi >= 0 and not indexes.has(bi):
			indexes.append(bi)
	if indexes.is_empty():
		return {"claim": null}
	return {"claim_indexes": indexes}
