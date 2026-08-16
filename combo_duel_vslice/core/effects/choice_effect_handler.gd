class_name ChoiceEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const TargetQueryScript = preload("res://core/effects/effect_target_query.gd")
const ChoiceRequestScript = preload("res://core/effects/battle_choice_request.gd")

var rng: RandomNumberGenerator
var value_resolver

func _init(random_source: RandomNumberGenerator, resolver = null) -> void:
    rng = random_source
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["select_cards", "select_option"]

func group_name() -> String:
    return "choice"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if str(effect.get("op", "")) == "select_option":
        return _select_option(effect, runtime)
    var query_spec = effect.get("query", {}).duplicate(true)
    if not query_spec is Dictionary:
        return EffectResultScript.failed("选择效果缺少 query 对象")
    if query_spec.get("limit") is Dictionary and value_resolver != null:
        query_spec["limit"] = value_resolver.resolve(query_spec["limit"], runtime)
    var filters: Dictionary = query_spec.get("filters", {}).duplicate(true)
    for value_field in ["effective_qi_at_most", "effective_qi_at_least"]:
        if filters.get(value_field) is Dictionary and value_resolver != null:
            filters[value_field] = value_resolver.resolve(filters[value_field], runtime)
    query_spec["filters"] = filters
    query_spec["card_identity_policy"] = runtime.card_identity_policy
    var query = TargetQueryScript.new().configure(query_spec)
    var minimum := _resolve_bound(effect.get("minimum", 0), runtime)
    var maximum := _resolve_bound(effect.get("maximum", 0), runtime)
    var choice_id := str(effect.get("choice_id", ""))
    if choice_id == "":
        return EffectResultScript.failed("选择效果缺少 choice_id")
    var request_id: String = runtime.choice_request_id(choice_id)
    if runtime.choice_responses.has(request_id):
        var selected_ids: Array = runtime.choice_responses[request_id]
        if not runtime.choice_candidates.has(request_id):
            return EffectResultScript.failed("选择恢复缺少冻结候选")
        var frozen_candidates: Array = runtime.choice_candidates[request_id]
        var request = ChoiceRequestScript.new().configure({
            "request_id": request_id,
            "prompt": effect.get("prompt", "请选择真气"),
            "chooser": effect.get("chooser", query.side_id),
            "minimum": minimum,
            "maximum": maximum,
            "insufficient_policy": str(effect.get("insufficient_policy", "")),
            "ordered": bool(effect.get("ordered", false)),
            "candidates": frozen_candidates,
            "metadata": {"query": query.snapshot()},
        })
        var check: Dictionary = request.validate_selection(selected_ids)
        if not check.get("ok", false):
            return EffectResultScript.failed(str(check.get("reason", "选择不合法")))
        var selected_cards: Array = request.selected_cards(selected_ids)
        runtime.captures[str(effect.get("capture", "selected_cards"))] = selected_cards
        runtime.choice_responses.erase(request_id)
        runtime.choice_candidates.erase(request_id)
        return EffectResultScript.succeeded("选择 %d 张真气" % selected_cards.size(), {
            "selected_card_ids": selected_ids.duplicate(),
        })

    var candidate_capture := str(effect.get("candidate_capture", ""))
    var query_result: Dictionary = ({
        "success": true,
        "reason": "",
        "cards": runtime.captures.get(candidate_capture, []).duplicate(),
        "side": runtime.actor if str(effect.get("chooser", "actor")) == "actor" else runtime.target,
    } if candidate_capture != "" else query.resolve(runtime, rng))
    if not query_result.get("success", false):
        return EffectResultScript.failed(str(query_result.get("reason", "目标查询失败")))
    var excluded_capture := str(query_spec.get("exclude_capture", ""))
    if excluded_capture != "":
        var excluded_ids: Array = runtime.captures.get(excluded_capture, []).map(
            func(card): return str(card.id))
        query_result["cards"] = query_result["cards"].filter(
            func(card): return not excluded_ids.has(str(card.id)))
    if str(effect.get("selection_purpose", "")) == "explicit_discard":
        query_result["cards"] = query_result["cards"].filter(
            func(card):
                return runtime.ports == null \
                    or runtime.ports.can_explicit_discard(
                        query_result["side"], card).get("allowed", true))
    var request = ChoiceRequestScript.new().configure({
        "request_id": request_id,
        "prompt": effect.get("prompt", "请选择真气"),
        "chooser": effect.get("chooser", query.side_id),
        "minimum": minimum,
        "maximum": maximum,
        "insufficient_policy": str(effect.get("insufficient_policy", "")),
        "ordered": bool(effect.get("ordered", false)),
        "candidates": query_result["cards"],
        "metadata": {"query": query.snapshot()},
    })
    var definition_check: Dictionary = request.validate_definition()
    if not definition_check.get("ok", false):
        return EffectResultScript.failed(str(definition_check.get("reason", "选择请求无效")))
    if request.requires_failure():
        return EffectResultScript.failed(
            "合格目标不足：需要至少 %d，实际 %d" % [request.minimum, request.candidates.size()])
    if request.should_auto_resolve():
        var all_ids: Array[String] = request.candidate_ids()
        runtime.choice_responses[request_id] = all_ids
        runtime.choice_candidates[request_id] = request.candidates.duplicate()
        return execute(effect, runtime)
    runtime.choice_candidates[request_id] = request.candidates.duplicate()
    return EffectResultScript.pending_choice("等待选择：%s" % request.prompt, request)

