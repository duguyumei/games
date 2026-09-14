@tool
class_name FighterPanel
extends Control

## 战斗者面板（设计画布）：竖版立绘占大头，顶部意图/准备槽（功法卡图，
## 与功法卡 ArtArea 同比例 130×88，功法名压在卡图上方，真气槽暂不显示），
## 心法竖排在立绘外侧（我方左、敌方右），
## 立绘下为气血条（敌方与手牌数同一行）+ 状态行。
## 心法为小丑牌式竖排胶囊：名称+悬浮披露效果文本（规则透明）。

const FONT_PATH := "res://assets/fonts/MaShanZheng.ttf"
const PORTRAIT_TOP := 112.0
const CHIP_W := 78.0

@export_enum("PLAYER", "ENEMY") var side: int = 0:
	set(value):
		side = value
		_apply()
@export var fighter_name: String = "侠客":
	set(value):
		fighter_name = value
		_apply()
@export var max_hp: int = 60:
	set(value):
		max_hp = maxi(value, 1)
		_apply()
@export var hp: int = 42:
	set(value):
		hp = clampi(value, 0, max_hp)
		_apply()
@export var guard: int = 3:
	set(value):
		guard = maxi(value, 0)
		_apply()
## 敌方手牌数（仅 ENEMY 显示，与气血条同一行）。
@export var enemy_hand: int = 4:
	set(value):
		enemy_hand = maxi(value, 0)
		_apply()
## 心法栏：逗号分隔的心法名称（竖排在立绘外侧，悬浮显示效果文本）。
@export var xinfa_names: String = "":
	set(value):
		xinfa_names = value
		_apply()
## 状态行演示：逗号分隔的状态名（不含护体，护体由 guard 生成）。
@export var status_names: String = "毒":
	set(value):
		status_names = value
		_apply()
## 应手灯（敌方系统 v2，仅 ENEMY）：预埋反制的绊线状态（如"窥隙·就绪"），悬浮显示明码。
@export var hook_lamp_text: String = "":
	set(value):
		hook_lamp_text = value
		_apply()
@export var hook_lamp_tooltip: String = "":
	set(value):
		hook_lamp_tooltip = value
		_apply()
@export var portrait_color: Color = Color(0.45, 0.55, 0.5):
	set(value):
		portrait_color = value
		_apply()
## 意图/准备槽：true 显示演示卡图（顶部已填丹珠），false 显示空槽。
@export var show_intent: bool = false:
	set(value):
		show_intent = value
		_apply()
@export var intent_name: String = "震山掌":
	set(value):
		intent_name = value
		_apply()
@export var intent_art_color: Color = Color(0.55, 0.28, 0.22):
	set(value):
		intent_art_color = value
		_apply()

# 气血演出：掉血时血条渐缩 + 立绘闪红（编辑器里直接落位，不播动画）。
var _prev_hp := -1
var _hp_fill_tween: Tween
var _flash_tween: Tween
var _intent_tween: Tween

func _ready() -> void:
	_prev_hp = -1
	_apply()


# 意图/准备槽中心（功法气影的第一段落点）——外部经此取坐标，不直捅 IntentDemo 节点。
func intent_center() -> Vector2:
	var node := get_node_or_null("IntentDemo")
	if node != null:
		return node.get_global_rect().get_center()
	return get_global_rect().get_center()


# 意图悬停详情（敌方意图的效果预览文本）。
func set_intent_tooltip(text: String) -> void:
	var node := get_node_or_null("IntentDemo")
	if node != null:
		node.tooltip_text = text


