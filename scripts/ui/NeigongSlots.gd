## 战斗内功槽显示；战斗中只读，不提供配装操作。
extends HBoxContainer
class_name NeigongSlots

## 阵营标识；player 显示玩家装备，enemy 显示敌方预留空槽。
@export var side: String = BattleQiState.SIDE_PLAYER

## 战斗开始、牌区变化或配装恢复时刷新槽位显示。
func _ready() -> void:
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.qi_zones_changed.connect(_on_qi_zones_changed)
	Signals.player_neigong_loadout_changed.connect(_on_neigong_loadout_changed)
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	refresh_slots()

## 从战斗现场读取当前阵营的内功槽快照。
func refresh_slots() -> void:
	clear_slots()
	var battle_state: BattleQiState = Global.get_qi_battle_state()
	if battle_state == null:
		return
	var slot_uids: Array[String] = battle_state.get_neigong_slot_uids(side)
	var slot_capacity: int = battle_state.get_neigong_slot_capacity(side)
	for slot_index: int in slot_capacity:
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(64, 40)
		slot_button.disabled = true
		var neigong_uid: String = slot_uids[slot_index] if slot_index < slot_uids.size() else ""
		if neigong_uid == "":
			slot_button.text = "空"
			slot_button.modulate = Color(1.0, 1.0, 1.0, 0.45)
		else:
			var neigong_data: NeigongData = Global.player_data.get_owned_neigong(neigong_uid)
			if neigong_data == null:
				slot_button.text = "未知"
			else:
				slot_button.text = neigong_data.neigong_name
				slot_button.tooltip_text = neigong_data.neigong_description
		add_child(slot_button)

## 清空当前显示节点。
func clear_slots() -> void:
	for child: Node in get_children():
		child.queue_free()

## 战斗开始后延迟一帧读取已经初始化的战斗快照。
func _on_combat_started(_event_id: String) -> void:
	call_deferred("refresh_slots")

## 牌区变化不改变槽位内容，但可处理战斗状态重新创建。
func _on_qi_zones_changed() -> void:
	if Global.get_qi_battle_state() != null:
		refresh_slots()

## 节点外配装变化在下一场战斗开始时生效。
func _on_neigong_loadout_changed() -> void:
	if Global.get_qi_battle_state() != null:
		refresh_slots()

## 战斗结束后隐藏旧的槽位内容，防止残留到下一节点。
func _on_combat_ended() -> void:
	clear_slots()

## 继续或读档时等待下一场战斗重新生成槽位。
func _on_run_started() -> void:
	clear_slots()

## 本局结束时清理槽位。
func _on_run_ended() -> void:
	clear_slots()
