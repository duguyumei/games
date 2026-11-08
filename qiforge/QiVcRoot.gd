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
const VC_SCREEN := preload("res://qiforge/QiVcBattle.tscn")   # 2026-11-04 场景化：战斗屏住场景（脚本挂根）
const VC_REWARD := preload("res://qiforge/QiVcReward.gd")
const VC_META := preload("res://qiforge/QiVcMeta.gd")   # 2026-11-07 属性轮：局外金币＋养成档

var _run: Dictionary = {}
var _map = null
var _screen = null
var _reward: Control = null
var _meta = null   # VC_META 实例（局外持久——金币/养成）
var _panel = null   # 局外养成面板（2026-11-07 属性轮）
var _after_reward := "map"
var _pending := {}   # {cell: Vector2i, boss: bool} 战斗归图定位

func _ready() -> void:
	QIPREFS.apply_display()
	QISTYLE.apply_root_theme(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_meta = VC_META.new()
	_meta.setup()
	_reset_run()
	var bg := ColorRect.new()
	bg.color = QISTYLE.INK_BG
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	_show_map()
	if "--qi-shot" in OS.get_cmdline_user_args():
		# 安全闸：任何一步卡住到点也退出，不让跑图进程挂死
		var _guard := 22.0 if ("--qi-xp" in OS.get_cmdline_user_args() or "--qi-xp-win" in OS.get_cmdline_user_args() or "--qi-hit" in OS.get_cmdline_user_args()) else 10.0
		if OS.has_environment("QI_TIP"):
			_guard = 30.0   # 浮窗跑图：多一张截图，放宽安全闸
		if OS.has_environment("QI_FXSLOW"):
			_guard = _guard * clampf(float(OS.get_environment("QI_FXSLOW")), 1.0, 12.0)
		get_tree().create_timer(_guard).timeout.connect(func(): get_tree().quit())
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
			# 经验特效验收（--qi-xp）：注 5 点经验、敌位放 5 珠连飞→到账→满级三选一，逐段抓图
			if "--qi-xp" in OS.get_cmdline_user_args() and _screen != null:
				for i in 5:
					_screen.battle.xp_pending.push_back(1)
				var spots := [Vector2(520, 360), Vector2(700, 430), Vector2(960, 340),
					Vector2(1200, 430), Vector2(1380, 360)]
				for p in spots:
					_screen._spawn_xp_orb(p)
				for i in 6:
					await get_tree().create_timer(0.2).timeout
					await _shot("/Users/cc/Documents/qi-forge-2/.qi_xp_%d.png" % i)
				await get_tree().create_timer(0.5).timeout
				await _shot("/Users/cc/Documents/qi-forge-2/.qi_xp_end.png")
			# 战斗特效验收（--qi-hit）：连打一张直刺，抓出招/命中/收尾
			if "--qi-hit" in OS.get_cmdline_user_args() and _screen != null \
					and OS.has_environment("QI_FXSCENE"):
				# 溢出/替补四场景一次跑完（2026-11-07 用户令）
				await _fx_scenes()
			elif "--qi-hit" in OS.get_cmdline_user_args() and _screen != null:
				var b = _screen.battle
				if b.hand.size() > 0:
					# 演示用：把敌人血量顶高，否则一击必杀、胜利浮层立刻盖住特效
					if not b.encounter["active"].is_empty():
						# QI_LOW_HP=1：把血量压到 6，用来截「敌卡死亡特效」（2026-11-06 调试口）
						if OS.has_environment("QI_LOW_HP") and not OS.has_environment("QI_SOLO"):
							# 调试：主怪 12 血（两下必死），另挂一个 999 血的假怪，
							# 这样杀掉主怪也不会立刻弹胜利横幅——能截到死亡特效
							b.encounter["active"][0]["hp"] = 12
							var dup: Dictionary = b.encounter["active"][0].duplicate(true)
							dup["uid"] = 9001
							dup["hp"] = 999
							b.encounter["active"].append(dup)
						else:
							b.encounter["active"][0]["hp"] = 999
						# QI_FX=1：三敌并排 999 血——验收「右→左扫过一排」
						# （单敌 6 击全落一处，走 repeat_jitter 分支，看不出扫的读感）
						if OS.has_environment("QI_FX"):
							for _k2 in 2:
								var d3: Dictionary = b.encounter["active"][0].duplicate(true)
								d3["uid"] = 9100 + _k2
								d3["hp"] = 999
								b.encounter["active"].append(d3)
					# 演示连击徽（默认没装内功「连击堆叠」是隐藏的）
					b.combo_enabled = true
					b.combo_count = 3
					# 演示裂纹：第二张牌顶到 uses=3 → 卡面带裂纹
					if b.hand.size() > 1:
						b.hand[1]["uses"] = 3
					_screen._refresh()
					var c0: Dictionary = b.hand[0]
					print("[hit] card=", String(c0["def"].get("name", "?")),
						" uid=", int(c0["uid"]))
					if OS.has_environment("QI_HPHIT"):
						# 受击特效验收：直接触发一次 12 点伤害表现
						_screen._player_hit_fx(1 if OS.has_environment("QI_HIT_LIGHT") else 25, 50)
						await get_tree().create_timer(0.05).timeout
						await _shot("/Users/cc/Documents/qi-forge-2/.qi_hphit_a.png")
						await get_tree().create_timer(0.10).timeout
						await _shot("/Users/cc/Documents/qi-forge-2/.qi_hphit_b.png")
						await get_tree().create_timer(0.20).timeout
						await _shot("/Users/cc/Documents/qi-forge-2/.qi_hphit_c.png")
					for _k in 2:
						if b.hand.size() <= 1:
							break
						_screen._play_clicked(int(b.hand[0]["uid"]))
						if _k == 0:
							if OS.has_environment("QI_FX"):
								# 直刺 v1 时间轴抓帧：到点即截（_shot 自带 2 帧等待≈33ms，故刻度前移）
								var t0 := Time.get_ticks_msec()
								var marks := [0.16, 0.34, 0.52, 0.70, 0.90, 1.10, 1.32, 1.54]
								var mi := 0
								while mi < marks.size():
									while float(Time.get_ticks_msec() - t0) / 1000.0 \
											< float(marks[mi]):
										await get_tree().process_frame
									await _shot("/Users/cc/Documents/qi-forge-2/.qi_fx_%d.png" % mi)
									if OS.has_environment("QI_FXDUMP"):
										_fx_dump(_screen._combat_fx, mi)
									mi += 1
							else:
								await get_tree().create_timer(0.05).timeout
								await _shot("/Users/cc/Documents/qi-forge-2/.qi_hit_strike.png")
						await get_tree().create_timer(0.30).timeout
					# 第三张强制碎：uses 顶到 4，再打一次＝第 5 次 → 原地碎裂
					if b.hand.size() > 0:
						b.hand[0]["uses"] = 4
						_screen._play_clicked(int(b.hand[0]["uid"]))
					await get_tree().create_timer(0.24).timeout
					await _shot("/Users/cc/Documents/qi-forge-2/.qi_hit_s0.png")
					await get_tree().create_timer(0.12).timeout
					await _shot("/Users/cc/Documents/qi-forge-2/.qi_hit_s1.png")
					await get_tree().create_timer(0.14).timeout
					await _shot("/Users/cc/Documents/qi-forge-2/.qi_hit_s2.png")
					print("[hit] played=", b.played_pile.size(), " events=", _screen._hit_events.size())
					for i in 5:
						await _shot("/Users/cc/Documents/qi-forge-2/.qi_hit_%d.png" % i)
					# 洗牌换气视觉验收（2026-11-06）：模拟 +3 气后触发洗牌表现
					if OS.has_environment("QI_SHUF"):
						b.player["qi"] = mini(30, int(b.player["qi"]) + (1 if OS.has_environment("QI_ONE") else (2 if OS.has_environment("QI_TWO") else 3)))
						_screen._on_piles_shuffled("discard")
						_screen._refresh()
						if OS.has_environment("QI_WATCH"):
							# 专测动态调速：等并入完成后，每 0.35s 打一次角度并截图
							await get_tree().create_timer(1.3).timeout
							for kw in 7:
								var ang: Array = []
								for m in _screen._qi_orbit._motes:
									ang.append(snappedf(fposmod(float(m["theta"]), TAU), 0.02))
								ang.sort()
								print("[watch] t=", snappedf(kw * 0.35, 0.01), " angles=", ang)
								await _shot("/Users/cc/Documents/qi-forge-2/.qi_watch_%d.png" % kw)
								await get_tree().create_timer(0.35).timeout
						if OS.has_environment("QI_ORBITBURST"):
							await get_tree().create_timer(2.6).timeout   # 等稳定绕转后再拍
							for ko in 14:
								await _shot("/Users/cc/Documents/qi-forge-2/.qi_orb_%d.png" % ko)
								await get_tree().create_timer(0.04).timeout
						if OS.has_environment("QI_MERGEBURST"):
							await get_tree().create_timer(0.80).timeout
							for kb in 8:
								await _shot("/Users/cc/Documents/qi-forge-2/.qi_burst_%d.png" % kb)
								await get_tree().create_timer(0.035).timeout
						if OS.has_environment("QI_ONE") or OS.has_environment("QI_TWO") or OS.has_environment("QI_THREE"):
							# 单颗并入：从 0.28s 起每 55ms 连拍，覆盖 0.46s 的到站时刻
							await get_tree().create_timer(0.2).timeout
							for k2 in 12:
								await _shot("/Users/cc/Documents/qi-forge-2/.qi_one_%d.png" % k2)
								await get_tree().create_timer(0.20).timeout
						await get_tree().create_timer(0.10).timeout
						await _shot("/Users/cc/Documents/qi-forge-2/.qi_shuf_a.png")
						await get_tree().create_timer(0.16).timeout
						await _shot("/Users/cc/Documents/qi-forge-2/.qi_shuf_b.png")
						await get_tree().create_timer(0.34).timeout
						await _shot("/Users/cc/Documents/qi-forge-2/.qi_shuf_c.png")

					print("[hit] done, time_scale=", Engine.time_scale)
			# 经验结算时序验收（--qi-xp-win）：杀光全部敌人→看珠数＝敌数、结算是否等珠落地
			if "--qi-xp-win" in OS.get_cmdline_user_args() and _screen != null:
				var b = _screen.battle
				b.encounter["reserve"].clear()
				var n: int = b.encounter["active"].size()
				for e in b.encounter["active"].duplicate():
					b._damage_enemy(e, 99999)
				print("[xpwin] killed=", n, " pending=", b.xp_pending.size(), " orbs=", _screen._xp_flights)
				b.check_end()
				print("[xpwin] after check_end orbs=", _screen._xp_flights,
					" overlay=", _screen._overlay != null)
				# 同帧多刷：一敌一珠的守卫（不重复放珠）
				_screen._refresh()
				_screen._refresh()
				_screen._refresh()
				print("[xpwin] after 3x refresh orbs=", _screen._xp_flights)
				for i in 4:
					await get_tree().create_timer(0.35 if i == 0 else 0.55).timeout
					await _shot("/Users/cc/Documents/qi-forge-2/.qi_xw_%d.png" % i)
				print("[xpwin] end orbs=", _screen._xp_flights, " overlay=", _screen._overlay != null,
					" run.xp=", _screen.run.get("xp", -1))
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

## ── 溢出/替补场景验收（QI_FXSCENE=1，配 --qi-hit）─────────────────────────────
## 四场景一轮跑完：①一击一死（余段空放）②每敌 8 血（溢出顺位）③三排两行（顶替）
## ④每敌 20 血（打不死，六段分摊）。每个场景打一张手牌并抓五帧。
func _fx_scenes() -> void:
	var b: RefCounted = _screen.battle
	# 2026-11-07 用户令：调试期只跑单卡场景（跑一次快得多）
	# 2026-11-08 用户令：多敌验证——一排 5 个、两排各 3 个
	var specs := [
		{"rows": [1], "hp": 10},         # 单敌一击必杀：验证剩余刀穿透到最右
		{"rows": [3, 3], "hp": 10},      # 多敌分裂：交错间距 + 碎裂 + 经验珠落地
	]
	for si in specs.size():
		var sp: Dictionary = specs[si]
		_fx_set_scene(sp["rows"], int(sp["hp"]))
		await get_tree().create_timer(0.30).timeout
		if b.hand.is_empty():
			print("[fxsc] 场景 ", si + 1, "：手牌空，跳过")
			continue
		var c0: Dictionary = b.hand[0]
		print("[fxsc] ── 场景 ", si + 1, " hp=", int(sp["hp"]),
			" rows=", str(sp["rows"]), " 敌=", b.encounter["active"].size(),
			" 卡=", String(c0["def"].get("name", "?")))
		_screen._play_clicked(int(c0["uid"]))
		var t0 := Time.get_ticks_msec()
		var slow := 1.0
		if OS.has_environment("QI_FXSLOW"):
			slow = clampf(float(OS.get_environment("QI_FXSLOW")), 1.0, 12.0)
		var n_hits: int = _screen._hit_events.size()
		var total: float = (0.16 + 0.70 + 0.20 + 0.11 * float(maxi(0, n_hits - 1))
			+ 0.22) * slow
		# 剑鞘制（5s 出鞘 + 0.5s 蓄力 + 5s 飞行）：抓帧总时长单开一档
		var fracs := [0.04, 0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.84, 0.94]
		if OS.has_environment("QI_FXSCA"):
			total = 2.95 * slow
			# 落点在命中前后：飞行中 → 命中 → 数字
			fracs = [0.04, 0.10, 0.17, 0.24, 0.32, 0.41, 0.50, 0.61, 0.76, 0.90]
		var marks: Array = []
		for f in fracs:
			marks.push_back(total * float(f))
		var mi := 0
		while mi < marks.size():
			while float(Time.get_ticks_msec() - t0) / 1000.0 < float(marks[mi]):
				await get_tree().process_frame
			await _shot("/Users/cc/Documents/qi-forge-2/.qi_sc%d_%d.png" % [si + 1, mi])
			mi += 1
		var seg := "[fxsc] hits:"
		for ev in _screen._hit_events:
			if bool((ev as Dictionary).get("death", false)):
				seg += " uid%d<death" % int(ev.get("uid", -1))
			else:
				seg += " uid%d<-%d" % [int(ev.get("uid", -1)), int(ev.get("amount", 0))]
		print(seg)
		for e in b.encounter["active"]:
			print("[fxsc]   存活 uid=", int(e["uid"]), " hp=", int(e["hp"]),
				" row=", int(e.get("row", 0)))
		await get_tree().create_timer(0.5).timeout

## 重建敌阵（静默：不走死亡链、不放经验珠）
func _fx_set_scene(rows: Array, hp: int) -> void:
	var b: RefCounted = _screen.battle
	# 掐掉经验/升级链：四场景连跑时杀敌攒经验会弹「择一功法」，把后两场整个盖住
	# （2026-11-07 首跑实测：场景 3、4 全是升级弹窗）
	if _screen._reward_ui != null:
		_screen._reward_ui.queue_free()
		_screen._reward_ui = null
	_screen._stop_xp_flights()
	b.xp_pending.clear()
	b.xp_gained = 0
	_screen.run["level"] = 30          # 高等级＝几点击杀涨不满一条，永不升级
	_screen.run["xp"] = 0
	_screen.run["pending_picks"] = 0
	for uid in _screen._enemy_cards.keys():
		var c = _screen._enemy_cards[uid]   # 可能已释放：不能声明成有类型的变量
		if is_instance_valid(c):
			c.queue_free()
	_screen._enemy_cards.clear()
	var tmpl: Dictionary = {}
	for e in b.encounter["active"]:
		tmpl = (e as Dictionary).duplicate(true)
		break
	if tmpl.is_empty():
		tmpl = {"id": "bat", "name": "蝙蝠", "alive": true, "armor": 0, "row": 0,
			"actions": [{"kind": "attack", "value": 3}]}
	var arr: Array = []
	var u := 9300
	for ri in rows.size():
		for k in int(rows[ri]):
			var e2: Dictionary = tmpl.duplicate(true)
			u += 1
			e2["uid"] = u
			e2["hp"] = hp
			e2["mhp"] = hp
			e2["armor"] = 0
			e2["row"] = ri
			e2["alive"] = true
			e2["skip"] = 0
			e2["just_spawned"] = false
			arr.append(e2)
	b.encounter["active"] = arr
	# 留一个假替补：全歼也不弹胜利浮层（否则后三帧直接被盖住）
	b.encounter["reserve"] = ["bat"]
	_screen._refresh()
	_screen._refresh_enemies()

## 特效层孩子清单（调试用 QI_FXDUMP=1：查"画面上这条线是谁画的"）
func _fx_dump(fx: Control, mark: int) -> void:
	if fx == null:
		return
	print("[fx] ── mark ", mark, " children=", fx.get_child_count())
	for ch in fx.get_children():
		var ln := "  %s" % ch.get_class()
		if ch is Control:
			var c := ch as Control
			ln += " z=%d pos=%s sc=%s rot=%.2f" % [c.z_index,
				str(c.position.round()), str(c.scale), c.rotation]
			if ch is TextureRect:
				var tr := ch as TextureRect
				ln += " size=%s mod=%s" % [str(tr.size.round()), str(tr.modulate)]
			elif ch is Label:
				ln += " text=%s" % (ch as Label).text
		elif ch is Line2D:
			var l2 := ch as Line2D
			ln += " z=%d col=%s w=%.2f pts=%d" % [l2.z_index, str(l2.default_color),
				l2.width, l2.get_point_count()]
		elif ch is CPUParticles2D:
			var p2 := ch as CPUParticles2D
			ln += " z=%d col=%s amt=%d" % [p2.z_index, str(p2.color), p2.amount]
		print("[fx] ", ln)

func _show_map() -> void:
	_free_screens()
	_map = VC_MAP.new()
	_map.setup(_run, int(_run["floor"]), _run["map"])
	_map.encounter_requested.connect(_start_battle)
	_map.boss_requested.connect(_start_battle)
	_map.dig_requested.connect(_dig_down)
	_map.upgrade_requested.connect(_open_upgrade_panel)   # 2026-11-07 属性轮：局外养成入口
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
		picked = (entity["group"] as Array).duplicate(true)   # 固定编队（教程明雷；队列制＝嵌套数组=排）
	else:
		var group_lo := int(spec.get("group", [2, 3])[0])
		var group_hi := int(spec.get("group", [2, 3])[1])
		var n := clampi(group_lo + rng.randi_range(0, group_hi - group_lo), 1, 3)
		# 难度选敌制（2026-11-07 原版 DifficultyRange 同构）：明雷本尊＋队友按层难度
		# 标签过滤＋加权随机（教程层 fixed 编队走 group 嵌套分支豁免此路）
		picked = [entity["id"]]
		var picked_rest: Array = VC.pick_enemies_by_difficulty(rng, spec, pool, n - 1)
		picked.append_array(picked_rest)
	_pending = {"cell": entity["cell"], "boss": String(entity["type"]) == "boss"}
	_free_screens()
	_screen = VC_SCREEN.instantiate()
	var run2: Dictionary = _run.duplicate(true)
	run2.erase("map")
	run2["_meta"] = _meta.meta_snapshot()   # 2026-11-07 属性轮：局外养成层注入（progression 合成）
	# 敌阵队列制（2026-11-07）：嵌套编队走 rows（前排在前）；平铺维持 pool（全前排一排）
	var enc: Dictionary = {"refill": 0}
	var is_rows := not picked.is_empty() and picked[0] is Array
	if is_rows:
		var total := 0
		for row in picked:
			total += (row as Array).size()
		enc["name"] = "%s×%d" % [String(VC.ENEMIES.get(String(entity["id"]), {}).get("name", "敌人")), total]
		enc["rows"] = picked
		enc["active_max"] = maxi(2, (picked[0] as Array).size())
	else:
		enc["name"] = "%s×%d" % [String(VC.ENEMIES.get(String(entity["id"]), {}).get("name", "敌人")), picked.size()]
		enc["pool"] = picked
		enc["active_max"] = maxi(2, picked.size())
	run2["enc_spec"] = enc
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
		# 2026-11-07 属性轮：胜场金币入局外档（greed 乘区已在 battle.gold_reward 内算）
		var gold := int(out.get("gold", 0))
		if gold > 0:
			_meta.add_gold(gold)
			_run["copper"] = int(_run.get("copper", 0)) + gold   # run 内累计显示
		# 2026-11-05 经验特效轮（用户令时序）：经验入账/升级已前移战斗屏内——珠到账即涨、
		# 满级立即弹三选一、升级关完才弹胜利横幅；此处取屏内结转快照直写，不再重算（防双算）
		var snap: Dictionary = out.get("run", {})
		if not snap.is_empty():
			for key in ["level", "xp", "deck", "pending_picks"]:
				if snap.has(key):
					_run[key] = snap[key]
		elif int(out.get("xp_gained", 0)) > 0:
			var lpb: Dictionary = VC.level_progress(int(_run.get("level", 1)),
				int(_run.get("xp", 0)) + int(out.get("xp_gained", 0)))
			_run["level"] = int(lpb["lvl"])
			_run["xp"] = int(lpb["xp"])
			if int(lpb["gained"]) > 0:
				_run["pending_picks"] = int(_run.get("pending_picks", 0)) + int(lpb["gained"])
		# 2026-11-06 碎牌：碎掉的卡从 run 卡组永久移除（按 cid 删一次出现——同名卡多张只碎一张）
		for sm in out.get("shattered", []):
			var deck_arr: Array = _run.get("deck", [])
			var di := deck_arr.find(String(sm.get("id", "")))
			if di >= 0:
				deck_arr.remove_at(di)
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
		var gifts: Array = ["feixing_shu", "cuipo_liao"] if int(_run.get("floor", 0)) == 0 else []
		_free_screens()
		_reward = VC_REWARD.new()
		_reward.setup(_run, gifts)
		_reward.card_chosen.connect(func(cid: String): _run["deck"].push_back(cid))   # 地图侧落点＝牌组
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

## 局外养成面板（2026-11-07 属性轮）：金币升级基础属性——ProgressionData 对应件。
## 简版：左列属性（名/当前级/下级加成/费用）＋升级钮；ESC/关闭回地图。
func _open_upgrade_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.add_theme_stylebox_override("panel", QISTYLE.panel(0.96))
	add_child(panel)
	_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(560.0, 0.0)
	panel.add_child(box)
	var title := Label.new()
	title.text = "修行（局外金币：%d）" % int(_meta.data["gold"])
	QISTYLE.font(title, 30, true)
	QISTYLE.text_color(title, QISTYLE.AMBER_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# 可升级轴（PROGRESSION_PER_LEVEL 的键＝有每级加成的轴）
	for axis in VC.PROGRESSION_TABLE.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var lv: int = _meta.upgrade_level(String(axis))
		var per: int = int(VC.PROGRESSION_TABLE[axis]["per"])
		var cn := String(VC.stat_cn_of(String(axis)))
		var info := Label.new()
		info.text = "%s  Lv.%d/%d  （每级 %+d%s）" % [cn, lv, int(VC.PROGRESSION_TABLE[axis]["max_lv"]), per,
			"%" if int(VC.stat_pct_of(String(axis))) else ""]
		QISTYLE.font(info, 19, false)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var btn := Button.new()
		if lv >= int(VC.PROGRESSION_TABLE[axis]["max_lv"]):
			btn.text = "已满"
			btn.disabled = true
		else:
			btn.text = "升级 %d 金" % _meta.upgrade_cost(String(axis))
			btn.disabled = int(_meta.data["gold"]) < _meta.upgrade_cost(String(axis))
			var ax := String(axis)
			btn.pressed.connect(func() -> void:
				if _meta.try_upgrade(ax):
					_open_upgrade_panel())   # 重开刷新
		row.add_child(btn)
	var close := Button.new()
	close.text = "关闭"
	QISTYLE.apply_primary(close)
	close.pressed.connect(func() -> void:
		if _panel != null and is_instance_valid(_panel):
			_panel.queue_free()
		_panel = null)
	box.add_child(close)

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
