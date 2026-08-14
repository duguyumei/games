class_name AnomalyLayerEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "transfer_anomaly_layers", "convert_anomaly_layers",
        "apply_layers_from_source", "apply_layers_to_each_captured",
        "remove_all_defense", "remove_anomaly_layers",
        "transfer_state_captured", "distribute_layers_evenly", "spread_one_layer",
    ]

func group_name() -> String:
    return "anomaly_layers"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("层数操作缺少战斗端口")
    match str(effect.get("op", "")):
        "transfer_anomaly_layers":
            return _transfer(effect, runtime)
        "convert_anomaly_layers":
            return _convert(effect, runtime)
        "apply_layers_from_source":
            return _apply_from_source(effect, runtime)
        "apply_layers_to_each_captured":
            return _apply_each(effect, runtime)
        "remove_all_defense":
            var removed := int(runtime.actor.defense)
            runtime.actor.defense = 0
            runtime.captures[str(effect.get("capture", "removed_defense"))] = [{"amount": removed}]
            return EffectResultScript.succeeded("移除全部防御 %d" % removed)
        "remove_anomaly_layers":
            return _remove_layers(effect, runtime)
        "transfer_state_captured":
            return _transfer_state(effect, runtime)
        "distribute_layers_evenly":
            return _distribute_evenly(effect, runtime)
        "spread_one_layer":
            return _spread_one(effect, runtime)
    return EffectResultScript.failed("层数处理器不支持此操作")

func _transfer(effect: Dictionary, runtime):
    var sources: Array = runtime.captures.get(str(effect.get("source_capture", "")), [])
    var targets: Array = runtime.captures.get(str(effect.get("target_capture", "")), [])
    if sources.is_empty() or targets.is_empty():
        return EffectResultScript.succeeded()
    var category := str(effect.get("category", "buff"))
    var anomaly := str(effect.get("anomaly", ""))
    var available := 0
    for card in sources:
        available += card.anomaly_layers(category, anomaly)
    var wanted := available if bool(effect.get("all", true)) \
        else mini(available, value_resolver.resolve(effect.get("amount", 0), runtime))
    if wanted <= 0:
        return EffectResultScript.succeeded()
    var distribution: Array[int] = []
    for _card in targets:
        distribution.append(wanted / targets.size())
    for index in range(wanted % targets.size()):
        distribution[index] += 1
    for index in range(targets.size()):
        if distribution[index] > 0 and not runtime.ports.can_apply_card_anomaly(
                targets[index], category, anomaly).get("allowed", false):
            return EffectResultScript.succeeded()
    var remaining := wanted
    for card in sources:
        var take := mini(remaining, card.anomaly_layers(category, anomaly))
        runtime.ports.set_card_anomaly_layers(
            card, category, anomaly,
            card.anomaly_layers(category, anomaly) - take,
            runtime.technique_name)
        remaining -= take
        if remaining <= 0:
            break
    for index in range(targets.size()):
        if distribution[index] > 0:
            runtime.ports.apply_card_anomaly(
                targets[index], category, anomaly, {}, runtime.technique_name,
                distribution[index])
    return EffectResultScript.succeeded("转移 %d 层%s" % [wanted, anomaly])

func _convert(effect: Dictionary, runtime):
    var cards: Array = runtime.captures.get(str(effect.get("capture", "")), [])
    var source_category := str(effect.get("source_category", "buff"))
    var source_anomaly := str(effect.get("source_anomaly", ""))
    var target_category := str(effect.get("target_category", "buff"))
    var target_anomaly := str(effect.get("target_anomaly", ""))
    var multiplier := int(effect.get("multiplier", 1))
    var converted := 0
    for card in cards:
        var layers: int = card.anomaly_layers(source_category, source_anomaly)
        if layers <= 0 or not runtime.ports.can_apply_card_anomaly(
                card, target_category, target_anomaly).get("allowed", false):
            continue
        runtime.ports.set_card_anomaly_layers(
            card, source_category, source_anomaly, 0, runtime.technique_name)
        runtime.ports.apply_card_anomaly(
            card, target_category, target_anomaly, {}, runtime.technique_name,
            layers * multiplier)
        converted += layers
    return EffectResultScript.succeeded("转换 %d 层" % converted)

func _apply_from_source(effect: Dictionary, runtime):
    var sources: Array = runtime.captures.get(str(effect.get("source_capture", "")), [])
    var targets: Array = runtime.captures.get(str(effect.get("target_capture", "")), [])
    if sources.is_empty() or targets.is_empty():
        return EffectResultScript.succeeded()
    var layers: int = sources[0].anomaly_layers(
        str(effect.get("source_category", "buff")), str(effect.get("source_anomaly", "")))
    layers *= int(effect.get("multiplier", 1))
    if layers > 0:
        runtime.ports.apply_card_anomaly(
            targets[0], str(effect.get("target_category", "buff")),
            str(effect.get("target_anomaly", "")), {}, runtime.technique_name, layers)
    return EffectResultScript.succeeded("按来源施加 %d 层" % layers)

