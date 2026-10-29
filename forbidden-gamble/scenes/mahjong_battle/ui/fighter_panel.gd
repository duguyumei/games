@tool
class_name MJBFighterPanel
extends VBoxContainer

## 一侧 fighter 的信息簇（2026-09-18 用户令：敌我同构对称——敌方背牌带已拆出独立上桌
## 见 backs_row）：气血行居左（旁挂心法名）＋资源读数（丹田领衔、攻防居劲左）。


const COL_NAME := Color(0.85, 0.8, 0.68)


var _hp := MJBHpStrip.new()
var _xinfa := Label.new()
var _resources := MJBResourceStrip.new()


@export var display_name := ""  # 展示名（场景装配可调；2026-09-18 场景化改造）


func _init(p_name := "") -> void:
	display_name = p_name


# 子节点构建挪至 _ready：场景实例化路径＝_init 无参→场景注入导出值→_ready 按值构建。
func _ready() -> void:
	add_theme_constant_override("separation", 3)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	add_child(header)  # 血量行居左
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 19)
	header.add_child(name_label)
	header.add_child(_hp)
	_xinfa.add_theme_font_size_override("font_size", 13)
	_xinfa.add_theme_color_override("font_color", COL_NAME)
	header.add_child(_xinfa)
	add_child(_resources)


func update_panel(f: MJFighter, show_charge := false, xinfa_list: Array = []) -> void:
	_hp.update_hp(f.hp_display(), f.max_hp_display(),
		"精确值 %.2f / %d（内部两位小数，显示向上取整）" % [f.hp_fp / 100.0, f.max_hp_display()])
	_update_xinfa(xinfa_list)
	_resources.update_resources(f, show_charge)


# 心法（血量旁，只显名＋浮窗）：多门以顿号相连；无门隐藏。
func _update_xinfa(xinfa_list: Array) -> void:
	if xinfa_list.is_empty():
		_xinfa.text = ""
		_xinfa.visible = false
		return
	var names: Array[String] = []
	var lines: Array = []
	for xf in xinfa_list:
		var x := xf as MJXinfa
		names.append(x.display_name)
		var body := x.summary().trim_prefix(x.display_name + "（").trim_suffix("）")
		lines.append(body if not body.is_empty() else x.summary())
	_xinfa.text = "、".join(names)
	_xinfa.visible = true
	MJBTipFloat.bind(_xinfa, "心法", lines)
