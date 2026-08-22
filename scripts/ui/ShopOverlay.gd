## 常驻修习商店界面；只展示 ShopData，不因打开或关闭生成新候选。
extends Control

@onready var normal_container: HBoxContainer = $NormalContainer
@onready var pack_container: HBoxContainer = $PackContainer
@onready var artifact_container: HBoxContainer = $ArtifactContainer
@onready var player_consumable_container: HBoxContainer = $PlayerConsumableContainer

@onready var money_label: Label = $MoneyLabel
@onready var meditation_button: Button = $MeditationButton
@onready var consumable_status_label: Label = $ConsumableStatusLabel
@onready var use_consumable_button: Button = $UseConsumableButton
@onready var discard_consumable_button: Button = $DiscardConsumableButton
@onready var continue_button: Button = $ContinueButton

@onready var map = $%Map
@onready var player_consumables = $%Consumables

## 当前在商店库存栏中选中的玩家消耗品槽位。
var selected_consumable_slot_index: int = -1

## 防止第一次补建商店时由 shop_inventory_changed 造成重入绘制。
var is_populating: bool = false

## 连接商店、购买和玩家消耗品变化事件。
func _ready() -> void:
	Signals.combat_started.connect(_on_combat_started)
	Signals.map_location_selected.connect(_on_map_location_selected)
	Signals.shop_opened.connect(_on_shop_opened)
	Signals.player_killed.connect(_on_player_killed)
	Signals.shop_inventory_changed.connect(_on_shop_inventory_changed)
	Signals.player_money_changed.connect(_on_player_money_changed)
	Signals.consumable_used.connect(_on_player_consumable_changed)
	Signals.consumable_added.connect(_on_player_consumable_changed)
	Signals.consumable_discarded.connect(_on_player_consumable_changed)

	meditation_button.button_up.connect(_on_meditation_button_up)
	use_consumable_button.button_up.connect(_on_use_consumable_button_up)
	discard_consumable_button.button_up.connect(_on_discard_consumable_button_up)
	continue_button.button_up.connect(_on_continue_button_up)

## 按固定 2/2/1 槽位重绘商店和当前玩家消耗品栏。
func populate_shop() -> void:
	if is_populating:
		return
	is_populating = true
	clear_shop()
	var shop_data: ShopData = Global.ensure_shop_initialized()
	if shop_data != null:
		_populate_offer_section(
			normal_container, ShopData.SECTION_NORMAL, ShopData.NORMAL_SLOT_COUNT)
		_populate_offer_section(
			pack_container, ShopData.SECTION_PACK, ShopData.PACK_SLOT_COUNT)
		_populate_offer_section(
			artifact_container, ShopData.SECTION_ARTIFACT, ShopData.ARTIFACT_SLOT_COUNT)
	populate_player_consumables()
	_update_money_and_meditation()
	is_populating = false

## 清除当前界面实例，不修改任何商店持久数据。
func clear_shop() -> void:
	for container: Control in [normal_container, pack_container, artifact_container]:
		for child: Node in container.get_children():
			child.queue_free()
	for child: Node in player_consumable_container.get_children():
		child.queue_free()

## 按稳定槽位顺序创建商品按钮或空槽占位。
func _populate_offer_section(
		container: Control,
		section: String,
		slot_count: int) -> void:
	var shop_data: ShopData = Global.get_shop_data()
	for slot_index: int in slot_count:
		var offer: ShopOfferData = shop_data.get_offer(section, slot_index)
		if offer == null:
			_add_empty_offer_slot(container, section)
			continue
		_add_offer_button(container, section, slot_index, offer)

