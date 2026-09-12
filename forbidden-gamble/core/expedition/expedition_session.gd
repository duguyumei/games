extends Node

# 局内会话与层间交接（原 RunState 的远征部分拆出；局外仓库与角色穿戴在 MetaArchive）。
# 交接收编为显式协议——字段不再裸露给场景直捅，"幽灵战果"类事故从结构上消灭：
# - 备战→探索：出发 start_run(seed, prep)（prep 来自备战页 ExpeditionPrep.payload()）
# - 探索→战斗：开战 prepare_battle(enemy_id) / 取上下文 take_battle_context()
# - 战斗→探索：战报 report_battle_result(result, hp) / consume_battle_result()（读完自动清）
# - 探索→备战：撤离结算 settle_and_end_run()（入库走 MetaArchive；穿戴是角色状态，
#   撤离原样带回、倒下即散失——C-027 拆掉了"撤离入库＋开局自动换穿"的自动化链）
# 玩家气血跨战斗贯通：战斗结束写回，下场战斗以此为始。
# 注：autoload 名即 ExpeditionSession，脚本不写 class_name（Godot 禁止同名遮蔽）。

const LOCATION_PATH := "res://data/location_qingfeng.json"
const ITEMS_PATH := "res://data/items.json"
const ENEMIES_PATH := "res://data/enemies.json"
const PLAYER_CONFIG_PATH := DataRepo.PLAYER_PATH

var board_state: BoardState
# 结算目标仓库（autoload 下自动接线；测试注入裸 MetaArchive 实例隔离真仓库）
var archive: Node

var _in_expedition := false
var _player_hp := 0
var _player_max_hp := 0
var _pending_enemy_id := ""
var _pending_battle_seed := 0
var _pending_enemy_first := false  # 这场是不是被袭击（敌方抢得先手）
var _battle_result := ""    # "" / "win" / "lose"
# GUT 测试态（仅 autoload 本尊会置位；测试注入的裸实例保持玩家侧行为）。
var _test_mode := false

func _ready() -> void:
	if archive == null:
		var a := get_node_or_null("/root/MetaArchive")
		if a != null:
			archive = a
	# 只有 autoload 本尊做测试隔离与开机补结算（测试注入的裸实例跳过）。
	# 测试隔离（17 号测试策略）：命令行带 GUT 运行器＝测试态——存档指向测试路径并清
	# 残留、读档一律扑空（续档/开机补结算是玩家侧行为）——用例之间不串局、上一轮
	# GUT/试玩留在磁盘上的局面不会被 board 场景续到，真档永不被 GUT 触碰。
	if get_node_or_null("/root/ExpeditionSession") == self:
		_test_mode = _detect_gut()
		if _test_mode:
			save_path = TEST_SAVE_PATH
			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(save_path)
		_settle_terminal_save_at_boot()

# 命令行里有没有 GUT 运行器（run_checks 走 -s addons/gut/gut_cmdln.gd）。
# 编辑器内直接跑 GUT（GutScene）不在此列——那是开发者在编辑器里的交互运行。
func _detect_gut() -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg).contains("addons/gut"):
			return true
	return false

# 测试复位（17 号）：清会话与测试档。场景类测试（board.tscn 等）before_each 调用，
# 杜绝同轮 GUT 里上一个用例的局串进来；需要确定局面时再自行 start_run(固定种子)。
func reset_for_tests() -> void:
	end_run()
	clear_save()

# 终态开机结算（C-027）：死亡/撤离后不点「回据点」直接退游戏的，开机补一次——
# 穿戴是跨局角色状态，撤离要带回、倒下要散失，不能因为没走完结算 UI 就丢账。
# 结算完即清档，防止下次开机重复入库。
func _settle_terminal_save_at_boot() -> void:
	var data := _read_save()
	if data.is_empty() or not bool(data.get("terminal", false)):
		return
	if int(data.get("version", 0)) != SAVE_VERSION:
		return
	if from_dict(data):
		settle_and_end_run()
		clear_save()

# ---------- 层间协议 ----------

func is_in_expedition() -> bool:
	return _in_expedition

func carried_hp() -> int:
	return _player_hp

func carried_max_hp() -> int:
	return _player_max_hp

func prepare_battle(enemy_id: String, enemy_first: bool = false) -> void:
	_pending_enemy_id = enemy_id
	# 每场战斗的种子从牌阵 rng 派生：整局远征可由一个种子重放。
	_pending_battle_seed = board_state.rng.randi()
	# 被袭击（准备态满表/迫近满）的战斗敌方先手（C-028）。
	_pending_enemy_first = enemy_first

