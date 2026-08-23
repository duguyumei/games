## 一套只读的初始真气卡组定义；开局选择只引用此固定内容，不在运行时生成牌面清单。
extends SerializableData
class_name StartingQiDeckData

## 卡组在开局选择界面显示的名称。
@export var deck_name: String = ""

## 卡组在开局选择界面显示的说明。
@export_multiline var deck_description: String = ""

## 卡组选择按钮使用的图片路径；为空时使用默认图标。
@export var deck_icon_texture_path: String = ""

## 作为本局底层玩家原型来源的角色固定 ID；角色不再作为玩家可见的开局选择项。
@export var deck_character_object_id: String = ""

## 开局加入本局牌组的真气固定 ID；数组顺序属于固定卡组内容的一部分。
@export var deck_qi_object_ids: Array[String] = []

## 校验卡组是否具有可用于开局的底层角色和真气清单。
func is_valid_starting_deck() -> bool:
	if deck_name == "" or deck_character_object_id == "" or deck_qi_object_ids.is_empty():
		return false
	for qi_object_id: String in deck_qi_object_ids:
		if qi_object_id == "":
			return false
	return true
