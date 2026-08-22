## 校验可持久化扩展状态是否仅包含 JSON 支持的值。
extends RefCounted
class_name JsonStateValidator

## 递归检查值是否可安全写入 JSON 存档。
static func is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for child_value: Variant in value:
				if not is_json_compatible(child_value):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not is_json_compatible(value[key]):
					return false
			return true
	return false