func _apply() -> void:
	if not is_inside_tree():
		return
	var name_label: Label = get_node_or_null("Portrait/NameTag/NameLabel")
	if name_label != null:
		name_label.text = fighter_name
	var portrait: ColorRect = get_node_or_null("Portrait")
	if portrait != null:
		portrait.color = portrait_color
	# 气血条（与立绘同宽居中；敌方手牌数是独立节点，不占气血条位置）
	var hp_bar: Control = get_node_or_null("HpBar")
	if hp_bar != null:
		var hp_fill: ColorRect = hp_bar.get_node_or_null("HpFill")
		if hp_fill != null:
			var target := Vector2((hp_bar.size.x - 4.0) * float(hp) / float(max_hp), hp_fill.size.y)
			_animate_hp_fill(hp_fill, target)
		var hp_label: Label = hp_bar.get_node_or_null("HpLabel")
		if hp_label != null:
			hp_label.text = "%d/%d" % [hp, max_hp]
	# 敌方手牌数
	var hand_chip: Control = get_node_or_null("HandChip")
	if hand_chip != null:
		hand_chip.visible = (side == 1)
		var hand_label: Label = hand_chip.get_node_or_null("HandLabel")
		if hand_label != null:
			hand_label.text = "×%d" % enemy_hand
	# 意图 / 准备槽
	var intent_demo: Control = get_node_or_null("IntentDemo")
	if intent_demo != null:
		intent_demo.visible = show_intent
		var art: ColorRect = intent_demo.get_node_or_null("Art")
		if art != null:
			art.color = intent_art_color
		var intent_label: Label = intent_demo.get_node_or_null("NameStrip/IntentName")
		if intent_label != null:
			intent_label.text = intent_name
	var intent_empty: Control = get_node_or_null("IntentEmpty")
	if intent_empty != null:
		intent_empty.visible = not show_intent
		var hint: Label = intent_empty.get_node_or_null("EmptyHint")
		if hint != null:
			hint.text = "意图" if side == 1 else "准备槽"
	_rebuild_chips()


# 掉血：血条 0.35s 渐缩 + 立绘闪红；回复/首帧直接落位；数值未变不动（别打断进行中的补间）。
func _animate_hp_fill(hp_fill: ColorRect, target: Vector2) -> void:
	if Engine.is_editor_hint() or _prev_hp < 0 or hp > _prev_hp:
		hp_fill.size = target
	elif hp < _prev_hp:
		if _hp_fill_tween != null and _hp_fill_tween.is_valid():
			_hp_fill_tween.kill()
		_hp_fill_tween = create_tween()
		_hp_fill_tween.tween_property(hp_fill, "size", target, 0.35)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_flash_hurt()
	_prev_hp = hp


func _flash_hurt() -> void:
	var portrait: ColorRect = get_node_or_null("Portrait")
	if portrait == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	portrait.modulate = Color(1.0, 0.45, 0.4)
	_flash_tween = create_tween()
	_flash_tween.tween_property(portrait, "modulate", Color.WHITE, 0.4)

# 破绽震慑：立绘金光一闪＋横向抖动——破绽在结算里产生即消耗，
# 不补这个可见瞬间，玩家只会觉得行动权莫名连转。
func flash_flaw() -> void:
	_flash_recoil(Color(1.0, 0.82, 0.35))

# 意图翻牌脉冲（敌方系统 v2：钩子改变意图＝翻牌即演出——意图卡闪色回落，
# 玩家视线钉在意图区时不漏看）。
func flash_intent(tint := Color(1.0, 0.62, 0.45)) -> void:
	var intent_demo: Control = get_node_or_null("IntentDemo")
	if intent_demo == null:
		return
	if _intent_tween != null and _intent_tween.is_valid():
		_intent_tween.kill()
	intent_demo.modulate = tint
	_intent_tween = create_tween()
	_intent_tween.tween_property(intent_demo, "modulate", Color.WHITE, 0.5)

# 护境被击碎：青白闪光＋抖动（破盾是破绽的主要来源，两者视觉上要连成一件事）。
func flash_guard_break() -> void:
	_flash_recoil(Color(0.68, 0.85, 1.0))

