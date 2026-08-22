## 保存本局常驻商店的候选、空槽和刷新进度。
##
## 空槽不会保存 null 对象，而是从对应槽位字典中移除键；get_offer() 对外返回 null。
extends SerializableData
class_name ShopData

## 自动刷新原因决定本次可以替换哪些商店区域。
enum REFRESH_REASONS {RUN_START, NORMAL_NODE, ELITE_NODE, BOSS_TRANSITION}

## 商店区域名称同时作为购买行为的稳定参数。
const SECTION_NORMAL: String = "normal"
const SECTION_PACK: String = "pack"
const SECTION_ARTIFACT: String = "artifact"

## 商店三个区域各自固定拥有的槽位数。
const NORMAL_SLOT_COUNT: int = 2
const PACK_SLOT_COUNT: int = 2
const ARTIFACT_SLOT_COUNT: int = 1

## 每间新商店第一次冥想的基础费用。
const INITIAL_MEDITATION_COST: int = 5

## 当前商店是否已经完成第一次全栏生成。
@export var shop_initialized: bool = false

## 普通商品槽位；缺少某个字符串槽位键表示该槽为空。
@export var normal_offers: Dictionary[String, ShopOfferData] = {}

## 补充包槽位；本阶段的值为直接购买的 ConsumableData。
@export var pack_offers: Dictionary[String, ShopOfferData] = {}

## 奇物槽位；当前框架使用 ArtifactData 作为奇物。
@export var artifact_offers: Dictionary[String, ShopOfferData] = {}

## 当前商店已经成功冥想的次数。
@export var meditation_count: int = 0

## 下一次冥想显示和结算使用的基础费用。
@export var next_meditation_cost: int = INITIAL_MEDITATION_COST

## 自动生成过的新商店批次数，用于存档检查和后续确定性扩展。
@export var refresh_sequence: int = 0

## 最近一次完成的节点刷新令牌，用于阻止重复结算。
@export var last_refresh_token: String = ""

## 旧版字段仅用于无崩溃读取旧存档；加载后会由 normalize_after_load() 清空。
@export var shop_is_visited: bool = false
@export var shop_location_id: String = ""
@export var shop_cards: Array[CardData] = []
@export var shop_artifact_ids: Array[String] = []
@export var shop_consumable_slot_to_consumable_object_id: Dictionary = {}
@export var shop_card_prices: Array[int] = []
@export var shop_artifact_prices: Array[int] = []
@export var shop_consumable_slot_to_consumable_price: Dictionary = {}

## 商品价格区间继续复用框架已有的内容稀有度。
const CARD_RARITY_TO_PRICE_RANGE: Dictionary = {
	CardData.CARD_RARITIES.COMMON: [50, 80],
	CardData.CARD_RARITIES.UNCOMMON: [85, 115],
	CardData.CARD_RARITIES.RARE: [120, 140],
}

## 奇物价格区间继续复用框架已有的 Artifact 稀有度。
const ARTIFACT_RARITY_TO_PRICE_RANGE: Dictionary = {
	ArtifactData.ARTIFACT_RARITIES.COMMON: [50, 80],
	ArtifactData.ARTIFACT_RARITIES.UNCOMMON: [85, 115],
	ArtifactData.ARTIFACT_RARITIES.RARE: [120, 140],
	ArtifactData.ARTIFACT_RARITIES.BOSS: [130, 150],
	ArtifactData.ARTIFACT_RARITIES.SHOP: [150, 200],
	ArtifactData.ARTIFACT_RARITIES.EVENT: [0, 1],
}

## 补充包栏临时使用的消耗品价格区间。
const CONSUMABLE_RARITY_TO_PRICE_RANGE: Dictionary = {
	ConsumableData.CONSUMABLE_RARITIES.COMMON: [50, 80],
	ConsumableData.CONSUMABLE_RARITIES.UNCOMMON: [85, 115],
	ConsumableData.CONSUMABLE_RARITIES.RARE: [120, 140],
	ConsumableData.CONSUMABLE_RARITIES.LEGENDARY: [130, 150],
}

## 清理旧版位置商店数据；旧候选无法无损映射到新的 2/2/1 槽位，因此重新生成。
func normalize_after_load() -> void:
	var has_new_offers: bool = not normal_offers.is_empty() \
		or not pack_offers.is_empty() or not artifact_offers.is_empty()
	if has_new_offers:
		shop_initialized = true

	shop_is_visited = false
	shop_location_id = ""
	shop_cards.clear()
	shop_artifact_ids.clear()
	shop_consumable_slot_to_consumable_object_id.clear()
	shop_card_prices.clear()
	shop_artifact_prices.clear()
	shop_consumable_slot_to_consumable_price.clear()
	next_meditation_cost = max(next_meditation_cost, INITIAL_MEDITATION_COST)