func _apply_each(effect: Dictionary, runtime):
    var applied := 0
    for card in runtime.captures.get(str(effect.get("capture", "")), []):
        var layers: Variant = effect.get("layers", 1)
        var amount: int = value_resolver.resolve(layers, runtime) if layers is Dictionary else int(layers)
        if effect.has("layers_from_self"):
            var spec: Dictionary = effect["layers_from_self"]
            amount = card.anomaly_layers(str(spec.get("category", "buff")), str(spec.get("anomaly", ""))) \
                * int(spec.get("multiplier", 1))
        if amount > 0 and runtime.ports.apply_card_anomaly(
                card, str(effect.get("category", "buff")), str(effect.get("anomaly", "")),
                {}, runtime.technique_name, amount).get("success", false):
            applied += 1
    return EffectResultScript.succeeded("逐张施加 %d 张" % applied)

func _remove_layers(effect: Dictionary, runtime):
    var removed := 0
    for card in runtime.captures.get(str(effect.get("capture", "")), []):
        var category := str(effect.get("category", "buff"))
        var anomaly := str(effect.get("anomaly", ""))
        var current: int = card.anomaly_layers(category, anomaly)
        var amount: int = current if bool(effect.get("all", true)) \
            else mini(current, value_resolver.resolve(effect.get("amount", 0), runtime))
        runtime.ports.set_card_anomaly_layers(
            card, category, anomaly, current - amount, runtime.technique_name)
        removed += amount
    runtime.captures[str(effect.get("result_capture", "removed_layers"))] = [{"amount": removed}]
    return EffectResultScript.succeeded("移除 %d 层" % removed)

func _transfer_state(effect: Dictionary, runtime):
    var sources: Array = runtime.captures.get(str(effect.get("source_capture", "")), [])
    var targets: Array = runtime.captures.get(str(effect.get("target_capture", "")), [])
    var anomaly := str(effect.get("anomaly", "poison"))
    if sources.is_empty() or targets.is_empty() \
            or not sources[0].has_anomaly("state", anomaly):
        runtime.captures[str(effect.get("result_capture", "transferred"))] = []
        return EffectResultScript.succeeded()
    if not runtime.ports.can_apply_card_anomaly(
            targets[0], "state", anomaly, false).get("allowed", false):
        runtime.captures[str(effect.get("result_capture", "transferred"))] = []
        return EffectResultScript.succeeded()
    var applied: Dictionary = runtime.ports.apply_card_anomaly(
        targets[0], "state", anomaly, {}, runtime.technique_name, 1, false)
    if not applied.get("success", false) or not applied.get("changed", true):
        runtime.captures[str(effect.get("result_capture", "transferred"))] = []
        return EffectResultScript.succeeded()
    runtime.ports.remove_card_anomaly(
        sources[0], "state", anomaly, runtime.technique_name)
    runtime.captures[str(effect.get("result_capture", "transferred"))] = [targets[0]]
    return EffectResultScript.succeeded("转移状态%s" % anomaly)

func _distribute_evenly(effect: Dictionary, runtime):
    var targets: Array = runtime.captures.get(str(effect.get("target_capture", "")), [])
    var total: int = value_resolver.resolve(effect.get("amount", 0), runtime)
    if targets.is_empty() or total <= 0:
        return EffectResultScript.succeeded()
    var extras: Array = runtime.captures.get(str(effect.get("extra_capture", "")), [])
    var base: int = total / targets.size()
    var remainder: int = total % targets.size()
    if extras.size() != remainder:
        extras = targets.slice(0, remainder)
    var category := str(effect.get("category", "buff"))
    var anomaly := str(effect.get("anomaly", "qi_heat"))
    for card in targets:
        var amount := base + (1 if extras.has(card) else 0)
        if amount > 0:
            runtime.ports.apply_card_anomaly(
                card, category, anomaly, {}, runtime.technique_name, amount)
    return EffectResultScript.succeeded("平均分配 %d 层" % total)

func _spread_one(effect: Dictionary, runtime):
    var sources: Array = runtime.captures.get(str(effect.get("source_capture", "")), [])
    var targets: Array = runtime.captures.get(str(effect.get("target_capture", "")), [])
    var category := str(effect.get("category", "buff"))
    var anomaly := str(effect.get("anomaly", "growth"))
    if sources.is_empty() or targets.is_empty() \
            or sources[0].anomaly_layers(category, anomaly) <= 0:
        return EffectResultScript.succeeded()
    for card in targets:
        if not runtime.ports.can_apply_card_anomaly(
                card, category, anomaly, false).get("allowed", true) \
                and card.anomaly_layers(category, anomaly) <= 0:
            return EffectResultScript.succeeded()
    for card in targets:
        runtime.ports.apply_card_anomaly(
            card, category, anomaly, {}, runtime.technique_name, 1)
    runtime.ports.set_card_anomaly_layers(
        sources[0], category, anomaly,
        sources[0].anomaly_layers(category, anomaly) - 1,
        runtime.technique_name)
    return EffectResultScript.succeeded("扩散1层%s" % anomaly)

func validate_effect(_effect: Dictionary, _validator, _scope: String) -> void:
    pass
