@tool
class_name Mj3dMeldZone
extends Node3D

## 副露区·真节点排样器（2026-09-21 建；09-22 三轮定形：①躺牌仰面（真桌摆法）；
## ②**被吃/碰/杠的那张牌横置**＝组内**右起第二张**横牌（面朝上、长轴沿行向）；
## ③**区域内靠右对齐**＋**一组一行竖排、组01＝最底行、沿 −z 逐行往上**（游戏中副露
## 从下往上排；最底行的底与牌河第三排的底一线——由根节点 z 落位）；组内**底边一条线**
## （横牌 z 前移 0.175＝近缘与竖牌齐）。整区位置＝根节点 transform，编辑器拖根节点即挪；
## 单组也可手拖（重排才回收）。
## 结构同牌河两级：孩子＝组节点（Node3D，场景树顺序＝副露顺序），组孩子＝牌
## （Mj3dTileBlank 实例，组内牌姿由存档决定）。本脚本只重排**组**（x 右对齐＋z 逐行）。
## 约定同 Mj3dRiver：改导出值才重排、_ready 清脏开档不碰手调位姿；位置量化 2 位。
## 敌我同构＝敌方根节点绕 Y 转 180°（同牌河做法）：局部同参，全局自动镜像到敌方侧
## （我方区在牌河右侧＝我方右手，敌方镜像＝其右手）；躺牌头朝 −Z 经镜像＝+Z 敌读正。

const TILE_HALF := Vector3(19.0 / 52.0, 0.5, 12.0 / 52.0)  # 牌体半尺寸（宽X×长Y×厚Z，长=1 归一）
const TILE_LEN := 1.0

@export var row_gap := 0.1:       # 行间缝（牌长数）
	set(v):
		row_gap = maxf(0.0, v)
		_dirty = true
@export var tile_scale := 1.3:    # 牌体统一缩放（同手牌/牌河档）
	set(v):
		tile_scale = maxf(0.3, v)
		_dirty = true
@export var start_x := 0.0:       # 区域右缘（局部 X；每组 x 包络右端对齐到此——右对齐）
	set(v):
		start_x = v
		_dirty = true

var _dirty := false


func _ready() -> void:
	# 同牌河：tscn 载入期 setter 触发的脏标记入场即清——开档不重排、存档位姿原样保留
	_dirty = false


func _process(_dt: float) -> void:
	if _dirty:
		relayout()


## 一键重排组（组内牌不动）：每组一行、组01＝最底行、沿 −z 逐行往上；x 右对齐区域右缘；量化 2 位。
func relayout() -> void:
	var pitch := (TILE_LEN + row_gap) * tile_scale
	var row := 0
	for g in get_children():
		if not (g is Node3D) or _tile_count(g) == 0:
			continue
		var gn := g as Node3D
		var xr: Array = _span_x(gn)
		gn.position.x = _q(gn.position.x + (start_x - xr[1]))
		gn.position.z = _q(-row * pitch)
		row += 1
	_dirty = false


func _tile_count(g: Node) -> int:
	var n := 0
	for c in g.get_children():
		if c is Node3D:
			n += 1
	return n


# 组 X 包络（组自身无旋转缩放，牌位置＋组位移）：躺/立/横牌通用＝OBB 沿 X 支撑长
# Σ|basis 列向量.x|×对应半尺寸（basis 已含缩放）
func _span_x(g: Node3D) -> Array:
	var xmin := 1e9
	var xmax := -1e9
	for c in g.get_children():
		if not (c is Node3D):
			continue
		var t := c as Node3D
		var px := t.position.x + g.position.x
		var ext := absf(t.basis.x.x) * TILE_HALF.x + absf(t.basis.y.x) * TILE_HALF.y + absf(t.basis.z.x) * TILE_HALF.z
		xmin = minf(xmin, px - ext)
		xmax = maxf(xmax, px + ext)
	return [xmin, xmax]


func _q(v: float) -> float:
	return round(v * 100.0) / 100.0
