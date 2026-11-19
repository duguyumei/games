## QiAnimTrace —— 全局动画时间线账本（span tracing 文字版，2026-11-19 用户令建）。
## 业内同构：Unity ProfilerMarker.Begin/End、前端 performance.mark()、Tracy ZoneScoped
## ——手动埋点划定业务区间（引擎无法自动知道「洗牌飞行」「1s 垫拍」的语义边界，手动
## 埋点即业内标准）。Godot 无现成区间 dump 件（add_custom_monitor 只画曲线图、
## EngineProfiler 要自写编辑器插件 UI），此为最薄文字版：纯观测、不改任何行为、
## 数据只住内存。观测件非复刻系统，不适用结构 1:1（无原版对应物，自有 API）。
## 用法（preload 静态调用，静态变量全脚本共享）：
##   const AT := preload("res://qiforge/QiAnimTrace.gd")
##   var id := AT.begin("洗牌飞行#3")   # 区间开始 → 票据（可并行多条/同名多条）
##   AT.end(id)                          # 区间结束（票据失效安全：清场/中断后 end 直接忽略）
##   AT.mark("死亡拍")                   # 瞬时事件点（时间轴里程碑/基准）
##   AT.dump("胜利收尾")                 # 倒表：相对基准（最早事件）排序打印全部区间
##   AT.reset()                          # 清账（新战斗开始）
## 时间源＝Time.get_ticks_msec() 墙钟（暂停期间照走——反映真实体感）＋帧号随行
## （首帧时序取证制：只打最终坐标/时刻不算取证）。
extends RefCounted

static var _spans: Array = []      # 区间账本：{tag, t0, t1(ms), f0, f1(帧), seq}
static var _marks: Array = []      # 瞬时点账本：{tag, t, f, seq}
static var _open: Dictionary = {}  # seq → 未闭合区间（漏 end 的在 dump 标 ⚠）
static var _seq := 0

## 区间开始：登记名字＋起跑墙钟/帧号，返回票据
static func begin(tag: String) -> int:
	_seq += 1
	var sp := {"tag": tag, "seq": _seq, "t0": Time.get_ticks_msec(), "t1": -1,
		"f0": Engine.get_frames_drawn(), "f1": -1}
	_spans.push_back(sp)
	_open[_seq] = sp
	return _seq

## 区间结束：补落结束墙钟/帧号；未知票据/重复 end 静默忽略（清场路径票据已随 reset 作废）
static func end(id: int) -> void:
	var sp: Dictionary = _open.get(id, {})
	if sp.is_empty():
		return
	sp["t1"] = Time.get_ticks_msec()
	sp["f1"] = Engine.get_frames_drawn()
	_open.erase(id)

## 瞬时事件点：只记时刻不做区间
static func mark(tag: String) -> void:
	_seq += 1
	_marks.push_back({"tag": tag, "seq": _seq, "t": Time.get_ticks_msec(),
		"f": Engine.get_frames_drawn()})

## 清账：未闭合区间一并清（清场动画的票据随之作废，之后 end 无害）
static func reset() -> void:
	_spans.clear()
	_marks.clear()
	_open.clear()

## 倒表：区间＋事件点合并按时刻排序，相对基准（最早事件）打印；未闭合区间标 ⚠。
## 纯 print 无副作用；空账本直接返回。
static func dump(title: String) -> void:
	if _spans.is_empty() and _marks.is_empty():
		return
	var rows: Array = []
	for sp in _spans:
		rows.push_back({"kind": "span", "t": int(sp["t0"]), "tag": String(sp["tag"]), "rec": sp})
	for mk in _marks:
		rows.push_back({"kind": "mark", "t": int(mk["t"]), "tag": String(mk["tag"]), "rec": mk})
	rows.sort_custom(func(a, b) -> bool: return int(a["t"]) < int(b["t"]))
	var base := int(rows[0]["t"])
	var last := int(rows[rows.size() - 1]["t"])
	print("[动画时间线·%s] 基准＝%s（t=%d，共 %d 条）" % [title, String(rows[0]["tag"]), base, rows.size()])
	for row in rows:
		var rel := int(row["t"]) - base
		if row["kind"] == "mark":
			print("   +%5dms           │◆ %s（帧 %d）" % [rel, String(row["tag"]), int(row["rec"]["f"])])
		else:
			var sp: Dictionary = row["rec"]
			if int(sp["t1"]) < 0:
				print("   +%5dms →  ⚠未闭合 │  %s（帧 %d→?）" % [rel, String(sp["tag"]), int(sp["f0"])])
			else:
				print("   +%5dms → +%5dms │  %s（帧 %d→%d）%dms" % [rel, int(sp["t1"]) - base,
					String(sp["tag"]), int(sp["f0"]), int(sp["f1"]), int(sp["t1"]) - int(sp["t0"])])
	print("   ── 基准→末事件 总账 %dms" % (last - base))
