## 购买商店准确槽位中的商品。
extends BaseAction

## 重新读取当前槽位并校验固定内容 ID，防止旧界面按钮购买刷新后的其他商品。
func perform_action() -> void:
	var shop_data: ShopData = Global.get_shop_data()
	if shop_data == null:
		return

	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var section: String = processor.get_shadowed_action_values(
			"offer_section", "")
		var slot_index: int = processor.get_shadowed_action_values(
			"offer_slot_index", -1)
		var expected_definition_id: String = processor.get_shadowed_action_values(
			"expected_definition_id", "")
		var expected_content_kind: int = processor.get_shadowed_action_values(
			"expected_content_kind", -1)
		var expected_price: int = processor.get_shadowed_action_values(
			"expected_price", -1)
		var offer: ShopOfferData = shop_data.get_offer(section, slot_index)
		if offer == null \
				or offer.definition_id != expected_definition_id \
				or offer.content_kind != expected_content_kind \
				or offer.price != expected_price:
			return

		var price: int = max(processor.get_shadowed_action_values(
			"money_amount", offer.price), 0)
		if Global.player_data.player_money < price:
			return

		match offer.content_kind:
			ShopOfferData.CONTENT_KINDS.CARD:
				_purchase_card(shop_data, section, slot_index, offer, price)
			ShopOfferData.CONTENT_KINDS.CONSUMABLE:
				_purchase_consumable(shop_data, section, slot_index, offer, price)
			ShopOfferData.CONTENT_KINDS.ARTIFACT:
				_purchase_artifact(shop_data, section, slot_index, offer, price)
			ShopOfferData.CONTENT_KINDS.QI:
				_purchase_qi(shop_data, section, slot_index, offer, price)
			ShopOfferData.CONTENT_KINDS.GONGFA:
				_purchase_gongfa(
					shop_data,
					section,
					slot_index,
					offer,
					price,
					processor.get_shadowed_action_values("allow_duplicate", false))
			ShopOfferData.CONTENT_KINDS.NEIGONG:
				_purchase_neigong(
					shop_data,
					section,
					slot_index,
					offer,
					price,
					processor.get_shadowed_action_values("allow_duplicate", false))
		return

## 购买普通卡牌商品并将独立实例加入本局牌组。
func _purchase_card(
		shop_data: ShopData,
		section: String,
		slot_index: int,
		offer: ShopOfferData,
		price: int) -> void:
	var card_data: CardData = Global.get_card_data_from_prototype(offer.definition_id)
	if card_data == null:
		return
	var actions: Array[BaseAction] = _create_payment_and_reward_actions(price, [{
		Scripts.ACTION_ADD_CARDS_TO_DECK: {"picked_cards": [card_data]}
	}])
	ActionHandler.add_actions(actions)
	shop_data.remove_offer(section, slot_index)
	Signals.card_purchased.emit(card_data)
	Signals.shop_transaction_committed.emit()

## 购买补充包栏中的临时消耗品；没有空余槽位时保持商品不变。
func _purchase_consumable(
		shop_data: ShopData,
		section: String,
		slot_index: int,
		offer: ShopOfferData,
		price: int) -> void:
	if Global.player_data.are_consumable_slots_full():
		return
	var actions: Array[BaseAction] = _create_payment_and_reward_actions(price, [{
		Scripts.ACTION_ADD_CONSUMABLE: {
			"consumable_object_id": offer.definition_id,
			"fill_all_slots": false,
			"random_consumable": false,
		}
	}])
	ActionHandler.add_actions(actions)
	shop_data.remove_offer(section, slot_index)
	Signals.consumable_purchased.emit(offer.definition_id)
	Signals.shop_transaction_committed.emit()

## 购买奇物并保持该槽为空，直到精英或 Boss 完成后刷新。
func _purchase_artifact(
		shop_data: ShopData,
		section: String,
		slot_index: int,
		offer: ShopOfferData,
		price: int) -> void:
	if not Global.player_data.get_player_artifacts_with_artifact_id(
			offer.definition_id).is_empty():
		return
	var artifact_data: ArtifactData = Global.get_artifact_data_from_prototype(
		offer.definition_id)
	if artifact_data == null:
		return
	var actions: Array[BaseAction] = _create_payment_and_reward_actions(price, [{
		Scripts.ACTION_ADD_ARTIFACT: {"artifact_id": offer.definition_id}
	}])
	ActionHandler.add_actions(actions)
	shop_data.remove_offer(section, slot_index)
	Signals.artifact_purchased.emit(artifact_data)
	Signals.shop_transaction_committed.emit()

## 购买真气并创建独立本局实例。
func _purchase_qi(
		shop_data: ShopData,
		section: String,
		slot_index: int,
		offer: ShopOfferData,
		price: int) -> void:
	var qi_definition: QiData = Global.get_qi_data(offer.definition_id)
	if qi_definition == null or not qi_definition.is_valid_qi():
		return
	var actions: Array[BaseAction] = _create_payment_and_reward_actions(price, [{
		Scripts.ACTION_ADD_QI: {"qi_object_id": offer.definition_id}
	}])
	ActionHandler.add_actions(actions)
	shop_data.remove_offer(section, slot_index)
	Signals.qi_purchased.emit(offer.definition_id)
	Signals.shop_transaction_committed.emit()

## 购买功法；预览与正式发放都会重新经过重复获得权限钩子。
func _purchase_gongfa(
		shop_data: ShopData,
		section: String,
		slot_index: int,
		offer: ShopOfferData,
		price: int,
		allow_duplicate: bool) -> void:
	var preview_action := ActionAddGongfa.new()
	preview_action.init(Global.get_player(), null, [], {
		"gongfa_object_id": offer.definition_id,
		"allow_duplicate": allow_duplicate,
	}, self)
	if not preview_action.can_add():
		return
	var actions: Array[BaseAction] = _create_payment_and_reward_actions(price, [{
		Scripts.ACTION_ADD_GONGFA: {
			"gongfa_object_id": offer.definition_id,
			"allow_duplicate": allow_duplicate,
		}
	}])
	ActionHandler.add_actions(actions)
	shop_data.remove_offer(section, slot_index)
	Signals.gongfa_purchased.emit(offer.definition_id)
	Signals.shop_transaction_committed.emit()

## 购买内功；预览与正式发放都会重新经过重复获得权限钩子。
func _purchase_neigong(
		shop_data: ShopData,
		section: String,
		slot_index: int,
		offer: ShopOfferData,
		price: int,
		allow_duplicate: bool) -> void:
	var preview_action := ActionAddNeigong.new()
	preview_action.init(Global.get_player(), null, [], {
		"neigong_object_id": offer.definition_id,
		"allow_duplicate": allow_duplicate,
	}, self)
	if not preview_action.can_add():
		return
	var actions: Array[BaseAction] = _create_payment_and_reward_actions(price, [{
		Scripts.ACTION_ADD_NEIGONG: {
			"neigong_object_id": offer.definition_id,
			"allow_duplicate": allow_duplicate,
		}
	}])
	ActionHandler.add_actions(actions)
	shop_data.remove_offer(section, slot_index)
	Signals.neigong_purchased.emit(offer.definition_id)
	Signals.shop_transaction_committed.emit()

## 创建经过现有金币与奖励行为管线的扣费和发放行为。
func _create_payment_and_reward_actions(
		price: int,
		reward_action_data: Array[Dictionary]) -> Array[BaseAction]:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_ADD_MONEY: {"money_amount": -price}
	}]
	action_data.append_array(reward_action_data)
	return ActionGenerator.create_actions(
		Global.get_player(), null, [], action_data, self)
