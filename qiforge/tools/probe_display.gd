## 显示设置诊断探针（2026-10-29 用户报「开关正常、窗口无反应」）：
## 需真窗口跑（无头无 DisplayServer 行为）。两层各测一遍，读引擎侧状态为证：
##  §1 直调 QiPrefs.apply_display（窗口档 1280×720→全屏→退全屏）——验 API 链
##  §2 走真实设置弹窗按钮链（open_settings→点全屏开关）——验 handler 链
## 注意：跑时屏幕会真进全屏再退出（约 1 秒闪烁）。
extends SceneTree

const QIPREFS := preload("res://qiforge/QiPrefs.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAIL: 需真窗口跑（无头无 DisplayServer 行为）")
		quit(1)
		return
	var md0 := int(DisplayServer.window_get_mode())
	var sz0 := DisplayServer.window_get_size()
	print("起始 window_mode=%d size=%s" % [md0, str(sz0)])

	# —— §1 直调 API 链 ——
	QIPREFS.set_fullscreen(false)
	QIPREFS.set_resizable(true)
	QIPREFS.set_resolution(Vector2i(1280, 720))
	QIPREFS.apply_display()
	await create_timer(0.4).timeout
	var sz := DisplayServer.window_get_size()
	_near(sz.x, 1280, 12, "§1 直调窗口档宽=1280（得 %d）" % sz.x)
	_near(sz.y, 720, 12, "§1 直调窗口档高=720（得 %d）" % sz.y)

	QIPREFS.set_fullscreen(true)
	QIPREFS.apply_display()
	await create_timer(0.6).timeout
	var md := int(DisplayServer.window_get_mode())
	_eqt("§1 直调全屏后 window_mode=3(FULLSCREEN)", "3", str(md))

	QIPREFS.set_fullscreen(false)
	QIPREFS.apply_display()
	await create_timer(0.6).timeout
	md = int(DisplayServer.window_get_mode())
	_eqt("§1 退全屏后 window_mode=0(WINDOWED)", "0", str(md))
	sz = DisplayServer.window_get_size()
	print("§1 退全屏后 size=%s（分辨率偏好仍 1280×720 应落回）" % str(sz))

	# —— §2 真实弹窗按钮链 ——
	QIPREFS.set_resolution(Vector2i(1920, 1080))
	QIPREFS.apply_display()
	await create_timer(0.4).timeout
	var host := Control.new()   # 弹窗宿主须为 Control（游戏内＝QiRoot；探针＝临时全屏宿主）
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await process_frame
	QIPREFS.open_settings(host)
	await create_timer(0.2).timeout
	var fsbtn: Button = null
	var box := host.find_child("QiDialog", true, false)
	if box != null:
		for b in box.find_children("*", "Button", true, false):
			var bb := b as Button
			if bb.toggle_mode and "全屏" in String(bb.text):
				fsbtn = bb
				break
	_eqt("§2 设置弹窗内找到全屏开关", "true", str(fsbtn != null))
	if fsbtn != null:
		fsbtn.button_pressed = true   # 走 toggled→set_fullscreen→apply_display 全链
		await create_timer(0.6).timeout
		md = int(DisplayServer.window_get_mode())
		_eqt("§2 弹窗链全屏后 window_mode=3", "3", str(md))
		_eqt("§2 偏好已落 fullscreen=true", "true", str(QIPREFS.fullscreen()))
		fsbtn.button_pressed = false
		await create_timer(0.6).timeout
		md = int(DisplayServer.window_get_mode())
		_eqt("§2 弹窗链退全屏后 window_mode=0", "0", str(md))

	# —— 还原默认（全屏关＋1920×1080＋可调开）——
	QIPREFS.set_fullscreen(false)
	QIPREFS.set_resolution(Vector2i(1920, 1080))
	QIPREFS.set_resizable(true)
	QIPREFS.apply_display()
	await create_timer(0.3).timeout
	print("DISPLAY_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("DISPLAY_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)

func _near(v: float, want: float, tol: float, tag: String) -> void:
	if abs(v - want) > tol:
		fails.append(tag)

func _eqt(tag: String, want: String, got: String) -> void:
	if want != got:
		fails.append("%s（得 %s）" % [tag, got])
