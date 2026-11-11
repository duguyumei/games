## 卡动画命令队列（2026-11-12 立，1:1 对齐原版 CommandRunner＋ViewCommand 编排——
## ISIL 实证：CardPileView.CardAddedViewCommand＝WaitFor.Seconds(错峰)→
## WaitUntil(!HasAnimationInterrupts)→TryAddCard；CommandRunner.IsProcessing＝队列非空
## 或任一在飞；胜利流程 WaitWhile(IsProcessing) 等清空）。
## 取代旧「rebuild 一次性摆 tween＋ms 墙钟（_fly_busy_until/_shuffle_busy_until）」制——
## 墙钟靠余量猜时长（0.4 vs 实际 0.36）天然脆；命令制每命令自追踪完成，精确落定。
##
## 命令三类（kind）：
##   "removed" —— 弃牌飞出（手牌冲弃/已打出区回收；启动器由宿主注入）
##   "added"   —— 抽牌飞入（错峰起飞；**全局屏障**：所有 removed/shuffle 落定才起飞
##                ＝2026-11-06 用户令「先弃完再抽」的队列化表达）
##   "shuffle" —— 洗牌特效占位（纯延时命令；added 让路由屏障统一覆盖）
## 启动有先后、各自追踪完成（逐张错峰飞，不串行卡死）；同 uid 前序未完则等
## （对位 HasAnimationInterrupts 单卡语义——弃后重抽同实例不叠动画）。
## 消费口：is_busy()＝IsProcessing 同构；signal all_done＝忙碌期→空沿（一沿一发）。
extends RefCounted

signal all_done

var _queue: Array = []          # 未启动命令（FIFO 保序——队首阻塞则全体等，同原版队列）
var _live: Array = []           # 已启动未落定命令
var _launch_removed: Callable = Callable()   # 宿主注入：(wrap, delay, done: Callable)
var _launch_added: Callable = Callable()     # 宿主注入：(wrap, delay, done: Callable)

func setup(launch_removed: Callable, launch_added: Callable) -> void:
	_launch_removed = launch_removed
	_launch_added = launch_added

func push_removed(wrap: Control, delay: float) -> void:
	_push({"kind": "removed", "uid": int(wrap.get_meta("hand_uid", -1)),
		"wrap": wrap, "delay": delay})

func push_added(wrap: Control, delay: float) -> void:
	_push({"kind": "added", "uid": int(wrap.get_meta("hand_uid", -1)),
		"wrap": wrap, "delay": delay})

func push_shuffle() -> void:
	_push({"kind": "shuffle", "uid": -2, "wrap": null, "delay": 0.0})

func _push(cmd: Dictionary) -> void:
	cmd["at"] = Time.get_ticks_msec() + int(float(cmd["delay"]) * 1000.0)
	_queue.push_back(cmd)
	tick()

## 每帧驱动（宿主 _process 调；push/落定也自调）：到点且无阻塞的命令启动
## 阻塞语义分层（审计修 2026-11-12）：屏障/错峰＝FIFO 保序（break 整队等）；
## 同 uid 前序＝单卡语义（只跳过本卡，不阻塞无关命令——HasAnimationInterrupts 同构）
func tick() -> void:
	var i := 0
	while i < _queue.size():
		var cmd: Dictionary = _queue[i]
		var kind := String(cmd["kind"])
		if kind == "added" and (_has_live("removed") or _has_live("shuffle")):
			# 全局屏障：先弃完（洗完）再抽。at 随阻塞顺延——错峰不被屏障吃掉
			# （放行时刻起算 delay，保住逐张 stagger——审计修）
			cmd["at"] = Time.get_ticks_msec() + int(float(cmd["delay"]) * 1000.0)
			break
		if _uid_live(int(cmd["uid"])):
			i += 1   # 同 uid 前序在飞：跳过本卡继续看后面
			continue
		if Time.get_ticks_msec() < int(cmd["at"]):
			break   # 错峰未到（WaitFor.Seconds 同构；FIFO 保序下后到的必然更晚）
		_queue.remove_at(i)
		_live.push_back(cmd)
		_start(cmd)   # 不递增 i：后一元素已移到本位

func is_busy() -> bool:
	return not _queue.is_empty() or not _live.is_empty()

func clear() -> void:
	_queue.clear()
	_live.clear()

# ── 内部 ────────────────────────────────────────────────────────────

func _has_live(kind: String) -> bool:
	for c in _live:
		if String(c["kind"]) == kind:
			return true
	return false

func _uid_live(uid: int) -> bool:
	for c in _live:
		if int(c["uid"]) == uid:
			return true
	return false

func _start(cmd: Dictionary) -> void:
	var done := func() -> void: _on_done(cmd)
	match String(cmd["kind"]):
		"removed":
			if _launch_removed.is_valid():
				_launch_removed.call(cmd["wrap"], float(cmd["delay"]), done)
				return
		"added":
			if _launch_added.is_valid():
				_launch_added.call(cmd["wrap"], float(cmd["delay"]), done)
				return
		"shuffle":
			var host := Engine.get_main_loop() as SceneTree
			if host != null:
				host.create_timer(0.32, false).timeout.connect(done)
				return
	done.call()   # 无启动器/无树：立即落定（不卡队列）

func _on_done(cmd: Dictionary) -> void:
	_live.erase(cmd)
	if _queue.is_empty() and _live.is_empty():
		all_done.emit()   # 忙碌期→空沿（消费者先查 is_busy 再 await，无沿不空等）
	tick()
