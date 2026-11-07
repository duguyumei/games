## VC 制主流程宿主（复刻线；2026-11-01 地图轮改流）：楼层地图屏 ⇄ 明雷遭遇战环。
## run＝{hp, mhp, copper, deck, neigong, floor, map(楼层图数据), seed}；
## 胜→hp 写回＋移除该明雷回图；负→满血回图重打（复刻阶段简化口径，死亡语义待裁）；
## 铲子→挖下一层（重生成楼层图）；Boss 层无铲——杀王即通关。
## 用法：godot --path /Users/cc/Documents/qi-forge-2 res://qiforge/QiVcRoot.tscn；
## --qi-shot＝截两图（地图/战斗）退出。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QIPREFS := preload("res://qiforge/QiPrefs.gd")
const VC := preload("res://qiforge/QiVcData.gd")
const MAPGEN := preload("res://qiforge/QiVcMapGen.gd")
const VC_MAP := preload("res://qiforge/QiVcMapScreen.gd")
const VC_SCREEN := preload("res://qiforge/QiVcScreen.gd")
const VC_REWARD := preload("res://qiforge/QiVcReward.gd")

var _run: Dictionary = {}
var _map = null
var _screen = null
var _reward: Control = null
var _after_reward := "map"
var _pending := {}   # {cell: Vector2i, boss: bool} 战斗归图定位

func _ready() -> void:
	QIPREFS.apply_display()
	QISTYLE.apply_root_theme(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_run()
	var bg := ColorRect.new()
	bg.color = QISTYLE.INK_BG
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	_show_map()
	if "--qi-shot" in OS.get_cmdline_user_args():
		# 安全闸：任何一步卡住到点也退出，不让跑图进程挂死
		get_tree().create_timer(10.0).timeout.connect(func(): get_tree().quit())
		await get_tree().create_timer(1.2).timeout
		await _shot("/Users/cc/Documents/qi-forge-2/.qi_vc_map.png")
		var first_enemy := _first_enemy_entity()
		print("[shot] enemy=", first_enemy)
		if not first_enemy.is_empty():
			# 跑图专用：牌组塞 6 张同牌，验扇形（正常局仍是孤张直刺）
			_run["deck"] = ["zhici", "zhici", "zhici", "zhici", "zhici", "zhici"]
			_start_battle(first_enemy)
			# 跑图专用：补抽 3 张凑 6 张手牌（首回合正常抽 3）
			if _screen != null and _screen.battle != null:
				_screen.battle.draw_cards(3)
			await get_tree().create_timer(1.5).timeout
			print("[shot] screen=", _screen, " hand=", _screen.battle.hand.size() if _screen != null and _screen.battle != null else -1)
			# 跑图专用：清掉系统光标造成的误悬停，拍干净扇形
			if _screen != null:
				_screen.set_meta("shot_no_hover", true)
				_screen._set_hand_focus(null)
				await get_tree().create_timer(0.5).timeout
			await _shot("/Users/cc/Documents/qi-forge-2/.qi_vc_battle.png")
			# 第二张：聚焦中间一张，验相让＋弹起
			if _screen != null and _screen._hand_wraps.size() >= 4:
				_screen.set_meta("shot_no_hold", true)
				_screen._set_hand_focus(_screen._hand_wraps[3])
				await get_tree().create_timer(0.6).timeout
				await _shot("/Users/cc/Documents/qi-forge-2/.qi_vc_battle_focus.png")
		get_tree().quit()

func _reset_run() -> void:
	_run = VC.default_vc_run()
	_run["floor"] = 0
	_run["map"] = MAPGEN.floor_map(int(_run["seed"]), 0, VC.FLOORS[0])
	_pending = {}

## 截图（哑渲染器出不了图——headless 只静默跳过，同探针守卫约定）。
## 2026-11-04：改等 process_frame（frame_post_draw 在离屏窗口偶发不派发，跑图会挂住）。
func _shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	# 离屏窗口会被系统判为不可见而停画——强制画一帧再取图（否则截到上一屏）
	RenderingServer.force_draw()
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)

func _show_map() -> void:
	_free_screens()
	_map = VC_MAP.new()
	_map.setup(_run, int(_run["floor"]), _run["map"])
	_map.encounter_requested.connect(_start_battle)
	_map.boss_requested.connect(_start_battle)
	_map.dig_requested.connect(_dig_down)
	add_child(_map)

