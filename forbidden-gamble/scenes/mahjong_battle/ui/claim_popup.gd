@tool
class_name MJBClaimPopup
extends PanelContainer

## 招架窗弹层（居中，2026-09-17 用户令重排）：
## 标题＝「招架：碰／杠／吃」（按可截类型点名）→ 牌行（可截默认全选、点牌改选、
## 不可截置灰、徽记＝实际将执行的动作）→ **底部按钮行**：取消（左，＝整批放行）
## ＋按类型的执行键（各只执行选中里的该类型项，无选中则灰）。
## 内容四周留边——牌不贴边框。


var box := VBoxContainer.new()  # 对外可见：m13 自动驾驶与测试检视用

const TYPE_NAMES := {"pon": "碰", "kan": "杠", "chi": "吃"}


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH  # 从中心点双向生长＝真居中
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.13)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.8, 0.2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16.0  # 牌与边框留距离（2026-09-17 用户令：不贴边）
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", sb)
	box.add_theme_constant_override("separation", 12)
	add_child(box)


func close() -> void:
	visible = false
	for child in box.get_children():
		child.queue_free()


# 每批位的实际动作：杠优先（引擎 claim_indexes 语义），次吃，次碰。
static func _type_of(option_types: Array) -> String:
	if option_types.has("kan"):
		return "kan"
	if option_types.has("chi"):
		return "chi"
	return "pon"


func open_popup(request: Dictionary, selected: Dictionary, submit: Callable, toggle: Callable) -> void:
	close()
	var batch: Array = request.get("batch", [])
	var options: Array = request.get("claim_options", [])
	var types_by_index := {}
	for option in options:
		var bi := int(option["batch_index"])
		if not types_by_index.has(bi):
			types_by_index[bi] = []
		(types_by_index[bi] as Array).append(String(option["type"]))
	var claimable := {}
	var type_set := {}
	for bi in types_by_index:
		claimable[bi] = true
		type_set[_type_of(types_by_index[bi])] = true
	# —— 标题：招架：碰／杠／吃（按存在类型点名） ——
	var names: Array[String] = []
	for t in ["pon", "kan", "chi"]:
		if type_set.has(t):
			names.append(TYPE_NAMES[t])
	var title := Label.new()
	title.text = "招架：" + "·".join(names)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62))
	box.add_child(title)
	# —— 牌行 ——
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for i in range(batch.size()):
		var tile := batch[i] as MJTile
		var is_claimable: bool = claimable.has(i)
		var widget := MJBTileFace.make_tile(tile, 48, 66, not is_claimable)  # 不可截置灰
		if selected.has(i):
			widget = MJBTileFace.glow(widget, Color(0.98, 0.85, 0.3))
			widget.position.y -= 6
			var badge := Label.new()
			badge.text = TYPE_NAMES[_type_of(types_by_index[i])]
			badge.add_theme_font_size_override("font_size", 12)
			badge.add_theme_color_override("font_color", Color(0.98, 0.8, 0.25))
			badge.position = Vector2(widget.custom_minimum_size.x - 20, 0)
			widget.add_child(badge)
		var index := i
		widget.gui_input.connect(func(event: InputEvent):
			if is_claimable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				toggle.call(index))
		row.add_child(widget)
	# —— 底部按钮：取消（左）＋按类型执行键 ——
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(130, 44)
	cancel.pressed.connect(func(): submit.call({"claim": null}))
	buttons.add_child(cancel)
	for t in ["pon", "kan", "chi"]:
		if not type_set.has(t):
			continue
		var indexes: Array = []
		for bi in selected.keys():
			if claimable.has(int(bi)) and _type_of(types_by_index[int(bi)]) == t:
				indexes.append(int(bi))
		var act := Button.new()
		act.name = "Claim%s" % TYPE_NAMES[t]
		act.text = "%s（%d）" % [TYPE_NAMES[t], indexes.size()]
		act.custom_minimum_size = Vector2(110, 44)
		act.disabled = indexes.is_empty()
		var payload: Array = indexes
		act.pressed.connect(func(): submit.call({"claim_indexes": payload}))
		buttons.add_child(act)
	visible = true
