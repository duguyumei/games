class_name UiDesign
extends RefCounted

const COLORS := {
    "background": Color("101614"),
    "ink": Color("090e0d"),
    "panel": Color("18201e"),
    "panel_2": Color("29322f"),
    "panel_3": Color("303a36"),
    "cream": Color("f3eedf"),
    "paper": Color("d8c9a8"),
    "muted": Color("a99b7f"),
    "gold": Color("e2ba68"),
    "copper": Color("b88b42"),
    "copper_dark": Color("815a35"),
    "orange": Color("d97832"),
    "red": Color("b44f49"),
    "danger": Color("b44f49"),
    "heal": Color("6ea67f"),
    "defense": Color("6f8f9a"),
    "poison": Color("78985a"),
    "true_damage": Color("d9d3c5"),
    "blue": Color("6f8f9a"),
    "green": Color("5b9b80"),
    "purple": Color("835bb4"),
    "line": Color("4a514a"),
}

const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 18
const SPACE_XL := 24
const SPACE_XXL := 32
const BORDER_THIN := 1
const BORDER_REGULAR := 2
const BORDER_STRONG := 3
const RADIUS_SM := 6
const RADIUS_MD := 10
const RADIUS_LG := 14
const CARD_SIZE := Vector2(132, 188)
const COMPACT_CARD_SIZE := Vector2(82, 118)
const INNER_SKILL_CARD_SIZE := Vector2(132, 188)
const BOTTOM_ZONE_HEIGHT := 300
const SIDE_COLUMN_WIDTH := 300
const ANIMATION_FAST := 0.12
const ANIMATION_NORMAL := 0.22
const ANIMATION_SLOW := 0.36
const FONT_CAPTION := 11
const FONT_BODY := 14
const FONT_SUBTITLE := 16
const FONT_TITLE := 22
const FONT_DISPLAY := 42

static func create_theme() -> Theme:
    var result := Theme.new()
    result.set_color("font_color", "Label", COLORS["cream"])
    result.set_color("font_color", "Button", COLORS["cream"])
    result.set_color("font_hover_color", "Button", Color("fff4d2"))
    result.set_color("font_pressed_color", "Button", Color("fff4d2"))
    result.set_color("font_disabled_color", "Button", Color("596365"))
    result.set_font_size("font_size", "Label", FONT_BODY)
    result.set_font_size("font_size", "Button", 13)
    result.set_constant("separation", "VBoxContainer", SPACE_SM)
    result.set_constant("separation", "HBoxContainer", SPACE_SM)
    result.set_stylebox("normal", "Button", button_box("normal"))
    result.set_stylebox("hover", "Button", button_box("hover"))
    result.set_stylebox("pressed", "Button", button_box("pressed"))
    result.set_stylebox("disabled", "Button", button_box("disabled"))
    return result

static func box(
        fill: Color,
        radius: int = 10,
        border: Color = Color.TRANSPARENT,
        border_width: int = 0,
        shadow_size: int = 0,
        margins: Vector2 = Vector2(10, 8)) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0.01, 0.025, 0.02, 0.46)
    style.shadow_size = shadow_size
    style.shadow_offset = Vector2(3, 5) if shadow_size > 0 else Vector2.ZERO
    style.content_margin_left = margins.x
    style.content_margin_right = margins.x
    style.content_margin_top = margins.y
    style.content_margin_bottom = margins.y
    style.anti_aliasing = true
    return style

static func button_box(state: String = "normal", accent: Color = Color()) -> StyleBoxFlat:
    var color := accent if accent != Color() else COLORS["panel_2"]
    match state:
        "hover":
            return box(color.lightened(0.10), 8, COLORS["gold"], 2, 5)
        "pressed":
            return box(color.darkened(0.12), 8, COLORS["gold"], 2, 1)
        "disabled":
            return box(Color("171d1f"), 8, Color("333d3f"), 1, 0)
        _:
            return box(color, 8, Color("4b5862"), 1, 3)

static func style_button(button: Button, accent: Color = Color(), height: float = 37.0) -> void:
    button.custom_minimum_size.y = height
    button.add_theme_stylebox_override("normal", button_box("normal", accent))
    button.add_theme_stylebox_override("hover", button_box("hover", accent))
    button.add_theme_stylebox_override("pressed", button_box("pressed", accent))
    button.add_theme_stylebox_override("disabled", button_box("disabled", accent))

static func chip(text_value: String, color: Color, minimum_width: float = 68.0) -> Label:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size = Vector2(minimum_width, 22)
    label.add_theme_font_size_override("font_size", FONT_CAPTION - 1)
    label.add_theme_color_override("font_color", Color("f1ebdf"))
    label.add_theme_stylebox_override(
        "normal", box(color.darkened(0.42), 7, color.darkened(0.06), 1, 1, Vector2(7, 2)))
    return label

static func divider(separation: int = 2) -> HSeparator:
    var separator := HSeparator.new()
    separator.add_theme_constant_override("separation", separation)
    return separator

## 资源药丸标签。用于层数、历练等单值展示。
static func pill(
        text_value: String,
        color: Color,
        minimum_size: Vector2 = Vector2(112, 34)) -> Label:
    var label := Label.new()
    label.text = text_value
    label.custom_minimum_size = minimum_size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", Color("fff4d5"))
    label.add_theme_stylebox_override(
        "normal", box(color.darkened(0.42), 10, color, 2, 2))
    return label

## 大字数值瓷砖。返回根节点与数值标签，调用方持有后者用于刷新。
static func number_tile(
        initial: String,
        caption_text: String,
        color: Color) -> Dictionary:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(83, 74)
    panel.add_theme_stylebox_override(
        "panel", box(color.darkened(0.1), 11, color.lightened(0.2), 2, 5))
    var column := VBoxContainer.new()
    var value := Label.new()
    value.text = initial
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value.add_theme_font_size_override("font_size", 29)
    value.add_theme_color_override("font_color", Color("fff4df"))
    column.add_child(value)
    var caption := Label.new()
    caption.text = caption_text
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 10)
    caption.add_theme_color_override("font_color", Color("f2d9c7"))
    column.add_child(caption)
    panel.add_child(column)
    return {"root": panel, "value": value}

## 小号说明文字。用于待出区分组标注等场景。
static func caption(text_value: String) -> Label:
    var label := Label.new()
    label.text = text_value
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", FONT_CAPTION + 1)
    label.add_theme_color_override("font_color", COLORS["muted"])
    return label
