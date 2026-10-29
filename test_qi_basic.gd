extends Node
## 最简单的真气系统测试
## 在Godot编辑器中：场景 -> 新建场景 -> 其他节点 -> Node -> 附加此脚本 -> F6运行

func _ready():
	print("=== 真气系统基础测试 ===")

	# 测试1：创建一张真气
	test_create_qi()

	# 测试2：创建战斗状态
	test_battle_state()

	print("=== 测试完成 ===")


func test_create_qi():
	print("\n[测试1] 创建一张金7真气")

	var qi = QiData.new()
	qi.qi_name = "金 7"
	qi.qi_base_element = QiEnums.ELEMENTS.METAL
	qi.qi_base_value = 7
	qi.qi_side = QiEnums.SIDES.PLAYER

	print("  创建成功：%s" % qi.qi_name)
	print("  基础属性：%d (金)" % qi.qi_base_element)
	print("  基础内力：%d" % qi.qi_base_value)
	print("  所属：%s" % ("玩家" if qi.qi_side == QiEnums.SIDES.PLAYER else "敌方"))


func test_battle_state():
	print("\n[测试2] 创建战斗状态")

	# 创建空牌区（注意：用正确的枚举名 DRAW/HAND/PENDING/DISCARD）
	var player_zones = {
		QiEnums.ZONES.DRAW: [],     # 凝气（牌库）
		QiEnums.ZONES.HAND: [],     # 行气（手牌）
		QiEnums.ZONES.PENDING: [],  # 驭气
		QiEnums.ZONES.DISCARD: [],  # 散气（弃牌堆）
	}

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var battle_state = BattleQiState.create(player_zones, [], rng)

	print("  战斗状态创建成功")
	print("  玩家凝气数量：%d" % battle_state.find_qi(QiEnums.SIDES.PLAYER, QiEnums.ZONES.DRAW).size())
