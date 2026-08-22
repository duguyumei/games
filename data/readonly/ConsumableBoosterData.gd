## 商店补充包的只读固定定义；补充包本身不是消耗品。
extends SerializableData
class_name ConsumableBoosterData

## 补充包名称。
@export var booster_name: String = ""

## 补充包说明。
@export_multiline var booster_description: String = ""

## 补充包显示图片路径。
@export var booster_texture_path: String = ""

## 商店购入基础价格。
@export var booster_purchase_price: int = 0

## 引用的 ConsumablePackData 固定内容 ID。
@export var booster_consumable_pack_id: String = ""

## 打开补充包时展示的候选数量。
@export var booster_display_count: int = 3

## 玩家可以从候选中选择的数量。
@export var booster_choice_count: int = 1

## 校验补充包数量与价格是否合法。
func is_valid_booster() -> bool:
	return booster_purchase_price >= 0 \
		and booster_display_count > 0 \
		and booster_choice_count > 0 \
		and booster_choice_count <= booster_display_count \
		and booster_consumable_pack_id != ""
