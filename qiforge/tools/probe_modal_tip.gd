## 模态独占探针 v2（2026-10-28 静默化改版）：
## A 对照：无弹窗时合成 hover 单位卡 → 命中我方拖拽壳（输入链可用）。
## B 主张：QiDialog 开着（全屏 scrim STOP 输入门）→ 同一 hover 命不中底层卡（被 scrim 截走）
##   → mouse_entered 不会触发 → QiTooltip 无窗。旧版直测浮窗计数与 QiTooltip janitor 的
## 真实鼠标跟拍互斥（合成悬停喂不饱 get_mouse_position），故改为测输入门这一层。
## 跑法＝zsh qiforge/tools/run_probes.sh（离屏组，需真输入通道）。
extends SceneTree

const QITIP := preload("res://qiforge/QiTooltip.gd")
const QIDIALOG := preload("res://qiforge/QiDialog.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	var scr: Control = (load("res://qiforge/QiBattleScreen.tscn") as PackedScene).instantiate()
	root.add_child(scr)
	await process_frame
	await process_frame

	var ar: HBoxContainer = scr.get_node("AllyRow")
	var awrap: Control = ar.get_child(0).get_child(0)
	var acard: Control = awrap.get_child(0)
	var center := acard.get_global_rect().get_center()
	QITIP.hide_all()

	# A) 对照：无弹窗 hover → 命中我方壳（输入链通）
	await _hover(center)
	chk("A 对照：hover 命中我方壳", true, _hit_is(awrap))
	chk("A 对照：浮窗层未触发（janitor 真鼠标制，合成悬停不开窗——行为留真机验证）",
		0.0, _tip_count())

	# B) 开弹窗 → 同一 hover 被 scrim 截走 → 命不中底层卡 → 无浮窗
	var arr: Array = QIDIALOG.create(scr, "测试弹窗", Vector2(420, 240), "确定")
	var dialog: Control = arr[1]   # QiDialogBox（Control 弹窗制，勿回 AcceptDialog）
	dialog.popup_centered.call_deferred()
	for i in 6:
		await process_frame
	chk("B 前置：弹窗已打开", true, dialog.visible)
	await _hover(center)
	chk("B 主张：弹窗开着 hover 命不中底层卡", false, _hit_is(awrap))
	chk("B 主张：无浮窗生成", 0.0, _tip_count())

	dialog.canceled.emit()   # 走 QiDialog 统一关窗（STS2 制：输入门同帧放行，背板 0.3s 淡出纯视觉）
	await create_timer(0.45).timeout   # 墙钟等淡出（P5：按帧等对撞按时间走的补间——120Hz 屏 26 帧<0.3s 案）
	await _hover(center)
	chk("B 复原：关弹窗后 hover 恢复命中", true, _hit_is(awrap))
	_finish()

func _hover(p: Vector2) -> void:
	# root.push_input 派发（离屏窗口可用；Input.parse_input_event 无头/离屏均不派发 GUI）
	for i in 4:
		var m := InputEventMouseMotion.new()
		var pos := p + Vector2(float(i), -float(i))
		m.position = pos
		m.global_position = pos
		m.relative = Vector2(1, -1)
		root.push_input(m)
		await process_frame

func _hit_is(wrap: Control) -> bool:
	var h: Object = root.gui_get_hovered_control()
	return h != null and (h == wrap or (h is CanvasItem and wrap.is_ancestor_of(h)))

func _tip_count() -> float:
	for node in root.get_children():
		if node is CanvasLayer and node.is_in_group("qi_tip_layer"):
			return float(node.get_child(0).get_child_count())
	return 0.0

func chk(label: String, want: Variant, got: Variant) -> void:
	var ok := str(want) == str(got)
	if not ok:
		fails.append("%s：期望 %s 实得 %s" % [label, str(want), str(got)])
	print("%s %s" % ["FAIL" if not ok else "OK", label])

func _finish() -> void:
	print("MODAL_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("MODAL_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
