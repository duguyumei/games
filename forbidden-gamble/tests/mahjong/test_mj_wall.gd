extends GutTest

# 气海（真气语法 v3 §1–2）：108 均匀共墙（死牌山已退役，全墙皆活）＋种子确定性＋气河洗回。


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_wall_all_live() -> void:
	var wall := MJWall.new()
	wall.setup(_rng(1))
	assert_eq(wall.live_left(), MJWall.TOTAL, "108 张全部入气海常规流转（死牌山退役）")


func test_wall_uniform_composition() -> void:
	var wall := MJWall.new()
	wall.setup(_rng(7))
	var count := {}
	for tile in wall.live:
		var key := (tile as MJTile).key()
		count[key] = int(count.get(key, 0)) + 1
	assert_eq(count.size(), 27, "三门×九值")
	for key in count:
		assert_eq(int(count[key]), 4, "%s 恰好 4 张" % key)


func test_wall_seeded_determinism() -> void:
	var a := MJWall.new()
	a.setup(_rng(42))
	var b := MJWall.new()
	b.setup(_rng(42))
	var da := a.draw(10)
	var db := b.draw(10)
	assert_eq(da.size(), 10)
	for i in range(10):
		assert_true((da[i] as MJTile).same(db[i] as MJTile), "同种子同序")


func test_wall_draw_decreases_live() -> void:
	var wall := MJWall.new()
	wall.setup(_rng(3))
	var drawn := wall.draw(3)
	assert_eq(drawn.size(), 3)
	assert_eq(wall.live_left(), MJWall.TOTAL - 3)


func test_wall_recycle_shuffles_back() -> void:
	var wall := MJWall.new()
	wall.setup(_rng(9))
	var before := wall.live_left()
	var tiles: Array[MJTile] = [MJTile.make("万", 1), MJTile.make("条", 9)]
	wall.recycle(tiles, _rng(11))
	assert_eq(wall.live_left(), before + 2, "洗回后活墙＋2")
