class_name BattleNotificationLayer
extends Control

const UiDesignScript = preload("res://ui/ui_design.gd")

var _message: Label
var _tween: Tween

func _ready() -> void:
    name = "BattleNotificationLayer"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 850
    _message = Label.new()
    _message.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _message.position = Vector2(-230, 170)
    _message.size = Vector2(460, 48)
    _message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _message.add_theme_color_override("font_color", UiDesignScript.COLORS["cream"])
    _message.add_theme_stylebox_override("normal", UiDesignScript.box(
        Color(UiDesignScript.COLORS["ink"], 0.94), UiDesignScript.RADIUS_MD,
        UiDesignScript.COLORS["copper_dark"], UiDesignScript.BORDER_REGULAR, 5))
    _message.visible = false
    add_child(_message)

func notify(text_value: String, error: bool = false) -> void:
    if text_value == "":
        return
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _message.text = text_value
    _message.add_theme_color_override("font_color",
        UiDesignScript.COLORS["danger"] if error else UiDesignScript.COLORS["cream"])
    _message.visible = true
    _message.modulate.a = 1.0
    _tween = create_tween()
    _tween.tween_interval(1.4)
    _tween.tween_property(_message, "modulate:a", 0.0, UiDesignScript.ANIMATION_NORMAL)
    _tween.tween_callback(func(): _message.visible = false)

func _exit_tree() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _tween = null
