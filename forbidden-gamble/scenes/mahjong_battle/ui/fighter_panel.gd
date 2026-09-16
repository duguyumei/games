class_name MJBFighterPanel
extends VBoxContainer

## 一侧 fighter 的信息簇：气血行左侧（旁挂心法名）＋资源读数（丹田领衔、攻防居劲左）＋
## （敌方）手牌带行（防御翼·背牌·攻击翼，手牌恒居中）。
## 敌方河/副露区不在此簇内——住中部两翼列（根协调器装配，2026-09-17 用户令：
## 打出区/战报与敌河/敌副露同层三列，打出区贴敌手牌带下方起）。


const COL_NAME := Color(0.85, 0.8, 0.68)
const COL_RUNNING := Color(0.98, 0.85, 0.3)

var _hp := MJBHpStrip.new()
var _xinfa := Label.new()
var _resources := MJBResourceStrip.new()
var _left_techs := HBoxContainer.new()   # 敌方手牌带·左翼＝防御武学（贴手牌侧）
var _backs := HBoxContainer.new()        # 敌方手牌带·中＝背牌行（恒居中）
var _right_techs := HBoxContainer.new()  # 敌方手牌带·右翼＝攻击武学（贴手牌侧）
var _tech_caps: Dictionary = {}  # 敌方武学 tech_id -> {name: Label, cap: Label}（运行态刷写）


func _init(display_name: String, show_backs := false) -> void:
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
	if show_backs:
		add_child(_build_band())


# 敌方手牌带行：防御翼｜背牌｜攻击翼——两翼等宽撑开、翼内贴中，背牌恒居屏幕中。
func _build_band() -> Control:
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 12)
	_left_techs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_techs.alignment = BoxContainer.ALIGNMENT_END  # 贴手牌侧（靠中）
	band.add_child(_left_techs)
	_backs.add_theme_constant_override("separation", 2)
	band.add_child(_backs)
	_right_techs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_techs.alignment = BoxContainer.ALIGNMENT_BEGIN  # 贴手牌侧（靠中）
	band.add_child(_right_techs)
	return band


func update_panel(f: MJFighter, techniques: Dictionary, show_charge := false, xinfa_list: Array = []) -> void:
	_hp.update_hp(f.hp_display(), f.max_hp_display(),
		"精确值 %.2f / %d（内部两位小数，显示向上取整）" % [f.hp_fp / 100.0, f.max_hp_display()])
	_update_xinfa(xinfa_list)
	_resources.update_resources(f, show_charge)
	if _backs.get_parent() != null:
		for side in [_left_techs, _backs, _right_techs]:
			for child in (side as HBoxContainer).get_children():
				child.queue_free()
		_tech_caps.clear()
		for _i in range(f.hand.size()):
			_backs.add_child(MJBTileFace.make_back(20, 30))
		_append_tech_names(techniques)
	_sync_running(f, techniques)


# 敌方武学名（只显名，详情浮窗）：防御入左翼、攻击入右翼；名下小字＝运行拍数（护体剩N拍/在途等N拍）。
func _append_tech_names(techniques: Dictionary) -> void:
	_left_techs.add_theme_constant_override("separation", 12)
	_right_techs.add_theme_constant_override("separation", 12)
	for kind in ["defense", "attack"]:
		for tech_id in techniques:
			var tech: MJTechnique = techniques[tech_id]
			if tech == null or tech.kind != kind:
				continue
			var stack := VBoxContainer.new()
			stack.add_theme_constant_override("separation", 0)
			var row := Label.new()
			row.text = tech.display_name
			row.add_theme_font_size_override("font_size", 14)
			row.add_theme_color_override("font_color", COL_NAME)
			var cap := Label.new()
			cap.add_theme_font_size_override("font_size", 11)
			cap.add_theme_color_override("font_color", COL_RUNNING)
			stack.add_child(row)
			stack.add_child(cap)
			MJBTipFloat.bind_tech(row, tech)
			_tech_caps[String(tech_id)] = {"name": row, "cap": cap}
			if kind == "defense":
				_left_techs.add_child(stack)
			else:
				_right_techs.add_child(stack)


# 运行态刷写（每次 _refresh 调）：护体生效＝该武学名金亮＋"剩N拍"；在途＝"等N拍"。
func _sync_running(f: MJFighter, techniques: Dictionary) -> void:
	for tech_id in _tech_caps:
		var entry: Dictionary = _tech_caps[tech_id]
		var tech: MJTechnique = techniques.get(tech_id)
		if tech == null:
			continue
		var cap_text := ""
		var running := false
		if tech.kind == "defense" and f.iron_active:
			running = true
			cap_text = "剩%d拍" % f.iron_beats_left
		for c in f.pending:
			if String(c["tech_id"]) == String(tech_id):
				running = true
				cap_text = "等%d拍" % maxi(int(c.get("windup", 1)) - int(c.get("elapsed", 0)), 0)
		(entry["name"] as Label).add_theme_color_override("font_color", COL_RUNNING if running else COL_NAME)
		(entry["cap"] as Label).text = cap_text


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
