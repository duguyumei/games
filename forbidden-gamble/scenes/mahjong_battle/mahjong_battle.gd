extends Control

## 麻将演武（真气语法 v3.6 拍结构的演出场：摸牌→自动效果→附属行为→打出恰一次）。
## 驱动 MJMatch 请求/应答状态机：玩家走 UI 按钮，敌方走 MJAI 贪心。
## 美术边界：**零提取商业资产**——占位牌面（代码绘制）＋同风格演出
## （截牌窗高亮、伤害弹字、拍幅横幅、tween 动效）；正式美术后补。

const SUIT_COLORS := {"万": Color(0.2, 0.47, 0.34), "筒": Color(0.66, 0.25, 0.22), "条": Color(0.5, 0.42, 0.2)}

var match_ := MJMatch.new()
var ai := MJAI.new()
var _current_request: Dictionary = {}
var _selected: Dictionary = {}  # 手牌索引 -> true（打出选弃；索引＝引擎手牌序，非显示序）
var _marker_seen := ""
var _bian_mode := false         # 变招·换一张：点手牌即换（弃 1 摸 1，机会-1）
var _auto_sort := true        # 自动理牌开关（我地麻 IsAutoSort 同位；暂存会话，持久化随设置面板轮）
# 敌方演出节奏（秒）——预览/自动驾驶会调小快进；玩家默认 0.6/0.35
var enemy_step_pause := 0.6
var enemy_after_pause := 0.35

var _enemy_header: HBoxContainer
var _enemy_hp_bar: ProgressBar
var _enemy_hp_label: Label
var _enemy_stats: Label
var _enemy_melds: HBoxContainer
var _enemy_pending: Label
var _wall_label: Label
var _river_enemy_row: HBoxContainer
var _river_player_row: HBoxContainer
var _player_melds: HBoxContainer
var _player_hand: HBoxContainer
var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _player_stats: Label
var _player_pending: Label
var _phase_hint: Label
var _action_bar: HBoxContainer
var _log_panel: RichTextLabel
var _claim_popup: PanelContainer
var _claim_box: VBoxContainer
var _banner: Label
var _overlay: PanelContainer
var _overlay_box: VBoxContainer
var _overlay_label: Label


func _ready() -> void:
	_build_ui()
	match_.setup({"seed": int(Time.get_unix_time_from_system()) % 100000})
	match_.start_battle()
	_pump()


# ———— 驱动循环 ————

func _pump() -> void:
	while true:
		_refresh()
		_dump_battle_state()
		if match_.state == "over":
			_show_result()
			return
		# 破绽拍横幅（回气拍已退役；marker 带拍号——连拍不吞演出）
		if match_.last_marker != _marker_seen:
			_marker_seen = match_.last_marker
			var marker_side := _marker_seen.split(":")[1] if _marker_seen.split(":").size() > 1 else ""
			if _marker_seen.begins_with("flaw:"):
				_banner_show("破绽 · %s 只自然摸牌" % ("你" if marker_side == "player" else "对方"))
		_current_request = match_.next_request()
		if _current_request.is_empty():
			_show_result()
			return
		if String(_current_request["side"]) == "enemy":
			_banner_show("对方回合")
			_set_buttons_enabled(false)  # 敌方演出期间禁用旧按钮：过期点击会替敌方提交决策＋双泵驱动（卡死根源）
			await get_tree().create_timer(enemy_step_pause).timeout
			var decision := ai.decide(_current_request)
			_flash_decision(decision)
			match_.decide(decision)
			await get_tree().create_timer(enemy_after_pause).timeout
		else:
			_banner_show("你的回合")
			_prepare_player_phase()
			return  # 等玩家操作；按钮回调里再调 _pump()


# ———— 玩家各阶段 UI ————

