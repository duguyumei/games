## VC 楼层地图生成探针（2026-11-01 地图轮）：纯 QiVcMapGen/QiVcBattle 断言（无 UI）。
## 断言链：五层全生成＋全地格连通 → 种子确定性（同种子同图）→ 撒点合法（实体在地格上/起点无实体/
## 计数对表＋Boss 层无铲）→ BFS 全实体可达 → enc_spec 覆盖口（明雷组队遭遇照 spec 建、可打赢）。
extends SceneTree

const VC := preload("res://qiforge/QiVcData.gd")
const MAPGEN := preload("res://qiforge/QiVcMapGen.gd")
const VC_BATTLE := preload("res://qiforge/QiVcBattle.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	var seed0 := 20261101
	# —— ① 五层生成＋连通＋撒点合法 ——
	for f in VC.FLOORS.size():
		var spec: Dictionary = VC.FLOORS[f]
		var m: Dictionary = MAPGEN.floor_map(seed0, f, spec)
		_eq("层%d 全地格连通" % (f + 1), true, MAPGEN.all_reachable(m))
		_eq("层%d 起点在地格上" % (f + 1), 1, m["grid"][m["start"].y][m["start"].x])
		var floor_set := {}
		for y in int(m["h"]):
			for x in int(m["w"]):
				if m["grid"][y][x] == 1:
					floor_set[Vector2i(x, y)] = true
		var n_enemy := 0
		var n_chest := 0
		var n_shovel := 0
		var n_boss := 0
		var n_exit := 0
		var start_hit := false
		for e in m["entities"]:
			if not floor_set.has(e["cell"]):
				fails.append("层%d 实体 %s 撒在墙上 %s" % [(f + 1), String(e["type"]), str(e["cell"])])
			if (e["cell"] as Vector2i) == (m["start"] as Vector2i):
				start_hit = true
			match String(e["type"]):
				"enemy": n_enemy += 1
				"chest": n_chest += 1
				"shovel": n_shovel += 1
				"boss": n_boss += 1
				"exit": n_exit += 1
		_eq("层%d 明雷数=%d" % [(f + 1), int(spec["enemies"])], int(spec["enemies"]), n_enemy)
		_eq("层%d 宝箱数=%d" % [(f + 1), int(spec["chests"])], int(spec["chests"]), n_chest)
		_eq("层%d 起点格无实体", false, start_hit)
		if String(spec.get("boss", "")) != "":
			_eq("层%d Boss=1", 1, n_boss)
			_eq("层%d Boss 层无铲", 0, n_shovel)
		elif String(spec.get("fixed", "")) != "":
			_eq("层%d 教程出口=1", 1, n_exit)
			_eq("层%d 教程层无铲", 0, n_shovel)
			_eq("层%d 教程明雷全带固定编队", n_enemy,
				(m["entities"] as Array).filter(func(e): return e.has("group")).size())
		else:
			_eq("层%d 铲子=1", 1, n_shovel)
		# BFS：起点到每个实体可达
		for e in m["entities"]:
			if MAPGEN.path(m, m["start"], e["cell"]) == null:
				fails.append("层%d 实体 %s 不可达 %s" % [(f + 1), String(e["type"]), str(e["cell"])])

	# —— ② 种子确定性：同种子同图（网格哈希＋实体序列）——
	var m1: Dictionary = MAPGEN.generate(seed0, 2, VC.FLOORS[2])
	var m2: Dictionary = MAPGEN.generate(seed0, 2, VC.FLOORS[2])
	_eq("同种子同网格", true, str(m1["grid"]) == str(m2["grid"]))
	_eq("同种子同实体序列", true, str(m1["entities"]) == str(m2["entities"]))
	var m3: Dictionary = MAPGEN.generate(seed0 + 1, 2, VC.FLOORS[2])
	_eq("异种子图不同（99% 置信口径）", true, str(m1["grid"]) != str(m3["grid"]))

	# —— ③ enc_spec 覆盖口：明雷组队遭遇照 spec 建＋可打赢 ——
	var run: Dictionary = VC.default_vc_run()
	run["enc_spec"] = {"name": "蝙蝠×2", "active_max": 2, "refill": 0, "pool": ["bat", "bat"]}
	var b: RefCounted = VC_BATTLE.new()
	b.setup(run)
	b.start()
	_eq("enc_spec 名生效", "蝙蝠×2", String(b.encounter["name"]))
	_eq("enc_spec 活跃 2", 2, b.encounter["active"].size())
	_eq("enc_spec 无补位", 0, int(b.encounter["refill"]))
	b.hand = [b._make_card("cuipo_liao_heavy")]   # 45×1 撩月斩直调清两只 8 血蝠（pentagram 未入现役）
	b.player["qi"] = 99
	var got := [""]
	b.ended.connect(func(r: String): got[0] = String(r))
	b.play_card(int(b.hand[0]["uid"]))   # 45 伤溢出链清场（refill=0 总池空）
	_eq("明雷遭遇可胜（无波次）", "win", got[0])
	# 2026-11-09 死帧入账制：击杀拍已进账，无需 settle
	_eq("击杀经验累加（清两蝠＝2）", 2, int(b.xp_gained))
	_eq("写回源带经验（player_out）", 2, int(b.player_out().get("xp_gained", 0)))

	# —— ④ 升级三选一逻辑（2026-11-01 奖励轮）：曲线/归并/分段费权出题 ——
	_eq("经验曲线 L1→2 需基础值 5", 5, VC.xp_to_next(1))
	_eq("经验曲线 L2 需 10", 10, VC.xp_to_next(2))
	_eq("经验曲线 L10 需 12", 12, VC.xp_to_next(10))
	_eq("经验曲线 L25 需 18（现行曲线）", 18, VC.xp_to_next(25))
	_eq("经验曲线 L46 需 28", 28, VC.xp_to_next(46))
	var lp0: Dictionary = VC.level_progress(1, 25)
	_eq("连续升级归并（25xp→4 级余 0）", [4, 0], [int(lp0["lvl"]), int(lp0["xp"])])
	var lp1: Dictionary = VC.level_progress(1, 7)
	_eq("教程第三场后突破（7xp→2 级余 2）", [2, 2], [int(lp1["lvl"]), int(lp1["xp"])])
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	for i in 6:
		var offers: Array = VC.reward_offers(rng2, 1, VC.START_DECK)
		_eq("三选一＝3 张", 3, offers.size())
		var uniq := {}
		for o in offers:
			uniq[o] = true
			if not VC.CARDS.has(o):
				fails.append("三选一出不存在的卡 %s" % String(o))
			if int(VC.CARDS[String(o)]["cost"]) > 1:
				fails.append("1 级段出了超档费卡 %s" % String(o))
			if String(VC.CARDS[String(o)].get("kind", "")) != "attack":
				fails.append("低级段出了非攻击卡 %s" % String(o))
			if (VC.START_DECK as Array).has(String(o)):
				fails.append("低级段出了已持有的卡 %s" % String(o))
		_eq("三选一互异", 3, uniq.size())
	_eq("高段（25 级）出题 3 张", 3, VC.reward_offers(rng2, 25, []).size())
	_eq("开局卡组＝孤张（VC Deck_Tutorial 制）", 1, VC.START_DECK.size())
	var tut_m: Dictionary = MAPGEN.floor_map(seed0, 0, VC.FLOORS[0])
	var xp1 := 0
	var xp2 := 0
	# 教程编队＝嵌套排制（2026-11-07 敌阵队列制：group=[[一排],[二排]]）——拍平计数
	for grp in tut_m["entities"][0]["group"]:
		for eid in grp:
			xp1 += int(VC.ENEMIES[String(eid)].get("xp", 0))
	for grp in tut_m["entities"][1]["group"]:
		for eid in grp:
			xp2 += int(VC.ENEMIES[String(eid)].get("xp", 0))
	_eq("教程首场＝1 蝠（XP 1）", [1, 1],
		[int((tut_m["entities"][0]["group"] as Array).size()), xp1])
	var e1_total := 0
	for grp2 in tut_m["entities"][1]["group"]:
		e1_total += int((grp2 as Array).size())
	_eq("教程第二场＝3 蝠（一排 3）", 3, e1_total)
	_eq("两场合计 XP=5（2026-11-08 用户令：一级打完第二关正好首升）", 5, xp1 + xp2)
	var lp_t: Dictionary = VC.level_progress(1, 5)
	_eq("5 XP 正好首升（余 0）", [2, 0], [int(lp_t["lvl"]), int(lp_t["xp"])])


	# —— ⑤ 难度选敌制（2026-11-07：教程固定豁免/标签过滤/回退保底）——
	var rng5 := RandomNumberGenerator.new()
	rng5.seed = 42
	var f_bats: Dictionary = VC.FLOORS[2]   # 蝙蝠巢 difficulty 2.0（池 bat 1.0 / mudman 2.0——均在容差内）
	var picks5: Array = VC.pick_enemies_by_difficulty(rng5, f_bats, f_bats["pool"], 20)
	_eq("难度选敌：20 选全在容差池", true, picks5.all(func(e): return ["bat", "mudman"].has(e)))
	var f_crypt: Dictionary = VC.FLOORS[3]   # 乱葬岗 3.5（bat 1.0 超容差被滤）
	var picks6: Array = VC.pick_enemies_by_difficulty(rng5, f_crypt, f_crypt["pool"], 20)
	_eq("难度过滤：蝙蝠(1.0) 不入 3.5 层", true, not picks6.has("bat"))
	var picks7: Array = VC.pick_enemies_by_difficulty(rng5, f_bats, ["bat"], 3)
	_eq("单池全中", true, picks7.size() == 3 and picks7.all(func(e): return e == "bat"))
	var f_tut: Dictionary = VC.FLOORS[0]   # 教程层 fixed——选敌不走（组队由 group 嵌套死编队）
	_eq("教程层 fixed 标记", "tutorial", String(f_tut.get("fixed", "")))
	_eq("方差归一：0→0 / 5→0.5 / 10→1", "0.0/0.5/1.0",
		"%.1f/%.1f/%.1f" % [VC.difficulty_variance(0.0), VC.difficulty_variance(5.0), VC.difficulty_variance(10.0)])

	_finish()

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("VC_MAP_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("VC_MAP_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