# 开战上下文（读取不消费——战斗内"重开一场"要能重复取）：
# {enemy_id, seed, player_hp, weapon_school, weapon_level, armor_defend,
#  loadout_techniques, loadout_xinfa}。
# 穿戴载荷（M4）来自版图穿戴栏；构筑载荷（D-060）来自据点 meta 档——无档时兜底
# player.json 初始构筑。载荷结构是扩展位：未来真气状态等跨战斗持续量加字段即可。
func take_battle_context() -> Dictionary:
	var weapon: Dictionary = board_state.equipped.get("weapon", {}) if board_state != null else {}
	var armor: Dictionary = board_state.equipped.get("armor", {}) if board_state != null else {}
	var context := {
		"enemy_id": _pending_enemy_id,
		"seed": _pending_battle_seed,
		"enemy_first": _pending_enemy_first,
		"player_hp": _player_hp,
		"weapon_school": str(weapon.get("weapon", {}).get("school", "")),
		"weapon_level": int(weapon.get("weapon", {}).get("level", 0)),
		"armor_defend": int(armor.get("armor", {}).get("level", 0)),
	}
	if archive != null:
		context["loadout_techniques"] = (archive.loadout.get("techniques", []) as Array).duplicate()
		context["loadout_xinfa"] = (archive.loadout.get("xinfa", []) as Array).duplicate()
	return context

# 战斗结束写回：胜负 + 余血（气血贯通）。胜仗入账历练（D-062，数值占位）。
func report_battle_result(result: String, hp: int) -> void:
	_battle_result = result
	_player_hp = hp
	if result == "win" and archive != null:
		archive.gain_experience(archive.EXP_PER_BATTLE_WIN)

# 地图侧消费战报：读完自动清空，杜绝上一局的"幽灵战果"。
func consume_battle_result() -> String:
	var result := _battle_result
	_battle_result = ""
	return result

# ---------- 远征生命周期 ----------

# 出征（C-027）：prep 是备战页装配载荷 {equipped, inventory, pouch}（全深拷贝落地，
# 局内磨损/消耗不回写角色状态）；空 prep＝空手开局（保底配发已取消，带什么全凭备战页）。
func start_run(new_seed: int, prep: Dictionary = {}) -> void:
	board_state = BoardState.new()
	if not board_state.load(LOCATION_PATH, ITEMS_PATH, ENEMIES_PATH):
		_in_expedition = false
		return
	_wire_board()
	board_state.generate(new_seed)
	if not prep.is_empty():
		board_state.equipped = (prep.get("equipped", {}) as Dictionary).duplicate(true)
		board_state.inventory = (prep.get("inventory", []) as Array).duplicate(true)
		board_state.pouch = (prep.get("pouch", []) as Array).duplicate(true)
	var player_fighter := EncounterLoader.load_player(PLAYER_CONFIG_PATH)
	if player_fighter != null:
		_player_max_hp = player_fighter.max_hp
		_player_hp = _player_max_hp
	_pending_enemy_id = ""
	_battle_result = ""
	_in_expedition = true

# 牌阵持有会话引用的接线点（探索域道具的 heal 效果经此落回气血属主；
# 装备实例 uid 由 MetaArchive 发号——跨局唯一，仓库与新局永不撞号；
# 贴身锦囊格数来自局外升级——MetaArchive.pouch_slots）。
func _wire_board() -> void:
	if board_state == null:
		return
	var session := self
	board_state.heal_player = func(amount: int): session.recover_hp(amount)
	if archive != null:
		board_state.pouch_slots = archive.pouch_slots
		var arch: Variant = archive
		board_state.issue_uid = func() -> int: return arch.next_uid()

# 探索域回血（伤药/跌打酒等；上限截断）。
func recover_hp(amount: int) -> void:
	_player_hp = clampi(_player_hp + amount, 0, _player_max_hp)

func end_run() -> void:
	_in_expedition = false
	board_state = null
	_player_hp = 0
	_player_max_hp = 0
	_pending_enemy_id = ""
	_battle_result = ""

# 随身总价值（背包＋锦囊＋穿戴，按件计＝价值×数量；撤离按钮的展示口径）。
func carried_value() -> int:
	var total := 0
	if board_state == null:
		return 0
	for item in board_state.inventory + board_state.pouch:
		total += int(item.get("value", 0)) * int(item.get("qty", 1))
	for slot in board_state.equipped:
		var entry: Dictionary = board_state.equipped[slot]
		if not entry.is_empty():
			total += int(entry.get("value", 0))
	return total

# 入库价值（撤离结算罩层口径）：背包＋锦囊——穿戴不入库（角色状态原样带回）。
func banked_value() -> int:
	if board_state == null:
		return 0
	var total := 0
	for item in board_state.inventory + board_state.pouch:
		total += int(item.get("value", 0)) * int(item.get("qty", 1))
	return total

# 锦囊内物品总价值（死亡保底口径——穿戴件与背包都会丢，只有囊中之物回仓库）。
func pouch_value() -> int:
	var total := 0
	if board_state == null:
		return 0
	for item in board_state.pouch:
		total += int(item.get("value", 0)) * int(item.get("qty", 1))
	return total

