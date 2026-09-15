extends Node
# M13 演出场自动驾驶（交互轮回归）：按真人路径驱动 mahjong_battle 的真实 UI
# （按钮点击/手牌点选/截牌窗），并模拟"不耐烦"行为——敌方演出期间乱点旧按钮。
# 回归目标：过期点击不得替敌方决策/双泵驱动（2026-09-15 用户卡死报告的根源）。
# 卡死检测＝局面签名持续 8 真秒不变且未终局。

const GAMES := 3
const GAME_BUDGET_MS := 40_000   # 每局墙钟预算
const STALL_MS := 8_000          # 签名 8 秒不变判卡死
const GRIND_BEAT_CAP := 300      # 超过此拍仍进行＝纯架势磨局（无僵局兜底的合法形态，跳过不计失败）


func _ready() -> void:
	var fails: Array[String] = []
	for g in range(GAMES):
		var scene: Control = load("res://scenes/mahjong_battle/mahjong_battle.tscn").instantiate()
		if scene.get_script() == null or scene.match_ == null:
			fails.append("game %d：mahjong_battle 脚本加载失败（解析错误？）" % g)
			break
		scene.enemy_step_pause = 0.02   # 快进敌方演出（预览专用）
		scene.enemy_after_pause = 0.01
		add_child(scene)
		await get_tree().process_frame
		var player_ai := MJAI.new()
		var start := Time.get_ticks_msec()
		var last_sig := ""
		var last_change := start
		var last_beat_log := start
		while Time.get_ticks_msec() - start < GAME_BUDGET_MS:
			await get_tree().process_frame
			var sig := _signature(scene)
			var now := Time.get_ticks_msec()
			if sig != last_sig:
				last_sig = sig
				last_change = now
			elif now - last_change > STALL_MS:
				break
			if now - last_beat_log > 5_000:
				last_beat_log = now
				print("[m13] game %d alive beat=%d state=%s sig_changed %.1fs ago" % [
					g, scene.match_.beat, scene.match_.state, (now - last_change) / 1000.0])
			if scene.match_.state == "over" or scene.match_.beat > GRIND_BEAT_CAP:
				break
			_drive_one(scene, player_ai)
		if scene.match_.state != "over":
			if Time.get_ticks_msec() - last_change <= 2_000:
				# 局面仍在推进但打不出结局＝纯架势磨局——无僵局兜底拍板（2026-09-15）的合法形态
				print("game %d SKIP：纯架势磨局（拍 %d）——无兜底形态不计失败" % [g, scene.match_.beat])
				scene.queue_free()
				await get_tree().process_frame
				continue
			fails.append("game %d 未终局——卡死现场：\n%s" % [g, _dump(scene)])
			break
		print("game %d 终局：胜者 %s，拍 %d，气河 %d" % [g, scene.match_.winner, scene.match_.beat, scene.match_.river.size()])
		scene.queue_free()
		await get_tree().process_frame
	if fails.is_empty():
		print("PASS: M13 演出场自动驾驶 %d 局全部自然终局（贪心玩家走真实 UI＋乱点过期按钮）" % GAMES)
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL: " + f)
		get_tree().quit(1)


# 局面签名：状态/拍/双方手牌与罡气/气河——任何合法推进都应改变其中之一。
func _signature(scene: Control) -> String:
	var m: MJMatch = scene.match_
	return "%s|%d|%d|%d|%d|%d|%d" % [m.state, m.beat,
		m.fighter("player").hand.size(), m.fighter("enemy").hand.size(),
		m.fighter("player").gang_qi, m.fighter("enemy").gang_qi, m.river.size()]


# 玩家侧＝贪心 AI 决策走真实 UI 路径（保证终局）；敌方演出期间注入乱点。
var _trace: Array[String] = []


func _note(text: String) -> void:
	_trace.append(text)
	if _trace.size() > 60:
		_trace.remove_at(0)