func _prepare_player_phase() -> void:
	_selected.clear()
	_bian_mode = false
	for child in _action_bar.get_children():
		child.queue_free()
	_set_buttons_enabled(true)
	_render_hand()  # 清选区后立即重绘——上一拍的选中残影不得照到新拍的手牌上
	var phase := String(_current_request["phase"])
	match phase:
		"free_fire":
			_phase_hint.text = "打出二选一：点手牌＝普攻（普通打出），或点功法按钮＝重击（耗式·前摇后落地）"
			_add_defense_button()
			_add_bian_button()
			# 暗杠按钮（特殊动作按需浮现，我地麻 AnGangButton 同位）：手里四张全同才出现
			for option in _current_request.get("ankan_options", []):
				var kan_key := String(option["key"])
				_add_action_button("暗杠·%s" % kan_key, func(): _submit({"ankan": kan_key}))
			# 功法按钮＝特殊动作按需浮现（我地麻主交互组同型）：可付才出现，名字＝功法名
			for tech in _current_request.get("techniques", []):
				if String(tech["kind"]) == "attack" and bool(tech["can_use"]):
					var tech_id := String(tech["id"])
					var b := _add_action_button(String(tech["name"]), func(): _on_tech_button(tech_id))
					b.tooltip_text = str(tech["summary"])
			var play := _add_action_button("打 出", func(): _submit({"fire": []}))
			play.custom_minimum_size = Vector2(190, 52)
		"posture":
			var need := int(_current_request.get("discard_count", 0))
			match String(_current_request.get("play_kind", "")):
				"counter":
					_phase_hint.text = "反击：招架后的打出（不可被截·绝对安全弃牌）——点选 %d 张" % need
				"xuzhao":
					_phase_hint.text = "虚招：手牌无超额——打出 1 张试探（0 伤，可被吃/碰/杠截走）"
				_:
					_phase_hint.text = "普攻：点选 %d 张打出（超几张打几张）——放行伤落地，被招架则取消" % need
			_add_defense_button()
			_add_bian_button()
			var confirm := _add_action_button("打 出", func(): _submit_posture())
			confirm.disabled = true
			confirm.name = "ConfirmButton"
			confirm.custom_minimum_size = Vector2(190, 52)
			if need == 0:
				confirm.disabled = false
		"claim":
			# 截牌窗（招架）只在真能碰/杠时弹（无选项静默放行）；弹出前默认全选可截项
			var options: Array = _current_request.get("claim_options", [])
			if options.is_empty():
				_submit({"claim": null})
			else:
				_prepare_claim_selection()
				_open_claim_popup()


# 功法按钮：一个付法直接发动；多个付法先列选项（哪几组牌供式）。
func _on_tech_button(tech_id: String) -> void:
	var plans: Array = []
	for tech in _current_request.get("techniques", []):
		if String(tech["id"]) == tech_id:
			plans = tech.get("plans", [])
			break
	if plans.size() <= 1:
		_submit({"fire": [tech_id]})
		return
	for child in _action_bar.get_children():
		child.queue_free()
	_phase_hint.text = "选择付法：点一行，用该组牌发动"
	for i in range(plans.size()):
		var plan: Dictionary = plans[i]
		var variant_index := i
		var b := _add_action_button(_plan_label(plan), func(): _submit({"fire": [tech_id], "fire_variant": variant_index}))
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_action_button("返 回", func(): _prepare_player_phase())


# 付法行文案：手牌实例 id 反查 key ＋ 耗明式数。
func _plan_label(plan: Dictionary) -> String:
	var by_id := {}
	for t in match_.fighter("player").hand:
		by_id[(t as MJTile).get_instance_id()] = t
	var keys: Array[String] = []
	for id in plan.get("ids", []):
		var t = by_id.get(int(id))
		if t != null:
			keys.append((t as MJTile).key())
	var label := "＋".join(keys) if not keys.is_empty() else "全用明式"
	if int(plan.get("melds", 0)) > 0:
		label += "（耗明式×%d）" % int(plan["melds"])
	return label