func _flash_recoil(tint: Color) -> void:
	var portrait: ColorRect = get_node_or_null("Portrait")
	if portrait == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	portrait.modulate = tint
	_flash_tween = create_tween()
	var origin_x := portrait.position.x
	_flash_tween.tween_property(portrait, "position:x", origin_x + 7.0, 0.05)
	_flash_tween.tween_property(portrait, "position:x", origin_x - 5.0, 0.05)
	_flash_tween.tween_property(portrait, "position:x", origin_x, 0.06)
	_flash_tween.tween_property(portrait, "modulate", Color.WHITE, 0.4)


# 心法竖排（立绘外侧：我方左、敌方右）+ 状态行横排。
# 无心法时整列隐藏；胶囊悬浮披露效果文本（数据即真相，XinfaRuntime.effect_text）。
func _rebuild_chips() -> void:
	var internal_col: Control = get_node_or_null("InternalColumn")
	if internal_col != null:
		_detach_children(internal_col)
		var names := xinfa_names.split(",", false)
		var has_xinfa := false
		for chip_name in names:
			if not chip_name.strip_edges().is_empty():
				has_xinfa = true
				break
		internal_col.visible = has_xinfa
		if has_xinfa:
			internal_col.position = Vector2(242.0 if side == 1 else 0.0, PORTRAIT_TOP)
			var tag := _make_label("心法", Color(0.92, 0.86, 0.7, 0.65), 12)
			tag.position = Vector2(0, -24)
			internal_col.add_child(tag)
			var y := 0.0
			for chip_name in names:
				var text := chip_name.strip_edges()
				if text.is_empty():
					continue
				var chip := _make_chip(text, Color(0.16, 0.15, 0.13, 0.8), Color(0.88, 0.82, 0.66))
				chip.tooltip_text = XinfaRuntime.effect_text(text)
				chip.mouse_filter = Control.MOUSE_FILTER_STOP
				chip.position = Vector2(0, y)
				internal_col.add_child(chip)
				y += chip.size.y + 6.0
	var status_row: Control = get_node_or_null("StatusRow")
	if status_row != null:
		_detach_children(status_row)
		var x := 0.0
		if guard > 0:
			var guard_chip := _make_chip("护体·%d" % guard, Color(0.2, 0.28, 0.38, 0.85), Color(0.75, 0.85, 0.95))
			guard_chip.position = Vector2(x, 0)
			status_row.add_child(guard_chip)
			x += guard_chip.size.x + 6.0
		for status_name in status_names.split(",", false):
			var status_text := status_name.strip_edges()
			if status_text.is_empty():
				continue
			var chip := _make_chip(status_text, Color(0.25, 0.35, 0.2, 0.85), Color(0.8, 0.92, 0.7))
			chip.position = Vector2(x, 0)
			status_row.add_child(chip)
			x += chip.size.x + 6.0
		# 应手灯（敌方专用）：绊线状态胶囊——亮＝就绪、歇N＝冷却、哑＝未武装/付不起
		var lamp_text := hook_lamp_text.strip_edges()
		if side == 1 and not lamp_text.is_empty():
			var lamp := _make_chip(lamp_text, Color(0.38, 0.16, 0.24, 0.9), Color(0.98, 0.82, 0.6))
			lamp.tooltip_text = hook_lamp_tooltip
			lamp.mouse_filter = Control.MOUSE_FILTER_STOP
			lamp.position = Vector2(x, 0)
			status_row.add_child(lamp)


# 同帧多次重建（hp/guard/甲护/状态各触发一次 _apply）时，queue_free 是延迟释放、
# 旧胶囊当帧仍可见会叠影——先脱离父节点再排队释放。
func _detach_children(row: Node) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _make_chip(text: String, bg: Color, fg: Color) -> Panel:
	var chip := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", sb)
	chip.size = Vector2(maxf(CHIP_W, 16.0 + text.length() * 14.0), 22)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _make_label(text, fg, 12)
	label.size = chip.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


func _make_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var font: FontFile = load(FONT_PATH)
	if font != null:
		label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
