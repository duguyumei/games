class_name BattleActionBar
extends VBoxContainer

signal confirm_requested
signal end_turn_requested
signal start_turn_requested
signal consumable_selected(slot_index: int)
signal consumable_use_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var _consumable_row: HBoxContainer
var _confirm_button: Button
var _end_button: Button
var _start_button: Button
var _active_slot := -1

func _ready() -> void:
    name = "BattleActionBar"
    custom_minimum_size.x = 286
    add_theme_constant_override("separation", UiDesignScript.SPACE_SM)
    _consumable_row = HBoxContainer.new()
    _consumable_row.name = "ConsumableCards"
    _consumable_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _consumable_row.add_theme_constant_override("separation", -10)
    add_child(_consumable_row)
    var buttons := HBoxContainer.new()
    buttons.name = "PrimaryActions"
    buttons.add_theme_constant_override("separation", UiDesignScript.SPACE_SM)
    add_child(buttons)
    _confirm_button = Button.new()
    _confirm_button.name = "ConfirmAction"
    _confirm_button.text = "确认出牌"
    _confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _confirm_button.pressed.connect(func(): confirm_requested.emit())
    UiDesignScript.style_button(_confirm_button, UiDesignScript.COLORS["copper"], 52)
    buttons.add_child(_confirm_button)
    _end_button = Button.new()
    _end_button.name = "EndTurn"
    _end_button.text = "结束回合"
    _end_button.pressed.connect(func(): end_turn_requested.emit())
    UiDesignScript.style_button(_end_button, UiDesignScript.COLORS["panel_2"], 52)
    buttons.add_child(_end_button)
    _start_button = Button.new()
    _start_button.name = "StartTurn"
    _start_button.text = "补牌"
    _start_button.pressed.connect(func(): start_turn_requested.emit())
    UiDesignScript.style_button(_start_button, UiDesignScript.COLORS["panel_2"], 52)
    buttons.add_child(_start_button)

func present(consumables: Array, active_slot: int, commands: Dictionary) -> void:
    _active_slot = active_slot
    _confirm_button.disabled = not bool(commands.get("confirm", false))
    _end_button.disabled = not bool(commands.get("end_turn", false))
    _start_button.visible = bool(commands.get("start_turn", false))
    for child in _consumable_row.get_children():
        child.queue_free()
    for index in range(consumables.size()):
        var data: Dictionary = consumables[index]
        var button := Button.new()
        button.name = "Consumable%d" % index
        button.text = "%s\n%s\n×%d" % [
            str(data.get("name", "消耗品")).left(1),
            str(data.get("name", "未命名")), int(data.get("count", 1))]
        button.tooltip_text = "%s\n%s" % [data.get("name", ""), data.get("description", "")]
        button.custom_minimum_size = UiDesignScript.COMPACT_CARD_SIZE
        button.add_theme_font_size_override("font_size", UiDesignScript.FONT_CAPTION)
        var active := index == _active_slot
        var fill := UiDesignScript.COLORS["panel"] if not active else Color("3b3120")
        var border := UiDesignScript.COLORS["copper_dark"] if not active else UiDesignScript.COLORS["gold"]
        button.add_theme_stylebox_override("normal", UiDesignScript.box(
            fill, 9, border, 3, 5, Vector2(5, 5)))
        button.pressed.connect(func(): consumable_selected.emit(index))
        _consumable_row.add_child(button)
    if _active_slot >= 0:
        var use := Button.new()
        use.name = "UseConsumable"
        use.text = "使用"
        use.disabled = not bool(commands.get("use_consumable", false))
        use.pressed.connect(func(): consumable_use_requested.emit())
        UiDesignScript.style_button(use, UiDesignScript.COLORS["copper"], 46)
        _consumable_row.add_child(use)

func primary_actions_rect() -> Rect2:
    var result := _confirm_button.get_global_rect()
    result = result.merge(_end_button.get_global_rect())
    if _start_button.visible:
        result = result.merge(_start_button.get_global_rect())
    return result