# 护体（护身槽·守功法）＝行动窗口内免费即时：自己摸牌后或招架后、打出前的两个阶段（free_fire/posture）
# 可放，直接结算不入应答流；按钮只在这两阶段出现，与引擎窗口闸一致。
# 点过之后立即同步按钮态（lambda 值捕获拿不到按钮自身，用 meta 标记统一刷）——
# 罡气是请求构建时的旧值，不刷新会静默失败打转（用户卡住报告的第二根源）。
func _add_defense_button() -> void:
	var iron: Dictionary = _current_request.get("iron", {})
	for tech in _current_request.get("techniques", []):
		if String(tech["kind"]) != "defense":
			continue
		var cost := int(tech.get("gang_qi_cost", 0))
		var tech_id := String(tech["id"])
		var b := _add_action_button("护体·%s" % str(tech["summary"]), func():
			if match_.try_defense("player", tech_id):
				_after_free_action()
			_sync_defense_buttons())
		b.set_meta("defense_cost", cost)
		b.disabled = not bool(tech["can_use"])
		if bool(iron.get("active", false)):
			b.text = "护体中·免伤%d%%（剩%d拍）" % [int(iron.get("reduction", 0)), int(iron.get("beats_left", 0))]
			b.disabled = true


func _sync_defense_buttons() -> void:
	var p := match_.fighter("player")
	for child in _action_bar.get_children():
		if child is Button and (child as Button).has_meta("defense_cost"):
			(child as Button).disabled = p.iron_active or p.gang_qi < int((child as Button).get_meta("defense_cost"))


# ———— 变招（v3.5 资源：窗口内免费操作，不占打出） ————
# 换一张：1 机会弃 1 摸 1；换面子组（手牌暗组/副露明组一视同仁）：3 机会、弃整组摸等量、每组 50% 伤害。
func _add_bian_button() -> void:
	var opps := int(_current_request.get("bian_opps", 0))
	if opps <= 0:
		return
	_add_action_button("变招（机会%d）" % opps, func(): _open_bian_options())


func _open_bian_options() -> void:
	for child in _action_bar.get_children():
		child.queue_free()
	var opps := int(_current_request.get("bian_opps", 0))
	var groups: Array = _current_request.get("bian_groups", [])
	_phase_hint.text = "变招：窗口内免费——换牌调手、换组回收死面子（不占打出）"
	if opps >= 1:
		_add_action_button("换一张（机会−1）", func():
			_bian_mode = true
			_phase_hint.text = "点一张手牌变招：弃掉换新（机会−1）")
	if opps >= 3:
		for gi in range(groups.size()):
			var g: Dictionary = groups[gi]
			var label := "换组·%s（机会−3·伤50%%）" % "＋".join(PackedStringArray(g.get("keys", [])))
			if String(g.get("kind", "")) == "meld":
				label = "换副露·%s" % label
			var meld_index := int(g.get("meld_index", -1))
			var hand_indexes: Array = g.get("indexes", [])
			_add_action_button(label, func():
				if match_.try_bian_group("player", meld_index, hand_indexes):
					_after_free_action())
	_add_action_button("返 回", func(): _prepare_player_phase())


# 窗口内免费操作（护体/变招）完成后的公共收尾：请求已过期，重取＋重建按钮＋刷新。
func _after_free_action() -> void:
	_current_request = match_.next_request()
	_prepare_player_phase()
	_refresh()


func _submit(decision: Dictionary) -> bool:
	# 过期应答闸：只在"当前请求归玩家"时受理——敌方演出期间点旧按钮＝替敌方决策＋双泵，一律忽略
	if String(_current_request.get("side", "")) != "player":
		return false
	_close_claim_popup()
	match_.decide(decision)
	_pump()
	return true


func _set_buttons_enabled(on: bool) -> void:
	for child in _action_bar.get_children():
		if child is Button:
			(child as Button).disabled = not on


func _submit_posture() -> void:
	var indexes: Array[int] = []
	for i in _selected.keys():
		indexes.append(int(i))
	_selected.clear()  # 提交即清：敌方回合的渲染不得带出本拍选中残影
	_submit({"discard_indexes": indexes})


