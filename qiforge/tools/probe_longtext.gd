## 效果区区域保护探针（v2 纯工厂直测，2026-10-28 脱离旧 Root 屏宿主）：
## 超长文自动缩号（下限 10）＋行尾省略＋面板硬裁；常规件保持 12；详情面板裁剪在位。
## 跑法＝非无头：godot --path . --script res://qiforge/tools/probe_longtext.gd
extends SceneTree

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QICARD := preload("res://qiforge/QiCardStyle.gd")

var fails: Array = []
var _host: Control = null

func _initialize() -> void:
	_run()

func _run() -> void:
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)
	await process_frame
	QISTYLE.apply_root_theme(_host)   # 根窗默认字体（Noto）——裸宿主自挂（入树后隔帧，window 才就位）
	var long_desc: String = "消耗 1 点真气，对敌单体造成 4 点伤害；若目标带有破绽，则额外造成 2 点伤害并封其一处穴道，直到回合结束为止不能行动。"
	var longer: String = long_desc + "此牌每回合首次打出后，抽一张牌并获得 1 点内力，内力可叠加至三层，三层后转化为护体真气。"
	var base: Button = QICARD.make_spell_card("功法一", 1, longer, 0, "")
	base.position = Vector2(50, 50)
	_host.add_child(base)
	var medium: Button = QICARD.make_spell_card("功法二", 2, "消耗 2 点真气，对敌单体造成 6 点伤害。", 0, "")
	medium.position = Vector2(300, 50)
	_host.add_child(medium)
	var detail: Button = QICARD.make_spell_detail_card("功法一", 1, longer,
		"伤害提升至 6 点，封穴延长至下回合结束", "追加：目标每带一层破绽，额外造成 1 点伤害",
		0, "")
	detail.position = Vector2(560, 50)
	_host.add_child(detail)
	for i in 40:
		await process_frame
	_check("超长基础卡", base, 10)
	_check("常规基础卡", medium, 12)
	_check_detail(detail)
	_finish()

func _check(tag: String, card: Button, expect_size: int) -> void:
	var panel: Panel = _find_panel(card)
	if panel == null:
		fails.append("%s：效果面板缺失" % tag)
		return
	var label: Label = panel.get_child(0).get_child(0) as Label
	var resolved: int = int(label.get_theme_font_size("font_size"))
	_eq("%s 字号=%d（期望 %d）" % [tag, resolved, expect_size], expect_size, resolved)
	_eq("%s 面板硬裁在位" % tag, true, panel.clip_contents)
	_eq("%s 行尾省略挂线" % tag, true,
		label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS)
	var font: Font = label.get_theme_font("font")
	var need_h: float = 0.0
	if font != null:
		need_h = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
			label.size.x, resolved).y
	print("diag: [", tag, "] 卡=", card.size, " 效果板=", panel.size, " 字号=", resolved,
		" 文字区高=", label.size.y, " 该字号需高=", need_h)

func _check_detail(card: Button) -> void:
	var panel: Panel = _find_panel(card)
	if panel == null:
		fails.append("详情卡：详情面板缺失")
		return
	var box: VBoxContainer = panel.get_child(0) as VBoxContainer
	if box == null:
		fails.append("详情卡：面板内无内容盒")
		return
	_eq("详情卡尺寸（工厂 detail 档）", true,
		absf(card.size.x - QICARD.size_of("detail").x) < 2.0
		and absf(card.size.y - QICARD.size_of("detail").y) < 2.0)
	_eq("详情卡面板硬裁在位", true, panel.clip_contents)
	var found := false
	for child in box.get_children():
		if child is Label:
			found = true
			print("diag: [详情卡] 卡=", card.size, " 主文字号=",
				int((child as Label).get_theme_font_size("font_size")))
			break
	_eq("详情卡主文行存在", true, found)

func _find_panel(card: Control) -> Panel:
	# 效果/详情面板判据＝Panel＋clip_contents（名字带也是 Panel 但无硬裁）
	for child in card.get_children():
		if child is Panel and child.clip_contents:
			return child
	return null

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("LONGTEXT_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("LONGTEXT_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