## 返回指定区域和槽位中的商品；空槽或非法区域返回 null。
func get_offer(section: String, slot_index: int) -> ShopOfferData:
	var offers: Dictionary = _get_section_offers(section)
	return offers.get(str(slot_index), null)

## 返回指定区域固定拥有的槽位数量。
func get_section_slot_count(section: String) -> int:
	match section:
		SECTION_NORMAL:
			return NORMAL_SLOT_COUNT
		SECTION_PACK:
			return PACK_SLOT_COUNT
		SECTION_ARTIFACT:
			return ARTIFACT_SLOT_COUNT
	return 0

## 判断本次自动刷新是否已经由相同节点令牌成功执行过。
func has_processed_refresh_token(refresh_token: String) -> bool:
	return refresh_token != "" and last_refresh_token == refresh_token

## 按刷新原因生成候选，并通过可拦截的商店填充行为正式替换分栏。
func refresh_for(refresh_reason: int, refresh_token: String) -> bool:
	if refresh_token == "" or has_processed_refresh_token(refresh_token):
		return false

	var replace_normal: bool = true
	var replace_pack: bool = true
	var replace_artifact: bool = refresh_reason in [
		REFRESH_REASONS.RUN_START,
		REFRESH_REASONS.ELITE_NODE,
		REFRESH_REASONS.BOSS_TRANSITION,
	]

	var generated_normal_offers: Dictionary[String, ShopOfferData] = {}
	var generated_pack_offers: Dictionary[String, ShopOfferData] = {}
	var generated_artifact_offers: Dictionary[String, ShopOfferData] = {}
	if replace_normal:
		generated_normal_offers.assign(_generate_normal_offers(
			Global.player_data.get_player_rng("rng_shop_normal")))
	if replace_pack:
		generated_pack_offers.assign(_generate_pack_offers(
			Global.player_data.get_player_rng("rng_shop_packs")))
	if replace_artifact:
		generated_artifact_offers.assign(_generate_artifact_offers(
			Global.player_data.get_player_rng("rng_shop_artifact")))

	ActionGenerator.generate_populate_shop_items(
		generated_normal_offers,
		generated_pack_offers,
		generated_artifact_offers,
		replace_normal,
		replace_pack,
		replace_artifact,
		refresh_token)
	return last_refresh_token == refresh_token

## 从界面发起一次可拦截的冥想行为；本方法自身不直接修改金币或候选。
func meditate() -> void:
	if shop_initialized and get_refreshable_normal_slot_count() > 0:
		ActionGenerator.generate_shop_meditation()

## 返回当前仍有商品、可以被冥想替换的普通槽位数量。
func get_refreshable_normal_slot_count() -> int:
	return normal_offers.size()

## 为冥想生成普通商品替换表；已经购买形成的空槽不会出现在结果中。
func generate_meditation_offers() -> Dictionary[String, ShopOfferData]:
	var replacements: Dictionary[String, ShopOfferData] = {}
	var rng: RandomNumberGenerator = Global.player_data.get_player_rng("rng_shop_meditation")
	var excluded_ids: Array[String] = []
	for offer: ShopOfferData in normal_offers.values():
		if offer != null and offer.definition_id != "":
			excluded_ids.append(offer.definition_id)

	for slot_index: int in NORMAL_SLOT_COUNT:
		var slot_key: String = str(slot_index)
		if not normal_offers.has(slot_key):
			continue
		var candidate: ShopOfferData = _generate_meditation_offer(rng, excluded_ids)
		if candidate != null:
			replacements[slot_key] = candidate
			excluded_ids.append(candidate.definition_id)
	return replacements

## 由冥想行为提交普通商品替换，并推进下一次费用。
func apply_meditation_offers(replacements: Dictionary) -> bool:
	if replacements.is_empty():
		return false
	for slot_key: String in replacements:
		if normal_offers.has(slot_key):
			normal_offers[slot_key] = replacements[slot_key]
	meditation_count += 1
	next_meditation_cost = INITIAL_MEDITATION_COST + meditation_count
	Signals.shop_inventory_changed.emit()
	return true

## 由商店填充行为一次性替换被允许刷新的区域。
func replace_sections(
		new_normal_offers: Dictionary,
		new_pack_offers: Dictionary,
		new_artifact_offers: Dictionary,
		replace_normal: bool,
		replace_pack: bool,
		replace_artifact: bool,
		refresh_token: String) -> void:
	if replace_normal:
		normal_offers.clear()
		normal_offers.assign(new_normal_offers)
	if replace_pack:
		pack_offers.clear()
		pack_offers.assign(new_pack_offers)
	if replace_artifact:
		artifact_offers.clear()
		artifact_offers.assign(new_artifact_offers)
		# 只有刷新行为正式提交后，才从本局奖池预留实际进入商店的奇物。
		for offer: ShopOfferData in artifact_offers.values():
			if offer != null \
					and offer.content_kind == ShopOfferData.CONTENT_KINDS.ARTIFACT:
				Global.player_data.remove_artifact_from_pool(offer.definition_id)

	shop_initialized = true
	meditation_count = 0
	next_meditation_cost = INITIAL_MEDITATION_COST
	refresh_sequence += 1
	last_refresh_token = refresh_token
	Signals.shop_inventory_changed.emit()

