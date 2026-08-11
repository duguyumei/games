class_name RunConsumablePanel
extends VBoxContainer

## 输入 RunBuildDTO.consumables，保持三个共享槽位的原始顺序。
## 输出 slot_activated(slot_index)，由上层查询正式使用协议。
## 不判断目标、选择数量、随机预览或具体消耗品效果。

signal slot_activated(slot_index: int)

const KIND_NAMES := {
    "insight": "心得",
    "pill": "丹药",
    "curio": "奇珍",
}

var _slot_row: HBoxContainer
var _hint: Label
var _built := false

func _ready() -> void:
    _ensure_built()

func present(build: RunBuildDTO) -> void:
    _ensure_built()
    for child in _slot_row.get_children():
        child.queue_free()
    for slot_value in build.consumables:
        var slot: Dictionary = slot_value
        var button := Button.new()
        button.custom_minimum_size = Vector2(260, 150)
        var content_id := str(slot.get("id", ""))
        button.text = (
            "槽位 %d\n空槽" % (int(slot.get("slot_index", 0)) + 1)
            if content_id == ""
            else "槽位 %d · %s\n%s\n%s" % [
                int(slot.get("slot_index", 0)) + 1,
                KIND_NAMES.get(str(slot.get("kind", "")), slot.get("kind", "")),
                slot.get("name", content_id),
                slot.get("description", "")])
        button.disabled = content_id == ""
        var slot_index := int(slot.get("slot_index", -1))
        button.pressed.connect(func(): slot_activated.emit(slot_index))
        _slot_row.add_child(button)
    _hint.text = (
        "可修改" if build.editable
        else "只读：%s" % build.blocked_reason)

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    add_theme_constant_override("separation", 12)
    _hint = Label.new()
    add_child(_hint)
    _slot_row = HBoxContainer.new()
    _slot_row.add_theme_constant_override("separation", 14)
    _slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
    add_child(_slot_row)
    var note := Label.new()
    note.text = "心得、丹药与奇珍共用以上 3 个槽位；点击非空槽位后由核心查询合法目标与选择协议。"
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(note)

