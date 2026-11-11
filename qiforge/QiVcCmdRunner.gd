## 统一命令队列（2026-11-12 立，1:1 对齐原版 CommandRunner——ISIL 实证住
## design-docs/references/吸血鬼爬行者_伤害管线逆向_v0.1.md §6.2）。
## 原版形状：单全局队列装「视图/演出命令」；数据结算同步、表现命令化；
## UpdateCommandRunner 单协程顺序排空；IsProcessing＝队列非空或任一在飞；
## Wait(seconds)＝纯延时命令；ClearCommands＝清空。
##
## 本件（QiVcCardCmd 泛化升格——四律齐备：编排职责单一/阻塞分层/顺延 at/done 必达）：
##   命令＝{kind, uid, delay, barrier, payload, launcher}；launcher(payload, done: Callable)
##   push()    —— 入队（delay 秒错峰、uid 同前序守卫、barrier 整队等）
##   push_wait() —— 纯延时命令（CommandRunner.Wait 同构）
##   tick()    —— 宿主 _process 驱动：到点且无阻塞即启动
##   is_busy() / signal all_done（忙→空沿）/ clear() / drain()（同步排空兜底）
extends RefCounted

signal all_done

var _queue: Array = []      # 未启动命令（FIFO）
var _live: Array = []       # 已启动未落定

func push(kind: String, payload, launcher: Callable, delay := 0.0, uid := -1,
		barrier := false) -> void:
	var cmd := {"kind": kind, "uid": uid, "delay": delay, "barrier": barrier,
		"payload": payload, "launcher": launcher}
	cmd["at"] = Time.get_ticks_msec() + int(delay * 1000.0)
	_queue.push_back(cmd)
	tick()

## 纯延时命令（原版 CommandRunner.Wait(seconds) 同构——排队中的呼吸位）
func push_wait(sec: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	push("wait", null, func(_p, done: Callable) -> void:
		if tree != null:
			tree.create_timer(maxf(0.01, sec), false).timeout.connect(done)
		else:
			done.call(), 0.0)

## 每帧驱动（宿主 _process 调；push/落定也自调）：到点且无阻塞的命令启动。
## 阻塞语义分层：barrier/错峰＝FIFO 保序（break 整队等，barrier 期间 at 顺延——
## 错峰不被阻塞吃掉）；同 uid 前序＝单卡语义（只跳过本卡，不阻塞无关命令）。
func tick() -> void:
	var i := 0
	while i < _queue.size():
		var cmd: Dictionary = _queue[i]
		if bool(cmd["barrier"]) and not _live.is_empty():
			cmd["at"] = Time.get_ticks_msec() + int(float(cmd["delay"]) * 1000.0)
			break   # 屏障：等在飞全清（「先弃完再抽」语义——at 顺延保错峰）
		if _uid_live(int(cmd["uid"])):
			i += 1   # 同 uid 前序在飞：跳过本卡继续看后面
			continue
		if Time.get_ticks_msec() < int(cmd["at"]):
			break   # 错峰未到（FIFO 保序下后到的必然更晚）
		_queue.remove_at(i)
		_live.push_back(cmd)
		_start(cmd)   # 不递增 i：后一元素已移到本位

func is_busy() -> bool:
	return not _queue.is_empty() or not _live.is_empty()

func clear() -> void:
	_queue.clear()
	_live.clear()

## 同步排空（无屏/探针兜底）：逐条启动并当场落定——行为等价旧同步循环。
## 仅对「即时完成」的命令成立（演出命令若真挂了动画则 drain 会同步等不了 tween——
## 探针路径不该有动画，Screen 路径走 tick）。
func drain() -> void:
	while is_busy():
		tick()
		if _live.is_empty() and _queue.is_empty():
			break
		if not _queue.is_empty() and _live.is_empty():
			# 队首还被 at 挡着：把时间拨到它的 at（探针不等错峰）
			var head: Dictionary = _queue[0]
			head["at"] = 0
		for c in _live.duplicate():
			_finish(c)

# ── 内部 ────────────────────────────────────────────────────────────

func _uid_live(uid: int) -> bool:
	if uid < 0:
		return false
	for c in _live:
		if int(c["uid"]) == uid:
			return true
	return false

func _start(cmd: Dictionary) -> void:
	var launcher: Callable = cmd["launcher"]
	var done := func() -> void: _on_done(cmd)
	if launcher.is_valid():
		launcher.call(cmd["payload"], done)
		return
	done.call()   # 无启动器：立即落定（不卡队列）

func _on_done(cmd: Dictionary) -> void:
	_finish(cmd)
	if _queue.is_empty() and _live.is_empty():
		all_done.emit()   # 忙碌期→空沿（消费者先查 is_busy 再 await，无沿不空等）
	tick()

func _finish(cmd: Dictionary) -> void:
	_live.erase(cmd)
