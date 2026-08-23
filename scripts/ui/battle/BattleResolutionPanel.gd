## 真气行动确认后的牌型和功法值结算面板。
extends PanelContainer
class_name BattleResolutionPanel

var _label: Label

## 创建默认隐藏的中央结算信息。
func _ready() -> void:
	visible = false
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	margin.add_child(_label)

## 展示双方冻结的牌型、同气、真气值和功法值。
func show_request(request: QiActionRequest) -> void:
	if request == null:
		return
	var lines: Array[String] = ["定招结算"]
	lines.append(_format_side("我方", request.player_result))
	lines.append(_format_side("敌方", request.enemy_result))
	_label.text = "\n".join(lines)
	visible = true

## 隐藏结算面板。
func hide_resolution() -> void:
	visible = false

func _format_side(side_name: String, result: QiActionSideResult) -> String:
	if result == null or result.pattern == null or not result.pattern.is_valid():
		return "%s  无有效牌型" % side_name
	var counts: Array[String] = []
	for attribute_id: String in QiData.ATTRIBUTE_IDS:
		counts.append("%s%d" % [attribute_id, result.attribute_counts.get(attribute_id, 0)])
	return "%s  %s  同气%s  C%d  M%d  P%d" % [
		side_name,
		_get_hand_type_name(result.pattern.hand_type_id),
		"/".join(counts),
		result.qi_value_sum,
		result.final_multiplier,
		result.effective_power]

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
