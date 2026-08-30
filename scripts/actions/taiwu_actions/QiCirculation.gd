## 真气运转的便捷构造器。
##
## 全部方法都返回同一个 ActionCirculateQi，只是预填不同的参数组合。
## 目的是让调用处可读，并把 is_auto、上限豁免这类容易写错的标志固定下来。
##
## 「凝气运转为行气」不需要专门的动作类 —— 它只是 draw_to_hand() 这一种参数组合。
class_name QiCirculation

## ============================================================
## 自动运转：流程驱动
## ============================================================

## 抽取：凝气 → 行气。回合开始时按基础抽取数量调用。
static func draw(qi_uid: String) -> ActionCirculateQi:
	return _build(qi_uid, QiEnums.ZONES.DRAW, QiEnums.ZONES.HAND, true)

## 回合结束收尾：行气或驭气 → 由该真气的离场去向决定。
##
## 去向已由 QiData.resolve_discard_target() 按「保留 > 耗散 > 归根」的优先级算出，
## 因此这里只需把结果传入，不重复判断状态。
static func settle_at_round_end(qi: QiData) -> ActionCirculateQi:
	var target := qi.resolve_discard_target()
	return _build(qi.object_uid, qi.qi_zone, target, true, true)

## 洗回：散气 → 凝气。凝气不足时由抽取流程触发。
static func reshuffle(qi_uid: String) -> ActionCirculateQi:
	return _build(qi_uid, QiEnums.ZONES.DISCARD, QiEnums.ZONES.DRAW, true, true)


## ============================================================
## 主动运转：功法与效果驱动
## ============================================================

## 通用主动运转；功法正文写「将 N 张 X 运转为 Y」时使用。
static func circulate(qi_uid: String, from_zone: int, to_zone: int) -> ActionCirculateQi:
	return _build(qi_uid, from_zone, to_zone, false)

## 调度：行气 → 驭气，并记录归属功法。
##
## 归属必须在此时写入，因为一个行动组中双方各有一门功法结算，
## 而「按输入顺序依次读取驭气」是每门功法内部的顺序。
static func assign_to_gongfa(qi_uid: String, gongfa_uid: String) -> ActionCirculateQi:
	var action := _build(qi_uid, QiEnums.ZONES.HAND, QiEnums.ZONES.PENDING, false)
	action.values[ActionCirculateQi.VALUE_OWNING_GONGFA_UID] = gongfa_uid
	return action

## 流动型功法的输入返回行气：驭气 → 行气。
static func return_to_hand(qi_uid: String) -> ActionCirculateQi:
	return _build(qi_uid, QiEnums.ZONES.PENDING, QiEnums.ZONES.HAND, false)

## 归根：任意牌区 → 凝气。
static func return_to_deck(qi_uid: String, from_zone: int) -> ActionCirculateQi:
	return _build(qi_uid, from_zone, QiEnums.ZONES.DRAW, false, true)

## 消耗：从牌库移除。消耗型功法的输入与耗散触发时走这条路径。
##
## 目标牌区传 -1 表示移除；被移除的真气记入战斗容器的本场移除列表，
## 一次探索结束后牌库恢复。
static func consume(qi_uid: String, from_zone: int) -> ActionCirculateQi:
	return _build(qi_uid, from_zone, -1, false, true)


## ============================================================
## 内部
## ============================================================

## 构造一个运转动作。
static func _build(
	qi_uid: String,
	from_zone: int,
	to_zone: int,
	is_auto: bool,
	ignore_hand_limit: bool = false
) -> ActionCirculateQi:
	var action := ActionCirculateQi.new()
	action.values = {
		ActionCirculateQi.VALUE_QI_UID: qi_uid,
		ActionCirculateQi.VALUE_FROM_ZONE: from_zone,
		ActionCirculateQi.VALUE_TO_ZONE: to_zone,
		ActionCirculateQi.VALUE_IS_AUTO: is_auto,
		ActionCirculateQi.VALUE_IGNORE_HAND_LIMIT: ignore_hand_limit,
	}
	return action
