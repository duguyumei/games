class_name BattleTechniqueGrid
extends VBoxContainer

signal details_requested(section: String, payload: Dictionary)
signal tooltip_requested(detail: Dictionary, target_rect: Rect2)
signal tooltip_hidden

const UiDesignScript = preload("res://ui/ui_design.gd")

var _title: Label
var _grid: GridContainer
var _compact := false
var _slot_registry: Dictionary = {}

func _ready() -> void:
    name = "BattleTechniqueGrid"
    custom_minimum_size = Vector2(300, 250)
    add_theme_constant_override("separation", UiDesignScript.SPACE_SM)
    _title = Label.new()
    _title.text = "功法槽"
    _title.add_theme_font_size_override("font_size", UiDesignScript.FONT_SUBTITLE)
    _title.add_theme_color_override("font_color", UiDesignScript.COLORS["paper"])
    add_child(_title)
    _grid = GridContainer.new()
    _grid.name = "TechniqueSlots"
    _grid.columns = 2
    _grid.add_theme_constant_override("h_separation", UiDesignScript.SPACE_SM)
    _grid.add_theme_constant_override("v_separation", UiDesignScript.SPACE_SM)
    add_child(_grid)

func present(slots: Array, title_text: String = "功法槽") -> void:
    _title.text = title_text
    var values := slots.duplicate(true)
    while values.size() < 8:
        values.append({})
    var live_keys: Dictionary = {}
    var ordered: Array[Button] = []
    for index in range(mini(values.size(), 8)):
        var value: Dictionary = values[index]
        var key := _slot_key(value, index)
        live_keys[key] = true
        var button: Button = _slot_registry.get(key)
        if button == null or not is_instance_valid(button):
            button = _slot(value, index)
            _grid.add_child(button)
            _slot_registry[key] = button
        _update_slot(button, value, index)
        ordered.append(button)
    for key in _slot_registry.keys():
        if not live_keys.has(key):
            var stale = _slot_registry[key]
            _slot_registry.erase(key)
            if is_instance_valid(stale):
                stale.queue_free()
    for child in ordered:
        _grid.move_child(child, ordered.find(child))

func set_compact(value: bool) -> void:
    _compact = value
    custom_minimum_size = Vector2(220, 150) if _compact else Vector2(300, 250)
    _grid.add_theme_constant_override("h_separation", 4 if _compact else UiDesignScript.SPACE_SM)
    _grid.add_theme_constant_override("v_separation", 4 if _compact else UiDesignScript.SPACE_SM)
    for child in _grid.get_children():
        child.custom_minimum_size = Vector2(106, 27) if _compact else Vector2(142, 44)

func _slot(data: Dictionary, index: int) -> Button:
    var button := Button.new()
    button.name = "TechniqueSlot%d" % (index + 1)
    button.custom_minimum_size = Vector2(106, 27) if _compact else Vector2(142, 44)
    button.pressed.connect(func(): details_requested.emit("techniques", button.get_meta("payload", {})))
    button.mouse_entered.connect(func():
        var tooltip_data: Dictionary = button.get_meta("payload", {})
        tooltip_requested.emit({"kind": "technique", "title": str(tooltip_data.get("hand_name", "功法槽")),
            "subtitle": str(tooltip_data.get("technique_id", "空槽")), "description": str(tooltip_data.get("description", "")),
            "values": [{"label": "槽位", "value": "%d/%d" % [int(tooltip_data.get("occupied", 0)), int(tooltip_data.get("capacity", 0))]}],
            "tags": tooltip_data.get("tags", []), "placeholder": "?"}, button.get_global_rect()))
    button.mouse_exited.connect(func(): tooltip_hidden.emit())
    return button

func _slot_key(data: Dictionary, index: int) -> String:
    var stable := str(data.get("slot_instance_id", data.get("hand_id", data.get("technique_id", ""))))
    return "%d:%s" % [index, stable if stable != "" else "empty"]

func _update_slot(button: Button, data: Dictionary, index: int) -> void:
    button.name = "TechniqueSlot%d" % (index + 1)
    button.custom_minimum_size = Vector2(106, 27) if _compact else Vector2(142, 44)
    if data.is_empty():
        button.text = "未配置        —"
        button.disabled = true
    else:
        var technique_id := str(data.get("technique_id", ""))
        var value_text := "—" if technique_id == "" else str(data.get("occupied", 0))
        button.text = "%s        %s" % [data.get("hand_name", "功法"), value_text]
        button.tooltip_text = "%s\n当前功法：%s\n槽位 %d / %d" % [
            data.get("hand_name", ""),
            technique_id if technique_id != "" else "空",
            int(data.get("occupied", 0)), int(data.get("capacity", 0))]
    button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    button.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
    UiDesignScript.style_button(button, UiDesignScript.COLORS["panel"], 27 if _compact else 44)
    button.set_meta("payload", data.duplicate(true))
