## 商店中的单个可购买项。
##
## 商店槽位只保存固定内容 ID 和价格，不直接保存固定内容资源引用。
extends SerializableData
class_name ShopOfferData

## 商品类型；前三项顺序固定以兼容旧存档，新增类型只能继续追加。
enum CONTENT_KINDS {
	CARD,
	CONSUMABLE,
	ARTIFACT,
	QI,
	GONGFA,
	NEIGONG,
	CONSUMABLE_BOOSTER,
}

## 固定内容所属类型，用于选择展示组件和购买行为。
@export var content_kind: int = CONTENT_KINDS.CARD

## 固定内容 ID；读取时通过 Global 查找对应定义。
@export var definition_id: String = ""

## 生成本次商店时冻结的商品价格。
@export var price: int = 0

## 创建一个商店商品快照。
func _init(
		_content_kind: int = CONTENT_KINDS.CARD,
		_definition_id: String = "",
		_price: int = 0) -> void:
	content_kind = _content_kind
	definition_id = _definition_id
	price = max(_price, 0)
