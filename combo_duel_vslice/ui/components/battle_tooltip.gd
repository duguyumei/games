class_name BattleTooltip
extends PanelContainer

const UiDesignScript = preload("res://ui/ui_design.gd")

var _title: Label
var _body: RichTextLabel
var _icon: Label
var _show_tween: Tween

func _ready() -> void:
    name = "BattleTooltip"
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 900
    custom_minimum_size = Vector2(260, 120)
    add_theme_stylebox_override("panel", UiDesignScript.box(
        UiDesignScript.COLORS["ink"], UiDesignScript.RADIUS_MD,
        UiDesignScript.COLORS["copper"], UiDesignScript.BORDER_REGULAR, 8))
    var column := VBoxContainer.new()
    add_child(column)
    _icon = Label.new()
    _icon.name = "IconPlaceholder"
    _icon.custom_minimum_size = Vector2(32, 32)
    _icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _icon.add_theme_font_size_override("font_size", 20)
    _icon.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    column.add_child(_icon)
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", UiDesignScript.FONT_SUBTITLE)
    _title.add_theme_color_override("font_color", UiDesignScript.COLORS["gold"])
    column.add_child(_title)
    _body = RichTextLabel.new()
    _body.bbcode_enabled = true
    _body.fit_content = true
    _body.custom_minimum_size.y = 72
    column.add_child(_body)

func show_detail(title_text: String, body_text: String, screen_position: Vector2) -> void:
    _title.text = title_text if title_text != "" else "未知详情"
    _body.text = body_text if body_text != "" else "暂无说明"
    position = screen_position + Vector2(14, 14)
    _stop_tween()
    visible = false
    modulate.a = 0.0
    _show_tween = create_tween()
    _show_tween.tween_interval(0.18)
    _show_tween.tween_callback(func(): visible = true)
    _show_tween.tween_property(self, "modulate:a", 1.0, UiDesignScript.ANIMATION_FAST)

func show_contract(detail: Dictionary, target_rect: Rect2, viewport_size: Vector2) -> void:
    var title_text := str(detail.get("title", "未知详情"))
    var body_text := str(detail.get("subtitle", ""))
    var description := str(detail.get("description", ""))
    if description != "":
        body_text += "\n" + description
    var values: Array = detail.get("values", [])
    for value in values:
        if value is Dictionary:
            body_text += "\n%s：%s" % [value.get("label", ""), value.get("value", "")]
    var tags: Array = detail.get("tags", [])
    if not tags.is_empty():
        body_text += "\n标签：%s" % " · ".join(tags.map(func(value): return str(value)))
    show_detail(title_text, body_text, Vector2.ZERO)
    var icon_path := str(detail.get("icon", detail.get("resource_path", "")))
    _icon.text = str(detail.get("placeholder", "?")) if icon_path == "" or not ResourceLoader.exists(icon_path) else "◆"
    var desired := target_rect.position + Vector2(14, target_rect.size.y + 8)
    var bounds := Rect2(Vector2.ZERO, viewport_size)
    desired.x = clampf(desired.x, 8.0, maxf(8.0, bounds.size.x - size.x - 8.0))
    desired.y = clampf(desired.y, 8.0, maxf(8.0, bounds.size.y - size.y - 8.0))
    position = desired

func hide_detail() -> void:
    _stop_tween()
    visible = false

func _stop_tween() -> void:
    if _show_tween != null and _show_tween.is_valid():
        _show_tween.kill()
    _show_tween = null

func _exit_tree() -> void:
    _stop_tween()
