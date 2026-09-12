extends GutTest

# ExpeditionSession 远征上下文：气血贯通与层间交接协议。
# 战报读完自动清空（消灭"幽灵战果"）；开战上下文读取不消费（战斗内重开仍可取）。

func _session() -> Node:
	var s: Node = preload("res://core/expedition/expedition_session.gd").new()
	add_child_autofree(s)
	return s

func test_player_hp_initialized_from_config() -> void:
	var s: Node = _session()
	s.start_run(1)
	assert_true(s.is_in_expedition())
	assert_eq(s.carried_max_hp(), 30, "上限来自玩家配置")
	assert_eq(s.carried_hp(), 30, "开局满血")
	s.report_battle_result("win", 17)  # 模拟战斗结束写回
	assert_eq(s.carried_hp(), 17, "写回保留，供下一场战斗读取")
	s.end_run()
	assert_eq(s.carried_hp(), 0, "远征结束清空")

func test_battle_result_consumed_once() -> void:
	var s: Node = _session()
	s.report_battle_result("win", 12)
	assert_eq(s.consume_battle_result(), "win", "第一次消费返回战报")
	assert_eq(s.consume_battle_result(), "", "读完自动清空——无幽灵战果")

func test_battle_context_readable_without_consume() -> void:
	var s: Node = _session()
	s.start_run(3)
	s.prepare_battle("山匪刀客")
	var ctx: Dictionary = s.take_battle_context()
	assert_eq(str(ctx["enemy_id"]), "山匪刀客", "开战上下文带敌人")
	assert_eq(int(ctx["player_hp"]), 30, "带携行气血")
	var ctx2: Dictionary = s.take_battle_context()
	assert_eq(str(ctx2["enemy_id"]), "山匪刀客", "读取不消费——战斗内重开一场仍可取")
