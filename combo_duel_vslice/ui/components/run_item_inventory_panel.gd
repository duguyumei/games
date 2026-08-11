class_name RunItemInventoryPanel
extends VBoxContainer

## 输入 RunBuildDTO.items，只读展示本局永久物品及数量。
## 本组件不显示奇珍，也不输出丢弃、出售或装备命令。
## 不运行 design_only 物品效果。

var _list: VBoxContainer
var _built := false

func _ready() -> void:
    _ensure_built()

func present(build: RunBuildDTO) -> void:
    _ensure_built()
    for child in _list.get_children():
        child.queue_free()
    if build.items.is_empty():
        var empty := Label.new()
        empty.text = "本局尚未获得物品"
        _list.add_child(empty)
        return
    for item_value in build.items:
        var item: Dictionary = item_value
        var label := Label.new()
        label.text = "%s ×%d\n%s" % [
            item.get("name", item.get("id", "")),
            int(item.get("count", 1)),
            item.get("description", "")]
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _list.add_child(label)

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    var note := Label.new()
    note.text = "物品是独立的本局永久持有区，不占消耗品槽位或内功槽位。"
    add_child(note)
    _list = VBoxContainer.new()
    _list.add_theme_constant_override("separation", 12)
    add_child(_list)

