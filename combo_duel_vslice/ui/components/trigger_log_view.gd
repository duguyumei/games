class_name TriggerLogView
extends PanelContainer

signal close_requested
signal channel_toggle_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var _delayed_badge: Label
var _channel_button: Button
var _subtitle: Label
var _log_label: RichTextLabel
var _built := false

func _ready() -> void:
    _ensure_built()

func present(data: Dictionary) -> void:
    _ensure_built()
    var channel := str(data.get("channel", "battle"))
    var history: Array = data.get("history", [])
    _delayed_badge.text = "延迟 %d" % int(data.get("delayed_count", 0))
    _channel_button.text = "系统日志" if channel == "battle" else "战斗日志"
    _subtitle.text = (
        "战斗日志 · 同一时点从左到右实时结算"
        if channel == "battle" else "系统日志 · 会话、命令与内容加载诊断")
    var lines: Array[String] = []
    var start := maxi(0, history.size() - 13)
    for index in range(start, history.size()):
        var entry: Dictionary = history[index]
        var status := str(entry.get("context", {}).get("status", entry.get("severity", "info")))
        var success: bool = entry.get("severity", "info") not in ["warning", "error"]
        var color := "#efbd50" if success else "#df6a61"
        lines.append((
            "[color=#657478]%02d  %s[/color]\n"
            + "[color=%s]●[/color] [b]%s[/b]  [color=#a7b1b2]%s[/color]\n"
            + "[color=#849092]%s[/color]") % [
                int(entry.get("serial", index)) + 1, entry.get("category", ""), color,
                entry.get("message", ""), status, entry.get("detail", "")])
    _log_label.text = (
        "\n\n".join(lines) if not lines.is_empty()
        else "[color=#768485]当前通道暂无记录……[/color]")
    _log_label.scroll_to_line(maxi(0, lines.size() * 3 - 1))

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    set_anchors_preset(Control.PRESET_TOP_RIGHT)
    offset_left = -382
    offset_top = 72
    offset_right = -18
    offset_bottom = 700
    z_index = 500
    visible = false
    add_theme_stylebox_override(
        "panel", UiDesignScript.box(UiDesignScript.COLORS["ink"], 13, Color("0b1216"), 3, 10))
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    add_child(box)
    var header := HBoxContainer.new()
    box.add_child(header)
    var title := Label.new()
    title.text = "触发历史"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 18)
    header.add_child(title)
    _delayed_badge = UiDesignScript.chip("延迟 0", UiDesignScript.COLORS["purple"])
    header.add_child(_delayed_badge)
    _channel_button = Button.new()
    _channel_button.tooltip_text = "切换战斗结算日志与系统诊断日志"
    _channel_button.pressed.connect(func(): channel_toggle_requested.emit())
    UiDesignScript.style_button(_channel_button)
    header.add_child(_channel_button)
    var close := Button.new()
    close.text = "×"
    close.tooltip_text = "关闭结算记录"
    close.pressed.connect(func(): close_requested.emit())
    UiDesignScript.style_button(close)
    header.add_child(close)
    _subtitle = Label.new()
    _subtitle.add_theme_font_size_override("font_size", 11)
    _subtitle.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    box.add_child(_subtitle)
    box.add_child(UiDesignScript.divider())
    _log_label = RichTextLabel.new()
    _log_label.bbcode_enabled = true
    _log_label.scroll_active = true
    _log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _log_label.add_theme_font_size_override("normal_font_size", 13)
    box.add_child(_log_label)
    var rule := Label.new()
    rule.text = "牌型基准值不会自动造成伤害\n弃牌堆不会自动洗回牌库"
    rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rule.add_theme_font_size_override("font_size", 11)
    rule.add_theme_color_override("font_color", Color("768485"))
    box.add_child(rule)
