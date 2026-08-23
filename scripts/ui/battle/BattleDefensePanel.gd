## 真气战斗 HUD 的护盾、格挡和化解摘要组件。
extends HBoxContainer
class_name BattleDefensePanel

## 当前组件所属阵营。
var side: String = BattleQiState.SIDE_PLAYER

## 悬停时显示来源详情的面板。
var _hover_detail: BattleHoverDetail

## 创建三个非零时才显示的防御芯片。
func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	_hover_detail = BattleHoverDetail.new()
	_hover_detail.z_index = 100
	add_child(_hover_detail)

## 从战斗状态刷新防御摘要和悬停来源。
func refresh(_battle_state: BattleQiState) -> void:
	for child: Node in get_children():
		if child != _hover_detail:
			child.free()
	if _battle_state == null:
		return
	_add_chip("防", BattleDefenseEntry.KIND_SHIELD, _battle_state.get_shield_entries(side))
	_add_chip("挡", BattleDefenseEntry.KIND_GUARD, _battle_state.get_guard_entries(side))
	_add_chip("解", BattleDefenseEntry.KIND_RESOLUTION, _battle_state.get_resolution_entries(side))

func _add_chip(
		prefix: String,
		kind: String,
		entries: Array[BattleDefenseEntry]) -> void:
	var total: int = 0
	for entry: BattleDefenseEntry in entries:
		total += int(entry.value)
	if total <= 0:
		return
	var chip: Button = Button.new()
	chip.text = "%s%d" % [prefix, total if kind != BattleDefenseEntry.KIND_GUARD else entries.size()]
	chip.flat = false
	chip.custom_minimum_size = Vector2(54.0, 28.0)
	chip.tooltip_text = _build_tooltip(entries)
	chip.mouse_entered.connect(func() -> void:
		_hover_detail.show_entries(entries, global_position + Vector2(0.0, size.y + 4.0)))
	chip.mouse_exited.connect(_hover_detail.hide_detail)
	add_child(chip)

func _build_tooltip(entries: Array[BattleDefenseEntry]) -> String:
	var lines: Array[String] = []
	for entry: BattleDefenseEntry in entries:
		lines.append("来源 %s，%s" % [entry.source_kind, _duration_text(entry)])
	return "\n".join(lines)

func _duration_text(entry: BattleDefenseEntry) -> String:
	if entry.duration_scope == BattleDefenseEntry.SCOPE_ROUNDS:
		return "剩余 %d 回合" % entry.remaining_rounds
	if entry.duration_scope == BattleDefenseEntry.SCOPE_HITS:
		return "剩余 %d 次" % entry.remaining_hits
	return "持续本场战斗"
