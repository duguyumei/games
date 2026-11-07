## 敌方总行为条（2026-11-06）：符号＋数字，攻击/护盾各一组。
## 数据来源（2026-11-07 意图接口化，对应 EncounterIntentView→TryGetIntentValues）：
## battle.merged_intent_total()（逐敌攻击值之和）＋ 前排各敌 current_intent 的结甲值。
## 两组都为 0 时整条隐藏。
extends Control

const ICON := preload("res://qiforge/QiIntentIcon.gd")
const QISTYLE := preload("res://qiforge/QiStyle.gd")

var _atk_i: Control = null
var _atk_l: Label = null
var _arm_i: Control = null
var _arm_l: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atk_i = _mk_icon("attack", Color(0.52, 0.15, 0.10), 0.0)
	_atk_l = _mk_lbl(Color(0.52, 0.15, 0.10), 0.0)
	_arm_i = _mk_icon("armor", Color(0.18, 0.30, 0.46), 108.0)
	_arm_l = _mk_lbl(Color(0.18, 0.30, 0.46), 108.0)
	visible = false

func _mk_icon(k: String, col: Color, x: float) -> Control:
	var c := ICON.new()
	c.kind = k
	c.tint = col
	c.position = Vector2(x + 8.0, 0.0)
	c.size = Vector2(42.0, 42.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _mk_lbl(col: Color, x: float) -> Label:
	var l := Label.new()
	l.position = Vector2(x + 2.0, 45.0)
	l.size = Vector2(58.0, 28.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(l, 24, true)
	QISTYLE.text_color(l, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func update_from(b: RefCounted) -> void:
	if b == null:
		return
	# 2026-11-07 意图接口化：禁直读 battle._intents（已退役）——
	# 攻值走聚合口，护盾值逐敌查 current_intent（结甲意图 projected=0 不进聚合口）
	var atk := int(b.merged_intent_total())
	var arm := 0
	for e in b.get("encounter")["active"]:
		if not bool(e.get("alive", true)) or int(e.get("row", 0)) > 0:
			continue
		if bool(e.get("just_spawned", false)) or int(e.get("skip", 0)) > 0:
			continue
		var act: Dictionary = e.get("current_intent", {})
		if String(act.get("kind", "")) == "armor":
			arm += int(act.get("value", 0))
	_atk_i.visible = atk > 0
	_atk_l.visible = atk > 0
	_atk_l.text = str(atk)
	_arm_i.visible = arm > 0
	_arm_l.visible = arm > 0
	_arm_l.text = str(arm)
	# 只有一边时居中
	if atk <= 0 and arm > 0:
		_arm_i.position.x = size.x * 0.5 - 21.0
		_arm_l.position.x = size.x * 0.5 - 29.0
	elif arm <= 0 and atk > 0:
		_atk_i.position.x = size.x * 0.5 - 21.0
		_atk_l.position.x = size.x * 0.5 - 29.0
	visible = atk > 0 or arm > 0
