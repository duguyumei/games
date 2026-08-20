class_name SourceBehaviorTransformationPort
extends RefCounted

## 被动 Handler 只通过该窄端口请求替换当前来源正文；候选解析、稳定随机、
## Store 写入和双身份投影均由 PassiveRuleRuntime 统一处理。

var _runtime_ref: WeakRef
var _source
var _context

func _init(runtime, source, context) -> void:
    _runtime_ref = weakref(runtime)
    _source = source
    _context = context

func transform_current_source() -> Dictionary:
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return {"success": false, "reason": "被动规则运行时已释放"}
    return runtime.commit_source_behavior_transformation(_source, _context)
