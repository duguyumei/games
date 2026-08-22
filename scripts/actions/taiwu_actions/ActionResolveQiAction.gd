## 真气行动功法效果完成后的统一收尾动作；只提交一次冻结请求。
extends BaseAction
class_name ActionResolveQiAction

## 需要提交的冻结真气行动。
var qi_action_request: QiActionRequest = null

## 初始化真气行动收尾动作。
func init_qi_action(_request: QiActionRequest) -> void:
	qi_action_request = _request

## 将待结算区真气移入弃牌堆并发布行动完成信号。
func perform_action() -> void:
	if qi_action_request == null:
		return
	Global.complete_qi_action(qi_action_request)

## 该收尾动作不产生额外等待。
func is_instant_action() -> bool:
	return true
