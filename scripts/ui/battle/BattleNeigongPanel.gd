## 真气战斗 HUD 的内功槽显示组件；战斗中只读。
extends VBoxContainer
class_name BattleNeigongPanel

## 当前组件所属阵营。
var side: String = BattleQiState.SIDE_PLAYER

## 设置阵营并刷新内功槽。
func setup(_side: String) -> void:
	side = _side

## 显示敌我实际配置的内功和剩余空槽。
func refresh(battle_state: BattleQiState) -> void:
	for child: Node in get_children():
		child.queue_free()
	var title: Label = Label.new()
	title.text = "内功"
	title.add_theme_font_size_override("font_size", 13)
	add_child(title)
	if battle_state == null:
		return
	var entries: Array[Dictionary] = battle_state.get_neigong_slot_entries(side)
	var capacity: int = battle_state.get_neigong_slot_capacity(side)
	for slot_index: int in capacity:
		var slot_label: Label = Label.new()
		if slot_index < entries.size():
			slot_label.text = "%d  %s" % [slot_index + 1, entries[slot_index].get("name", "空槽")]
		else:
			slot_label.text = "%d  空槽" % (slot_index + 1)
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.clip_text = true
		add_child(slot_label)
