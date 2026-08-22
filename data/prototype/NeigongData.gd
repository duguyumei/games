## 一门可持久化的内功；固定定义和本局实例共用此格式。
extends PrototypeData
class_name NeigongData

## 内功稀有度。
enum NEIGONG_RARITIES {COMMON, UNCOMMON, RARE, LEGENDARY}

## 内功名称。
@export var neigong_name: String = ""

## 内功说明。
@export_multiline var neigong_description: String = ""

## 内功显示图片路径。
@export var neigong_texture_path: String = ""

## 商店购入基础价格。
@export var neigong_purchase_price: int = 0

## 遗忘或出售时的基础价格。
@export var neigong_sell_price: int = 0

## 内功内容品类，用于内容池与界面筛选。
@export var neigong_category: String = ""

## 内功稀有度。
@export var neigong_rarity: int = NEIGONG_RARITIES.COMMON

## 装备后注册到行为管线的拦截器固定 ID。
@export var neigong_interceptor_ids: Array[String] = []

## 本局实例的通用计数。
@export var neigong_counter: int = 0

## 本局实例是否已经消耗其一次性效果。
@export var neigong_used: bool = false

## 本局实例扩展状态；只允许保存 JSON 兼容值。
@export var neigong_runtime_state: Dictionary[String, Variant] = {}

## 安全设置本局实例计数。
func set_counter(value: int) -> void:
	neigong_counter = max(value, 0)

## 安全替换本局扩展状态，非法值不会写入实例。
func set_runtime_state(value: Dictionary[String, Variant]) -> bool:
	if not JsonStateValidator.is_json_compatible(value):
		return false
	neigong_runtime_state = value.duplicate(true)
	return true

## 校验价格、计数和扩展状态是否可持久化。
func is_valid_neigong() -> bool:
	return neigong_purchase_price >= 0 \
		and neigong_sell_price >= 0 \
		and neigong_counter >= 0 \
		and JsonStateValidator.is_json_compatible(neigong_runtime_state)
