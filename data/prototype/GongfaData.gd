## 一门可持久化的功法；固定定义和本局唯一实例共用此格式。
extends PrototypeData
class_name GongfaData

## 游戏支持的八种稳定牌型 ID。
const HAND_TYPE_IDS: Array[String] = [
	"high_card",
	"pair",
	"two_pair",
	"three_kind",
	"straight",
	"full_house",
	"four_kind",
	"five_kind",
]

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

## 功法效果配置；本阶段只保存配置，不接入完整牌型战斗。
@export var gongfa_effects: Array[Dictionary] = []

## 本局获得此功法的次数；首次获得为一。
@export var gongfa_owned_count: int = 1

## 判断此功法是否允许配置到指定牌型。
func supports_hand_type(hand_type_id: String) -> bool:
	return HAND_TYPE_IDS.has(hand_type_id) \
		and gongfa_eligible_hand_ids.has(hand_type_id)

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

## 校验价格、牌型、次数和效果配置是否可持久化。
func is_valid_gongfa() -> bool:
	if gongfa_purchase_price < 0 or gongfa_sell_price < 0 or gongfa_owned_count < 1:
		return false
	for hand_type_id: String in gongfa_eligible_hand_ids:
		if not HAND_TYPE_IDS.has(hand_type_id):
			return false
	return JsonStateValidator.is_json_compatible(gongfa_effects)