# 手牌点选：麻将原生交互——想弃牌直接点牌（在"选打出"阶段点第一张＝自动走进打出选牌），
# 点足张数后按「打 出」确认；选中的再点一下取消。变招·换一张模式下点牌即换。
func _on_tile_clicked(index: int) -> void:
	if _bian_mode:
		if match_.try_bian_hand("player", index):
			_after_free_action()
		return
	var phase := String(_current_request.get("phase", ""))
	if phase == "free_fire":
		# 点牌＝选普攻打出：先推进到打出选牌阶段（fire 空应答＝不发动重击），手牌与索引不变
		if not _submit({"fire": []}):
			return
		phase = String(_current_request.get("phase", ""))
	if phase != "posture":
		return
	var need := int(_current_request.get("discard_count", 0))
	if _selected.has(index):
		_selected.erase(index)
	elif _selected.size() < need:
		_selected[index] = true
	_render_hand()
	var confirm := _action_bar.get_node_or_null("ConfirmButton") as Button
	if confirm != null:
		confirm.disabled = _selected.size() != need


# ———— 截牌窗弹层（一次按钮多截，2026-09-16 用户定案） ————
# 全批牌都显示：可截的默认全选（黄框＋碰/杠徽记），不可截的置灰；点牌改选；
# 「碰（N）」一次执行全部选中（手里≥3 的自动按杠），「跳过」整批放行（第一次放行即死）。
var _claim_selected := {}  # 批位索引 -> true


func _open_claim_popup() -> void:
	_close_claim_popup()
	var batch: Array = _current_request.get("batch", [])
	var options: Array = _current_request.get("claim_options", [])
	var kan_marks := {}
	var chi_marks := {}
	var claimable := {}
	for option in options:
		var bi := int(option["batch_index"])
		claimable[bi] = true
		if String(option["type"]) == "kan":
			kan_marks[bi] = true
		elif String(option["type"]) == "chi":
			chi_marks[bi] = true
	var is_xu := bool(_current_request.get("batch_is_xu", false))
	var title := Label.new()
	title.text = "招架（截牌窗）：碰/杠＝拆掉对方这一记普攻%s——点牌改选（默认全选），「截」一次执行，手里三张的自动按杠" % (
		"；虚招还能吃（顺子成轻式）" if is_xu else "")
	title.add_theme_font_size_override("font_size", 16)
	_claim_box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_claim_box.add_child(row)
	for i in range(batch.size()):
		var tile := batch[i] as MJTile
		var is_claimable: bool = claimable.has(i)
		var widget := _make_tile_widget(tile, 48, 66, not is_claimable)  # 不可截置灰
		if _claim_selected.has(i):
			widget = _glow(widget, Color(0.98, 0.85, 0.3))
			widget.position.y -= 6
			var badge := Label.new()
			badge.text = "杠" if kan_marks.has(i) else ("吃" if chi_marks.has(i) else "碰")
			badge.add_theme_font_size_override("font_size", 12)
			badge.add_theme_color_override("font_color", Color(0.98, 0.8, 0.25))
			badge.position = Vector2(widget.custom_minimum_size.x - 20, 0)
			widget.add_child(badge)
		var index := i
		widget.gui_input.connect(func(event: InputEvent):
			if is_claimable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_toggle_claim_select(index))
		row.add_child(widget)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_claim_box.add_child(buttons)
	var confirm := Button.new()
	confirm.name = "ClaimConfirm"
	confirm.text = "截（%d）" % _claim_selected.size()
	confirm.custom_minimum_size = Vector2(150, 48)
	confirm.disabled = _claim_selected.is_empty()
	confirm.pressed.connect(func(): _submit({"claim_indexes": _claim_selected.keys()}))
	buttons.add_child(confirm)
	var skip := Button.new()
	skip.text = "跳过（整批放行）"
	skip.custom_minimum_size = Vector2(150, 48)
	skip.pressed.connect(func(): _submit({"claim": null}))
	buttons.add_child(skip)
	_claim_popup.visible = true


func _toggle_claim_select(index: int) -> void:
	if _claim_selected.has(index):
		_claim_selected.erase(index)
	else:
		_claim_selected[index] = true
	_open_claim_popup()  # 重建弹窗反映选择态（含按钮计数）


# 进入截牌窗前设置默认全选（可截项）。
func _prepare_claim_selection() -> void:
	_claim_selected.clear()
	var options: Array = _current_request.get("claim_options", [])
	var seen := {}
	for option in options:
		var bi := int(option["batch_index"])
		if not seen.has(bi):
			seen[bi] = true
			_claim_selected[bi] = true


