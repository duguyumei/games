## 开局菜单中的初始真气卡组选择按钮。
extends TextureButton
class_name StartingQiDeckSelectionButton

## 此按钮代表的初始真气卡组固定 ID。
var starting_qi_deck_object_id: String = ""

## 玩家选择卡组时发送其固定 ID。
signal starting_qi_deck_selected(starting_qi_deck_id: String)

func _ready() -> void:
	button_up.connect(_on_button_up)

## 使用固定卡组定义初始化按钮图片和选择值。
func init(deck_object_id: String) -> void:
	starting_qi_deck_object_id = deck_object_id
	var deck_data: StartingQiDeckData = Global.get_starting_qi_deck_data(deck_object_id)
	if deck_data != null and deck_data.deck_icon_texture_path != "":
		texture_normal = FileLoader.load_texture(deck_data.deck_icon_texture_path)

func _on_button_up() -> void:
	starting_qi_deck_selected.emit(starting_qi_deck_object_id)
