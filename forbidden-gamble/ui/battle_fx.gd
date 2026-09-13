class_name BattleFx
extends Node

# 战斗演出层：气影幽灵/功法横幅/气血飘字/抽弃流转，全部由战报消息驱动（拉模式的
# 演出侧：消息在刷新 UI 前消费，此时状态已更新而旧珠仍在台上，坐标快照正好取起飞点）。
# pace（演出速度档系数）由场景根注入；功法专属演出可经注册表挂入（万剑归宗式），
# 未注册的功法走通用横幅＋气影。

const BP := preload("res://ui/battle_palette.gd")

# 演出节奏基准（乘 pace 系数）
const GHOST_SEC := 0.34
const GHOST_FADE_SEC := 0.15
const BANNER_IN_SEC := 0.12
const BANNER_HOLD_SEC := 0.55
const BANNER_OUT_SEC := 0.25
const FLOATER_SEC := 0.8

var pace := 1.0

var _stage: Control
var _hand: HandBar
var _player_panel: FighterPanel
var _enemy_panel: FighterPanel
# 演出节点的挂载层（全屏、忽略鼠标）：必须 OUTSIDE Column——横幅/幽灵/飘字若是
# VBox 的直接子节点，会被容器当布局孩子排位（横幅 52px 最小高把列撑到 772，
# 顶栏被切、功法层沉底、横幅自己被排到列尾贴底）。battle.gd 注入。
var _fx_layer: Control
var _banner: PanelContainer
var _banner_label: Label
var _banner_tween: Tween
# 功法专属演出注册表：technique_id -> Callable(ctx: Dictionary)。
# ctx：{side, technique, used_qi（含起飞坐标与颜色的快照）}
var _effects := {}

func setup(stage: Control, hand: HandBar, player_panel: FighterPanel, fx_layer: Control = null, enemy_panel: FighterPanel = null) -> void:
	_stage = stage
	_hand = hand
	_player_panel = player_panel
	_enemy_panel = enemy_panel
	_fx_layer = fx_layer

func register_effect(technique_id: String, effect: Callable) -> void:
	_effects[technique_id] = effect

# 按战报消息触发对应演出。hand_colors＝当前手牌各珠属性色（抽牌流入用）。
func play_message(message: String, used_qi: Array = [], hand_colors: Array = []) -> void:
	if message.begins_with("你发动"):
		var technique := message.get_slice("：", 0).trim_prefix("你发动")
		if _effects.has(technique):
			_effects[technique].call({
				"side": "player", "technique": technique, "used_qi": used_qi})
		else:
			technique_banner("player", technique)
			var intent := _player_panel.intent_center()
			var qihai := _hand.qihai_center()
			var delay := 0.0
			for qi in used_qi:
				qi_ghost(Vector2(qi["pos"]), intent, qi["color"], delay, qihai)
				delay += 0.07 * pace
	elif message.begins_with("敌方发动"):
		var technique := message.get_slice("：", 0).trim_prefix("敌方发动")
		if _effects.has(technique):
			_effects[technique].call({
				"side": "enemy", "technique": technique, "used_qi": used_qi})
		else:
			technique_banner("enemy", technique)
	elif message.contains("改招"):
		# 乱钩翻牌（敌方系统 v2）：盾碎瞬间慌忙换招——闪光＋抖动＋飘字（贴事件原位）
		var flip_panel := _panel_for(message)
		if flip_panel != null:
			flip_panel.flash_guard_break()
			_float_text("改招！", flip_panel, Color(0.98, 0.82, 0.6), 26)
	elif message.contains("改出"):
		# 应钩翻牌：它抓住你的空隙改出应手——敌方亮招＋我方破绽双闪
		var counter_panel := _panel_for(message)
		if counter_panel != null:
			counter_panel.flash_flaw()
			_float_text("改出！", counter_panel, Color(0.98, 0.62, 0.5), 26)
		if _player_panel != null:
			_player_panel.flash_flaw()
	elif message.contains("护境被击碎"):
		# 破盾先于破绽匹配（同一条消息两个词都含）：闪光＋抖动＋飘字
		var guard_panel := _panel_for(message)
		if guard_panel != null:
			guard_panel.flash_guard_break()
			_float_text("护境碎！", guard_panel, Color(0.75, 0.88, 1.0), 24)
	elif message.contains("露出破绽，错失一拍"):
		var flaw_panel := _panel_for(message)
		if flaw_panel != null:
			flaw_panel.flash_flaw()
			_float_text("破绽！", flaw_panel, BP.COLOR_GOLD, 26)
	elif message.contains("双方各抽") and not message.contains("第1回合"):
		_draw_flow(hand_colors)
	elif message.begins_with("剩余真气收回丹田"):
		_recycle_flow()

