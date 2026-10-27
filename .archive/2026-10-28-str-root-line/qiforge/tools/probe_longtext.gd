## 验收探针（无头）：效果区区域保护——超长文自动缩号（下限 10）＋行尾省略＋面板硬裁；常规件保持 12
extends SceneTree

var _frames: int = 0
var _host: Control = null

func _initialize() -> void:
	change_scene_to_file("res://scenes/Root.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		_host = Control.new()
		root.add_child(_host)
		var card_style = load("res://qiforge/QiCardStyle.gd")
		var long_desc: String = "消耗 1 点真气，对敌单体造成 4 点伤害；若目标带有破绽，则额外造成 2 点伤害并封其一处穴道，直到回合结束为止不能行动。"
		var longer: String = long_desc + "此牌每回合首次打出后，抽一张牌并获得 1 点内力，内力可叠加至三层，三层后转化为护体真气。"

		var base: Button = card_style.make_spell_card("术法一", 1, longer, 0, "", "身法")
		base.position = Vector2(50, 50)
		_host.add_child(base)
		var medium: Button = card_style.make_spell_card("术法二", 2, "消耗 2 点真气，对敌单体造成 6 点伤害。", 0, "", "身法")
		medium.position = Vector2(300, 50)
		_host.add_child(medium)
		var detail: Button = card_style.make_spell_detail_card("术法一", 1, longer,
			"伤害提升至 6 点，封穴延长至下回合结束", "追加：目标每带一层破绽，额外造成 1 点伤害",
			0, "", "身法")
		detail.position = Vector2(560, 50)
		_host.add_child(detail)
		return false
	if _frames == 50:
		_check("超长基础卡", _host.get_child(0), 10)
		_check("常规基础卡", _host.get_child(1), 12)
		_check_detail(_host.get_child(2))
		quit()
		return true
	return false

func _check(tag: String, card: Button, expect_size: int) -> void:
	var panel: Panel = _find_panel(card)
	var label: Label = panel.get_child(0).get_child(0) as Label
	var resolved: int = int(label.get_theme_font_size("font_size"))
	var need_h: float = 0.0
	var font: Font = label.get_theme_font("font")
	if font != null:
		need_h = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
			label.size.x, resolved).y
	print("diag: [", tag, "] 卡=", card.size, " 效果板=", panel.size, " 字号=", resolved,
		" (expect ", expect_size, ") 文字区高=", label.size.y, " 该字号需高=", need_h,
		" 省略号=", label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		" 面板硬裁=", panel.clip_contents)

func _check_detail(card: Button) -> void:
	var panel: Panel = _find_panel(card)
	var box: VBoxContainer = panel.get_child(0) as VBoxContainer
	for child in box.get_children():
		if child is Label:
			var label: Label = child
			var resolved: int = int(label.get_theme_font_size("font_size"))
			print("diag: [详情卡] 卡=", card.size, " (expect 270x345) 详情板=", panel.size,
				" 主文字号=", resolved, " 面板硬裁=", panel.clip_contents)
			break

func _find_panel(card: Control) -> Panel:
	# 效果/详情面板判据＝Panel＋clip_contents（v3.0 布局名字带 y≈176 也会 >130，须靠硬裁位区分）
	for child in card.get_children():
		if child is Panel and child.clip_contents:
			return child
	return null
