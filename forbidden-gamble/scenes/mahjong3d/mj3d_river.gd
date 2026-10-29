@tool
class_name Mj3dRiver
extends Node3D

## 牌河·真节点排样器（2026-09-21 用户令「往3D场景里面做牌河…敌我都有…多行…按组…一次行动一组
## 从中间往两侧…我方气海下方左侧开始、敌方上方右侧开始、中心对称」）。
## 结构两级：孩子＝组节点（Node3D，场景树顺序＝打出顺序），组孩子＝牌（Mj3dTileBlank 实例）。
## 本脚本只做**一键重排**（同 Mj3dHandRow 约定）：改导出值才按公式重铺全部组与牌；
## 不触发就完全不碰手调位姿。加减组/牌＝编辑器里复制删除节点。
## 中心对称实现：敌方侧**不改任何参数**——「敌方牌河」父节点绕 Y 转 180°（同敌方手牌做法），
## 局部坐标与我方同构（行序往 +z 展开），全局自动镜像到敌方侧。
## 区域左缘钉定制（2026-09-22 用户缩短行长后令「牌河区域左上角改成我缩短前的」——
## 区域不再随行长居中，左缘钉在 region_left＝−8.55（3×18 时代的区域左缘）；
## 内容自**区域左上角**锚定生长（行 0＝近气海行、自区域左缘往右铺）——敌方经父级
## 180° 镜像＝自**右下角**锚定。两遍排样（先分行、后落位）；行长 row_len 只管换行
## 容量，行内已放内容不随后续添加移动（预留制）。
## 容量纵向增长（2026-09-21 用户定）：基层 max_rows 行铺满后不外扩——上层从行 0 上方续叠，
## 层高＝牌厚（TILE_T×tile_scale）＋层间 x 偏移 layer_shift_x（用户令「不要完全覆盖 应该有点
## 偏移…有点层次感」；0＝正上方全盖）；越新的牌叠在越老的行上方，牌河信息永不丢。
## 位置量化 2 位小数（2026-09-21 用户令「数值都给个2位的 位置预留 不然可能会位置变化」）：
## 重排输出的组/牌位置一律 round 到 0.01——存档与重排逐位一致，杜绝浮点尾差。

const TILE_W := 19.0 / 26.0   # 躺牌行进向占宽（牌宽）
const TILE_LEN := 1.0          # 躺牌行深向占长（牌长，归一）
const TILE_T := 12.0 / 26.0    # 牌厚（躺平后立起高度）

@export var center_gap := 1.9:     # 中央留空半宽：首行近缘 z（行序往本方 +z 展开）
	set(v):
		center_gap = v
		_dirty = true
@export var row_len := 12.0:       # 行长（单位＝躺牌张数；2026-09-21 用户令行长 6 不行，定 12 可调 10）
	set(v):
		row_len = maxf(1.0, v)
		_dirty = true
@export var region_left := -8.55:  # 区域左缘 X（局部；2026-09-22 钉定不随行长居中——
                                   # 用户缩短 row_len 后令左上角回缩短前位置）
	set(v):
		region_left = v
		_dirty = true
@export var max_rows := 4:        # 基层行数——满行数后不外扩，上层从行 0 上方续叠（2026-09-21
                                 # 用户定「满了就新加一层 这样慢慢累加」；层高＝牌厚 0.6）
	set(v):
		max_rows = maxi(1, v)
		_dirty = true
@export var layer_shift_x := 0.5:  # 层间 x 偏移（牌宽数；0＝正上方全盖——2026-09-21 用户令
                                  # 「不要完全覆盖 应该有点偏移…有点层次感」）
	set(v):
		layer_shift_x = v
		_dirty = true
@export var group_gap := 0.35:     # 组间缝（牌宽数）
	set(v):
		group_gap = v
		_dirty = true
@export var spacing_k := 1.03:     # 组内牌距（牌宽倍数）
	set(v):
		spacing_k = v
		_dirty = true
@export var row_gap := 0.12:       # 行间缝（牌长数）
	set(v):
		row_gap = v
		_dirty = true
@export var tile_scale := 1.3:     # 牌体统一缩放（同手牌档，物理同大）
	set(v):
		tile_scale = maxf(0.3, v)
		_dirty = true

var _dirty := false


func _ready() -> void:
	# tscn 载入期 setter 先于入树触发（存档值≠默认值时）——入场清脏不重排，
	# tscn 存档位姿原样保留；用户在检查器改导出值才触发重排。
	_dirty = false


func _process(_dt: float) -> void:
	if _dirty:
		relayout()


## 一键重排（两遍）：先按行长把组分进行（基层满 max_rows → 上层行 0），再把每行以自身内容宽
## 在 x=0 轴居中落位（2026-09-21 用户令居中）；组内牌躺平仰面（头朝对面）；位置一律量化 2 位。
func relayout() -> void:
	var k := tile_scale
	var step := TILE_W * spacing_k * k
	var gap := group_gap * TILE_W * k
	var row_depth := (TILE_LEN + row_gap) * k
	var lift := TILE_T * 0.5 * k
	var shift := layer_shift_x * TILE_W * k
	# 第一遍：分行＋计每行内容宽（牌单位，含组缝）
	var rows: Array = []
	var cur := {}
	var used := 0.0
	var row := 0
	var layer := 0
	for g in get_children():
		if not (g is Node3D):
			continue
		if _tile_count(g) == 0:
			continue
		var w := _tile_count(g) * spacing_k
		if cur.is_empty():
			cur = {"layer": 0, "row": 0, "used": 0.0, "groups": []}
			rows.append(cur)
		elif used > 0.0 and used + group_gap + w > row_len:
			row += 1
			if row >= max_rows:
				row = 0        # 基层满 → 上层从行 0 上方续叠（+y 长高；x 偏 shift 露下层左缘）
				layer += 1
			used = 0.0
			cur = {"layer": layer, "row": row, "used": 0.0, "groups": []}
			rows.append(cur)
		if used > 0.0:
			used += group_gap
		cur.groups.append(g)
		used += w
		cur.used = used
	# 第二遍：左缘钉定落位——每行自区域左缘（region_left＋层偏移）起铺
	for r in rows:
		var ly: float = r.layer
		var rw: float = r.row
		var cursor := region_left + ly * shift
		var first := true
		for g in r.groups:
			var tiles := _tiles_of(g)
			if not first:
				cursor += gap
			first = false
			g.position = Vector3(_q(cursor), _q(ly * TILE_T * k), _q(center_gap + (rw + 0.5) * row_depth))
			for i in tiles.size():
				tiles[i].position = Vector3(_q((i + 0.5) * step), _q(lift), 0.0)
				tiles[i].rotation = Vector3(-PI / 2.0, 0.0, 0.0)
				tiles[i].scale = Vector3.ONE * k
			cursor += tiles.size() * spacing_k * TILE_W * k
	_dirty = false


func _tiles_of(g: Node) -> Array[Node3D]:
	var tiles: Array[Node3D] = []
	for c in g.get_children():
		if c is Node3D:
			tiles.append(c)
	return tiles


func _tile_count(g: Node) -> int:
	var n := 0
	for c in g.get_children():
		if c is Node3D:
			n += 1
	return n


func _q(v: float) -> float:
	return round(v * 100.0) / 100.0
