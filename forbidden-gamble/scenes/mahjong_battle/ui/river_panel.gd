class_name MJBRiverPanel
extends VBoxContainer

## 气河区（单侧·定宽，2026-09-17 用户布局令）：贴本侧手牌排——敌方在手牌左侧、我方在手牌行上方。
## **一次打出的批次＝一行内不拆**（行宽按最宽批次 9 张设计）；行满溢出换行：
## 我方向上排（新行在上）、敌方向下排（新行在下）；只留最近两行。
## 滞后入河：还挂在最新打出区的牌不显（hide_ids 按实例 id 对账）。
## 区宽与副露区同宽（ZONE_W 两组件共用值）。


const ZONE_W := 330.0
const TILE_W := 26
const TILE_H := 36
const BATCH_GAP := 14
const MAX_ROWS := 2
const TILE_GAP := 2


var _side := "enemy"


func _init(side := "enemy") -> void:
	_side = side
	custom_minimum_size = Vector2(ZONE_W, 0)


func update_panel(river: MJRiver, hide_ids: Array = []) -> void:
	for child in get_children():
		child.queue_free()
	# 1) 收本侧批次（同批次号＝同一次打出；整批隐藏＝批次未落河，跳过）
	var tiles := river.tiles
	var start := maxi(0, tiles.size() - 36)
	var batches: Array = []  # [{batch:int, tiles:Array[MJTile]}]
	for i in range(start, tiles.size()):
		if river.side_at(i) != _side:
			continue
		var tile := tiles[i]
		if hide_ids.has(tile.get_instance_id()):
			continue
		var batch := river.batch_at(i)
		if batches.is_empty() or int(batches.back()["batch"]) != batch:
			batches.append({"batch": batch, "tiles": []})
		(batches.back()["tiles"] as Array).append(tile)
	# 2) 批次流式装行：一次打出的批次不拆行；行宽超出 ZONE_W 换行
	var rows: Array = []
	var row_width := 0.0
	for b in batches:
		var width := float((b["tiles"] as Array).size()) * (TILE_W + TILE_GAP)
		if not rows.is_empty() and row_width > 0 and row_width + BATCH_GAP + width > ZONE_W:
			rows.append([])
			row_width = 0.0
		if rows.is_empty():
			rows.append([])
		var cur: Array = rows.back()
		if not cur.is_empty():
			width += BATCH_GAP
			row_width += BATCH_GAP
		cur.append(b)
		row_width += width
	# 3) 只留最近两行；我方新行在上（往上排）、敌方新行在下（往下排）
	if rows.size() > MAX_ROWS:
		rows = rows.slice(rows.size() - MAX_ROWS)
	if _side == "player":
		rows.reverse()
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", BATCH_GAP)
		line.alignment = BoxContainer.ALIGNMENT_BEGIN  # 从左缘向右排（两侧向中间——2026-09-17 用户令）
		for b in row:
			var group := HBoxContainer.new()
			group.add_theme_constant_override("separation", TILE_GAP)
			for t in b["tiles"]:
				group.add_child(MJBTileFace.make_tile(t as MJTile, TILE_W, TILE_H))
			line.add_child(group)
		add_child(line)
