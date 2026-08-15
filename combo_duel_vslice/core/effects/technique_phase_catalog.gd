class_name TechniquePhaseCatalog
extends RefCounted

## 功法效果阶段的唯一目录。
##
## 阶段顺序、显式 phase 校验、Handler 默认阶段校验与运行时筛选都必须
## 经过这里，避免行动解析器、调用结算和内容校验各自维护名单。

const PREPARE := "prepare"
const DAMAGE := "damage"
const ZONES := "zones"
const POST_COMMIT := "post_commit"

const ORDERED_PHASE_IDS := [PREPARE, DAMAGE, ZONES, POST_COMMIT]

static func phase_ids() -> Array[String]:
    var result: Array[String] = []
    result.assign(ORDERED_PHASE_IDS)
    return result

static func pre_commit_phase_ids() -> Array[String]:
    return [PREPARE, DAMAGE, ZONES]

static func has_phase(phase_id: String) -> bool:
    return ORDERED_PHASE_IDS.has(phase_id)

static func resolve_effect_phase(
        effect: Dictionary,
        handler_registry) -> Dictionary:
    var explicit_value = effect.get("phase", "")
    if effect.has("phase") and not explicit_value is String:
        return {"success": false, "reason": "effect.phase 必须是字符串"}
    var explicit_phase := str(explicit_value)
    if explicit_phase != "":
        if not has_phase(explicit_phase):
            return {
                "success": false,
                "reason": "未知功法效果阶段 %s" % explicit_phase,
            }
        return {"success": true, "phase": explicit_phase}
    var operation_id := str(effect.get("op", ""))
    if handler_registry == null or not handler_registry.has_handler(operation_id):
        return {
            "success": false,
            "reason": "无法为未注册效果 %s 解析默认阶段" % operation_id,
        }
    var default_phase := str(handler_registry.default_phase(operation_id))
    if not has_phase(default_phase):
        return {
            "success": false,
            "reason": "效果 %s 声明未知默认阶段 %s" % [
                operation_id, default_phase],
        }
    return {"success": true, "phase": default_phase}

static func effects_for_phase(
        effects: Array,
        phase_id: String,
        handler_registry) -> Dictionary:
    if not has_phase(phase_id):
        return {
            "success": false,
            "reason": "请求了未知功法效果阶段 %s" % phase_id,
            "effects": [],
        }
    var result: Array = []
    for effect_value in effects:
        if not effect_value is Dictionary:
            return {
                "success": false,
                "reason": "功法效果必须是对象",
                "effects": [],
            }
        var phase_result := resolve_effect_phase(effect_value, handler_registry)
        if not phase_result.get("success", false):
            phase_result["effects"] = []
            return phase_result
        if str(phase_result.get("phase", "")) == phase_id:
            result.append(effect_value)
    return {"success": true, "phase": phase_id, "effects": result}
