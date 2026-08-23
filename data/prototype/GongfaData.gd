## 一门可持久化的功法；固定定义和本局唯一实例共用此格式。
extends PrototypeData
class_name GongfaData

## 游戏支持的八种稳定牌型 ID。
const HAND_TYPE_IDS: Array[String] = [
	"high_card",
	"pair",
	"three_kind",
	"two_pair",
	"four_kind",
	"full_house",
	"straight",
	"five_kind",
]

## 功法类别的稳定 ID；类别会自动映射到允许配置的牌型。
const GONGFA_CATEGORIES: Array[String] = [
	"general",
	"high_card",
	"pair",
	"three_kind",
	"four_kind",
	"straight",
]

## 功法类别到精确牌型的固定映射。
const GONGFA_CATEGORY_HAND_TYPES: Dictionary = {
	"general": HAND_TYPE_IDS,
	"high_card": ["high_card"],
	"pair": ["pair", "two_pair", "full_house"],
	"three_kind": ["three_kind", "full_house"],
	"four_kind": ["four_kind", "five_kind"],
	"straight": ["straight"],
}

## 功法稀有度。
enum GONGFA_RARITIES {COMMON, UNCOMMON, RARE, LEGENDARY}

## 功法名称。
@export var gongfa_name: String = ""

## 功法说明。
@export_multiline var gongfa_description: String = ""

## 功法显示图片路径。
@export var gongfa_texture_path: String = ""

## 商店购入基础价格。
@export var gongfa_purchase_price: int = 0

## 遗忘或出售时的基础价格。
@export var gongfa_sell_price: int = 0

## 功法内容品类，用于内容池与界面筛选。
@export var gongfa_category: String = ""

## 功法稀有度。
@export var gongfa_rarity: int = GONGFA_RARITIES.COMMON

## 允许配置此功法的牌型 ID。
@export var gongfa_eligible_hand_ids: Array[String] = []

## 功法的有序原子；每个原子包含一个按配置顺序执行的 Action 数组。
@export var gongfa_atoms: Array[Dictionary] = []

## 功法作为被动来源参与统一数值查询的固定配置。
@export var qi_value_effects: Array[Dictionary] = []

## 功法监听战斗事件时使用的固定效果配置。
@export var qi_battle_event_effects: Array[Dictionary] = []

## 本局获得此功法的次数；首次获得为一。
@export var gongfa_owned_count: int = 1

## 判断此功法是否允许配置到指定牌型。
func supports_hand_type(hand_type_id: String) -> bool:
	return get_eligible_hand_type_ids().has(hand_type_id)

## 返回此功法按类别或旧牌型列表计算出的允许牌型。
func get_eligible_hand_type_ids() -> Array[String]:
	if gongfa_category != "" and GONGFA_CATEGORY_HAND_TYPES.has(gongfa_category):
		var category_hand_types: Array[String] = []
		category_hand_types.assign(GONGFA_CATEGORY_HAND_TYPES[gongfa_category])
		return category_hand_types
	var legacy_hand_types: Array[String] = []
	legacy_hand_types.assign(gongfa_eligible_hand_ids)
	return legacy_hand_types

## 增加本局获得次数，不创建第二个功法实例。
func increase_owned_count(amount: int = 1) -> bool:
	if amount <= 0:
		return false
	gongfa_owned_count += amount
	return true

## 减少本局获得次数；调用方负责在归零时移除实例。
func decrease_owned_count(amount: int = 1) -> bool:
	if amount <= 0 or amount > gongfa_owned_count:
		return false
	gongfa_owned_count -= amount
	return true

## 校验价格、牌型、次数、数值钩子和功法原子是否可持久化。
func is_valid_gongfa() -> bool:
	if gongfa_purchase_price < 0 or gongfa_sell_price < 0 or gongfa_owned_count < 1:
		return false
	if gongfa_category != "" and not GONGFA_CATEGORIES.has(gongfa_category):
		return false
	if gongfa_category == "":
		for hand_type_id: String in gongfa_eligible_hand_ids:
			if not HAND_TYPE_IDS.has(hand_type_id):
				return false
	return JsonStateValidator.is_json_compatible(gongfa_atoms) \
		and JsonStateValidator.is_json_compatible(qi_value_effects) \
		and JsonStateValidator.is_json_compatible(qi_battle_event_effects) \
		and QiValuePipeline.validate_value_effects(qi_value_effects) \
		and GongfaAtomScheduler.validate_atom_definitions(gongfa_atoms) \
		and QiActionResolver.validate_atom_formulas(gongfa_atoms)
