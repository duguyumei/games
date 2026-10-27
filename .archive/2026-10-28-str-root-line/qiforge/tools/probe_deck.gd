## 验收探针（无头）：卡组按档重构——《基础规则 v0.4》§2：每心法 2 术法 × 各 2 张；
## 选两门后卡组＝8 张术法牌（X·术法一×2＋X·术法二×2），无占位杂牌
extends SceneTree
var _frames: int = 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/Root.tscn")
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		var rs = root.find_child("RunScreen", true, false)
		if rs != null: rs.visible = true
		var rso = root.find_child("RunStartOptions", true, false)
		rso._on_run_started()
		var host = rso._cards_host
		var picked_names: Array = []
		for col_index in [0, 2]:
			var col: Control = host.get_child(col_index)
			for child in col.get_child(0).get_children():
				if child is Button and child.visible:
					child.pressed.emit()
			picked_names.append(str((col.get_meta("xinfa_full") as Dictionary).get("name", "")))
		print("diag: 所选包=", picked_names)
		rso._on_confirm_pressed()
		return false
	if _frames == 160:
		var global_db = root.get_node("/root/Global")
		var deck: Array = global_db.player_data.player_deck
		var counts: Dictionary = {}
		for cd in deck:
			var n: String = cd.get_card_name()
			counts[n] = counts.get(n, 0) + 1
		var ok: bool = deck.size() == 8
		for key in counts.keys():
			if int(counts[key]) != 2 or key.find("·术法") == -1:
				ok = false
		print("diag: 卡组=", counts, " 总数=", deck.size(), " (expect 8，全部 X·术法N ×2)")
		print("diag: 卡组合规=", ok)
		quit()
		return true
	return false
