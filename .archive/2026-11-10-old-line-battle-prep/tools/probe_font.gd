## 字体统一回归探针（2026-10-28 用户裁定：黄油体退役、全项目统一 Noto Sans SC）。
## 跑法＝非无头：godot --path . --script res://qiforge/tools/probe_font.gd
## 直调浮窗工厂（悬停合成事件不稳）→ 断言「敌方意图」标题 Label 的 theme font＝QiFontBank.noto() 同一实例＋截图。
extends SceneTree

const SCR := preload("res://qiforge/QiBattleScreen.tscn")
const QITIP := preload("res://qiforge/QiTooltip.gd")
const QIF := preload("res://qiforge/QiFontBank.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	var screen: Control = SCR.instantiate()
	root.add_child(screen)
	for i in 30:
		await process_frame
	var erec: Dictionary = (screen.get("_enemy_slots") as Array)[0]
	var chip: Control = erec["chip"]
	# 直调静态构建（show_for 受每帧看门人回收——鼠标不在宿主区即摘窗，探针环境留不住）
	var win: Control = QITIP._build_win(
		[{"t": "title", "text": "敌方意图"}, {"t": "line", "text": "内容行字体统一测试。"}],
		{"type": "意图", "min_w": 260.0})
	var title_lbl: Label = null
	var stack: Array = [win]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and String((n as Label).text) == "敌方意图":
			title_lbl = n
		for c in n.get_children():
			stack.push_back(c)
	if title_lbl == null:
		fails.append("构建窗内未找到标题 Label")
	else:
		var f: Font = title_lbl.get_theme_font("font")
		print("TITLE_FONT_CLASS=", f.get_class(), " SAME_AS_NOTO=", f == QIF.noto())
		if f != QIF.noto():
			fails.append("标题字体非 Noto 同一实例（%s）" % str(f))
	# 顺手验一个正文行（RichTextLabel 正常字体＝Noto 默认主题）
	var rtl: RichTextLabel = null
	stack = [win]
	while not stack.is_empty():
		var n2: Node = stack.pop_back()
		if n2 is RichTextLabel:
			rtl = n2
		for c in n2.get_children():
			stack.push_back(c)
	if rtl != null:
		print("LINE_FONT=", rtl.get_theme_font("normal_font"), " SAME=", rtl.get_theme_font("normal_font") == QIF.noto())
	win.queue_free()
	print("FONT_FAILS=%d" % fails.size())
	for s in fails:
		print("FAIL: " + s)
	print("FONT_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
