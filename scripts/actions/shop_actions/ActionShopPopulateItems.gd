## 通过行为拦截器提交一次分栏商店刷新。
extends BaseAction

## 读取拦截后的候选和刷新边界，并一次性写入 ShopData。
func perform_action() -> void:
	var shop_data: ShopData = Global.get_shop_data()
	if shop_data == null:
		return

	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var normal_offers: Dictionary = processor.get_shadowed_action_values(
			"normal_offers", {})
		var pack_offers: Dictionary = processor.get_shadowed_action_values(
			"pack_offers", {})
		var artifact_offers: Dictionary = processor.get_shadowed_action_values(
			"artifact_offers", {})
		var replace_normal: bool = processor.get_shadowed_action_values(
			"replace_normal", false)
		var replace_pack: bool = processor.get_shadowed_action_values(
			"replace_pack", false)
		var replace_artifact: bool = processor.get_shadowed_action_values(
			"replace_artifact", false)
		var refresh_token: String = processor.get_shadowed_action_values(
			"refresh_token", "")

		if refresh_token == "" or shop_data.has_processed_refresh_token(refresh_token):
			return
		shop_data.replace_sections(
			normal_offers,
			pack_offers,
			artifact_offers,
			replace_normal,
			replace_pack,
			replace_artifact,
			refresh_token)

## 商店刷新不需要等待动画或行为延迟。
func is_instant_action() -> bool:
	return true
