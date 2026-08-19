class_name BattleSideDrawer
extends PanelContainer

signal open_changed(open: bool)

const UiDesignScript = preload("res://ui/ui_design.gd")

var _open := false
var _tabs: TabContainer
var _toggle: Button
var _detail_label: RichTextLabel
var _sections := {}

func _ready() -> void:
    name = "BattleSideDrawer"
    set_anchors_preset(Control.PRESET_CENTER_RIGHT)
    offset_left = -420
    offset_right = -18
    offset_top = -310
    offset_bottom = 310
    z_index = 420
    add_theme_stylebox_override("panel", UiDesignScript.box(
        UiDesignScript.COLORS["ink"], UiDesignScript.RADIUS_LG,
        UiDesignScript.COLORS["copper_dark"], UiDesignScript.BORDER_REGULAR, 10))
    var column := VBoxContainer.new()
    add_child(column)
    var header := HBoxContainer.new()
    column.add_child(header)
    var title := Label.new()
    title.text = "构筑与详情"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", UiDesignScript.FONT_TITLE)
    header.add_child(title)
    _toggle = Button.new()
    _toggle.text = "收起"
    _toggle.pressed.connect(toggle)
    UiDesignScript.style_button(_toggle)
    header.add_child(_toggle)
    _tabs = TabContainer.new()
    _tabs.name = "DrawerTabs"
    _tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(_tabs)
    for section in ["功法序列", "内功", "消耗品", "卡牌详情", "状态详情"]:
        var scroll := ScrollContainer.new()
        scroll.name = section
        var label := RichTextLabel.new()
        label.name = "Content"
        label.bbcode_enabled = true
        label.fit_content = true
        label.custom_minimum_size.x = 340
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(label)
        _tabs.add_child(scroll)
        _sections[section] = label
    _detail_label = _sections["卡牌详情"]
    set_open(false, false)

func present(snapshot: Dictionary) -> void:
    var player: Dictionary = snapshot.get("player", {})
    var sequences: Array = snapshot.get("technique_sequences", {}).get("player", [])
    _sections["功法序列"].text = _sequence_text(sequences)
    _sections["内功"].text = _list_text(player.get("inner_skills", []), "name", "尚未装备内功")
    _sections["消耗品"].text = _list_text(player.get("consumables", []), "name", "当前没有消耗品")
    _sections["状态详情"].text = _status_text(player.get("statuses", []))

func show_detail(section: String, payload: Dictionary) -> void:
    var tab_name: String = {
        "techniques": "功法序列",
        "inner_skills": "内功",
        "consumables": "消耗品",
        "statuses": "状态详情",
    }.get(section, "卡牌详情")
    var index := _tab_index(tab_name)
    if index >= 0:
        _tabs.current_tab = index
    if tab_name == "卡牌详情":
        _detail_label.text = "[b]%s[/b]\n\n%s" % [
            payload.get("name", payload.get("id", "详情")),
            payload.get("description", JSON.stringify(payload, "  "))]
    set_open(true)

func set_open(value: bool, animate: bool = true) -> void:
    _open = value
    mouse_filter = Control.MOUSE_FILTER_STOP if _open else Control.MOUSE_FILTER_IGNORE
    if not animate or not is_inside_tree():
        visible = _open
        modulate.a = 1.0
    elif _open:
        visible = true
        modulate.a = 0.0
        var tween := create_tween()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(self, "modulate:a", 1.0, UiDesignScript.ANIMATION_NORMAL)
    else:
        var tween := create_tween()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(self, "modulate:a", 0.0, UiDesignScript.ANIMATION_FAST)
        tween.tween_callback(func(): visible = false)
    open_changed.emit(_open)

func toggle() -> void:
    set_open(not _open)

func is_open() -> bool:
    return _open

func _tab_index(tab_name: String) -> int:
    for index in range(_tabs.get_tab_count()):
        if _tabs.get_tab_title(index) == tab_name:
            return index
    return -1

func _sequence_text(slots: Array) -> String:
    if slots.is_empty():
        return "当前没有功法序列。"
    var lines: Array[String] = []
    for value in slots:
        var slot: Dictionary = value
        lines.append("[b]%s[/b]  %s  [%d/%d]" % [
            slot.get("hand_name", "功法"),
            slot.get("technique_id", "空"),
            int(slot.get("occupied", 0)), int(slot.get("capacity", 0))])
    return "\n\n".join(lines)

func _list_text(values: Array, key: String, empty_text: String) -> String:
    if values.is_empty():
        return empty_text
    var lines: Array[String] = []
    for value in values:
        if value is Dictionary:
            lines.append("• %s\n  %s" % [value.get(key, "未命名"), value.get("description", "")])
        else:
            lines.append("• %s" % str(value))
    return "\n\n".join(lines)

func _status_text(values: Array) -> String:
    if values.is_empty():
        return "当前没有状态。"
    return "\n\n".join(values.map(func(value): return "• %s" % str(value.get("text", ""))))
