## 一次性生成 qiforge/qi_theme.tres（少码优先制·样式进 Theme）：
## Button 两变体（QiGhost＝墨底次级钮 / QiPrimary＝琥珀主钮）——样式定义从屏幕代码挪进 Theme 资源，
## 屏幕只挂 theme_type_variation。面板/浮窗等带参数样式盒仍走 QiStyle 构建器（见档注）。
## 跑法：godot --headless --path . --script res://qiforge/tools/build_theme.gd
extends SceneTree

func _initialize() -> void:
	var t := Theme.new()
	t.set_type_variation("QiGhost", "Button")
	t.set_type_variation("QiPrimary", "Button")

	# —— QiGhost：墨底次级钮（战斗屏/备战舱功能钮、刷新、价格签…） ——
	var gh := StyleBoxFlat.new()
	gh.bg_color = Color(0.23, 0.18, 0.13, 0.92)
	gh.border_color = Color("6b5426")
	gh.set_border_width_all(2)
	gh.set_corner_radius_all(10)
	gh.content_margin_left = 18.0
	gh.content_margin_right = 18.0
	gh.content_margin_top = 6.0
	gh.content_margin_bottom = 6.0
	var gh_h := gh.duplicate()
	gh_h.bg_color = Color(0.30, 0.24, 0.16, 0.95)
	t.set_stylebox("normal", "QiGhost", gh)
	t.set_stylebox("hover", "QiGhost", gh_h)
	t.set_stylebox("pressed", "QiGhost", gh_h)
	t.set_stylebox("focus", "QiGhost", StyleBoxEmpty.new())

	# —— QiPrimary：琥珀主钮（结束回合/出战/系统升级…） ——
	var pr := StyleBoxFlat.new()
	pr.bg_color = Color("8a6428")
	pr.border_color = Color("c9a227")
	pr.set_border_width_all(3)
	pr.set_corner_radius_all(12)
	pr.content_margin_left = 24.0
	pr.content_margin_right = 24.0
	pr.content_margin_top = 8.0
	pr.content_margin_bottom = 8.0
	var pr_h := pr.duplicate()
	pr_h.bg_color = Color("a37a30")
	t.set_stylebox("normal", "QiPrimary", pr)
	t.set_stylebox("hover", "QiPrimary", pr_h)
	t.set_stylebox("pressed", "QiPrimary", pr_h)
	t.set_stylebox("focus", "QiPrimary", StyleBoxEmpty.new())

	var err := ResourceSaver.save(t, "res://qiforge/qi_theme.tres")
	print("THEME_SAVED err=", err)
	quit(1 if err != OK else 0)
