## 真气运转：把一张真气从一个牌区移动到另一个牌区。
##
## 这是**唯一**的牌区移动动作。抽取、调度、弃置、洗回、消耗全部走这里，
## 方向由 from_zone 与 to_zone 两个参数表达，不为每个方向单独建类。
##
## 因此「每当凝气运转为行气时」这类监听条件不是一种动作，而是对运转事件的过滤：
##     if event.from_zone == ZONES.DRAW and event.to_zone == ZONES.HAND
##
## 自动运转与主动运转的区分由 is_auto 参数携带：
##   自动运转 —— 流程自然发生（回合开始抽取、回合结束收尾、凝气不足洗回）
##   主动运转 —— 功法或效果驱动
## 部分内容只统计主动运转，因此这个标志必须随事件传出。
extends BaseAction
class_name ActionCirculateQi

## 参数键：要移动的真气实例 UID。
const VALUE_QI_UID: String = "qi_uid"

## 参数键：来源牌区，取值见 QiEnums.ZONES。
const VALUE_FROM_ZONE: String = "from_zone"

## 参数键：目标牌区，取值见 QiEnums.ZONES；传 -1 表示从牌库移除。
const VALUE_TO_ZONE: String = "to_zone"

## 参数键：是否为自动运转；缺省视为主动运转。
const VALUE_IS_AUTO: String = "is_auto"

## 参数键：是否跳过行气上限检查；洗回与移除类操作不受上限约束。
const VALUE_IGNORE_HAND_LIMIT: String = "ignore_hand_limit"

## 参数键：是否忽略封脉；解除封脉本身与强制移除需要绕过该检查。
const VALUE_IGNORE_SEALED: String = "ignore_sealed"

## 参数键：归属功法的实例 UID；仅移动到驭气时使用。
const VALUE_OWNING_GONGFA_UID: String = "owning_gongfa_uid"


func _init() -> void:
	# 运转是瞬时动作，不占用动画时间；表现层通过事件自行播放。
	time_delay = 0.0


## 执行运转。
func perform_action() -> void:
	var qi_uid: String = get_action_value(VALUE_QI_UID, "")
	if qi_uid.is_empty():
		push_warning("ActionCirculateQi：缺少 qi_uid 参数。")
		return

	var battle_state: BattleQiState = Global.get_battle_qi_state()
	if battle_state == null:
		return

	var qi: QiData = battle_state.find_qi_by_uid(qi_uid)
	if qi == null:
		return

	var from_zone: int = get_action_value(VALUE_FROM_ZONE, qi.qi_zone)
	var to_zone: int = get_action_value(VALUE_TO_ZONE, -1)
	var is_auto: bool = get_action_value(VALUE_IS_AUTO, false)
	var ignore_hand_limit: bool = get_action_value(VALUE_IGNORE_HAND_LIMIT, false)
	var ignore_sealed: bool = get_action_value(VALUE_IGNORE_SEALED, false)

	# 封脉的真气不能进行牌区运转。
	if not ignore_sealed and qi.is_sealed():
		return

	# 目标为 -1 表示从牌库移除；移除不受行气上限约束。
	if to_zone < 0:
		_remove_from_deck(battle_state, qi, from_zone, is_auto)
		return

	# 行气上限检查：已满时运转不发生，而非把真气挤到别处。
	if to_zone == QiEnums.ZONES.HAND and not ignore_hand_limit:
		if battle_state.get_zone_size(qi.qi_side, QiEnums.ZONES.HAND) >= QiEnums.HAND_LIMIT:
			return

	# 进入散气前先判定毒发；门槛使用存有的内力。
	# 毒发在移动之前结算，因此毒发造成的气力变化会影响此后读取到的数值。
	if to_zone == QiEnums.ZONES.DISCARD and qi.should_burst_on_discard():
		_enqueue_poison_burst(qi)

	battle_state.move_qi(qi, from_zone, to_zone)

	# 进入驭气时写入归属功法；离开驭气时清空，避免真气回到凝气后残留脏归属。
	if to_zone == QiEnums.ZONES.PENDING:
		qi.qi_owning_gongfa_uid = get_action_value(VALUE_OWNING_GONGFA_UID, "")
	elif from_zone == QiEnums.ZONES.PENDING:
		qi.qi_owning_gongfa_uid = ""

	# 进入散气时清除以此为终点的状态，例如冻结。
	if to_zone == QiEnums.ZONES.DISCARD:
		qi.on_enter_discard()

	Signals.qi_circulated.emit(qi, from_zone, to_zone, is_auto, _get_source_uid())
	Signals.qi_zones_changed.emit()


## 把真气从牌库移除；耗散与消耗型功法走这条路径。
##
## 被移除的真气记入战斗容器的本场移除列表，因此「每消耗 N 张真气」这类效果
## 仍能读到具体是哪些真气，而不只是一个计数。
## 一次探索结束后牌库恢复，被移除的真气重新回归。
func _remove_from_deck(battle_state: BattleQiState, qi: QiData, from_zone: int, is_auto: bool) -> void:
	battle_state.remove_qi_from_deck(qi, from_zone)
	Signals.qi_removed_from_deck.emit(qi, from_zone, is_auto, _get_source_uid())
	Signals.qi_zones_changed.emit()


## 把毒发排入动作队列；毒发本身是独立动作，因为它会造成伤害并可能致死。
func _enqueue_poison_burst(qi: QiData) -> void:
	var burst := ActionQiPoisonBurst.new()
	burst.init(parent_combatant, card_play_request, targets, {
		ActionQiPoisonBurst.VALUE_QI_UID: qi.object_uid,
	}, self)
	ActionHandler.add_action_to_top(burst)


## 返回本次运转的来源实例 UID；用于事件归因。
func _get_source_uid() -> String:
	if card_play_request != null:
		return card_play_request.get_source_uid()
	return ""
