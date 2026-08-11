class_name RunDeckPanel
extends VBoxContainer

## 输入 RunBuildDTO.cards，按实例展示本局全部真气。
## 输出仅为本组件内部的排序视图，不发送领域命令。
## 不修改牌组，也不判断任何真气改造是否合法。

var _summary: Label
var _tree: Tree
var _cards: Array = []
var _sort_mode: String = "attribute"
var _built := false

func _ready() -> void:
    _ensure_built()

func present(build: RunBuildDTO) -> void:
    _ensure_built()
    _cards = build.cards.duplicate(true)
    _render()

func set_sort_mode(mode: String) -> void:
    if not ["attribute", "rank"].has(mode):
        return
    _sort_mode = mode
    _render()

func _ensure_built() -> void:
    if _built:
        return
    _built = true
    add_theme_constant_override("separation", 8)
    var toolbar := HBoxContainer.new()
    var by_attribute := Button.new()
    by_attribute.text = "按属性排序"
    by_attribute.pressed.connect(func(): set_sort_mode("attribute"))
    toolbar.add_child(by_attribute)
    var by_rank := Button.new()
    by_rank.text = "按牌阶排序"
    by_rank.pressed.connect(func(): set_sort_mode("rank"))
    toolbar.add_child(by_rank)
    _summary = Label.new()
    _summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    toolbar.add_child(_summary)
    add_child(toolbar)
    _tree = Tree.new()
    _tree.columns = 6
    _tree.set_column_title(0, "真气")
    _tree.set_column_title(1, "实例")
    _tree.set_column_title(2, "牌阶")
    _tree.set_column_title(3, "属性")
    _tree.set_column_title(4, "真气值")
    _tree.set_column_title(5, "本源 / 强化 / 印记 / 其他")
    _tree.column_titles_visible = true
    _tree.hide_root = true
    _tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tree.custom_minimum_size.y = 420
    add_child(_tree)

func _render() -> void:
    if _tree == null:
        return
    var ordered := _cards.duplicate(true)
    ordered.sort_custom(func(left, right):
        var left_key := _sort_key(left)
        var right_key := _sort_key(right)
        return left_key < right_key)
    _tree.clear()
    var root := _tree.create_item()
    for card_value in ordered:
        var card: Dictionary = card_value
        var row := _tree.create_item(root)
        row.set_text(0, str(card.get("display_name", "")))
        row.set_text(1, _short_instance_id(str(card.get("instance_id", ""))))
        row.set_text(2, str(card.get("rank", "")))
        row.set_text(3, str(card.get("attribute_name", "")))
        row.set_text(4, str(card.get("qi_value", 0)))
        row.set_text(5, _reshape_text(card))
        row.set_tooltip_text(1, str(card.get("instance_id", "")))
    _summary.text = "本局真气 %d 张" % ordered.size()

func _sort_key(card: Dictionary) -> String:
    var attribute := str(card.get("attribute", ""))
    var rank_order := int(card.get("rank_order", 0))
    return (
        "%s:%03d:%s" % [attribute, rank_order, card.get("instance_id", "")]
        if _sort_mode == "attribute"
        else "%03d:%s:%s" % [rank_order, attribute, card.get("instance_id", "")])

func _short_instance_id(instance_id: String) -> String:
    if instance_id.length() <= 12:
        return instance_id
    return "…%s" % instance_id.right(10)

func _reshape_text(card: Dictionary) -> String:
    var values: Array[String] = []
    for field in ["origin_name", "enhancement_name", "imprint_name"]:
        var name := str(card.get(field, ""))
        if name != "":
            values.append(name)
    values.append_array(card.get("other_names", []))
    return "无" if values.is_empty() else " / ".join(values)

