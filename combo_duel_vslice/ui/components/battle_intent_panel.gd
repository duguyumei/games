class_name BattleIntentPanel
extends PanelContainer

signal panel_open_changed(open: bool)

const UiDesignScript = preload("res://ui/ui_design.gd")

var _summary_button: Button
var _candidate_box: VBoxContainer
var _intents: Array = []
var _open := false

func _ready() -> void:
    name = "BattleIntentPanel"
    custom_minimum_size = Vector2(190, 132)
    add_theme_stylebox_override("panel", UiDesignScript.box(
        UiDesignScript.COLORS["panel"], UiDesignScript.RADIUS_LG,
        UiDesignScript.COLORS["copper_dark"], UiDesignScript.BORDER_REGULAR, 8))
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", UiDesignScript.SPACE_SM)
    add_child(column)
    var caption := Label.new()
    caption.text = "敌方功法意图"
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
    caption.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    column.add_child(caption)
    _summary_button = Button.new()
    _summary_button.name = "IntentToggle"
    _summary_button.text = "?"
    _summary_button.tooltip_text = "查看敌方公开的可能意图；不会显示最终选择"
    _summary_button.add_theme_font_size_override("font_size", UiDesignScript.FONT_DISPLAY)
    _summary_button.pressed.connect(toggle)
    UiDesignScript.style_button(_summary_button, UiDesignScript.COLORS["panel"], 74)
    column.add_child(_summary_button)
    _candidate_box = VBoxContainer.new()
    _candidate_box.name = "IntentCandidates"
    _candidate_box.visible = false
    _candidate_box.add_theme_constant_override("separation", UiDesignScript.SPACE_XS)
    column.add_child(_candidate_box)

func present(intents: Array) -> void:
    _intents = intents.duplicate(true).slice(0, 5)
    _summary_button.text = "?\n%d 个方向" % _intents.size()
    _summary_button.disabled = _intents.is_empty()
    _rebuild_candidates()

func set_open(value: bool) -> void:
    _open = value and not _intents.is_empty()
    _candidate_box.visible = _open
    _summary_button.set_pressed_no_signal(_open)
    panel_open_changed.emit(_open)

func toggle() -> void:
    set_open(not _open)

func is_open() -> bool:
    return _open

func candidate_count() -> int:
    return _intents.size()

func _rebuild_candidates() -> void:
    for child in _candidate_box.get_children():
        child.queue_free()
    for index in range(_intents.size()):
        var intent: Dictionary = _intents[index]
        var row := Label.new()
        row.name = "IntentCandidate%d" % (index + 1)
        row.text = "%d  %s" % [index + 1, str(intent.get("display_name", "可能意图"))]
        row.tooltip_text = "伤害 %d · 防御 %d · 同气 +%d · 约 %d 张" % [
            int(intent.get("damage", 0)), int(intent.get("defense", 0)),
            int(intent.get("same_qi_gain", 0)), int(intent.get("played_count", 0))]
        row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        row.custom_minimum_size.y = 28
        row.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
        row.add_theme_color_override("font_color", _direction_color(str(intent.get("direction", ""))))
        row.add_theme_stylebox_override("normal", UiDesignScript.box(
            UiDesignScript.COLORS["ink"], UiDesignScript.RADIUS_SM,
            UiDesignScript.COLORS["line"], UiDesignScript.BORDER_THIN, 0, Vector2(8, 4)))
        _candidate_box.add_child(row)

func _direction_color(direction: String) -> Color:
    match direction:
        "assault": return UiDesignScript.COLORS["danger"]
        "survival": return UiDesignScript.COLORS["defense"]
        "cycle": return UiDesignScript.COLORS["green"]
        "develop": return UiDesignScript.COLORS["orange"]
        "control": return UiDesignScript.COLORS["purple"]
    return UiDesignScript.COLORS["gold"]
