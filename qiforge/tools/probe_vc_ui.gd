## VC UI 几何探针（复刻线 2026-11-01）：定位「两块新屏内容挤上半」布局 bug。
## 无头建 QiVcRoot（.tscn）→ 逐层量尺寸：根 Control／地图屏／其 VBox／底栏可见性；
## 再 _start_battle 量战斗屏：root_v／我方面板行／手牌行位置尺寸／手牌壳数。
## 跑法＝无头 -s（probe_lib.fit 矫正视口）；断言失败会打出全部 P: 诊断行辅助定责。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")
const VC_ROOT_SCENE := preload("res://qiforge/QiVcRoot.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var host: Control = VC_ROOT_SCENE.instantiate()
	root.add_child(host)
	await process_frame
	await process_frame
	await process_frame

	var vp := Vector2(1920, 1080)
	_eq("根 Control 铺满视口", vp, host.size)
	var map_c: Control = host._map
	_p("map.size=%s pos=%s anchors(r/b)=%s/%s" % [map_c.size, map_c.position,
		map_c.anchor_right, map_c.anchor_bottom])
	_eq("地图屏铺满根", vp, map_c.size)
	_p("map 令牌数=%d（实体 %d）" % [map_c._tokens.size(),
		(host._run["map"]["entities"] as Array).size()])
	_eq("实体令牌全部生成", (host._run["map"]["entities"] as Array).size(), map_c._tokens.size())
	_eq("玩家令牌在树", true, map_c._player_token != null and map_c._player_token.is_inside_tree())

	host._start_battle(host._first_enemy_entity())
	await process_frame
	await process_frame
	await process_frame
	var scr: Control = host._screen
	_p("screen.size=%s pos=%s" % [scr.size, scr.position])
	_eq("战斗屏铺满根", vp, scr.size)
	var scr_bg: Control = scr.get_child(0)
	_p("screen 首子 size=%s pos=%s" % [scr_bg.size, scr_bg.position])
	_eq("战斗屏首子＝全幅底板（机柜同壳制）", vp, scr_bg.size, 1.0)
	var hand: Array = scr._hand_wraps
	_p("手牌扇 n=%d" % hand.size())
	_eq("手牌扇有壳（开局孤卡制：抽 3 但组内 1 张→手 1）", true, hand.size() >= 1)
	if hand.size() > 0:
		var sh0: Control = hand[0]
		_p("首壳 pos=%s size=%s 全局=%s" % [sh0.position, sh0.size, sh0.global_position])
		_eq("手牌基线带（y 600~1080，飞入 Lerp 中容差）", true,
			sh0.position.y > 600.0 and sh0.position.y <= 1080.5)
		_eq("手牌壳尺寸＝手牌档 216×304", Vector2(216.0, 304.0),
			Vector2(roundf(sh0.size.x), roundf(sh0.size.y)))
	var endb: Button = scr._end_btn
	_p("结束回合钮 pos=%s size=%s 全局y=%s" % [endb.position, endb.size, endb.global_position.y])
	_eq("结束回合钮在画面内", true, endb.global_position.y < 1080.5)
	_finish()

func _p(text: String) -> void:
	print("P: " + text)

func _eq(tag: String, want: Variant, got: Variant, tol: float = 0.0) -> void:
	var ok := false
	if tol > 0.0 and want is float and got is float:
		ok = absf(want - got) <= tol
	else:
		ok = str(want) == str(got)
	if not ok:
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("VC_UI_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("VC_UI_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
