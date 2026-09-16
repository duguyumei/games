class_name MJRiver
extends RefCounted

# 气河（真气语法 v3 §2）：共用排出口——弃牌、被功法耗用之式的牌，全入；
# 气海干涸时由引擎整条洗回（drain）。分河读牌的损失由副露明牌补偿（读"他攒什么式"优于读"他弃过什么"）。
# origins 与 tiles 平行：每张牌的打出方（展示用——机制仍是共用气河；洗回时一并清）。
# batches 与 tiles 平行：同一次 add（＝一次打出的批次）同号（展示分组用——组内间隔小、批次间隔大）。


var tiles: Array[MJTile] = []
var origins: Array[String] = []
var batches: Array[int] = []
var _batch_seq := 0


func add(batch: Array, side: String = "") -> void:
	_batch_seq += 1
	for tile in batch:
		tiles.append(tile)
		origins.append(side)
		batches.append(_batch_seq)


# 整条取走（供气河→气海循环）。
func drain() -> Array[MJTile]:
	var drained := tiles.duplicate()
	tiles.clear()
	origins.clear()
	batches.clear()
	return drained


func size() -> int:
	return tiles.size()


# 第 i 张牌的打出方（"player"|"enemy"，未知＝空串）。
func side_at(i: int) -> String:
	if i < 0 or i >= origins.size():
		return ""
	return origins[i]


# 第 i 张牌的批次号（同一次打出同号；展示分组用）。
func batch_at(i: int) -> int:
	if i < 0 or i >= batches.size():
		return -1
	return batches[i]
