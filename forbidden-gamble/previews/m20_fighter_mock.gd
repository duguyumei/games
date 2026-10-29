@tool
class_name M20FighterMock
extends PanelContainer

## m20 预览专用：2D MJBFighterPanel 同格式复刻（2026-09-18 用户令「敌我状态和基本信息
## 应该可以用2D吧」——格式照抄 2D：名 19＋分段气血＋心法 13＋资源 chips 13 逐项配色）。
## 数据全走导出假值；正式接线时整簇换真 MJBFighterPanel 喂 MJFighter，勿在预览上长功能。
## 位置＝节点自身 offset（2D 画布直接拖）；bg_alpha=0 即纯文字无底板。


const COL_NAME := Color(0.85, 0.8, 0.68)
const SEGMENT_HP := 10
const COL_FILLED := Color(0.72, 0.25, 0.2)
const COL_PARTIAL := Color(0.82, 0.45, 0.35)
const COL_EMPTY := Color(0.2, 0.18, 0.16)
# chips＝2D resource_strip 同序同色：丹田领衔，罡蓝变棕
const CHIP_STYLE := [
	["丹田", "chip_dantian", Color(0.72, 0.66, 0.52)],
	["攻", "chip_atk", Color(0.85, 0.55, 0.45)],
	["防", "chip_def", Color(0.6, 0.68, 0.6)],
	["劲", "chip_jin", Color(0.92, 0.68, 0.38)],
	["骨", "chip_gu", Color(0.66, 0.68, 0.78)],
	["气", "chip_qi", Color(0.78, 0.78, 0.42)],
	["罡", "chip_gang", Color(0.6, 0.78, 0.95)],
	["变", "chip_bian", Color(0.78, 0.7, 0.5)],
]


@export var display_name := "无名客":
	set(v):
		display_name = v
		_rebuild_if_ready()
@export var hp_now := 100:
	set(v):
		hp_now = v
		_rebuild_if_ready()
@export var hp_max := 100:
	set(v):
		hp_max = v
		_rebuild_if_ready()
@export var xinfa_name := "":
	set(v):
		xinfa_name = v
		_rebuild_if_ready()
# 2026-09-20 用户令「敌我基本信息和状态是透明的」——默认无底板（2D fighter_panel 本就
# 裸排无底），bg_alpha>0 才出半透明底＋描边（要衬托文字时再调）。
@export_range(0.0, 1.0) var bg_alpha := 0.0:
	set(v):
		bg_alpha = v
		_rebuild_if_ready()
@export var chip_dantian := 13:
	set(v):
		chip_dantian = v
		_rebuild_if_ready()
@export var chip_atk := 12:
	set(v):
		chip_atk = v
		_rebuild_if_ready()
@export var chip_def := 5:
	set(v):
		chip_def = v
		_rebuild_if_ready()
@export var chip_jin := 1:
	set(v):
		chip_jin = v
		_rebuild_if_ready()
@export var chip_gu := 0:
	set(v):
		chip_gu = v
		_rebuild_if_ready()
@export var chip_qi := 1:
	set(v):
		chip_qi = v
		_rebuild_if_ready()
@export var chip_gang := 0:
	set(v):
		chip_gang = v
		_rebuild_if_ready()
@export var chip_bian := 2:
	set(v):
		chip_bian = v
		_rebuild_if_ready()


func _ready() -> void:
	_build()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		c.free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBox
	if bg_alpha > 0.001:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.09, 0.085, 0.08, bg_alpha)
		flat.set_border_width_all(1)
		flat.border_color = Color(0.44, 0.39, 0.3, 0.8)
		flat.set_corner_radius_all(4)
		sb = flat
	else:
		sb = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(header)
	var name_l := Label.new()
	name_l.text = display_name
	name_l.add_theme_font_size_override("font_size", 19)
	header.add_child(name_l)
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 3)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(hp)
	var left := hp_now
	for _i in maxi(1, ceili(hp_max / float(SEGMENT_HP))):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(18, 16)
		seg.color = COL_FILLED if left >= SEGMENT_HP else (COL_PARTIAL if left > 0 else COL_EMPTY)
		hp.add_child(seg)
		left -= SEGMENT_HP
	var hp_l := Label.new()
	hp_l.text = "%d / %d" % [hp_now, hp_max]
	hp_l.add_theme_font_size_override("font_size", 15)
	hp.add_child(hp_l)
	if not xinfa_name.is_empty():
		var xf := Label.new()
		xf.text = xinfa_name
		xf.add_theme_font_size_override("font_size", 13)
		xf.add_theme_color_override("font_color", COL_NAME)
		header.add_child(xf)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 14)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(chips)
	for e in CHIP_STYLE:
		var l := Label.new()
		l.text = "%s %d" % [e[0], get(e[1])]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", e[2])
		chips.add_child(l)
