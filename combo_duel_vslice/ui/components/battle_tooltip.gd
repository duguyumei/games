class_name BattleTooltip
extends PanelContainer

const UiDesignScript = preload("res://ui/ui_design.gd")

var _title: Label
var _body: RichTextLabel

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
    visible = true
    modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 1.0, UiDesignScript.ANIMATION_FAST)

func hide_detail() -> void:
    visible = false
