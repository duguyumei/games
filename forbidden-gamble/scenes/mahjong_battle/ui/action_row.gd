class_name MJBActionRow
extends HBoxContainer

## 主按钮组（手牌上方的打出行）：单行紧凑居中，按调用序排：防御｜变招·打出｜暗杠·攻击。
## 按钮＝带边框的窄片（2026-09-17 用户令：按钮就字那么高、零纵向内衬；小字贴着边框、
## 间距＝一个边框宽）——描边即视觉基准，状态色走边框与底色。
## 每个按钮可带上方小字（资源需求/运行拍数）；只管排布与禁用，语义由根协调器装配。


const COL_RUNNING := Color(0.98, 0.85, 0.3)
const COL_BORDER := Color(0.62, 0.56, 0.4)
const COL_BORDER_DIM := Color(0.36, 0.34, 0.3)


func _init() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # 整簇居中
	add_theme_constant_override("separation", 10)


## 带上方小字的按钮：caption 空则不加行。返回 {button, caption}。
func add_capped_button(text: String, caption: String, handler: Callable,
		min_size := Vector2.ZERO, _which := "mid") -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)  # 小字与按钮零行距：贴边框
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var b := _make_button(text, handler, min_size)
	box.add_child(b)
	add_child(box)
	return {"button": b, "caption": cap}


func add_button(text: String, handler: Callable, min_size := Vector2.ZERO, _which := "mid") -> Button:
	var b := _make_button(text, handler, min_size)
	add_child(b)
	return b


func _make_button(text: String, handler: Callable, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(handler)
	_style_button(b)
	return b


# 窄片样式：边框描出按钮轮廓（小字贴它），纵向内衬 0——高度＝字高；横向留 10 呼吸。
func _style_button(b: Button) -> void:
	var states := {
		"normal": [Color(0.2, 0.19, 0.17), COL_BORDER],
		"hover": [Color(0.28, 0.26, 0.22), COL_BORDER],
		"pressed": [Color(0.33, 0.3, 0.25), Color(0.8, 0.72, 0.5)],
		"disabled": [Color(0.15, 0.145, 0.14), COL_BORDER_DIM],
		"focus": [Color(0.2, 0.19, 0.17), COL_BORDER],
	}
	for state in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[state][0]
		sb.set_border_width_all(1)
		sb.border_color = states[state][1]
		sb.set_corner_radius_all(4)
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 0.0
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		b.add_theme_stylebox_override(state, sb)


func clear_buttons() -> void:
	for child in get_children():
		child.queue_free()


func set_enabled(on: bool) -> void:
	for b in _all_buttons():
		b.disabled = not on


# 递归收集本行全部 Button（小字包裹层之下——m13 自动驾驶检视面）。
func _all_buttons() -> Array[Button]:
	var out: Array[Button] = []
	_collect_buttons(self, out)
	return out


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child as Button)
		_collect_buttons(child, out)


# 运行中样式：金色字＋高亮（护体生效/重击在途——2026-09-16 用户令）。
static func set_running_style(button: Button, on: bool) -> void:
	button.add_theme_color_override("font_color", COL_RUNNING if on else Color(0.88, 0.88, 0.86))
	button.modulate = Color(1.15, 1.05, 0.75) if on else Color(1, 1, 1)


# 备付态样式（2026-09-17 审计项）：比运行态轻的微金调——提示两击武学"已备付，再点即发动"。
static func set_armed_style(button: Button, on: bool) -> void:
	button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.62) if on else Color(0.88, 0.88, 0.86))
	button.modulate = Color(1.06, 1.0, 0.88) if on else Color(1, 1, 1)
