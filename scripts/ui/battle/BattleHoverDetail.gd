## 真气战斗 HUD 的悬停详情面板。
extends Panel
class_name BattleHoverDetail

var _detail_label: Label

## 创建默认隐藏的详情面板。
func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _make_style())
	_detail_label = Label.new()
	_detail_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_label.offset_left = 8.0
	_detail_label.offset_top = 6.0
	_detail_label.offset_right = -8.0
	_detail_label.offset_bottom = -6.0
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 12)
	add_child(_detail_label)

## 显示一组来源条目的持续时间和剩余次数。
func show_entries(entries: Array[BattleDefenseEntry], screen_position: Vector2) -> void:
	var lines: Array[String] = []
	for entry: BattleDefenseEntry in entries:
		lines.append("%s  %s  %s" % [
			entry.source_kind,
			_get_value_text(entry),
			_get_duration_text(entry)])
	_detail_label.text = "\n".join(lines) if not lines.is_empty() else "无来源"
	position = screen_position
	size = Vector2(210.0, max(42.0, 24.0 + lines.size() * 20.0))
	visible = true

## 隐藏详情面板。
func hide_detail() -> void:
	visible = false

func _get_value_text(entry: BattleDefenseEntry) -> String:
	if entry.kind == BattleDefenseEntry.KIND_REFLECT:
		return "反震 %s%%" % int(entry.value)
	return str(int(entry.value))

func _get_duration_text(entry: BattleDefenseEntry) -> String:
	if entry.duration_scope == BattleDefenseEntry.SCOPE_ROUNDS:
		return "余 %d 回合" % entry.remaining_rounds
	if entry.duration_scope == BattleDefenseEntry.SCOPE_HITS:
		return "余 %d 次" % entry.remaining_hits
	return "本场"

func _make_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#242b3b")
	style.border_color = Color("#8e9bb8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
