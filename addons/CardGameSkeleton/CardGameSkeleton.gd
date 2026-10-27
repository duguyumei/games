@tool
extends EditorPlugin

var toolbar
var dock_instance

## 挂/卸 Dock 带空值护栏：上游把挂载只写在 _enable_plugin()（仅手动勾选时触发），
## 编辑器正常启动走 _enter_tree() 不挂 Dock——已修为两处都挂、护栏防重复。
func _add_dock() -> void:
	if toolbar == null:
		toolbar = preload("res://addons/CardGameSkeleton/CardGameSkeleton.tscn").instantiate()
		add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, toolbar)


func _remove_dock() -> void:
	if toolbar != null:
		remove_control_from_docks(toolbar)
		toolbar.free()
		toolbar = null


func _enable_plugin() -> void:
	_add_dock()


func _disable_plugin() -> void:
	_remove_dock()


func _enter_tree() -> void:
	_add_dock()


func _exit_tree() -> void:
	_remove_dock()
