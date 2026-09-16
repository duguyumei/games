class_name RunSession
extends RefCounted

# 场景交接（组挑战·代码设计 v1.4 §4.3）：DojoConfig 同模式静态类。
# begin：读 DataRepo 卡组建 RunState 并落首档；opponent()/shop_cfg()：DataRepo 包装；
# 进出现由场景在检查点调 save（写穿）。测试不依赖本类（直接喂 RunState）。


static var active := false
static var state: RunState


static func begin(deck_id: String, seed_value: int = 0) -> bool:
	var decks: Dictionary = DataRepo.mj_decks()
	if not decks.has(deck_id):
		push_error("[RunSession] 未知卡组: " + deck_id)
		return false
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) % 1000000
	state = RunState.new()
	state.start(decks[deck_id], seed_value)
	active = true
	save()
	return true


# 存档恢复（deck_select「继续挑战」）：成功则 active=true。
static func resume() -> bool:
	var loaded := RunSaver.load_state()
	if loaded == null:
		return false
	state = loaded
	active = true
	return true


static func end() -> void:
	active = false
	state = null


static func save() -> void:
	if active and state != null:
		RunSaver.save_state(state)


static func opponent() -> Dictionary:
	if not active:
		return {}
	# 组序＝对手卡 key 序（Godot JSON 解析保持插入序：浪人→力士→Boss）
	var ids: Array = DataRepo.mj_opponents().keys()
	if state.battle_index < ids.size():
		return DataRepo.mj_opponents()[ids[state.battle_index]]
	return {}


static func shop_cfg() -> Dictionary:
	return DataRepo.mj_shop()