# 终态结算（C-027）：撤离＝背包＋锦囊入库，穿戴原样带回（耐久照旧，写 meta 档）；
# 死亡/力竭＝只保锦囊（背包与穿戴在倒下当场已清空，这里按结局再兜底一次），穿戴散失。
# meta 档每次结算必写——穿戴的带回/散失不能依赖"恰好有物资入库"。
func settle_and_end_run() -> int:
	var stored := 0
	if board_state != null and archive != null:
		var extracted := board_state.outcome == "extracted"
		var kept: Array = board_state.inventory + board_state.pouch if extracted else board_state.pouch
		if not kept.is_empty():
			stored = archive.store_items(kept)
		if extracted:
			archive.gain_experience(archive.EXP_PER_EXTRACTION)
			archive.set_equipped(board_state.equipped)
		else:
			archive.clear_equipped()
		archive.save_meta()
	end_run()
	return stored

# 局内主动放弃：物资全丢（不入库）、穿戴散失、弃档——与死亡同口径，只是不保锦囊。
func abandon_run() -> void:
	if archive != null:
		archive.clear_equipped()
		archive.save_meta()
	clear_save()
	end_run()

# ---------- 被动存档 ----------
# 无手动存档 UI。存档时机全部自动：探索开始、牌阵每个动作结算后、进入战斗前
# （检查点）、战斗结算后。死亡/力竭/撤离的存档是终态——不续玩，开新局覆盖；
# 中途退出（未结算）下次启动读最近存档续玩；战斗中强退回到战前检查点（合法 SL）。

var save_path := "user://expedition_save.json"
# GUT 测试态的存档落点（真档与测试档互不相犯；每轮 GUT 启动清一次残留）。
const TEST_SAVE_PATH := "user://test_expedition_save.json"
# 存档版本：规则模型升级即 +1，旧版本档不续玩（resume 失败自动新开）。
# v3：物品定义加 type/subtype/use/max_stack（背包条目为定义副本，随之变形）。
# v4：镇物追杀状态（qixi/hunter/hunt_count/hunt_queue/guardians_off）入档。
# v5：贴身锦囊（pouch；格数 pouch_slots 仍在 meta 档）。
# v6：穿戴栏（equipped 兵器/护具/行囊；装备条目为 {id,uid,dur} 实例不叠堆，
#      背包容格数改由穿戴行囊驱动）。
# v7（C-028）：明牌地块网格——site.stack/ground 合并为 site.grid（3 列网格，空字典＝洞），
#      敌牌带 alert 警戒值；新增 sneak_ap（迷踪香静音窗）/battle_cell/battle_enemy_first/
#      chain_queue（连坐待战位）；hunter 增 prox（迫近）/cell。翻牌与散落区概念删除。
const SAVE_VERSION := 7

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_hp": _player_hp,
		"player_max_hp": _player_max_hp,
		"board": board_state.to_dict() if board_state != null else {},
	}

# 从存档数据恢复整局：配置重新加载，牌阵状态整体还原。
func from_dict(data: Dictionary) -> bool:
	var board_data: Dictionary = data.get("board", {})
	if board_data.is_empty():
		return false
	var bs := BoardState.new()
	if not bs.load(LOCATION_PATH, ITEMS_PATH, ENEMIES_PATH):
		return false
	bs.from_dict(board_data)
	board_state = bs
	_wire_board()
	_player_hp = int(data.get("player_hp", 0))
	_player_max_hp = int(data.get("player_max_hp", 0))
	_pending_enemy_id = ""
	_pending_enemy_first = false
	_battle_result = ""
	_in_expedition = true
	return true

# 写入当前进度。outcome 非空 = 终态存档（死亡/力竭/撤离），不续玩、被新局覆盖。
func save_game() -> void:
	if not _in_expedition or board_state == null:
		return
	var data := to_dict()
	data["terminal"] = board_state.is_run_over()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档: " + save_path)
		return
	file.store_string(JSON.stringify(data))

# 存在可续玩的存档（文件在、能解析、版本匹配、非终态）。
func has_save() -> bool:
	return _save_resumable(_read_save())

# 启动续档：恢复最近的非终态存档。无存档/终态/版本不符/损坏一律返回 false（走新开）。
func resume_from_save() -> bool:
	var data := _read_save()
	if not _save_resumable(data):
		return false
	return from_dict(data)

func _save_resumable(data: Dictionary) -> bool:
	if data.is_empty() or bool(data.get("terminal", false)):
		return false
	return int(data.get("version", 0)) == SAVE_VERSION

func _read_save() -> Dictionary:
	# 测试态读档一律扑空（连本轮 GUT 中途写下的测试档也不读）——
	# board 场景在测试里只会 start_run 新开，不会续到任何磁盘局面。
	if _test_mode:
		return {}
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	return parsed

# 弃掉进行中的远征存档（主菜单"新的远征"确认后调用；终态存档本就会被新局覆盖）
func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
