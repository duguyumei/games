class_name AutosaveStatus
extends PanelContainer

signal retry_requested

const UiDesignScript = preload("res://ui/ui_design.gd")

var status_label: Label
var retry_button: Button
var last_detail: String = ""
var _built := false

func _ready() -> void:
    _ensure_built()

func present_idle(text: String = "等待自动保存") -> void:
    _ensure_built()
    status_label.text = text
    status_label.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    retry_button.visible = false

func present_success(_reason: String = "") -> void:
    _ensure_built()
    last_detail = ""
    status_label.text = "已自动保存"
    status_label.add_theme_color_override("font_color", Color("9ed8bd"))
    retry_button.visible = false

func present_failure(_reason: String, detail: String) -> void:
    _ensure_built()
    last_detail = detail
    status_label.text = "自动存档失败：%s" % detail
    status_label.add_theme_color_override("font_color", Color("ffad9d"))
    retry_button.visible = true

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color("172326"), 9, Color("3b5558"), 1, 2))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    status_label = Label.new()
    status_label.text = "等待自动保存"
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_label.add_theme_font_size_override("font_size", 13)
    row.add_child(status_label)
    retry_button = Button.new()
    retry_button.text = "重试保存"
    retry_button.visible = false
    retry_button.pressed.connect(func(): retry_requested.emit())
    UiDesignScript.style_button(retry_button)
    row.add_child(retry_button)
