class_name RewardOverlay
extends ColorRect

signal claim_requested(bundle_id: String)

const UiDesignScript = preload("res://ui/ui_design.gd")

var _title: Label
var _entries: VBoxContainer
var _bundle_id := ""
var _built := false

func _ready() -> void:
    _ensure_built()

func present(bundle: Dictionary) -> void:
    _ensure_built()
    _bundle_id = str(bundle.get("id", ""))
    _title.text = {
        "combat": "战斗胜利", "elite": "精英战胜利", "boss": "Boss 战胜利",
        "event": "事件完成", "rest": "休息完成", "treasure": "宝箱节点完成",
    }.get(str(bundle.get("node_type", "")), "节点完成")
    for child in _entries.get_children():
        child.queue_free()
    var entries: Array = bundle.get("entries", [])
    if entries.is_empty():
        _entries.add_child(_entry_label("本节点暂无已确认的基础奖励", 22, UiDesignScript.COLORS["muted"]))
    for value in entries:
        var entry: Dictionary = value
        var text_value := (
            "历练　+%d" % int(entry.get("amount", 0))
            if str(entry.get("kind", "")) == "experience"
            else "%s（尚未接入）" % str(entry.get("kind", "未知奖励")))
        _entries.add_child(_entry_label(text_value, 28, UiDesignScript.COLORS["gold"]))
    visible = true

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color(0.018, 0.026, 0.03, 0.94)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    z_index = 190
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(720, 470)
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(Color("25251f"), 22, UiDesignScript.COLORS["gold"], 3, 16))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 20)
    panel.add_child(box)
    _title = Label.new()
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 34)
    _title.add_theme_color_override("font_color", Color("ffe4a2"))
    box.add_child(_title)
    var subtitle := Label.new()
    subtitle.text = "领取本次节点奖励后返回地图"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", UiDesignScript.COLORS["muted"])
    box.add_child(subtitle)
    box.add_child(UiDesignScript.divider())
    _entries = VBoxContainer.new()
    _entries.alignment = BoxContainer.ALIGNMENT_CENTER
    _entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _entries.add_theme_constant_override("separation", 12)
    box.add_child(_entries)
    var claim := Button.new()
    claim.text = "领取并继续"
    claim.custom_minimum_size = Vector2(300, 60)
    claim.pressed.connect(func(): claim_requested.emit(_bundle_id))
    UiDesignScript.style_button(claim)
    box.add_child(claim)
    var note := Label.new()
    note.text = "自我精进及其与内功收益的结算顺序尚未确认，本页面暂不结算。"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_color_override("font_color", Color("877f8b"))
    box.add_child(note)

func _entry_label(text_value: String, font_size: int, color_value: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color_value)
    return label
