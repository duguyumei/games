## 世界冻结·引用计数制（2026-11-09 贴原版 VC TimeManager 同构）
## 原版：LateUpdate 每帧 timeScale = requests 非空 ? 0 : 恢复值——多冻结源进出 HashSet
## 天然叠加。Godot 侧落 get_tree().paused：请求集非空＝冻结、全退出＝恢复。
## 用法：QI_PAUSE.request("reward") / QI_PAUSE.release("reward")（tag＝冻结源名）。
extends RefCounted

static var _reqs := {}

static func request(tag: String) -> void:
	_reqs[tag] = true
	_apply()

static func release(tag: String) -> void:
	_reqs.erase(tag)
	_apply()

## 全清（换屏/退出兜底）
static func release_all() -> void:
	_reqs.clear()
	_apply()

static func frozen() -> bool:
	return not _reqs.is_empty()

static func _apply() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).paused = not _reqs.is_empty()
