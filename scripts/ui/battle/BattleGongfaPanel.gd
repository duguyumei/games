## 真气战斗 HUD 的八条功法循环队列显示组件。
extends VBoxContainer
class_name BattleGongfaPanel

## 当前组件所属阵营。
var side: String = BattleQiState.SIDE_PLAYER

## 设置阵营并刷新功法序列。
func setup(_side: String) -> void:
	side = _side

## 显示八种牌型的当前循环队列和容量。
func refresh(battle_state: BattleQiState) -> void:
	for child: Node in get_children():
		child.queue_free()
	var title: Label = Label.new()
	title.text = "功法循环"
	title.add_theme_font_size_override("font_size", 13)
	add_child(title)
	if battle_state == null:
		return
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		var entries: Array[Dictionary] = battle_state.get_gongfa_queue_entries(side, hand_type_id)
		var capacity: int = battle_state.get_gongfa_queue_capacity(side, hand_type_id)
		var row: Label = Label.new()
		row.text = "%s  %s/%d" % [
			_get_hand_type_name(hand_type_id), _get_entry_names(entries), capacity]
		row.add_theme_font_size_override("font_size", 10)
		row.clip_text = true
		add_child(row)

func _get_entry_names(entries: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for entry: Dictionary in entries:
		var definition_id: String = str(entry.get("gongfa_definition_id", ""))
		var gongfa_data: GongfaData = Global.get_gongfa_data(definition_id)
		names.append(gongfa_data.gongfa_name if gongfa_data != null else definition_id)
	return "、".join(names) if not names.is_empty() else "空"

func _get_hand_type_name(hand_type_id: String) -> String:
	var names: Dictionary = {
		"high_card": "高牌",
		"pair": "对子",
		"two_pair": "双对",
		"three_kind": "三条",
		"straight": "顺子",
		"full_house": "葫芦",
		"four_kind": "四条",
		"five_kind": "五条",
	}
	return str(names.get(hand_type_id, hand_type_id))
