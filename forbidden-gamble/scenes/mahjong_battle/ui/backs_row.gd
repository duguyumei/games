@tool
class_name MJBBacksRow
extends HBoxContainer

## 敌方背牌带（2026-09-18 用户令：从敌方信息簇拆出独立上桌——敌我信息簇对称 52px，
## 牌都在桌上）：防御翼｜背牌（恒居中）｜攻击翼——两翼等宽撑开贴中。
## 背牌＝敌方手牌数的暗面；两翼武学名（名＋运行拍数小字）随每次刷新重建。


const COL_NAME := Color(0.85, 0.8, 0.68)
const COL_RUNNING := Color(0.98, 0.85, 0.3)
const TILE_W := 20
const TILE_H := 30


var _left_techs := HBoxContainer.new()   # 左翼＝防御武学（贴手牌侧）
var _backs := HBoxContainer.new()        # 中＝背牌行（恒居中）
var _right_techs := HBoxContainer.new()  # 右翼＝攻击武学（贴手牌侧）
var _tech_caps: Dictionary = {}          # tech_id -> {name: Label, cap: Label}（运行态刷写）


func _init() -> void:
	custom_minimum_size = Vector2(0, 52)  # 编辑器占位＝背牌带行高（透视放大后远端背牌 ~46；背牌运行时才生成）
	add_theme_constant_override("separation", 12)
	_left_techs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_techs.alignment = BoxContainer.ALIGNMENT_END  # 贴手牌侧（靠中）
	add_child(_left_techs)
	_backs.add_theme_constant_override("separation", 2)
	add_child(_backs)
	_right_techs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_techs.alignment = BoxContainer.ALIGNMENT_BEGIN  # 贴手牌侧（靠中）
	add_child(_right_techs)


func update_backs(f: MJFighter, techniques: Dictionary) -> void:
	for side in [_left_techs, _backs, _right_techs]:
		for child in (side as HBoxContainer).get_children():
			(side as HBoxContainer).remove_child(child)  # 立即摘树：queue_free 延迟摘除会让重建当帧 min 虚高（旧翼仍占位翻倍，2026-09-18 实锤）
			child.queue_free()
	_tech_caps.clear()
	# 透视定尺寸（2026-09-18 用户令：与全桌同大，只按远近缩放）
	var sz := MJBPerspective.tile_size_at(_backs.get_global_rect().get_center().y)
	for _i in range(f.hand.size()):
		_backs.add_child(MJBTileFace.make_back(sz.x, sz.y))
	_append_tech_names(techniques)
	_sync_running(f, techniques)


# 敌方武学名（只显名，详情浮窗）：防御入左翼、攻击入右翼；名下小字＝运行拍数。
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


# 运行态刷写（每次 update_backs 调）：护体生效＝武学名金亮＋"剩N拍"；在途＝"等N拍"。
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
