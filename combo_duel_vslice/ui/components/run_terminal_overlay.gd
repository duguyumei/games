class_name RunTerminalOverlay
extends ColorRect

signal restart_requested
signal return_to_menu_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var title_label: Label
var detail_label: Label
var progress_label: Label
var restart_button: Button
var menu_button: Button
var presented_kind: String = ""
var _built := false

func _ready() -> void:
    _ensure_built()

func present(terminal_result: Dictionary, run_snapshot: Dictionary) -> void:
    _ensure_built()
    presented_kind = str(terminal_result.get("kind", ""))
    title_label.text = {
        "victory": "通 关",
        "defeat": "战 败",
        "abandoned": "主动放弃",
        "unresolved_rule": "规则未确认",
        "scenario_error": "场景错误",
    }.get(presented_kind, "本局结束")
    detail_label.text = _detail_for(terminal_result)
    var node_id := str(terminal_result.get(
        "node_id", run_snapshot.get("current_node_id", "")))
    progress_label.text = "到达第 %d 层　｜　当前节点 %s　｜　当前历练 %d" % [
        int(terminal_result.get("act", run_snapshot.get("act", 1))),
        node_id if node_id != "" else "旅程起点",
        int(run_snapshot.get("experience", 0)),
    ]
    visible = true

func _detail_for(terminal_result: Dictionary) -> String:
    var detail := str(terminal_result.get("detail", ""))
    if detail != "":
        return detail
    return {
        "victory": "第三层 Boss 的完整奖励已经结算。",
        "defeat": "玩家在战斗中失败，本局已经结束。",
        "abandoned": "本局由玩家主动结束。",
        "unresolved_rule": "双方同时倒下。\n当前胜负规则尚未确认，本局无法继续结算。",
        "scenario_error": "场景或内容运行错误，本局无法继续。",
    }.get(str(terminal_result.get("kind", "")), "本局已经结束。")

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color(0.012, 0.02, 0.024, 0.97)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    z_index = 500
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(760, 500)
    panel.add_theme_stylebox_override(
        "panel",
        UiDesignScript.box(
            Color("20272b"), 22, UiDesignScript.COLORS["gold"], 3, 16))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 22)
    panel.add_child(box)
    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 38)
    title_label.add_theme_color_override("font_color", Color("ffe4a2"))
    box.add_child(title_label)
    box.add_child(UiDesignScript.divider())
    detail_label = Label.new()
    detail_label.custom_minimum_size = Vector2(650, 120)
    detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.add_theme_font_size_override("font_size", 18)
    detail_label.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    box.add_child(detail_label)
    progress_label = Label.new()
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 16)
    progress_label.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    box.add_child(progress_label)
    restart_button = Button.new()
    restart_button.text = "重新开始本局"
    restart_button.custom_minimum_size = Vector2(300, 60)
    restart_button.pressed.connect(func(): restart_requested.emit())
    UiDesignScript.style_button(restart_button)
    box.add_child(restart_button)
    menu_button = Button.new()
    menu_button.text = "返回主菜单"
    menu_button.custom_minimum_size = Vector2(300, 52)
    menu_button.pressed.connect(func(): return_to_menu_requested.emit())
    UiDesignScript.style_button(menu_button)
    box.add_child(menu_button)
