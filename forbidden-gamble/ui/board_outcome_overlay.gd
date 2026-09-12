class_name BoardOutcomeOverlay
extends Control

# 版图终态结算罩层：全屏压暗 + 中央结算卡（金/朱红）。outcome 文案由本组件按
# board.outcome 生成；回据点经信号上抛。

signal return_pressed

const Palette := preload("res://ui/board_palette.gd")

var board: BoardState
var rs: Node

func setup(p_board: BoardState, p_rs: Node) -> void:
	board = p_board
	rs = p_rs

func render(parent: Control) -> void:
	if not board.is_run_over():
		return
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.1, 0.08, 0.06, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)
	var accent: Color = Palette.COLOR_GOLD if board.outcome == "extracted" else Color("#C0392B")
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLOR_CARD
	style.border_color = accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	var title_text := ""
	var sub_text := ""
	match board.outcome:
		"extracted":
			title_text = "—— 撤离成功 ——"
			sub_text = "你带着物资离开了险地。带回物资价值 %d 已存入据点仓库，随身兵甲完好带回（耐久照旧）。" % rs.banked_value()
		"exhausted":
			title_text = "—— 力竭被擒 ——"
			sub_text = _lost_text("你眼前一黑，倒在了荒郊野外。")
		"dead":
			title_text = "—— 阵亡 ——"
			sub_text = _lost_text("你倒在了这片险地里。")
	var title := Palette.brush_label(title_text, 40, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := Palette.plain_label(sub_text, 16, Palette.COLOR_INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	var restart := Button.new()
	restart.text = "回据点"
	restart.focus_mode = Control.FOCUS_NONE
	restart.add_theme_font_size_override("font_size", 18)
	restart.pressed.connect(func(): return_pressed.emit())
	vbox.add_child(restart)
	parent.add_child(panel)

# 败北文案：空囊全丢；囊里有货则报出保住的价值（死亡保底的落点，穿戴与背包一并丢）。
func _lost_text(base: String) -> String:
	if board.pouch.is_empty():
		return base + "携带的物资全部丢失。"
	return base + "随身兵甲与背包物资散落一地，贴身锦囊保住了价值 %d 的东西。" % rs.pouch_value()