func _close_claim_popup() -> void:
	_claim_popup.visible = false
	for child in _claim_box.get_children():
		child.queue_free()


# ———— 刷新 ————

func _refresh() -> void:
	var p := match_.fighter("player")
	var e := match_.fighter("enemy")
	_enemy_hp_bar.max_value = e.max_hp_display()
	_enemy_hp_bar.value = mini(e.hp_display(), e.max_hp_display())
	_enemy_hp_label.text = "%d / %d" % [e.hp_display(), e.max_hp_display()]
	_enemy_stats.text = "罡气 %d｜变招 %d｜护体 %s｜攻 %d｜承伤 %d%%｜手牌 %d" % [
		e.gang_qi, e.bian_opps, _iron_text(e), e.attack_panel(), e.damage_taken_ratio() / 10, e.hand.size()]
	_enemy_pending.text = _pending_text(e)
	_render_melds(_enemy_melds, e)
	_player_hp_bar.max_value = p.max_hp_display()
	_player_hp_bar.value = mini(p.hp_display(), p.max_hp_display())
	_player_hp_label.text = "%d / %d" % [p.hp_display(), p.max_hp_display()]
	_player_stats.text = "罡气 %d｜变招 %d（充%d）｜护体 %s｜攻 %d｜承伤 %d%%" % [
		p.gang_qi, p.bian_opps, p.bian_charge, _iron_text(p), p.attack_panel(), p.damage_taken_ratio() / 10]
	_player_pending.text = _pending_text(p)
	_render_melds(_player_melds, p)
	_render_hand()
	_wall_label.text = "气海 %d ｜ 气河 %d" % [match_.wall.live_left(), match_.river.size()]
	_render_river()
	_render_log()


func _iron_text(f: MJFighter) -> String:
	if not f.iron_active:
		return "—"
	return "%d%%·%d拍" % [f.iron_reduction, f.iron_beats_left]


func _pending_text(f: MJFighter) -> String:
	if f.pending.is_empty():
		return "在途：—"
	var parts: Array[String] = []
	for c in f.pending:
		var tech: MJTechnique = match_.techniques[f.side].get(String(c["tech_id"]))
		parts.append("%s（剩%d拍·%d%%）" % [tech.display_name if tech != null else "?",
			maxi(int(c.get("windup", 1)) - int(c.get("elapsed", 0)), 0), tech.power if tech != null else 0])
	return "在途：" + "、".join(parts)


func _render_hand() -> void:
	for child in _player_hand.get_children():
		child.queue_free()
	# 手牌常显（对方回合也看得到自己的丹田）；点选交互由 _on_tile_clicked 按阶段门控
	var hand: Array = match_.fighter("player").hand
	for entry in _display_order(hand):
		var index := int(entry["i"])
		var widget := _make_tile_widget(entry["t"] as MJTile, 46, 64)
		if _selected.has(index):
			widget = _glow(widget, Color(0.98, 0.85, 0.3))
			widget.position.y -= 8
		widget.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_tile_clicked(index))
		_player_hand.add_child(widget)


# 显示序（自动理牌开时）：全部手牌按属性序＋数值升序（用户裁定：摸到的牌也参与排序）。
# 返回 [{i: 引擎手牌索引, t: MJTile}]——点选回传引擎索引，弃牌应答不因显示排序错位。
func _display_order(hand: Array) -> Array:
	var entries: Array = []
	for i in range(hand.size()):
		entries.append({"i": i, "t": hand[i]})
	if _auto_sort:
		entries.sort_custom(func(a, b) -> bool:
			var ta := a["t"] as MJTile
			var tb := b["t"] as MJTile
			var sa := MJTile.SUITS.find(ta.suit)
			var sb := MJTile.SUITS.find(tb.suit)
			if sa != sb:
				return sa < sb
			return ta.value < tb.value)
	return entries


func _render_melds(row: HBoxContainer, f: MJFighter) -> void:
	for child in row.get_children():
		child.queue_free()
	for meld in f.melds:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var tag := Label.new()
		var meld_type := String(meld["type"])
		tag.text = ("杠" if meld_type == "KAN" else ("吃" if meld_type == "CHI" else "碰")) + String(meld["suit"])
		tag.add_theme_font_size_override("font_size", 12)
		box.add_child(tag)
		for t in meld["tiles"]:
			box.add_child(_make_tile_widget(t as MJTile, 30, 42))
		row.add_child(box)


