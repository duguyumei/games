class_name FrontMenuPage
extends Control

signal new_game_requested
signal info_requested(title: String, body: String)
signal quit_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var _continue_button: Button
var _built := false

func _ready() -> void:
    _ensure_built()

func continue_button() -> Button:
    _ensure_built()
    return _continue_button

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build()

func _build() -> void:
    var title_box := VBoxContainer.new()
    title_box.position = Vector2(105, 128)
    title_box.size = Vector2(710, 560)
    title_box.add_theme_constant_override("separation", 10)
    add_child(title_box)
    var eyebrow := Label.new()
    eyebrow.text = "原创真气组合构筑游戏"
    eyebrow.add_theme_font_size_override("font_size", 17)
    eyebrow.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    title_box.add_child(eyebrow)
    var title := Label.new()
    title.text = "组合出招"
    title.add_theme_font_size_override("font_size", 78)
    title_box.add_child(title)
    var rule := HSeparator.new()
    rule.custom_minimum_size = Vector2(510, 16)
    title_box.add_child(rule)
    var subtitle := Label.new()
    subtitle.text = "调动风林火山真气，编排循环功法，走完三层行旅。"
    subtitle.custom_minimum_size.x = 600
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 22)
    subtitle.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    title_box.add_child(subtitle)
    var status := Label.new()
    status.text = "第一阶段可玩纵切 · 规则数据驱动 · 固定种子可复现"
    status.add_theme_font_size_override("font_size", 14)
    status.add_theme_color_override("font_color", Color("66817d"))
    title_box.add_child(status)
    var menu_panel := PanelContainer.new()
    menu_panel.position = Vector2(900, 92)
    menu_panel.size = Vector2(420, 710)
    menu_panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color(0.06, 0.12, 0.13, 0.94), 24, Color("365256"), 2, 18))
    add_child(menu_panel)
    var margin := MarginContainer.new()
    for side in ["margin_left", "margin_right"]:
        margin.add_theme_constant_override(side, 40)
    for side in ["margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 42)
    menu_panel.add_child(margin)
    var buttons := VBoxContainer.new()
    buttons.add_theme_constant_override("separation", 13)
    margin.add_child(buttons)
    var heading := Label.new()
    heading.text = "行 旅"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 25)
    heading.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    buttons.add_child(heading)
    buttons.add_child(UiDesignScript.divider(8))
    buttons.add_child(_menu_button("新游戏", func(): new_game_requested.emit(), true))
    _continue_button = _menu_button("继续游戏", Callable(), false)
    _continue_button.disabled = true
    _continue_button.tooltip_text = "当前尚未建立本局存档，暂无可继续记录"
    buttons.add_child(_continue_button)
    buttons.add_child(_info_button("图鉴", "图 鉴", "图鉴入口已经建立。卡牌、功法、内功、消耗品、异状与敌人条目的正式展示规则尚未确认，因此当前不生成虚假条目。"))
    buttons.add_child(_info_button("记录", "记 录", "记录入口已经建立。本局历史、战斗回放与统计持久化尚未完成；当前结构化日志只在运行中的会话内可审计。"))
    buttons.add_child(_info_button("设置", "设 置", "设置入口已经建立。完整的音量、画面、操作与辅助功能尚未接入；远程 AI 的本机配置继续由现有设置服务管理。"))
    buttons.add_child(_menu_button(
        "退出游戏", func(): quit_requested.emit(), false, UiDesignScript.COLORS["red"]))

func _info_button(text_value: String, title: String, body: String) -> Button:
    return _menu_button(text_value, func(): info_requested.emit(title, body))

func _menu_button(
        text_value: String,
        callback: Callable = Callable(),
        primary: bool = false,
        accent: Color = Color()) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size.y = 68
    button.add_theme_font_size_override("font_size", 21)
    var color := accent
    if color == Color():
        color = UiDesignScript.COLORS["gold"] if primary else Color("49666a")
    button.add_theme_stylebox_override(
        "normal", UiDesignScript.box(color.darkened(0.58), 12, color.darkened(0.05), 2, 5))
    button.add_theme_stylebox_override(
        "hover", UiDesignScript.box(color.darkened(0.38), 12, color.lightened(0.18), 3, 10))
    button.add_theme_stylebox_override(
        "pressed", UiDesignScript.box(color.darkened(0.65), 12, color, 2, 2))
    if callback.is_valid():
        button.pressed.connect(callback)
    return button
