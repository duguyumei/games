## 真气身上的一条战斗状态记录。
##
## 状态采用**只追加**的方式记录：施加就追加一条，减少也追加一条负数记录，
## 从不修改已有记录。读取时对同种记录求和得到当前总量。
##
## 例：毒 +1（功法A）、毒 +3（功法B）、毒 -5（毒发）→ 当前毒量 0
##
## 之所以不直接改数值，是为了保留每条记录的来源 —— 界面需要展示
## 「这张真气为什么气力是 -3」，也可能出现「清除敌方施加的毒」
## 这类按来源筛选的效果。
##
## 全部状态都写入存档。存档只发生在战斗之间的间隙，那时战斗内的临时状态
## （冻结、封脉）已被各自的处理器移除，因此本类不需要「存活范围」字段。
##
## 与持久重塑（QiReshape）的区别：重塑是局外改造，永久保留且不被净化清除；
## 状态是探索中产生的，净化会清除本场战斗产生的状态。
extends SerializableData
class_name QiStateEntry

## 状态种类。
enum KINDS {
	MOMENTUM,          ## 气力：影响提供的内力，可正可负
	POISON,            ## 毒量：非负，毒发时造成等量毒伤
	ELEMENT_OVERRIDE,  ## 属性覆盖：临时替换属性，战斗结束由处理器移除
	FROZEN,            ## 冻结：被功法读取时只提供 1 点内力
	RETAINED,          ## 保留：本应进散气时改为留在行气
	RETURNING,         ## 归根：本应进散气时改为洗回凝气
	CONSUMING,         ## 耗散：本应进散气时从牌库移除
	SEALED,            ## 封脉：不能运转，留到下个回合
}

## 状态种类对应的稳定 ID。
const KIND_IDS: Array[String] = [
	"momentum", "poison", "element_override", "frozen",
	"retained", "returning", "consuming", "sealed",
]

## 状态种类对应的显示名称。
const KIND_NAMES: Array[String] = [
	"气力", "毒量", "属性覆盖", "冻结",
	"保留", "归根", "耗散", "封脉",
]

## 战斗结束归档产生的历史记录，其来源标记为此值。
const SOURCE_HISTORY: String = "history"


## 本状态的种类。
@export var state_kind: int = KINDS.MOMENTUM

## 增减量。气力与毒量使用，可为负；标记类恒为 1。
@export var amount: int = 0

## 仅属性覆盖使用，取值见 QiEnums.ELEMENTS。
@export var element: int = -1

## 应用顺序。属性覆盖取该值最大的一条生效。
@export var applied_order: int = 0

## 来源实例 UID，必填。归档记录使用 SOURCE_HISTORY。
@export var source_uid: String = ""


## ============================================================
## 工厂方法
## ============================================================

## 创建一条气力记录；delta 可为负。
static func momentum(delta: int, source: String = "") -> QiStateEntry:
	return _create(KINDS.MOMENTUM, delta, source)

## 创建一条毒量记录；delta 可为负，毒发衰减即追加负数记录。
static func poison(delta: int, source: String = "") -> QiStateEntry:
	return _create(KINDS.POISON, delta, source)

## 创建一条属性覆盖记录。
static func element_override(target: int, source: String = "") -> QiStateEntry:
	var entry := _create(KINDS.ELEMENT_OVERRIDE, 1, source)
	entry.element = target
	return entry

## 创建一条标记类状态记录（冻结、保留、归根、耗散、封脉）；数值恒为 1。
static func flag(kind: int, source: String = "") -> QiStateEntry:
	return _create(kind, 1, source)

## 创建一条归档的历史记录。
static func history(kind: int, total: int) -> QiStateEntry:
	return _create(kind, total, SOURCE_HISTORY)


## 按种类与数值创建记录；内部使用。
static func _create(kind: int, value: int, source: String) -> QiStateEntry:
	var entry := QiStateEntry.new()
	entry.state_kind = kind
	entry.amount = value
	entry.source_uid = source
	return entry


## ============================================================
## 分类判断
## ============================================================

## 该种状态在战斗结束时是否需要归档为一条历史记录。
##
## 气力与毒量是持续累积的数值 —— 一场战斗可能产生十几条记录，
## 因此结束时压缩成一条，避免存档随战斗场数膨胀。
## 其余状态由各自的处理器在战斗结束时移除，不需要归档。
static func needs_archive(kind: int) -> bool:
	return kind == KINDS.MOMENTUM or kind == KINDS.POISON

## 是否为标记类状态。
##
## 标记类**不叠加** —— 同一张真气获得两次保留只生效一次，
## 因此重复施加会被忽略，移除时一次清除全部记录。
static func is_flag_kind(kind: int) -> bool:
	return kind == KINDS.FROZEN \
		or kind == KINDS.RETAINED \
		or kind == KINDS.RETURNING \
		or kind == KINDS.CONSUMING \
		or kind == KINDS.SEALED

## 是否为改变离场去向的状态；优先级见 QiData.resolve_discard_target()。
func is_discard_redirect() -> bool:
	return state_kind == KINDS.RETAINED \
		or state_kind == KINDS.CONSUMING \
		or state_kind == KINDS.RETURNING

## 是否为归档产生的历史记录。
func is_history() -> bool:
	return source_uid == SOURCE_HISTORY


## ============================================================
## 校验与展示
## ============================================================

## 返回状态种类对应的稳定 ID；越界时返回空字符串。
func get_kind_id() -> String:
	if state_kind < 0 or state_kind >= KIND_IDS.size():
		return ""
	return KIND_IDS[state_kind]

## 返回状态种类对应的显示名称；越界时返回空字符串。
func get_kind_name() -> String:
	if state_kind < 0 or state_kind >= KIND_NAMES.size():
		return ""
	return KIND_NAMES[state_kind]

## 校验本记录的字段是否与其种类匹配。
func is_valid() -> bool:
	match state_kind:
		KINDS.MOMENTUM, KINDS.POISON:
			return amount != 0
		KINDS.ELEMENT_OVERRIDE:
			return QiEnums.is_valid_element(element)
		KINDS.FROZEN, KINDS.RETAINED, KINDS.RETURNING, KINDS.CONSUMING, KINDS.SEALED:
			return amount > 0
	return false

## 返回界面展示用的一行描述，例如「气力 +2」。
func get_display_text() -> String:
	match state_kind:
		KINDS.MOMENTUM, KINDS.POISON:
			return "%s %+d" % [get_kind_name(), amount]
		KINDS.ELEMENT_OVERRIDE:
			return "属性覆盖 → " + QiEnums.get_element_name(element)
		_:
			return get_kind_name()