func _render_river() -> void:
	for row in [_river_enemy_row, _river_player_row]:
		for child in row.get_children():
			child.queue_free()
	# 气河机制共用不变；展示按来源分行（用户裁定：能看出对面打过什么）
	var tiles := match_.river.tiles
	var start := maxi(0, tiles.size() - 36)
	for i in range(start, tiles.size()):
		var side := match_.river.side_at(i)
		var row := _river_enemy_row if side == "enemy" else _river_player_row
		row.add_child(_make_tile_widget(tiles[i], 26, 36))


func _render_log() -> void:
	var lines := match_.log.slice(maxi(0, match_.log.size() - 8))
	_log_panel.text = "\n".join(lines)


# ———— 演出（占位 VFX） ————

# 战斗现场落盘（user://mj_battle_log.txt）：引擎态＋UI 请求态＋战报尾部。
# 每次驱动循环覆盖写——卡死时这份文件就是可读的现场（2026-09-16 用户"能读日志吗"落地）。
func _dump_battle_state() -> void:
	var req: Dictionary = match_.next_request() if match_.state == "running" else {}
	var lines: Array[String] = []
	lines.append("=== %s ===" % Time.get_datetime_string_from_system())
	lines.append("state=%s winner=%s beat=%d turn_side=%s req=%s/%s ui_req=%s/%s popup=%s batch=%d" % [
		match_.state, match_.winner, match_.beat, match_.turn_side,
		String(req.get("phase", "")), String(req.get("side", "")),
		String(_current_request.get("phase", "")), String(_current_request.get("side", "")),
		_claim_popup.visible, match_.pending_batch.size()])
	lines.append("player hand=%d gang=%d bian=%d iron=%s pending=%d melds=%d hp=%.2f | enemy hand=%d gang=%d bian=%d iron=%s pending=%d melds=%d hp=%.2f | wall=%d river=%d" % [
		match_.fighter("player").hand.size(), match_.fighter("player").gang_qi,
		match_.fighter("player").bian_opps, match_.fighter("player").iron_active,
		match_.fighter("player").pending.size(), match_.fighter("player").melds.size(),
		match_.fighter("player").hp_fp / 100.0,
		match_.fighter("enemy").hand.size(), match_.fighter("enemy").gang_qi,
		match_.fighter("enemy").bian_opps, match_.fighter("enemy").iron_active,
		match_.fighter("enemy").pending.size(), match_.fighter("enemy").melds.size(),
		match_.fighter("enemy").hp_fp / 100.0,
		match_.wall.live_left(), match_.river.size()])
	for line in match_.log.slice(maxi(0, match_.log.size() - 30)):
		lines.append(line)
	var f := FileAccess.open("user://mj_battle_log.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))


func _banner_show(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


# AI 决策一闪（决策可见性：让玩家看见对方做了什么）
func _flash_decision(decision: Dictionary) -> void:
	var phase := String(_current_request.get("phase", ""))
	var text := ""
	match phase:
		"free_fire":
			text = "对方重击蓄势" if (decision.get("fire", []) as Array).size() > 0 else "对方打出"
			if str(decision.get("defense", "")) != "":
				text = "对方护体"
		"posture":
			match String(_current_request.get("play_kind", "")):
				"counter":
					text = "对方反击（不可截）"
				"xuzhao":
					text = "对方虚招（0 伤，可截走）"
				_:
					text = "对方普攻"
		"claim":
			var claim = decision.get("claim")
			var indexes = decision.get("claim_indexes")
			var claimed := (claim is Dictionary and not (claim as Dictionary).is_empty()) \
				or (indexes is Array and not (indexes as Array).is_empty())
			text = "对方招架——你的打出被截" if claimed else ""
	if not text.is_empty():
		_banner_show(text)


# 伤害弹字：从血条上方飘起（护境吸收也提示）
func _show_result() -> void:
	_dump_battle_state()
	_overlay.visible = true
	_overlay_label.text = "⚔ 胜 —— 对方气血耗尽" if match_.winner == "player" else "败 —— 你的气血耗尽"
	var restart := Button.new()
	restart.text = "再战一局"
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	_overlay_box.add_child(restart)
	var back := Button.new()
	back.text = "回演武场"
	back.pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.DOJO))
	_overlay_box.add_child(back)


