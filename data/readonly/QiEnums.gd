## 真气系统的公共枚举与常量。
##
## 五行属性、牌区、阵营三个枚举在真气、功法、内功之间共用，
## 因此集中定义在此，避免各处重复声明导致取值不一致。
class_name QiEnums

## ============================================================
## 五行属性
## ============================================================

## 五行属性；顺序为金、木、水、火、土，不可调整。
## 属性线牌型（同属性的对子、三连、四连）依据此枚举判定。
enum ELEMENTS {METAL, WOOD, WATER, FIRE, EARTH}

## 属性枚举对应的稳定内容 ID；存档与配置使用字符串而非整数，避免枚举顺序变动导致存档失效。
const ELEMENT_IDS: Array[String] = ["metal", "wood", "water", "fire", "earth"]

## 属性枚举对应的显示名称。
const ELEMENT_NAMES: Array[String] = ["金", "木", "水", "火", "土"]

## 五行属性的总数。
const ELEMENT_COUNT: int = 5


## ============================================================
## 牌区
## ============================================================

## 真气所处的四个牌区。
## 被消耗的真气直接从牌库移除，不占用独立牌区，由战斗容器单独记录。
enum ZONES {
	DRAW,     ## 凝气：牌库
	HAND,     ## 行气：本回合可调度
	PENDING,  ## 驭气：已分配给某功法，等待读取
	DISCARD,  ## 散气：弃牌堆
}

## 牌区枚举对应的稳定 ID。
const ZONE_IDS: Array[String] = ["draw", "hand", "pending", "discard"]

## 牌区枚举对应的显示名称。
const ZONE_NAMES: Array[String] = ["凝气", "行气", "驭气", "散气"]

## 行气上限；抽取只取 5 张，但保留、封脉与运转效果会让行气累积。
const HAND_LIMIT: int = 8

## 每回合的基础抽取数量。
const DRAW_PER_ROUND: int = 5


## ============================================================
## 阵营
## ============================================================

## 战斗中的两个阵营。
enum SIDES {PLAYER, ENEMY}

## 阵营枚举对应的稳定 ID。
const SIDE_IDS: Array[String] = ["player", "enemy"]


## ============================================================
## 内力
## ============================================================

## 基础内力的合法范围；起始牌库为五行 × 内力 5～9 各一张，共 25 张。
const BASE_VALUE_MIN: int = 5
const BASE_VALUE_MAX: int = 9

## 重塑槽位的硬上限；单张真气的实际容量由自身的重塑槽数量决定，起始为 1。
const RESHAPE_SLOT_MAX: int = 9


## ============================================================
## 工具方法
## ============================================================

## 返回属性枚举对应的稳定 ID；越界时返回空字符串。
static func get_element_id(element: int) -> String:
	if element < 0 or element >= ELEMENT_IDS.size():
		return ""
	return ELEMENT_IDS[element]

## 返回稳定 ID 对应的属性枚举；无法识别时返回 -1。
static func get_element_from_id(element_id: String) -> int:
	return ELEMENT_IDS.find(element_id)

## 返回属性枚举对应的显示名称；越界时返回空字符串。
static func get_element_name(element: int) -> String:
	if element < 0 or element >= ELEMENT_NAMES.size():
		return ""
	return ELEMENT_NAMES[element]

## 返回牌区枚举对应的稳定 ID；越界时返回空字符串。
static func get_zone_id(zone: int) -> String:
	if zone < 0 or zone >= ZONE_IDS.size():
		return ""
	return ZONE_IDS[zone]

## 返回稳定 ID 对应的牌区枚举；无法识别时返回 -1。
static func get_zone_from_id(zone_id: String) -> int:
	return ZONE_IDS.find(zone_id)

## 判断属性枚举是否合法。
static func is_valid_element(element: int) -> bool:
	return element >= 0 and element < ELEMENT_COUNT

## 判断基础内力是否在合法范围内。
static func is_valid_base_value(value: int) -> bool:
	return value >= BASE_VALUE_MIN and value <= BASE_VALUE_MAX