func summarize(_effect: Dictionary, _context, _intent: Dictionary, _state: Dictionary) -> void:
    pass

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) == "select_option":
        var options = effect.get("options", [])
        if not options is Array or options.is_empty():
            validator.report_error(scope + ".options", "必须是非空数组")
            return
        var seen: Dictionary = {}
        for index in range(options.size()):
            var option = options[index]
            if not option is Dictionary:
                validator.report_error("%s.options[%d]" % [scope, index], "必须是对象")
                continue
            var option_id := str(option.get("id", ""))
            if option_id == "" or seen.has(option_id):
                validator.report_error(
                    "%s.options[%d].id" % [scope, index],
                    "必须为来源内唯一非空ID")
            seen[option_id] = true
        if str(effect.get("choice_id", "")) == "":
            validator.report_error(scope + ".choice_id", "必须提供 choice_id")
        return
    if effect.has("candidate_capture"):
        if not effect["candidate_capture"] is String or str(effect["candidate_capture"]) == "":
            validator.report_error(scope + ".candidate_capture", "必须是非空字符串")
        var normalized := effect.duplicate(true)
        normalized["query"] = {"side":effect.get("chooser", "actor"),"zone":"hand","order":"zone","filters":{}}
        validator.validate_choice_effect(normalized, scope)
    else:
        validator.validate_choice_effect(effect, scope)

func _resolve_bound(value, runtime) -> int:
    if value is Dictionary and value_resolver != null:
        return maxi(0, value_resolver.resolve(value, runtime))
    return maxi(0, int(value))

func _select_option(effect: Dictionary, runtime):
    var choice_id := str(effect.get("choice_id", ""))
    if choice_id == "":
        return EffectResultScript.failed("选项效果缺少 choice_id")
    var request_id: String = runtime.choice_request_id(choice_id)
    var options: Array = effect.get("options", []).duplicate(true)
    var minimum := _resolve_bound(effect.get("minimum", 0), runtime)
    var maximum := _resolve_bound(effect.get("maximum", 1), runtime)
    var request = ChoiceRequestScript.new().configure({
        "request_id": request_id,
        "prompt": effect.get("prompt", "请选择是否执行"),
        "chooser": effect.get("chooser", "actor"),
        "minimum": minimum,
        "maximum": maximum,
        "insufficient_policy": str(effect.get(
            "insufficient_policy", "use_available")),
        "ordered": false,
        "candidates": options,
        "metadata": {"choice_kind": "option"},
    })
    if runtime.choice_responses.has(request_id):
        var selected_ids: Array = runtime.choice_responses[request_id]
        var check: Dictionary = request.validate_selection(selected_ids)
        if not check.get("ok", false):
            return EffectResultScript.failed(str(check.get("reason", "选项选择不合法")))
        runtime.captures[str(effect.get("capture", "selected_options"))] = \
            request.selected_cards(selected_ids)
        runtime.choice_responses.erase(request_id)
        runtime.choice_candidates.erase(request_id)
        return EffectResultScript.succeeded("选择 %d 个选项" % selected_ids.size(), {
            "selected_option_ids": selected_ids.duplicate(),
        })
    var definition_check: Dictionary = request.validate_definition()
    if not definition_check.get("ok", false):
        return EffectResultScript.failed(str(
            definition_check.get("reason", "选项请求无效")))
    runtime.choice_candidates[request_id] = options.duplicate(true)
    return EffectResultScript.pending_choice(
        "等待选择：%s" % request.prompt, request)