# ———— 构件 ————

func _add_action_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 46)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(handler)
	_action_bar.add_child(b)
	return b


func _make_tile_widget(tile: MJTile, w: int, h: int, dimmed := false) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUIT_COLORS.get(tile.suit, Color.GRAY)
	if dimmed:
		sb.bg_color = sb.bg_color.darkened(0.25)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.1, 0.09, 0.08)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	var value_label := Label.new()
	value_label.text = str(tile.value)
	value_label.add_theme_font_size_override("font_size", int(h * 0.5))
	value_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	value_label.set_anchors_preset(Control.PRESET_CENTER)
	value_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	value_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(value_label)
	var suit_label := Label.new()
	suit_label.text = tile.suit
	suit_label.add_theme_font_size_override("font_size", maxi(10, int(h * 0.2)))
	suit_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8))
	suit_label.position = Vector2(3, 1)
	panel.add_child(suit_label)
	# 入场微动效（同风格演出：牌有呼吸感）
	panel.pivot_offset = Vector2(w / 2.0, h / 2.0)
	panel.scale = Vector2(0.6, 0.6)
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12)
	return panel


func _glow(widget: Control, color: Color) -> Control:
	var sb := widget.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		var glow_sb := sb.duplicate() as StyleBoxFlat
		glow_sb.set_border_width_all(3)
		glow_sb.border_color = color
		widget.add_theme_stylebox_override("panel", glow_sb)
	return widget