## 明雷遭遇：该敌＋楼池随机队友，组队规模吃 FLOORS.group 区间（种子＝run.seed 掺层与格）
func _start_battle(entity: Dictionary) -> void:
	var fidx := int(_run["floor"])
	var spec: Dictionary = VC.FLOORS[mini(fidx, VC.FLOORS.size() - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_run["seed"]) + fidx * 31 + (entity["cell"] as Vector2i).x * 7 + (entity["cell"] as Vector2i).y
	var pool: Array = (spec.get("pool", []) as Array).duplicate()
	var picked: Array = []
	if entity.has("group"):
		picked = (entity["group"] as Array).duplicate()   # 固定编队（教程明雷）
	else:
		var group_lo := int(spec.get("group", [2, 3])[0])
		var group_hi := int(spec.get("group", [2, 3])[1])
		var n := clampi(group_lo + rng.randi_range(0, group_hi - group_lo), 1, 3)
		picked = [entity["id"]]
		for i in n - 1:
			if pool.is_empty():
				break
			picked.push_back(pool[rng.randi_range(0, pool.size() - 1)])
	_pending = {"cell": entity["cell"], "boss": String(entity["type"]) == "boss"}
	_free_screens()
	_screen = VC_SCREEN.new()
	var run2: Dictionary = _run.duplicate(true)
	run2.erase("map")
	run2["enc_spec"] = {"name": "%s×%d" % [String(VC.ENEMIES.get(String(entity["id"]), {}).get("name", "敌人")), picked.size()],
		"active_max": maxi(2, picked.size()), "refill": 0, "pool": picked}
	_screen.setup(run2)
	_screen.battle_over.connect(_on_battle_over)
	add_child(_screen)

func _on_battle_over(result: String) -> void:
	if result == "win":
		var out: Dictionary = _screen.player_out()
		_run["hp"] = out["hp"]
		_run["mhp"] = out["mhp"]
		var rec := int(out.get("recovery", 0))
		if rec > 0:
			_run["hp"] = mini(int(_run["mhp"]), int(_run["hp"]) + rec)
		# 经验结转（VC 制曲线）：击杀经验入账＋连续升级归并；升级次数记 pending_picks（三选一奖励随奖励批实装）
		var lp: Dictionary = VC.level_progress(int(_run.get("level", 1)),
			int(_run.get("xp", 0)) + int(out.get("xp_gained", 0)))
		_run["level"] = int(lp["lvl"])
		_run["xp"] = int(lp["xp"])
		if int(lp["gained"]) > 0:
			_run["pending_picks"] = int(_run.get("pending_picks", 0)) + int(lp["gained"])
		if bool(_pending.get("boss", false)):
			_after_reward = "clear"
		else:
			_remove_map_entity(_pending["cell"])
			_after_reward = "map"
		_show_rewards_or_next()
	else:
		_run["hp"] = int(_run.get("mhp", VC.PLAYER_BASE["hp"]))   # 复刻阶段简化：败北满血重打
		_show_map()

## 升级三选一流：有突破次数先出奖励屏（连锁出题），完了归图/通关。
## 教程层（第一层）＝单卡天赐（VC Deck_Tutorial 孤张制＋2026-11-01 用户口述「只可以选一个」）：
## 首赐「上撩」（开局孤张→两个撩）、再赐「撩月斩」——奖励屏单卡模式＋醍醐灌顶特效。
func _show_rewards_or_next() -> void:
	if int(_run.get("pending_picks", 0)) > 0:
		var gifts: Array = ["shangliao", "cuipo_liao"] if int(_run.get("floor", 0)) == 0 else []
		_free_screens()
		_reward = VC_REWARD.new()
		_reward.setup(_run, gifts)
		_reward.done.connect(_on_reward_done)
		add_child(_reward)
	else:
		_on_reward_done()

func _on_reward_done() -> void:
	_free_screens()
	if _after_reward == "clear":
		_show_clear_panel()
	else:
		_show_map()

func _remove_map_entity(cell: Vector2i) -> void:
	var ents: Array = _run["map"]["entities"]
	for i in range(ents.size() - 1, -1, -1):
		if (ents[i]["cell"] as Vector2i) == cell:
			ents.remove_at(i)

func _dig_down() -> void:
	var fidx := int(_run["floor"]) + 1
	if fidx >= VC.FLOORS.size():
		_show_clear_panel()
		return
	_run["floor"] = fidx
	_run["map"] = MAPGEN.floor_map(int(_run["seed"]), fidx, VC.FLOORS[fidx])
	_show_map()

func _first_enemy_entity() -> Dictionary:
	for e in _run["map"]["entities"]:
		if String(e["type"]) == "enemy":
			return e
	return {}

func _show_clear_panel() -> void:
	_free_screens()
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.add_theme_stylebox_override("panel", QISTYLE.panel(0.9))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "地牢通关！"
	QISTYLE.font(title, 40, true)
	QISTYLE.text_color(title, QISTYLE.AMBER_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var btn := Button.new()
	btn.text = "重开地牢"
	QISTYLE.apply_primary(btn)
	btn.pressed.connect(func():
		_reset_run()
		_show_map())
	box.add_child(btn)

func _free_screens() -> void:
	for node in [_map, _screen, _reward]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_map = null
	_screen = null
	_reward = null
