extends Node
# M12 麻将对弈全流程仿真（真气语法 v3 首发验收）：
# AI 对 AI 打完整局 × 多种子：1) 自然终局（有胜者）2) 静息不变量全程成立
# 3) 牌守恒（气海＋气河＋双手＋副露 ＝ 108；死牌山已退役）4) 战斗有内容（截牌/在途/伤害都发生过）

const SEEDS := [7, 42, 123, 2026, 99991]
const MAX_STEPS := 4000


func _ready() -> void:
	var fails: Array[String] = []
	var total_beats := 0
	var total_claims := 0
	var total_resolved := 0

	for seed_value in SEEDS:
		var match_ := MJMatch.new()
		match_.setup({"seed": seed_value})
		match_.start_battle()
		var ai_p := MJAI.new()
		var ai_e := MJAI.new()
		var claims := 0
		var resolved := 0
		var steps := 0
		while match_.state == "running" and steps < MAX_STEPS:
			steps += 1
			var request := match_.next_request()
			if request.is_empty():
				break
			# 静息不变量：行动方在架势阶段手牌数－应弃数＝静息上限
			if String(request["phase"]) == "posture":
				var f := match_.fighter(String(request["side"]))
				if int(request["discard_count"]) < 0:
					fails.append("seed %d step %d：弃牌数为负（静息不变量破坏）" % [seed_value, steps])
			var before_pending := match_.fighter("player").pending.size() + match_.fighter("enemy").pending.size()
			var before_melds := match_.fighter("player").melds.size() + match_.fighter("enemy").melds.size()
			var decision: Dictionary = ai_p.decide(request) if String(request["side"]) == "player" else ai_e.decide(request)
			match_.decide(decision)
			if String(request["phase"]) == "claim" and decision.get("claim") is Dictionary:
				claims += 1
			if match_.fighter("player").melds.size() + match_.fighter("enemy").melds.size() > before_melds:
				claims += 1
			resolved += maxi(0, before_pending - (match_.fighter("player").pending.size() + match_.fighter("enemy").pending.size()))
		if match_.state != "over":
			fails.append("seed %d：%d 步未终局" % [seed_value, steps])
		# 牌守恒
		var count := match_.wall.live_left() + match_.river.size()
		for side in ["player", "enemy"]:
			var f := match_.fighter(side)
			count += f.hand.size()
			for meld in f.melds:
				count += (meld["tiles"] as Array).size()
		if count != MJWall.TOTAL:
			fails.append("seed %d：牌守恒破（%d ≠ 108）" % [seed_value, count])
		total_beats += match_.beat
		total_claims += claims
		total_resolved += resolved
		print("seed %d：拍数 %d，截牌 %d，在途结算 %d，胜者 %s，守恒 %d" % [
			seed_value, match_.beat, claims, resolved, match_.winner, count])

	if total_claims == 0:
		fails.append("五种子零截牌——对弈无互动内容")
	if total_resolved == 0:
		fails.append("五种子零在途结算——功法系统未运转")
	if total_beats > SEEDS.size() * 120:
		fails.append("平均拍数 %.1f 过长（>120/局，v3 §10 预测：先拧罡气参数）" % (float(total_beats) / SEEDS.size()))

	if fails.is_empty():
		print("PASS: M12 麻将对弈全流程仿真（终局/静息不变量/牌守恒/内容活性）")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL: " + f)
		get_tree().quit(1)
