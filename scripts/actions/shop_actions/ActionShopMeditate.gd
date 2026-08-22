## 扣除金币并只替换仍被占用的普通商品槽位。
extends BaseAction

## 冥想费用和结果均经过行为拦截器，失败时不推进随机流和冥想次数。
func perform_action() -> void:
	var shop_data: ShopData = Global.get_shop_data()
	if shop_data == null or shop_data.get_refreshable_normal_slot_count() <= 0:
		return

	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var meditation_cost: int = max(processor.get_shadowed_action_values(
			"money_amount", shop_data.next_meditation_cost), 0)
		if Global.player_data.player_money < meditation_cost:
			return

		# 金币校验通过后才生成候选，避免失败操作推进冥想随机流。
		var replacements: Dictionary[String, ShopOfferData] = (
			shop_data.generate_meditation_offers())
		if replacements.is_empty():
			return

		var money_action_data: Array[Dictionary] = [{
			Scripts.ACTION_ADD_MONEY: {"money_amount": -meditation_cost}
		}]
		var money_action: BaseAction = ActionGenerator.create_actions(
			Global.get_player(), null, [], money_action_data, self)[0]
		money_action.perform_action()
		if shop_data.apply_meditation_offers(replacements):
			Signals.shop_transaction_committed.emit()
		return

## 冥想提交本身不需要等待界面动画。
func is_instant_action() -> bool:
	return true
