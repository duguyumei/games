class_name NodeInteractionOverlay
extends ColorRect

signal commit_requested(
    interaction_token: String,
    choice_id: String,
    choice_payload: Dictionary)
signal finish_requested(interaction_token: String)

const UiDesignScript = preload("res://ui/ui_design.gd")

var title_label: Label
var description_label: Label
var choices_box: VBoxContainer
var submit_button: Button
var finish_button: Button
var interaction: Dictionary = {}
var selected_choice_id: String = ""
var _built := false

func _ready() -> void:
    _ensure_built()

func present(frozen_interaction: Dictionary) -> void:
    _ensure_built()
    interaction = frozen_interaction.duplicate(true)
    selected_choice_id = ""
    title_label.text = str(interaction.get("title", "节点选择"))
    description_label.text = str(interaction.get("description", ""))
    for child in choices_box.get_children():
        child.queue_free()
    var group := ButtonGroup.new()
    for choice_value in interaction.get("choices", []):
        if not choice_value is Dictionary:
            continue
        var choice: Dictionary = choice_value
        var button := Button.new()
        button.toggle_mode = true
        button.button_group = group
        button.text = "%s\n%s" % [
            str(choice.get("label", choice.get("id", ""))),
            str(choice.get("description", "")),
        ]
        button.disabled = not bool(choice.get("enabled", true))
        button.tooltip_text = str(choice.get("disabled_reason", ""))
        button.custom_minimum_size = Vector2(560, 68)
        button.pressed.connect(_select_choice.bind(str(choice.get("id", ""))))
        UiDesignScript.style_button(button)
        choices_box.add_child(button)
    submit_button.disabled = true
    finish_button.visible = bool(interaction.get("allow_finish", false))
    finish_button.disabled = not bool(interaction.get("allow_finish", false))
    visible = true

func _select_choice(choice_id: String) -> void:
    selected_choice_id = choice_id
    submit_button.disabled = selected_choice_id == ""

func _submit() -> void:
    if selected_choice_id == "":
        return
    commit_requested.emit(
        str(interaction.get("interaction_token", "")),
        selected_choice_id,
        {})

func _finish() -> void:
    finish_requested.emit(str(interaction.get("interaction_token", "")))

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    color = Color(0.01, 0.02, 0.025, 0.96)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    z_index = 210
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(700, 520)
    panel.add_theme_stylebox_override(
        "panel", UiDesignScript.box(
            Color("18252a"), 20, UiDesignScript.COLORS["gold"], 2, 12))
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 16)
    panel.add_child(box)
    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 28)
    box.add_child(title_label)
    description_label = Label.new()
    description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description_label.custom_minimum_size.y = 70
    box.add_child(description_label)
    choices_box = VBoxContainer.new()
    choices_box.add_theme_constant_override("separation", 10)
    box.add_child(choices_box)
    submit_button = Button.new()
    submit_button.text = "确认选择"
    submit_button.custom_minimum_size = Vector2(260, 54)
    submit_button.pressed.connect(_submit)
    UiDesignScript.style_button(submit_button)
    box.add_child(submit_button)
    finish_button = Button.new()
    finish_button.text = "结束本次选择"
    finish_button.custom_minimum_size = Vector2(260, 48)
    finish_button.pressed.connect(_finish)
    UiDesignScript.style_button(finish_button, UiDesignScript.COLORS["panel_2"])
    box.add_child(finish_button)
