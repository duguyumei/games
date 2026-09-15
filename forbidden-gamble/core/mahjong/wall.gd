class_name MJWall
extends RefCounted

# 气海（真气语法 v3 §1–2）：三门 × 九值 × 4 张 ＝ 108 张均匀共墙，双方共吸。
# 死牌山退役（2026-09-16 用户拍板："直接融入气海。后续要的话再加"）——全墙皆活。
# 干涸＝活墙摸空；供应由对局引擎触发气河整条洗回（本类只管存取，不管循环）。

const COPIES := 4
const TOTAL := 3 * 9 * 4  # 108

var live: Array[MJTile] = []


func setup(rng: RandomNumberGenerator) -> void:
	live.clear()
	var all: Array[MJTile] = []
	for suit in MJTile.SUITS:
		for value in range(MJTile.VALUE_MIN, MJTile.VALUE_MAX + 1):
			for _copy in range(COPIES):
				all.append(MJTile.make(suit, value))
	# 种子洗牌（Fisher–Yates，确定性）
	for i in range(all.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := all[i]
		all[i] = all[j]
		all[j] = tmp
	live = all


# 从活墙顶摸牌（调用方需先查 is_dry 或依赖引擎的循环保障）。
func draw(count: int) -> Array[MJTile]:
	var drawn: Array[MJTile] = []
	for _i in range(count):
		if live.is_empty():
			break
		drawn.append(live.pop_front())
	return drawn


func live_left() -> int:
	return live.size()


func is_dry() -> bool:
	return live.is_empty()


# 气河整条洗回（引擎在活墙干涸时调用）：追加后整活墙重洗。
func recycle(tiles: Array[MJTile], rng: RandomNumberGenerator) -> void:
	live.append_array(tiles)
	for i in range(live.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := live[i]
		live[i] = live[j]
		live[j] = tmp
