class_name BattleIntentPanel
extends PanelContainer

signal panel_open_changed(open: bool)
signal tooltip_requested(detail: Dictionary, target_rect: Rect2)
signal tooltip_hidden
signal detail_requested(section: String, payload: Dictionary)

const UiDesignScript = preload("res://ui/ui_design.gd")

var _summary_button: Button
var _candidate_box: VBoxContainer
var _popup: PopupPanel
var _intents: Array = []
var _open := false
var _tween: Tween

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
    _candidate_box.add_theme_constant_override("separation", UiDesignScript.SPACE_XS)
    _popup = PopupPanel.new()
    _popup.name = "IntentPopup"
    _popup.size = Vector2(300, 260)
    _popup.add_theme_stylebox_override("panel", UiDesignScript.box(
        UiDesignScript.COLORS["ink"], UiDesignScript.RADIUS_LG,
        UiDesignScript.COLORS["copper"], UiDesignScript.BORDER_REGULAR, 8))
    var popup_column := VBoxContainer.new()
    popup_column.add_theme_constant_override("separation", UiDesignScript.SPACE_SM)
    var popup_title := Label.new()
    popup_title.text = "公开候选方向"
    popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    popup_column.add_child(popup_title)
    popup_column.add_child(_candidate_box)
    var close_button := Button.new()
    close_button.name = "CloseIntentPopup"
    close_button.text = "关闭"
    close_button.pressed.connect(func(): set_open(false))
    UiDesignScript.style_button(close_button)
    popup_column.add_child(close_button)
    _popup.add_child(popup_column)
    add_child(_popup)
    _popup.popup_hide.connect(func():
        _open = false
        panel_open_changed.emit(false))

func present(intents: Array) -> void:
    _intents = intents.duplicate(true).slice(0, 5)
    _summary_button.text = "?\n%d 个方向" % _intents.size()
    _summary_button.disabled = _intents.is_empty()
    _rebuild_candidates()

func set_open(value: bool) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _open = value and not _intents.is_empty()
    _summary_button.set_pressed_no_signal(_open)
    if _open:
        var origin := get_global_rect().position + Vector2(0, size.y + 8)
        _popup.position = Vector2i(origin)
        _popup.popup()
    elif _popup != null:
        _popup.hide()
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
        row.mouse_entered.connect(func(): tooltip_requested.emit({"kind": "enemy_intent",
            "title": str(intent.get("display_name", "可能意图")), "subtitle": "公开候选方向",
            "description": "仅展示公开方向，不包含 AI 最终选择",
            "values": [{"label": "伤害", "value": int(intent.get("damage", 0))},
                {"label": "防御", "value": int(intent.get("defense", 0))},
                {"label": "同气", "value": int(intent.get("same_qi_gain", 0))}],
            "tags": intent.get("public_tags", []), "placeholder": "?"}, row.get_global_rect()))
        row.mouse_exited.connect(func(): tooltip_hidden.emit())
        row.gui_input.connect(func(event: InputEvent):
            if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
                detail_requested.emit("intents", intent.duplicate(true)))

func _direction_color(direction: String) -> Color:
    match direction:
        "assault": return UiDesignScript.COLORS["danger"]
        "survival": return UiDesignScript.COLORS["defense"]
        "cycle": return UiDesignScript.COLORS["green"]
        "develop": return UiDesignScript.COLORS["orange"]
        "control": return UiDesignScript.COLORS["purple"]
    return UiDesignScript.COLORS["gold"]

func _exit_tree() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
