class_name BattleDebugDrawer
extends PanelContainer

signal reset_requested(seed: int)
signal channel_toggle_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var _debug_enabled := false
var _open := false
var _seed_input: SpinBox
var _log: RichTextLabel
var _raw: RichTextLabel

func _ready() -> void:
    name = "BattleDebugDrawer"
    set_anchors_preset(Control.PRESET_CENTER_LEFT)
    offset_left = 18
    offset_right = 470
    offset_top = -330
    offset_bottom = 330
    z_index = 500
    add_theme_stylebox_override("panel", UiDesignScript.box(
        UiDesignScript.COLORS["ink"], UiDesignScript.RADIUS_LG,
        UiDesignScript.COLORS["purple"], UiDesignScript.BORDER_REGULAR, 10))
    var column := VBoxContainer.new()
    add_child(column)
    var header := HBoxContainer.new()
    column.add_child(header)
    var title := Label.new()
    title.text = "调试抽屉"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", UiDesignScript.FONT_TITLE)
    header.add_child(title)
    var close := Button.new()
    close.text = "关闭"
    close.pressed.connect(func(): set_open(false))
    UiDesignScript.style_button(close)
    header.add_child(close)
    var tools := HBoxContainer.new()
    column.add_child(tools)
    var seed_label := Label.new()
    seed_label.text = "种子"
    tools.add_child(seed_label)
    _seed_input = SpinBox.new()
    _seed_input.min_value = 0
    _seed_input.max_value = 99999999
    _seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tools.add_child(_seed_input)
    var reset := Button.new()
    reset.text = "重置战斗"
    reset.pressed.connect(func(): reset_requested.emit(int(_seed_input.value)))
    UiDesignScript.style_button(reset)
    tools.add_child(reset)
    var channel := Button.new()
    channel.text = "切换日志"
    channel.pressed.connect(func(): channel_toggle_requested.emit())
    UiDesignScript.style_button(channel)
    tools.add_child(channel)
    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(tabs)
    _log = RichTextLabel.new()
    _log.name = "完整日志"
    _log.bbcode_enabled = true
    _log.scroll_active = true
    tabs.add_child(_log)
    _raw = RichTextLabel.new()
    _raw.name = "原始状态"
    _raw.bbcode_enabled = true
    _raw.scroll_active = true
    tabs.add_child(_raw)
    configure_mode(false)

func configure_mode(enabled: bool) -> void:
    _debug_enabled = enabled
    if not _debug_enabled:
        _open = false
    visible = _debug_enabled and _open

func present(data: Dictionary) -> void:
    _seed_input.value = int(data.get("seed", 2308))
    var channel := str(data.get("active_channel", "battle"))
    var history: Array = data.get("battle_log", []) if channel == "battle" else data.get("system_log", [])
    var lines: Array[String] = []
    for value in history:
        var entry: Dictionary = value
        lines.append("[b]%s[/b]  %s\n%s" % [
            entry.get("category", ""), entry.get("message", ""), entry.get("detail", "")])
    _log.text = "\n\n".join(lines) if not lines.is_empty() else "当前通道暂无记录。"
    _raw.text = "[code]%s[/code]" % JSON.stringify(data.get("raw_state", {}), "  ")

func set_open(value: bool) -> void:
    _open = value and _debug_enabled
    visible = _open

func toggle() -> void:
    set_open(not _open)

func is_open() -> bool:
    return _open

func is_debug_enabled() -> bool:
    return _debug_enabled
