@tool
class_name MJBResourceStrip
extends HBoxContainer

## 资源读数条：**丹田数领衔**（手牌张数，2026-09-17 用户令——原手牌区标题行退役，腾出行空间）；
## 三力分列各带各的浮窗与色（劲＝暖橙、骨＝冷钢、气＝草黄）；罡＝蓝、变＝棕、攻＝红、防＝灰绿。
## 只显当前；上限/充能/公式入浮窗，"怎么获取/干嘛用"在顶栏问号词条。


func _init() -> void:
	add_theme_constant_override("separation", 14)


func update_resources(f: MJFighter, show_charge := false) -> void:
	for child in get_children():
		child.queue_free()
	_chip("丹田 %d" % f.hand.size(), Color(0.72, 0.66, 0.52), "丹田（手牌数）", [
		"静息账本：手牌 ＋ 3×副露组数 收敛于 13",
		"当前手牌 %d 张" % f.hand.size()])
	_chip("攻 %d" % f.attack_panel(), Color(0.85, 0.55, 0.45), "攻击面板", [
		"攻 %d ＝ 10 ＋ 2×劲%d" % [f.attack_panel(), f.jin_li]])
	_chip("防 %d" % f.defense_panel(), Color(0.6, 0.68, 0.6), "防御", [
		"承伤比 ＝ 5/(5＋防)",
		"防 %d → 5/(5＋%d) ＝ %d%%" % [f.defense_panel(), f.defense_panel(), f.damage_taken_ratio() / 10]])
	_chip("劲 %d" % f.jin_li, Color(0.92, 0.68, 0.38), "劲", [
		"劲＝出力：攻 +2/点",
		"攻 %d ＝ 基础10 ＋ 2×劲%d" % [f.attack_panel(), f.jin_li]])
	_chip("骨 %d" % f.gu_li, Color(0.66, 0.68, 0.78), "骨", [
		"骨＝承伤：防 +1/点",
		"防 %d → 承伤 %d%%" % [f.defense_panel(), f.damage_taken_ratio() / 10]])
	_chip("气 %d" % f.qi_li, Color(0.78, 0.78, 0.42), "气（气力）", [
		"气＝流转：每拍变招充能 ＋1/点；每逢 3 点缺牌补充 ＋1"])
	_chip("罡 %d" % f.gang_qi, Color(0.6, 0.78, 0.95), "罡（罡气）", [
		"当前 %d / 上限 %d" % [f.gang_qi, f.GANG_QI_CAP]] + (["护体生效期间冻结"] if f.iron_active else []))
	if show_charge:
		_chip("变 %d" % f.bian_opps, Color(0.78, 0.7, 0.5), "变招", [
			"充能 %d/%d → 1 机会（每个自身拍 ＋%d）" % [f.bian_charge, f.BIAN_STEP, 1 + f.qi_li],
			"换一张 1 机会 ／ 换组 3 机会"])
	else:
		_chip("变 %d" % f.bian_opps, Color(0.78, 0.7, 0.5), "变招", ["机会 %d" % f.bian_opps])
	if f.iron_active:
		_chip("护体 免伤%d%%·%d拍" % [f.iron_reduction, f.iron_beats_left], Color(0.75, 0.8, 0.9))


func _chip(text: String, color: Color, tip_title := "", tip_lines: Array = []) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	if not tip_title.is_empty():
		MJBTipFloat.bind(label, tip_title, tip_lines)
