@tool
extends PanelContainer

## m20 预览专用：2D MJBTopBar 同格式复刻（2026-09-18 用户令「还有顶部的也加吧」）。
## 按钮为摆样、不接信号——预览不做路由；正式接线换真 MJBTopBar。


@export var title := "麻将演武":
	set(v):
		title = v
		_rebuild_if_ready()
@export var turn_text := "第 3 回合 · 敌方行动":
	set(v):
		turn_text = v
		_rebuild_if_ready()
@export var turn_color := Color(0.85, 0.45, 0.4, 1):
	set(v):
		turn_color = v
		_rebuild_if_ready()
# 2026-09-20 用户问「怎么变高度/为什么不能在 godot 里调」——高度与返回文案原是脚本常量
# ＝没收手调权（同 3D 真节点教训），升为导出值检查器直调。
# 2026-09-20 用户问「back text 的高度没有一起变」——内容字号不再写死，按条高比例派生
# （0.47/0.37/0.39，38 基准＝2D 原值 18/14/15），调 bar_height 整条一起缩放。
@export var bar_height := 38:
	set(v):
		bar_height = maxi(24, v)
		_rebuild_if_ready()
@export var back_text := "‹ 演武场":
	set(v):
		back_text = v
		_rebuild_if_ready()
# 2026-09-20 用户令「战斗记录就放在顶部吧」——组-场进度（如 1-3＝第一组第三场），
# 双 EXPAND 弹性夹在条正中；空串不占位。
@export var record_text := "":
	set(v):
		record_text = v
		_rebuild_if_ready()
# 2026-09-20 用户定调：顶栏不透明、敌我信息簇透明——顶栏底板保留 2D 原值 0.95。
@export_range(0.0, 1.0) var bg_alpha := 0.95:
	set(v):
		bg_alpha = v
		_rebuild_if_ready()


func _ready() -> void:
	_build()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		c.free()
	custom_minimum_size = Vector2(0, bar_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.085, 0.08, bg_alpha)
	sb.border_width_bottom = 1
	sb.border_color = Color(0.44, 0.39, 0.3, 0.8)
	add_theme_stylebox_override("panel", sb)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var back := Button.new()
	back.text = back_text
	back.add_theme_font_size_override("font_size", maxi(10, int(round(bar_height * 0.37))))
	bar.add_child(back)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", maxi(10, int(round(bar_height * 0.47))))
	t.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
	bar.add_child(t)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	if not record_text.is_empty():
		var rec := Label.new()
		rec.text = record_text
		rec.add_theme_font_size_override("font_size", maxi(10, int(round(bar_height * 0.37))))
		rec.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
		rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(rec)
		var spacer2 := Control.new()
		spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(spacer2)
	var turn := Label.new()
	turn.text = turn_text
	turn.add_theme_font_size_override("font_size", maxi(10, int(round(bar_height * 0.37))))
	turn.add_theme_color_override("font_color", turn_color)
	bar.add_child(turn)
	var help := Button.new()
	help.text = "?"
	help.add_theme_font_size_override("font_size", maxi(10, int(round(bar_height * 0.39))))
	help.tooltip_text = "词条（式与面子、罡气、变招…）"
	bar.add_child(help)
	var gear := Button.new()
	gear.text = "⚙"
	gear.add_theme_font_size_override("font_size", maxi(10, int(round(bar_height * 0.39))))
	gear.tooltip_text = "设置"
	bar.add_child(gear)