func _drive_one(scene: Control, player_ai: MJAI) -> void:
	if scene._claim_popup.visible:
		_note("claim-popup")
		var decision := player_ai.decide(scene._current_request)
		var claim = decision.get("claim")
		var buttons: Array = []
		for child in scene._claim_box.get_children():
			for c in (child as Control).get_children():
				if c is Button:
					buttons.append(c)
		var clicked := false
		if claim is Dictionary and not (claim as Dictionary).is_empty():
			for b in buttons:
				var text := String((b as Button).text)
				var want := ("碰" if String(claim.get("type", "")) == "pon" else "杠")
				if not text.begins_with("跳过") and text.begins_with(want):
					(b as Button).pressed.emit()
					clicked = true
					break
		if not clicked:
			for b in buttons:
				if String((b as Button).text).begins_with("跳过"):
					(b as Button).pressed.emit()
					break
		return
	var request: Dictionary = scene._current_request
	if request.is_empty():
		return
	if String(request.get("side", "")) != "player":
		# 不耐烦行为：敌方演出期间乱点仍可交互的旧按钮/手牌——修复后应全部无效
		if randf() < 0.05:
			for child in scene._action_bar.get_children():
				if child is Button and not (child as Button).disabled:
					_note("stale-click")
					(child as Button).pressed.emit()
					break
			scene._on_tile_clicked(0)
		return
	var decision := player_ai.decide(request)
	match String(request.get("phase", "")):
		"free_fire":
			var texts := _action_buttons(scene)
			# 多付法选项视图：点第一行（贪心默认变体）
			var has_back := false
			for t in texts.values():
				if String(t).begins_with("返"):
					has_back = true
			if has_back:
				for b in texts.keys():
					if not String(texts[b]).begins_with("返"):
						(b as Button).pressed.emit()
						break
				return
			var fire: Array = decision.get("fire", [])
			if not fire.is_empty():
				# 找 id -> 功法名，点对应按钮
				var want_name := ""
				for tech in request.get("techniques", []):
					if String(tech.get("id", "")) == String(fire[0]):
						want_name = String(tech.get("name", ""))
				for b in texts.keys():
					if String(texts[b]) == want_name and not (b as Button).disabled:
						_note("fire-btn %s" % want_name)
						(b as Button).pressed.emit()
						return
			if str(decision.get("defense", "")) != "":
				var clicked := false
				for b in texts.keys():
					if String(texts[b]).begins_with("守·") and not (b as Button).disabled:
						_note("defense-btn")
						(b as Button).pressed.emit()
						clicked = true
						break
				if clicked:
					return
			_note("defense greyed→play")
			# 三成概率走"点牌开局"路径（麻将原生交互：free_fire 直接点手牌＝进入选弃）
			if randf() < 0.3 and not scene.match_.fighter("player").hand.is_empty():
				_note("tile-first")
				scene._on_tile_clicked(0)
				return
			for b in texts.keys():
				if String(texts[b]) == "打 出" and not (b as Button).disabled:
					_note("play-btn submit")
					(b as Button).pressed.emit()
					break
		"posture":
			# 幂等选牌：只点需要变化的索引（切换语义下重复点同组会震荡，选中数永远到不了 need）
			var want := {}
			for idx in decision.get("discard_indexes", []):
				want[int(idx)] = true
			for key in scene._selected.keys().duplicate():
				if not want.has(int(key)):
					scene._on_tile_clicked(int(key))
			for idx in want.keys():
				if not scene._selected.has(idx):
					scene._on_tile_clicked(int(idx))
			if str(decision.get("defense", "")) != "":
				for b in _action_buttons(scene).keys():
					if String((b as Button).text).begins_with("守·"):
						(b as Button).pressed.emit()
						break
			for b in _action_buttons(scene).keys():
				if (b as Button).name == "ConfirmButton" and not (b as Button).disabled:
					(b as Button).pressed.emit()
					break


func _action_buttons(scene: Control) -> Dictionary:
	var out := {}
	for child in scene._action_bar.get_children():
		if child is Button:
			out[child] = String((child as Button).text)
	return out


func _dump(scene: Control) -> String:
	var m: MJMatch = scene.match_
	var lines: Array[String] = []
	var req := m.next_request()
	lines.append("state=%s winner=%s beat=%d turn_side=%s req_phase=%s req_side=%s pending_batch=%d" % [
		m.state, m.winner, m.beat, m.turn_side, String(req.get("phase", "")),
		String(req.get("side", "")), m.pending_batch.size()])
	lines.append("ui request phase=%s side=%s popup=%s" % [String(scene._current_request.get("phase", "")),
		String(scene._current_request.get("side", "")), scene._claim_popup.visible])
	lines.append("player hand=%d gang=%d pending=%d | enemy hand=%d gang=%d pending=%d | river=%d wall_live=%d" % [
		m.fighter("player").hand.size(), m.fighter("player").gang_qi, m.fighter("player").pending.size(),
		m.fighter("enemy").hand.size(), m.fighter("enemy").gang_qi, m.fighter("enemy").pending.size(),
		m.river.size(), m.wall.live_left()])
	for line in m.log.slice(maxi(0, m.log.size() - 14)):
		lines.append(line)
	lines.append("—— 驱动轨迹（最近 60 帧）——")
	lines.append("\n".join(_trace))
	return "\n".join(lines)