# 消息归属面板：以"你"开头的消息归我方，其余（名字开头）归敌方。
func _panel_for(message: String) -> FighterPanel:
	return _player_panel if message.begins_with("你") else _enemy_panel

# 抽牌流入：丹田 → 各孔位（状态已更新，取的正是新手牌）。
func _draw_flow(colors: Array) -> void:
	var from := _hand.dantian_center()
	var targets := _hand.socket_centers()
	for index in range(mini(colors.size(), targets.size())):
		qi_ghost(from, targets[index], colors[index], 0.05 * index)

# 回收流动：台上剩余珠 → 丹田（刷新前旧珠还在原位，快照即起飞点）。
func _recycle_flow() -> void:
	var indices: Array[int] = []
	indices.assign(range(8))
	var to := _hand.dantian_center()
	var delay := 0.0
	for qi in _hand.orb_snapshots(indices):
		qi_ghost(Vector2(qi["pos"]), to, qi["color"], delay)
		delay += 0.05

# 真气流动幽灵珠：从 from 飞向 to（可两段），带属性色，播完自毁。
func qi_ghost(from: Vector2, to: Vector2, color: Color, delay := 0.0, second_leg_to := Vector2.INF) -> void:
	var ghost := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(9)
	ghost.add_theme_stylebox_override("panel", sb)
	ghost.size = Vector2(18, 18)
	ghost.position = from - Vector2(9, 9)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 40
	ghost.name = "QiGhost"
	ghost.add_to_group("qi_ghost")
	_battle_root().add_child(ghost)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(ghost, "position", to - Vector2(9, 9), GHOST_SEC * pace)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if second_leg_to != Vector2.INF:
		tween.tween_property(ghost, "position", second_leg_to - Vector2(9, 9), GHOST_SEC * pace)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_SEC * pace)
	tween.finished.connect(ghost.queue_free)

# 功法横幅：中央演出带（按钮已隐藏的时段）大字显示功法名，我方金/敌方朱红。
func technique_banner(side: String, technique: String) -> void:
	if _banner == null:
		_banner = PanelContainer.new()
		_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.z_index = 45
		var strip := StyleBoxFlat.new()
		strip.bg_color = BP.BANNER_BG
		strip.content_margin_left = 26.0
		strip.content_margin_right = 26.0
		strip.set_corner_radius_all(4)
		_banner.add_theme_stylebox_override("panel", strip)
		_banner_label = Label.new()
		_banner_label.add_theme_font_override("font", BP.BRUSH_FONT)
		_banner_label.add_theme_font_size_override("font_size", 32)
		_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_child(_banner_label)
		_battle_root().add_child(_banner)
	var stage_rect := _stage.get_global_rect()
	_banner.custom_minimum_size = Vector2(stage_rect.size.x * 0.72, 52)
	_banner.size = Vector2.ZERO
	_banner.position = stage_rect.position + Vector2(stage_rect.size.x * 0.14, stage_rect.size.y * 0.4)
	_banner_label.text = "· %s ·" % technique
	_banner_label.add_theme_color_override("font_color",
		BP.COLOR_GOLD if side == "player" else BP.COLOR_ENEMY)
	_banner.modulate.a = 0.0
	_banner.visible = true
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, BANNER_IN_SEC * pace)
	_banner_tween.tween_interval(BANNER_HOLD_SEC * pace)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, BANNER_OUT_SEC * pace)
	_banner_tween.finished.connect(func(): _banner.visible = false)

