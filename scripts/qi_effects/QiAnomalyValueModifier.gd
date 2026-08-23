## 通过固定配置为异状提供纯真气值加算、乘算或设值。
extends BaseQiAnomalyEffect
class_name QiAnomalyValueModifier

## 按异状层数修改有效真气值，不消费层数也不生成行为。
func modify_qi_value(
		value: int,
		stacks: int,
		_context: Dictionary[String, Variant]) -> int:
	if anomaly_data == null:
		return value
	var operand: float = float(anomaly_data.effect_config.get("value_per_stack", 0.0)) \
		* float(max(stacks, 0))
	match str(anomaly_data.effect_config.get("operation", "add")):
		"add":
			return max(int(floor(float(value) + operand)), 0)
		"multiply":
			return max(int(floor(float(value) * operand)), 0)
		"set":
			return max(int(floor(operand)), 0)
	return value
