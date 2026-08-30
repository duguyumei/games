## 一次动作的来源。
##
## 所有动作都必须携带来源，用于三件事：
##   伤害归因 —— 反震要知道伤害来自谁才能打回去；
##   拦截判定 —— 拦截器按来源类型区分（例如只拦功法造成的伤害）；
##   条件读取 —— 内功的条件常依赖来源类型（例如「每发动 3 门功法」不含内功触发的）。
##
## 来源在动作链中**继承传递**：由 A 动作派生的 B 动作沿用 A 的来源。
## 因此「敌方功法运转我方真气导致毒发」这条链上，毒伤的来源始终是敌方那门功法，
## 而不是被毒的那张真气 —— 否则反震会打错目标。
extends RefCounted
class_name ActionSource

## 来源类型。
enum TYPES {
	GONGFA,   ## 功法
	NEIGONG,  ## 内功
	ITEM,     ## 道具
	SYSTEM,   ## 流程驱动：抽取、回合结束收尾、凝气不足洗回
}

## 来源类型对应的稳定 ID。
const TYPE_IDS: Array[String] = ["gongfa", "neigong", "item", "system"]

## 本次动作的来源类型。
var type: int = TYPES.SYSTEM

## 来源实例的 UID；流程驱动时为空字符串。
var uid: String = ""

## 来源阵营，取值见 QiEnums.SIDES；流程驱动时为 -1。
var side: int = -1

## 来源对象引用，按 type 解释；流程驱动时为 null。
##
## 动作不写入存档，因此持有对象引用不会带来序列化问题。
## 直接持有引用而非只存 UID，是为了让条件判断不必反查注册表。
var instance: Variant = null


## ============================================================
## 构造
## ============================================================

## 创建一个功法来源。
static func of_gongfa(gongfa: Variant, from_side: int) -> ActionSource:
	return _create(TYPES.GONGFA, gongfa, from_side)

## 创建一个内功来源。
static func of_neigong(neigong: Variant, from_side: int) -> ActionSource:
	return _create(TYPES.NEIGONG, neigong, from_side)

## 创建一个道具来源。
static func of_item(item: Variant, from_side: int) -> ActionSource:
	return _create(TYPES.ITEM, item, from_side)

## 创建一个流程驱动来源。
##
## 抽取、回合结束收尾、凝气不足洗回都属于流程驱动，没有来源实例与阵营。
## 部分内容只统计由内容驱动的运转，因此这个类型必须能被区分出来。
static func system() -> ActionSource:
	var source := ActionSource.new()
	source.type = TYPES.SYSTEM
	return source


## 按类型创建来源；内部使用。
static func _create(source_type: int, source_instance: Variant, from_side: int) -> ActionSource:
	var source := ActionSource.new()
	source.type = source_type
	source.instance = source_instance
	source.side = from_side
	if source_instance != null and source_instance.get("object_uid") != null:
		source.uid = source_instance.object_uid
	return source


## ============================================================
## 查询
## ============================================================

## 是否由内容驱动而非流程。
##
## 取代了早期设计中的 is_auto 布尔标志 —— 「主动运转」的实质就是
## 「有内容驱动它」，因此不需要额外字段。
func is_driven() -> bool:
	return type != TYPES.SYSTEM

## 是否来自指定阵营。
func is_from(target_side: int) -> bool:
	return side == target_side

## 返回来源类型对应的稳定 ID；越界时返回空字符串。
func get_type_id() -> String:
	if type < 0 or type >= TYPE_IDS.size():
		return ""
	return TYPE_IDS[type]

## 来源是否为功法。
func is_gongfa() -> bool:
	return type == TYPES.GONGFA

## 来源是否为内功。
func is_neigong() -> bool:
	return type == TYPES.NEIGONG

## 来源是否为道具。
func is_item() -> bool:
	return type == TYPES.ITEM

## 返回用于日志与调试的一行描述。
func get_debug_text() -> String:
	if type == TYPES.SYSTEM:
		return "[流程]"
	var side_text := "我方" if side == QiEnums.SIDES.PLAYER else "敌方"
	return "[%s %s %s]" % [side_text, get_type_id(), uid]
