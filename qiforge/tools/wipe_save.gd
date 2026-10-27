## 清存档小工具（dev）：godot --headless --path . -s res://qiforge/tools/wipe_save.gd
extends SceneTree

const QISAVE := preload("res://qiforge/QiSave.gd")

func _initialize() -> void:
	QISAVE.clear()
	print("SAVE_WIPED")
	quit()
