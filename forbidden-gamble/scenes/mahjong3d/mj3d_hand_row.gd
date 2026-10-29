@tool
class_name Mj3dHandRow
extends Node3D

## 我方手牌行·真节点排样器（2026-09-20 用户令「我需要能够调整 不然我怎么看是什么位置 什么角度」）。
## 孩子牌＝场景树真节点（可点选/W 拖位/R 转角/存档）；本脚本只做**一键重排**：
## 改导出值（间距/仰角/离沿）或父桌 net_side 时按公式重铺全部孩子——
## 不触发时就完全不碰牌，手调的单张位置/角度原样保留。
## 加减张＝编辑器里对牌节点右键复制/删除（重排按现存张数居中）。

const TILE_W := 19.0 / 26.0

@export var spacing_k := 1.06:  # 间距×牌宽
	set(v):
		spacing_k = v
		_dirty = true
@export var lean_deg := 25.0:   # 后仰角（重排时套用）
	set(v):
		lean_deg = v
		_dirty = true
@export var inset := 1.0:       # 距近沿（牌长数，未含缩放）
	set(v):
		inset = v
		_dirty = true
@export var tile_scale := 1.0:  # 牌体统一缩放（2026-09-20 用户令调大麻将——桌子机位不动，动牌）
	set(v):
		tile_scale = maxf(0.3, v)
		_dirty = true

var _dirty := false
var _built_for := -1.0


func _ready() -> void:
	# tscn 载入时 setter 顺序不定，避免覆盖手调存档：入场不重排
	_built_for = (get_parent() as Mj3dTable).net_side if get_parent() is Mj3dTable else -1.0


func _process(_dt: float) -> void:
	var table := get_parent() as Mj3dTable
	if table == null:
		return
	if _dirty or not is_equal_approx(table.net_side, _built_for):
		relayout()


## 一键重排：按现公式铺全部孩子（编辑器里手动改导出值后触发；也可手动调用）
func relayout() -> void:
	var table := get_parent() as Mj3dTable
	if table == null:
		return
	var n := get_child_count()
	if n == 0:
		return
	var rad := deg_to_rad(lean_deg)
	var k := tile_scale
	var lift := 0.5 * k * cos(rad)   # 后仰立牌：底棱贴地补偿（含缩放）
	var push := -0.5 * k * sin(rad)
	var z := table.net_side * 0.5 - inset + push
	var step := TILE_W * spacing_k * k
	for i in n:
		var t := get_child(i)
		# 位置量化 2 位（2026-09-21 用户令「数值都给个2位的」——存档与重排逐位一致）
		t.position = Vector3(_q((i - (n - 1) * 0.5) * step), _q(lift), _q(z))
		t.rotation = Vector3(-rad, 0, 0)
		t.scale = Vector3.ONE * k
	_dirty = false
	_built_for = table.net_side


func _q(v: float) -> float:
	return round(v * 100.0) / 100.0
