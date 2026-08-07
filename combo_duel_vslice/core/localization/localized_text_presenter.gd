class_name LocalizedTextPresenter
extends RefCounted

const CHINESE_FONT_FAMILIES := [
    "Noto Sans CJK SC",
    "Source Han Sans SC",
    "PingFang SC",
    "Microsoft YaHei",
    "Arial Unicode MS",
    "sans-serif",
]

static var _configured_font: Font


static func apply(control: Control, value: String, tooltip: String = "") -> void:
    if control == null:
        return
    control.add_theme_font_override("font", fallback_font())
    control.tooltip_text = tooltip
    if control is Label:
        control.text = value
        control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    elif control is RichTextLabel:
        control.text = value
        control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    elif control is Button:
        control.text = value


static func fallback_font() -> Font:
    if _configured_font != null:
        return _configured_font
    # macOS 的 headless TextServer 无法可靠解析 SystemFont 字体集合；测试环境使用
    # Godot 内置 fallback，实际窗口环境按顺序选择首个可用中文字体。
    if DisplayServer.get_name() == "headless":
        _configured_font = ThemeDB.fallback_font
        return _configured_font
    var system_font := SystemFont.new()
    system_font.font_names = PackedStringArray(CHINESE_FONT_FAMILIES)
    system_font.allow_system_fallback = true
    _configured_font = system_font
    return _configured_font