# 伤害飘字：面板上方浮起并淡出，掉多少血飘多少（毒发等失去气血同样触发）。
func hp_feedback(before: int, after: int, panel: FighterPanel) -> void:
	var delta := before - after
	if delta <= 0:
		return
	var rect := panel.get_global_rect()
	var floater := Label.new()
	floater.text = "-%d" % delta
	floater.add_theme_font_override("font", BP.BRUSH_FONT)
	floater.add_theme_font_size_override("font_size", 24)
	floater.add_theme_color_override("font_color", BP.COLOR_ENEMY)
	floater.position = rect.position + Vector2(rect.size.x * 0.5 - 18.0, -4.0)
	floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floater.z_index = 50
	_battle_root().add_child(floater)
	var tween := create_tween()
	tween.tween_property(floater, "position:y", floater.position.y - 46.0, FLOATER_SEC * pace)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floater, "modulate:a", 0.0, FLOATER_SEC * pace).set_ease(Tween.EASE_IN)
	tween.finished.connect(floater.queue_free)

# 治疗飘字：金色 +N（伤药/跌打酒等战斗域道具），与伤害飘字同动效。
func heal_feedback(before: int, after: int, panel: FighterPanel) -> void:
	var delta := after - before
	if delta <= 0:
		return
	var rect := panel.get_global_rect()
	var floater := Label.new()
	floater.text = "+%d" % delta
	floater.add_theme_font_override("font", BP.BRUSH_FONT)
	floater.add_theme_font_size_override("font_size", 24)
	floater.add_theme_color_override("font_color", BP.COLOR_GOLD)
	floater.position = rect.position + Vector2(rect.size.x * 0.5 - 18.0, -4.0)
	floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floater.z_index = 50
	_battle_root().add_child(floater)
	var tween := create_tween()
	tween.tween_property(floater, "position:y", floater.position.y - 46.0, FLOATER_SEC * pace)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floater, "modulate:a", 0.0, FLOATER_SEC * pace).set_ease(Tween.EASE_IN)
	tween.finished.connect(floater.queue_free)

# 通用状态飘字（破绽/护境碎）：面板上方浮起并淡出，与气血飘字同动效。
func _float_text(text: String, panel: FighterPanel, color: Color, font_size: int) -> void:
	if panel == null:
		return
	var rect := panel.get_global_rect()
	var floater := Label.new()
	floater.text = text
	floater.add_theme_font_override("font", BP.BRUSH_FONT)
	floater.add_theme_font_size_override("font_size", font_size)
	floater.add_theme_color_override("font_color", color)
	floater.position = rect.position + Vector2(
		rect.size.x * 0.5 - text.length() * font_size * 0.5, -30.0)
	floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floater.z_index = 50
	_battle_root().add_child(floater)
	var tween := create_tween()
	tween.tween_property(floater, "position:y", floater.position.y - 46.0, FLOATER_SEC * pace)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floater, "modulate:a", 0.0, FLOATER_SEC * pace).set_ease(Tween.EASE_IN)
	tween.finished.connect(floater.queue_free)

# 横幅是否正在显示（预览/测试用）
func banner_visible() -> bool:
	return _banner != null and is_instance_valid(_banner) and _banner.visible

# 演出节点挂在战斗场景根上（本组件是纯逻辑子节点，不承担布局）
func _battle_root() -> Node:
	# 演出挂载层优先；未注入时退回舞台父节点（老调用方/测试路径）。
	return _fx_layer if _fx_layer != null else (_stage.get_parent() if _stage != null else get_parent())