## 根据商品类型复用框架已有的卡牌、消耗品和 Artifact 商店按钮。
func _add_offer_button(
		container: Control,
		section: String,
		slot_index: int,
		offer: ShopOfferData) -> void:
	var action_values: Dictionary[String, Variant] = {
		"offer_section": section,
		"offer_slot_index": slot_index,
		"expected_definition_id": offer.definition_id,
		"expected_content_kind": offer.content_kind,
		"expected_price": offer.price,
		"money_amount": offer.price,
	}
	var button: BaseShopButton = null
	match offer.content_kind:
		ShopOfferData.CONTENT_KINDS.CARD:
			var card_data: CardData = Global.get_card_data_from_prototype(
				offer.definition_id)
			if card_data != null:
				action_values["card_data"] = card_data
				button = Scenes.CARD_SHOP_BUTTON.instantiate()
		ShopOfferData.CONTENT_KINDS.CONSUMABLE:
			action_values["consumable_object_id"] = offer.definition_id
			button = Scenes.CONSUMABLE_SHOP_BUTTON.instantiate()
		ShopOfferData.CONTENT_KINDS.ARTIFACT:
			action_values["artifact_id"] = offer.definition_id
			button = Scenes.ARTIFACT_SHOP_BUTTON.instantiate()
		ShopOfferData.CONTENT_KINDS.QI:
			var qi_data: QiData = Global.get_qi_data(offer.definition_id)
			if qi_data != null:
				action_values["display_name"] = qi_data.qi_name
				action_values["texture_path"] = qi_data.qi_texture_path
				button = Scenes.CONTENT_SHOP_BUTTON.instantiate()
		ShopOfferData.CONTENT_KINDS.GONGFA:
			var gongfa_data: GongfaData = Global.get_gongfa_data(offer.definition_id)
			if gongfa_data != null:
				action_values["display_name"] = gongfa_data.gongfa_name
				action_values["texture_path"] = gongfa_data.gongfa_texture_path
				button = Scenes.CONTENT_SHOP_BUTTON.instantiate()
		ShopOfferData.CONTENT_KINDS.NEIGONG:
			var neigong_data: NeigongData = Global.get_neigong_data(offer.definition_id)
			if neigong_data != null:
				action_values["display_name"] = neigong_data.neigong_name
				action_values["texture_path"] = neigong_data.neigong_texture_path
				button = Scenes.CONTENT_SHOP_BUTTON.instantiate()
		ShopOfferData.CONTENT_KINDS.CONSUMABLE_BOOSTER:
			var booster_data: ConsumableBoosterData = Global.get_consumable_booster_data(
				offer.definition_id)
			if booster_data != null:
				action_values["display_name"] = booster_data.booster_name
				action_values["texture_path"] = booster_data.booster_texture_path
				# 补充包选择界面尚未实现，本阶段只允许展示和存档。
				action_values["purchase_disabled"] = true
				button = Scenes.CONTENT_SHOP_BUTTON.instantiate()

	if button == null:
		_add_empty_offer_slot(container, section)
		return
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_SHOP_PURCHASE_ITEMS: action_values
	}]
	var purchase_action: BaseAction = ActionGenerator.create_actions(
		null, null, [], action_data, null)[0]
	container.add_child(button)
	button.init(purchase_action)

## 创建不可点击的可见空槽，保证购买后其他商品不会移动位置。
func _add_empty_offer_slot(container: Control, section: String) -> void:
	var empty_slot := Button.new()
	empty_slot.disabled = true
	empty_slot.text = "空"
	empty_slot.custom_minimum_size = (
		Vector2(144, 208) if section == ShopData.SECTION_NORMAL else Vector2(256, 56))
	container.add_child(empty_slot)

## 展示玩家当前全部消耗品槽位，包括中间和末尾的空槽。
func populate_player_consumables() -> void:
	for child: Node in player_consumable_container.get_children():
		child.queue_free()
	for slot_index: int in Global.player_data.player_consumable_slot_count:
		var consumable_button: ConsumableButton = Scenes.CONSUMABLE_BUTTON.instantiate()
		player_consumable_container.add_child(consumable_button)
		consumable_button.init(slot_index)
		consumable_button.consumable_slot_button_up.connect(
			_on_player_consumable_slot_pressed)
	_update_consumable_actions()