func _make_hp_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.14, 0.12)
	sb.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.25, 0.2)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", sb)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# —— 敌方区 ——
	_enemy_header = HBoxContainer.new()
	_enemy_header.add_theme_constant_override("separation", 14)
	root.add_child(_enemy_header)
	var enemy_name := Label.new()
	enemy_name.text = "石仆·麻将演武"
	enemy_name.add_theme_font_size_override("font_size", 20)
	_enemy_header.add_child(enemy_name)
	_enemy_hp_bar = _make_hp_bar()
	_enemy_header.add_child(_enemy_hp_bar)
	_enemy_hp_label = Label.new()
	_enemy_header.add_child(_enemy_hp_label)
	_enemy_stats = Label.new()
	_enemy_stats.add_theme_font_size_override("font_size", 13)
	root.add_child(_enemy_stats)
	_enemy_pending = Label.new()
	_enemy_pending.add_theme_font_size_override("font_size", 14)
	_enemy_pending.add_theme_color_override("font_color", Color(0.95, 0.6, 0.3))
	root.add_child(_enemy_pending)
	_enemy_melds = HBoxContainer.new()
	_enemy_melds.add_theme_constant_override("separation", 10)
	root.add_child(_enemy_melds)

	# —— 中部：气海/气河 ——
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	root.add_child(middle)
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.add_theme_constant_override("separation", 6)
	middle.add_child(center_col)
	_wall_label = Label.new()
	_wall_label.add_theme_font_size_override("font_size", 14)
	center_col.add_child(_wall_label)
	var river_title := Label.new()
	river_title.text = "气河（共用排出口，干涸整洗回气海；分行＝谁打出的）"
	river_title.add_theme_font_size_override("font_size", 12)
	center_col.add_child(river_title)
	var river_scroll := ScrollContainer.new()
	river_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	river_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	river_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_col.add_child(river_scroll)
	var river_rows := VBoxContainer.new()
	river_rows.add_theme_constant_override("separation", 4)
	river_scroll.add_child(river_rows)
	var enemy_row_title := Label.new()
	enemy_row_title.text = "对方打出"
	enemy_row_title.add_theme_font_size_override("font_size", 12)
	enemy_row_title.add_theme_color_override("font_color", Color(0.82, 0.55, 0.5))
	river_rows.add_child(enemy_row_title)
	_river_enemy_row = HBoxContainer.new()
	_river_enemy_row.add_theme_constant_override("separation", 3)
	river_rows.add_child(_river_enemy_row)
	var player_row_title := Label.new()
	player_row_title.text = "我打出"
	player_row_title.add_theme_font_size_override("font_size", 12)
	player_row_title.add_theme_color_override("font_color", Color(0.6, 0.75, 0.58))
	river_rows.add_child(player_row_title)
	_river_player_row = HBoxContainer.new()
	_river_player_row.add_theme_constant_override("separation", 3)
	river_rows.add_child(_river_player_row)
	_log_panel = RichTextLabel.new()
	_log_panel.custom_minimum_size = Vector2(330, 0)
	_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_panel.bbcode_enabled = false
	_log_panel.add_theme_font_size_override("normal_font_size", 12)
	_log_panel.add_theme_color_override("default_color", Color(0.75, 0.72, 0.66))
	middle.add_child(_log_panel)

	# —— 玩家区 ——
	var melds_title := Label.new()
	melds_title.text = "副露（活式仓：截来的重式，被功法消耗后入气河）"
	melds_title.add_theme_font_size_override("font_size", 12)
	root.add_child(melds_title)
	_player_melds = HBoxContainer.new()
	_player_melds.add_theme_constant_override("separation", 10)
	root.add_child(_player_melds)
	var hand_title_row := HBoxContainer.new()
	hand_title_row.add_theme_constant_override("separation", 12)
	root.add_child(hand_title_row)
	var hand_title := Label.new()
	hand_title.text = "丹田（静息账本：手牌 ＋ 3×明式 收敛于 13——重击挖坑后逐拍回填）"
	hand_title.add_theme_font_size_override("font_size", 12)
	hand_title_row.add_child(hand_title)
	var sort_toggle := CheckBox.new()
	sort_toggle.text = "自动理牌"
	sort_toggle.button_pressed = _auto_sort
	sort_toggle.add_theme_font_size_override("font_size", 12)
	sort_toggle.toggled.connect(func(on: bool):
		_auto_sort = on
		_render_hand())
	hand_title_row.add_child(sort_toggle)
	_player_hand = HBoxContainer.new()
	_player_hand.add_theme_constant_override("separation", 4)
	_player_hand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_player_hand)
	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 14)
	root.add_child(player_row)
	_player_hp_bar = _make_hp_bar()
	player_row.add_child(_player_hp_bar)
	_player_hp_label = Label.new()
	player_row.add_child(_player_hp_label)
	_player_stats = Label.new()
	_player_stats.add_theme_font_size_override("font_size", 13)
	root.add_child(_player_stats)
	_player_pending = Label.new()
	_player_pending.add_theme_font_size_override("font_size", 14)
	_player_pending.add_theme_color_override("font_color", Color(0.95, 0.6, 0.3))
	root.add_child(_player_pending)
	_phase_hint = Label.new()
	_phase_hint.add_theme_font_size_override("font_size", 15)
	_phase_hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	root.add_child(_phase_hint)
	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 10)
	root.add_child(_action_bar)

	# —— 回合横幅 ——
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 90
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6))
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	# —— 截牌窗弹层 ——
	_claim_popup = PanelContainer.new()
	_claim_popup.set_anchors_preset(Control.PRESET_CENTER)
	_claim_popup.visible = false
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.16, 0.15, 0.13)
	csb.set_border_width_all(2)
	csb.border_color = Color(0.95, 0.8, 0.2)
	csb.set_corner_radius_all(10)
	_claim_popup.add_theme_stylebox_override("panel", csb)
	add_child(_claim_popup)
	_claim_box = VBoxContainer.new()
	_claim_box.add_theme_constant_override("separation", 10)
	_claim_popup.add_child(_claim_box)

	# —— 终局遮罩 ——
	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	var osb := StyleBoxFlat.new()
	osb.bg_color = Color(0, 0, 0, 0.72)
	_overlay.add_theme_stylebox_override("panel", osb)
	add_child(_overlay)
	_overlay_box = VBoxContainer.new()
	_overlay_box.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_theme_constant_override("separation", 16)
	_overlay.add_child(_overlay_box)
	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 40)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(_overlay_label)
