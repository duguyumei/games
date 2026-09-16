extends GutTest

# 图鉴·发现制收藏（代码设计 v1.4 §4.9）：发现去重/持久化跨"重启"/坏档容错/完成度计数。
# CodexState 重定向到临时路径。


func before_each() -> void:
	CodexState.reset_for_tests()


func after_each() -> void:
	CodexState.reset_for_tests("user://test_mj_meta.json")
	if FileAccess.file_exists("user://test_mj_meta.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_mj_meta.json"))


func test_discover_idempotent_and_counts() -> void:
	assert_true(CodexState.discover("dian_xue"))
	assert_false(CodexState.discover("dian_xue"), "重复发现不算")
	assert_true(CodexState.discover("ling_gang"))
	assert_eq(CodexState.discovered_count(), 2)
	assert_true(CodexState.is_discovered("dian_xue"))
	assert_false(CodexState.is_discovered("grp1_boss"))


func test_persistence_across_reload() -> void:
	CodexState.discover("tie_bu_shan")
	CodexState.discover("grp1_ronin")
	CodexState.reset_for_tests()  # 模拟重启：清内存、重读同一档
	assert_true(CodexState.is_discovered("tie_bu_shan"), "收藏跨局存活")
	assert_true(CodexState.is_discovered("grp1_ronin"))
	assert_eq(CodexState.discovered_count(), 2)


func test_bad_file_tolerated() -> void:
	var path := "user://test_mj_meta.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("不是 JSON")
	file.close()
	CodexState.reset_for_tests()  # 重读→坏档
	assert_false(CodexState.is_discovered("dian_xue"), "坏档按无档开局")
	assert_true(CodexState.discover("dian_xue"), "坏档后仍可正常新档")


func test_ratio_and_all_ids_cover_universe() -> void:
	var ids := CodexState.all_ids()
	assert_true(ids.size() >= 12, "武学 3 基础＋5 新＋牌灵 4＋对手 3")
	assert_true(ids.has("dian_xue"))
	assert_true(ids.has("lianhuan_zhang"), "货架池武学入全集")
	assert_true(ids.has("ling_jia"))
	assert_true(ids.has("grp1_boss"))
	assert_eq(CodexState.discovered_ratio(), 0.0)
	for id_str in ids:
		CodexState.discover(id_str)
	assert_eq(CodexState.discovered_count(), ids.size())
	assert_almost_eq(CodexState.discovered_ratio(), 1.0, 0.0001)