## 购买成功后清空准确槽位，不移动同区域中的其他商品。
func remove_offer(section: String, slot_index: int) -> void:
	var offers: Dictionary = _get_section_offers(section)
	offers.erase(str(slot_index))
	Signals.shop_inventory_changed.emit()

## 返回区域对应的可变槽位字典；非法区域返回独立空字典。
func _get_section_offers(section: String) -> Dictionary:
	match section:
		SECTION_NORMAL:
			return normal_offers
		SECTION_PACK:
			return pack_offers
		SECTION_ARTIFACT:
			return artifact_offers
	return {}

## 生成两个普通卡牌商品。
func _generate_normal_offers(rng: RandomNumberGenerator) -> Dictionary[String, ShopOfferData]:
	var result: Dictionary[String, ShopOfferData] = {}
	var cards: Array[CardData] = Random.generate_rarity_weighted_card_draft(
		rng, NORMAL_SLOT_COUNT, Random.CARD_DRAFT_TABLE_TYPES.SHOP, false)
	var prices: Array[int] = Random.get_shop_card_prices(cards, rng)
	for index: int in min(cards.size(), prices.size(), NORMAL_SLOT_COUNT):
		result[str(index)] = ShopOfferData.new(
			ShopOfferData.CONTENT_KINDS.CARD, cards[index].object_id, prices[index])
	return result

## 生成两个临时消耗品商品，作为本阶段补充包栏的数据适配。
func _generate_pack_offers(rng: RandomNumberGenerator) -> Dictionary[String, ShopOfferData]:
	var result: Dictionary[String, ShopOfferData] = {}
	var selected_ids: Array[String] = []
	for slot_index: int in PACK_SLOT_COUNT:
		var consumable_id: String = Random.get_random_consumable_object_id(
			rng, [], selected_ids)
		if consumable_id == "":
			continue
		selected_ids.append(consumable_id)
		var prices: Array[int] = Random.get_shop_consumable_prices([consumable_id], rng)
		if not prices.is_empty():
			result[str(slot_index)] = ShopOfferData.new(
				ShopOfferData.CONTENT_KINDS.CONSUMABLE, consumable_id, prices[0])
	return result

## 使用独立随机流从仍可获得的奇物池中生成一个奇物。
func _generate_artifact_offers(rng: RandomNumberGenerator) -> Dictionary[String, ShopOfferData]:
	var result: Dictionary[String, ShopOfferData] = {}
	var eligible_ids: Array[String] = []
	for artifact_id: String in Global.player_data.player_artifact_pool:
		if not Global.player_data.player_artifact_available_artifact_id_cache.has(artifact_id):
			continue
		var artifact_data: ArtifactData = Global.get_artifact_data(artifact_id)
		if artifact_data == null:
			continue
		var eligible_rarities: Array = ArtifactData.STANDARD_ARTIFACT_RARITIES + [
			ArtifactData.ARTIFACT_RARITIES.SHOP]
		if artifact_data.artifact_rarity in eligible_rarities:
			eligible_ids.append(artifact_id)
	if eligible_ids.is_empty():
		return result

	Random.shuffle_array(rng, eligible_ids)
	var selected_id: String = eligible_ids[0]
	var prices: Array[int] = Random.get_shop_artifact_prices([selected_id], rng)
	if not prices.is_empty():
		result["0"] = ShopOfferData.new(
			ShopOfferData.CONTENT_KINDS.ARTIFACT, selected_id, prices[0])
	return result

## 为一个已占用普通槽生成不同于当前候选的替换商品。
func _generate_meditation_offer(
		rng: RandomNumberGenerator,
		excluded_ids: Array[String]) -> ShopOfferData:
	var available_count: int = Global.player_data.player_reward_card_filter_cache \
		.convert_to_unique_card_object_ids().size()
	var draft_size: int = min(max(excluded_ids.size() + 2, 4), available_count)
	if draft_size <= 0:
		return null
	var cards: Array[CardData] = Random.generate_rarity_weighted_card_draft(
		rng, draft_size, Random.CARD_DRAFT_TABLE_TYPES.SHOP, false)
	for card_data: CardData in cards:
		if excluded_ids.has(card_data.object_id):
			continue
		var prices: Array[int] = Random.get_shop_card_prices([card_data], rng)
		if not prices.is_empty():
			return ShopOfferData.new(
				ShopOfferData.CONTENT_KINDS.CARD, card_data.object_id, prices[0])
	return null
