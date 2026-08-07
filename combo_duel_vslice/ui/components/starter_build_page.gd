class_name StarterBuildPage
extends Control

signal selection_requested
signal begin_requested
signal back_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var _build_button: Button
var _begin_button: Button
var _built := false

func _ready() -> void:
    _ensure_built()

func begin_button() -> Button:
    _ensure_built()
    return _begin_button

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := PanelContainer.new()
    panel.position = Vector2(95, 65)
    panel.size = Vector2(1250, 770)
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color(0.055, 0.11, 0.12, 0.97), 25, Color("3b5758"), 2, 20))
    add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 50)
    margin.add_theme_constant_override("margin_right", 50)
    margin.add_theme_constant_override("margin_top", 38)
    margin.add_theme_constant_override("margin_bottom", 38)
    panel.add_child(margin)
    var root_box := VBoxContainer.new()
    root_box.add_theme_constant_override("separation", 20)
    margin.add_child(root_box)
    var title := Label.new()
    title.text = "选择初始构筑"
    title.add_theme_font_size_override("font_size", 35)
    root_box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "当前纵切仅开放一套标准真气牌组。选择后才会建立本局并生成第1层路线。"
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    root_box.add_child(subtitle)
    root_box.add_child(UiDesignScript.divider(8))
    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 34)
    root_box.add_child(body)
    _build_button = Button.new()
    _build_button.custom_minimum_size = Vector2(470, 470)
    _build_button.toggle_mode = true
    _build_button.pressed.connect(func(): selection_requested.emit())
    body.add_child(_build_button)
    var detail := PanelContainer.new()
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail.add_theme_stylebox_override(
        "panel", UiDesignScript.box(UiDesignScript.COLORS["panel"], 18, Color("2e4447"), 2, 8))
    body.add_child(detail)
    var detail_margin := MarginContainer.new()
    detail_margin.add_theme_constant_override("margin_left", 32)
    detail_margin.add_theme_constant_override("margin_right", 32)
    detail_margin.add_theme_constant_override("margin_top", 30)
    detail_margin.add_theme_constant_override("margin_bottom", 30)
    detail.add_child(detail_margin)
    var detail_box := VBoxContainer.new()
    detail_box.add_theme_constant_override("separation", 15)
    detail_margin.add_child(detail_box)
    detail_box.add_child(_detail_label("牌组构成", "风、林、火、山各13张，共52张"))
    detail_box.add_child(_detail_label("牌阶", "A、2～10、J、Q、K完整四属性组合"))
    detail_box.add_child(_detail_label("真气状态", "无初始强化、品相、印记或战斗异状"))
    detail_box.add_child(_detail_label("功法配置", "暂沿用当前纵切调试序列；初始功法选择尚未开放"))
    var note := Label.new()
    note.text = "这一步只确认初始牌组，不会提前生成地图或修改本局状态。"
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 15)
    note.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    detail_box.add_child(note)
    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    actions.add_theme_constant_override("separation", 14)
    root_box.add_child(actions)
    var back := _action_button("返回主菜单", func(): back_requested.emit())
    actions.add_child(back)
    _begin_button = _action_button("开始行旅", func(): begin_requested.emit(), true)
    actions.add_child(_begin_button)

func present(definition: Dictionary) -> void:
    _ensure_built()
    var selected := not definition.is_empty()
    _build_button.button_pressed = selected
    _build_button.text = "%s\n\n%s\n\n%d 张真气\n\n%s" % [
        str(definition.get("name", "未选择构筑")),
        str(definition.get("description", "点击选择可用构筑")),
        int(definition.get("card_count", 0)),
        "◆ 已选择" if selected else "点击选择"]
    _build_button.add_theme_font_size_override("font_size", 21)
    _build_button.add_theme_stylebox_override(
        "normal", UiDesignScript.box(UiDesignScript.COLORS["panel_2"], 20, Color("416064"), 3, 9))
    _build_button.add_theme_stylebox_override(
        "hover", UiDesignScript.box(Color("294143"), 20, UiDesignScript.COLORS["gold"], 4, 14))
    _build_button.add_theme_stylebox_override(
        "pressed", UiDesignScript.box(Color("304c42"), 20, UiDesignScript.COLORS["gold"], 5, 7))
    _begin_button.disabled = not selected

func _action_button(text_value: String, callback: Callable, primary: bool = false) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(230, 58)
    button.add_theme_font_size_override("font_size", 18)
    button.pressed.connect(callback)
    UiDesignScript.style_button(
        button, UiDesignScript.COLORS["gold"] if primary else Color("49666a"), 58)
    return button

func _detail_label(title: String, body: String) -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    var heading := Label.new()
    heading.text = title
    heading.add_theme_font_size_override("font_size", 16)
    heading.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    box.add_child(heading)
    var text := Label.new()
    text.text = body
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_theme_font_size_override("font_size", 18)
    box.add_child(text)
    return box