## 选择玩家消耗品槽位，并显示可用的战斗外操作。
func _on_player_consumable_slot_pressed(slot_index: int) -> void:
	selected_consumable_slot_index = slot_index
	_update_consumable_actions()

## 根据目标需求、禁用状态和能量更新“使用/丢弃”按钮。
func _update_consumable_actions() -> void:
	var consumable_data: ConsumableData = Global.get_player_consumable_in_slot_index(
		selected_consumable_slot_index)
	if consumable_data == null:
		selected_consumable_slot_index = -1
		use_consumable_button.disabled = true
		discard_consumable_button.disabled = true
		consumable_status_label.text = "请选择一个已有消耗品"
		return

	var intercepted: Dictionary[String, Variant] = (
		consumable_data.get_consumable_intercepted_action_results())
	var use_disabled: bool = intercepted.get("consumable_use_disabled", false)
	var energy_cost: int = intercepted.get("consumable_energy_cost", 0)
	var requires_target: bool = consumable_data.consumable_requires_target
	use_consumable_button.disabled = use_disabled or requires_target \
		or Global.player_data.player_energy < energy_cost
	discard_consumable_button.disabled = false
	use_consumable_button.text = str(intercepted.get(
		"consumable_use_text", consumable_data.consumable_use_text))
	consumable_status_label.text = (
		"需要战斗目标，只能在战斗中使用" if requires_target
		else consumable_data.consumable_name)

## 使用无需战斗目标的当前消耗品。
func _on_use_consumable_button_up() -> void:
	if selected_consumable_slot_index < 0:
		return
	player_consumables.use_consumable_from_external_ui(
		selected_consumable_slot_index)

## 丢弃当前消耗品并保留原槽位为空。
func _on_discard_consumable_button_up() -> void:
	if selected_consumable_slot_index < 0:
		return
	player_consumables.discard_consumable(selected_consumable_slot_index)

## 发起冥想行为；实际扣费和刷新由 ActionShopMeditate 完成。
func _on_meditation_button_up() -> void:
	var shop_data: ShopData = Global.get_shop_data()
	if shop_data != null:
		shop_data.meditate()

## 打开只重绘已保存的商店，不生成新候选。
func _on_shop_opened() -> void:
	visible = true
	selected_consumable_slot_index = -1
	populate_shop()

## 商店状态变化后等待行为结束，再重绘并显示最终金币和库存。
func _on_shop_inventory_changed() -> void:
	if not visible:
		return
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	populate_shop()

## 玩家消耗品变化后更新商店内库存栏，并保存战斗外操作结果。
func _on_player_consumable_changed(
		_slot_index: int,
		_object_id: String) -> void:
	if not visible:
		return
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	selected_consumable_slot_index = -1
	populate_player_consumables()
	FileLoader.autosave()

## 金币变化时更新余额和冥想按钮状态。
func _on_player_money_changed(_delta: int = 0) -> void:
	if visible:
		_update_money_and_meditation()

## 同步金币文本、下一次冥想费用和可点击状态。
func _update_money_and_meditation() -> void:
	var shop_data: ShopData = Global.get_shop_data()
	money_label.text = "金币 %d" % Global.player_data.player_money
	if shop_data == null:
		meditation_button.disabled = true
		return
	meditation_button.text = "冥想刷新（%d 金币）" % shop_data.next_meditation_cost
	meditation_button.disabled = shop_data.get_refreshable_normal_slot_count() <= 0 \
		or Global.player_data.player_money < shop_data.next_meditation_cost

## 关闭商店后返回同一个地图待选状态，不刷新任何分栏。
func _on_continue_button_up() -> void:
	visible = false
	selected_consumable_slot_index = -1
	map.show_map()

## 进入任何节点后关闭商店。
func _on_map_location_selected(_location_data: LocationData) -> void:
	visible = false

## 战斗开始时确保商店不可见。
func _on_combat_started(_event_id: String) -> void:
	visible = false

## 战败时清理界面实例，但不触发任何商店刷新。
func _on_player_killed(_player: Player) -> void:
	clear_shop()
	visible = false
