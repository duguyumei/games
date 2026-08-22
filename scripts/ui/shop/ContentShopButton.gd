## 展示真气、功法、内功或补充包的通用商店按钮。
extends BaseShopButton

@onready var button: Button = $Button

## 点击时提交已经构造好的商店购买行为。
func _ready() -> void:
	button.button_up.connect(_on_button_up)

## 从购买行为的通用展示字段初始化名称、图片和禁用状态。
func init(_action_on_click: BaseAction) -> void:
	super(_action_on_click)
	button.text = str(_action_on_click.values.get("display_name", "未知商品"))
	var texture_path: String = _action_on_click.values.get("texture_path", "")
	if texture_path != "":
		button.icon = FileLoader.load_texture(texture_path)
	button.disabled = bool(_action_on_click.values.get("purchase_disabled", false))
