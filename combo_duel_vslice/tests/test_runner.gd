extends SceneTree

const QiCardScript = preload("res://core/qi_card.gd")
const CardInstanceIdFactoryScript = preload("res://core/card_instance_id_factory.gd")
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")
const RunDeckScript = preload("res://core/run_deck.gd")
const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSideScript = preload("res://core/battle_side.gd")
const BattleFlowCoordinatorScript = preload("res://core/battle_flow_coordinator.gd")
const BattleTimingSystemScript = preload("res://core/battle_timing_system.gd")
const DefenseRetentionPolicyScript = preload(
    "res://core/defense_retention_policy.gd")
const SameQiRuleScript = preload("res://core/same_qi_rule.gd")
const StatusSystemScript = preload("res://core/status_system.gd")
const StatusBehaviorRegistryScript = preload(
    "res://core/statuses/status_behavior_registry.gd")
const TriggerQueueScript = preload("res://core/trigger_queue.gd")
const BattleObservationScript = preload("res://core/battle_observation.gd")
const PlayerActionControllerScript = preload("res://core/player_action_controller.gd")
const EnemyActionControllerScript = preload("res://core/enemy_action_controller.gd")
const BattleActionProposalScript = preload("res://core/battle_action_proposal.gd")
const AiBattleContextScript = preload("res://core/ai/ai_battle_context.gd")
const AiDecisionObservationScript = preload("res://core/ai/ai_decision_observation.gd")
const AiHistoryProjectorScript = preload("res://core/ai/ai_history_projector.gd")
const AiBattleConversationScript = preload("res://core/ai/ai_battle_conversation.gd")
const AiCandidateScript = preload("res://core/ai/ai_candidate.gd")
const AiConversationStoreScript = preload("res://core/ai/ai_conversation_store.gd")
const AiSettingsServiceScript = preload("res://core/ai/ai_settings_service.gd")
const AiDecisionGatewayScript = preload("res://core/ai/ai_decision_gateway.gd")
const AiPromptEncoderScript = preload("res://core/ai/ai_prompt_encoder.gd")
const AiResponseValidatorScript = preload("res://core/ai/ai_response_validator.gd")
const AiStableValueEncoderScript = preload(
    "res://core/ai/ai_stable_value_encoder.gd")
const AiHistoryCompactorScript = preload(
    "res://core/ai/ai_history_compactor.gd")
const AiTraceReporterScript = preload(
    "res://tools/ai/ai_trace_reporter.gd")
const MockAiProviderScript = preload("res://core/ai/providers/mock_ai_provider.gd")
const AiProviderSettingsScript = preload("res://core/ai/providers/ai_provider_settings.gd")
const ChatCompletionsAiProviderScript = preload("res://core/ai/providers/chat_completions_ai_provider.gd")
const AiProviderFactoryScript = preload("res://core/ai/providers/ai_provider_factory.gd")
const EnemyCandidateReducerScript = preload(
    "res://core/ai/enemy_candidate_reducer.gd")
const EnemyCandidateDominanceFilterScript = preload(
    "res://core/ai/enemy_candidate_dominance_filter.gd")
const EnemyCandidateFeaturesScript = preload(
    "res://core/ai/enemy_candidate_features.gd")
const EnemyAiValueQueryServiceScript = preload(
    "res://core/ai/enemy_ai_value_query_service.gd")
const FakeEnemyAiValueProviderScript = preload(
    "res://tests/support/fake_enemy_ai_value_provider.gd")
const DamageResolverScript = preload("res://core/damage_resolver.gd")
const GameLogScript = preload("res://core/game_log.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const BattleFinalResultDTOScript = preload(
    "res://core/battle_final_result_dto.gd")
const RunTerminalResultDTOScript = preload(
    "res://core/run_terminal_result_dto.gd")
const MapGeneratorScript = preload("res://core/map_generator.gd")
const NodeDispatcherScript = preload("res://core/node_dispatcher.gd")
const RunStateScript = preload("res://core/run_state.gd")
const RunSessionScript = preload("res://core/run_session.gd")
const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunCombatHistoryScript = preload("res://core/run_combat_history.gd")
const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const RunSaveDataScript = preload("res://core/run_save_data.gd")
const SaveRepositoryScript = preload("res://core/save_repository.gd")
const RunSaveApplicationServiceScript = preload(
    "res://core/run_save_application_service.gd")
const InnerSkillRepositoryScript = preload("res://core/inner_skill_repository.gd")
const InnerSkillLoadoutServiceScript = preload(
    "res://core/inner_skill_loadout_service.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const StarterBuildAssemblerScript = preload("res://core/starter_build_assembler.gd")
const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const EnemyRepositoryScript = preload("res://core/enemy_repository.gd")
const EnemyDeckEncodingScript = preload("res://core/enemy_deck_encoding.gd")
const NodeRewardServiceScript = preload("res://core/node_reward_service.gd")
const RunEffectHandlerRegistryScript = preload(
    "res://core/run_effects/run_effect_handler_registry.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const PracticeServiceScript = preload("res://core/practice_service.gd")
const PracticeOverlayScript = preload("res://ui/components/practice_overlay.gd")
const RunBuildDTOScript = preload("res://core/run_build_dto.gd")
const RunBuildOverlayScene = preload(
    "res://ui/components/run_build_overlay.tscn")
const RunCardSelectionDialogScene = preload(
    "res://ui/components/run_card_selection_dialog.tscn")
const RunTechniqueLoadoutPanelScene = preload(
    "res://ui/components/run_technique_loadout_panel.tscn")
const RunInnerSkillLoadoutPanelScene = preload(
    "res://ui/components/run_inner_skill_loadout_panel.tscn")
const EffectExecutorScript = preload("res://core/effect_executor.gd")
const EffectHandlerRegistryScript = preload(
    "res://core/effects/effect_handler_registry.gd")
const BattleScene = preload("res://ui/main.tscn")
const RunScene = preload("res://ui/run_main.tscn")
const RunTerminalOverlayScript = preload(
    "res://ui/components/run_terminal_overlay.gd")
const FrontScene = preload("res://ui/front_main.tscn")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const CardReshapeBehaviorRegistryScript = preload(
    "res://core/card_reshapes/card_reshape_behavior_registry.gd")
const CardReshapeBehaviorContextScript = preload(
    "res://core/card_reshapes/card_reshape_behavior_context.gd")
const CardReshapeBehaviorHandlerScript = preload(
    "res://core/card_reshapes/card_reshape_behavior_handler.gd")
const ConsumableEffectHandlerRegistryScript = preload(
    "res://core/consumables/consumable_effect_handler_registry.gd")
const ConsumableUseServiceScript = preload(
    "res://core/consumables/consumable_use_service.gd")
const RunConsumableUseContextScript = preload(
    "res://core/consumables/run_consumable_use_context.gd")
const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")
const CardOriginServiceScript = preload("res://core/card_origin_service.gd")
const NodeInteractionHandlerRegistryScript = preload(
    "res://core/node_interactions/node_interaction_handler_registry.gd")
const NodeInteractionServiceScript = preload(
    "res://core/node_interactions/node_interaction_service.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const PassiveIntPolicyResolverScript = preload(
    "res://core/passives/passive_int_policy_resolver.gd")
const RunPassiveEventServiceScript = preload(
    "res://core/passives/run_passive_event_service.gd")
const RunPassiveEventContextScript = preload(
    "res://core/passives/run_passive_event_context.gd")
const BattleSetupServiceScript = preload("res://core/battle_setup_service.gd")
const BattlePassiveCounterReadPortScript = preload(
    "res://core/passives/battle_passive_counter_read_port.gd")
const BattlePassiveEventContextScript = preload(
    "res://core/passives/battle_passive_event_context.gd")
const BattlePassiveCommittedEventContextScript = preload(
    "res://core/passives/battle_passive_committed_event_context.gd")
const HandRecognitionOptionsScript = preload(
    "res://core/passives/hand_recognition_options.gd")
const HandRecognitionPolicyScript = preload(
    "res://core/passives/hand_recognition_policy.gd")
const CardIdentityPolicyScript = preload(
    "res://core/passives/card_identity_policy.gd")
const BattlePermissionServiceScript = preload(
    "res://core/passives/battle_permission_service.gd")
const EffectTargetQueryScript = preload(
    "res://core/effects/effect_target_query.gd")
const TargetQueryFieldRegistryScript = preload(
    "res://core/effects/target_query_field_registry.gd")
const EffectValueResolverScript = preload(
    "res://core/effects/effect_value_resolver.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")
const ValueSpecRegistryScript = preload(
    "res://core/specs/value_spec_registry.gd")
const TechniqueEffectContextScript = preload(
    "res://core/effects/technique_effect_context.gd")
const TechniqueRepositoryPolicyScript = preload(
    "res://core/technique_repository.gd")

const ProbeEffectHandlerScript = preload("res://tests/support/probe_effect_handler.gd")
const ProbeStatusBehaviorHandlerScript = preload(
    "res://tests/support/probe_status_behavior_handler.gd")

class TimingProbe:
    extends RefCounted

    var calls: Array[String] = []

    func record(event, label: String) -> Dictionary:
        calls.append("%s:%s:%d" % [event.timing, label, event.serial])
        return {"success": true, "detail": label}

class DefenseRetentionProbe:
    extends RefCounted

    var target
    var additional_percent: int
    var prevents_decay: bool

    func _init(
            target_value,
            additional_percent_value: int = 0,
            prevents_decay_value: bool = false) -> void:
        target = target_value
        additional_percent = additional_percent_value
        prevents_decay = prevents_decay_value

    func defense_retention_modifier(side, _context: Dictionary) -> Dictionary:
        if side != target:
            return {}
        return {
            "additional_retention_percent": additional_percent,
            "prevent_decay": prevents_decay,
        }

class BattleOutcomeFailureProbe:
    extends "res://core/battle_outcome_commit_service.gd"

    var failure_stage: String

    func _init(stage: String) -> void:
        failure_stage = stage

    func _checkpoint(stage: String, _run_session) -> Dictionary:
        if stage == failure_stage:
            return {"success": false, "reason": "聚合事务注入失败：%s" % stage}
        return {"success": true}

class BattleCloseProbe:
    extends RefCounted

    var close_count: int = 0

    func close_battle() -> bool:
        close_count += 1
        return false

class BattleCompletedMutationProbe:
    extends RefCounted

    var call_count: int = 0
    var mutate_uncommittable_counter: bool = false

    func _init(mutate_counter: bool = false) -> void:
        mutate_uncommittable_counter = mutate_counter

    func capture_source_snapshot(_owner) -> Array:
        return []

    func dispatch(context, growth, event_state) -> Dictionary:
        call_count += 1
        growth.experience += 7
        growth.base_hand_limit_modifier += 2
        growth.source_marker_store.write(
            "inner_skill", "inner:probe:0", "probe_inner",
            "battle_completed_probe", "run", "add", 3)
        if mutate_uncommittable_counter:
            growth.passive_counter_store._values["aggregate-probe"] = {
                "key": {
                    "source_kind": "item", "content_id": "probe_item",
                    "state_key": "aggregate", "counter_id": "completed",
                },
                "value": 1,
            }
        event_state.committed_passive_event_tokens.append(
            str(context.transaction_token))
        return {
            "success": true,
            "duplicate": false,
            "hook": str(context.hook),
            "transaction_token": str(context.transaction_token),
            "results": [],
        }

class InnerSkillForgetValueProbe:
    extends RefCounted

    var additional_value: int

    func _init(additional_value_override: int) -> void:
        additional_value = additional_value_override

    func resolve(definition: Dictionary, _growth) -> int:
        return int(definition.get("forget_value", 0)) + additional_value

class PassiveCapacityProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var stable_id: String

    func _init(id_value: String = "capacity_probe") -> void:
        stable_id = id_value

    func behavior_id() -> String:
        return stable_id

    func supported_hooks() -> Array[String]:
        return ["inner_skill_capacity_query"] as Array[String]

    func validate_configuration(configuration: Dictionary) -> Array[String]:
        if not configuration.get("amount") is int:
            return ["amount 必须是整数"] as Array[String]
        return []

    func handle(_hook: String, _context, configuration: Dictionary) -> Dictionary:
        return {
            "success": true,
            "additional_capacity": int(configuration["amount"]),
        }

class PassiveStateProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    func behavior_id() -> String:
        return "state_probe"

    func supported_hooks() -> Array[String]:
        return ["action_preview", "action_resolve"] as Array[String]

    func validate_configuration(_configuration: Dictionary) -> Array[String]:
        return []

    func handle(hook: String, context, _configuration: Dictionary) -> Dictionary:
        if hook == "action_preview":
            return {"success": true, "intent": {"defense": 1}}
        if bool(context.payload.get("direct_runtime_probe", false)):
            var before := int(context.actor.defense)
            context.actor.add_defense(before + 1)
            return {"success": true, "before": before, "after": context.actor.defense}
        return {"success": true, "effects": [{"op": "defense", "amount": 1}]}

class PassiveRepeatProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    func behavior_id() -> String:
        return "repeat_probe"

    func supported_hooks() -> Array[String]:
        return ["passive_invocation_plan_query"] as Array[String]

    func validate_configuration(configuration: Dictionary) -> Array[String]:
        if not configuration.get("target_content_id") is String:
            return ["target_content_id 必须是字符串"] as Array[String]
        return []

    func handle(_hook: String, context, configuration: Dictionary) -> Dictionary:
        if context.plan_target_source == null \
                or context.plan_target_source.content_id != str(
                    configuration["target_content_id"]):
            return {"success": true, "additional_executions": 0}
        return {
            "success": true,
            "additional_executions": 1,
            "target_content_id": str(configuration["target_content_id"]),
        }

class RunPassiveProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var event_calls: Array[Dictionary] = []

    func behavior_id() -> String:
        return "run_passive_probe"

    func supported_hooks() -> Array[String]:
        return [
            "practice_price_query",
            "inner_skill_forget_value_query",
            "meditation_cost_query",
            "pack_offer_count_query",
            "pack_choose_count_query",
            "practice_opened",
            "practice_purchase_committed",
            "practice_pack_opened",
            "meditation_committed",
            "inner_skill_forgotten",
            "battle_completed",
            "node_completed",
        ] as Array[String]

    func validate_configuration(configuration: Dictionary) -> Array[String]:
        for field in [
                "price_delta", "forget_delta", "meditation_delta",
                "offer_delta", "choose_delta", "event_experience"]:
            if configuration.has(field) and not configuration[field] is int:
                return ["%s 必须是整数" % field] as Array[String]
        for field in ["grant_item_id", "grant_hook"]:
            if configuration.has(field) and not configuration[field] is String:
                return ["%s 必须是字符串" % field] as Array[String]
        return []

    func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
        if hook.ends_with("_query"):
            if str(configuration.get("fail_hook", "")) == hook:
                return {"success": false, "reason": "Fake 查询失败"}
            var current := int(context.payload.get("current_value", 0))
            var request = context.payload.get("int_query")
            var target_id := str(configuration.get("target_id", ""))
            if hook == "practice_price_query" \
                    and target_id != "" and request != null \
                    and request.subject_id != target_id:
                return {"success": true, "value": current}
            var field: String = {
                "practice_price_query": "price_delta",
                "inner_skill_forget_value_query": "forget_delta",
                "meditation_cost_query": "meditation_delta",
                "pack_offer_count_query": "offer_delta",
                "pack_choose_count_query": "choose_delta",
            }.get(hook, "")
            return {
                "success": true,
                "value": current + int(configuration.get(field, 0)),
            }
        var ports = context.payload.get("effect_ports")
        var recorded_payload: Dictionary = context.payload.duplicate(false)
        recorded_payload.erase("effect_ports")
        event_calls.append({
            "hook": hook,
            "source_instance_key": context.source.source_instance_key,
            "transaction_token": context.transaction_token,
            "payload": recorded_payload,
            "growth": ports.growth_snapshot() if ports != null else {},
        })
        var amount := int(configuration.get("event_experience", 0))
        if amount > 0:
            var applied: Dictionary = ports.apply_effects([{
                "op": "gain_experience", "amount": amount,
                "source": "run_passive_probe",
            }])
            if not applied.get("success", false):
                return applied
        var grant_item_id := str(configuration.get("grant_item_id", ""))
        if grant_item_id != "" \
                and str(configuration.get("grant_hook", hook)) == hook:
            var granted: Dictionary = ports.apply_effects([{
                "op": "grant_items", "item_ids": [grant_item_id],
            }])
            if not granted.get("success", false):
                return granted
        if str(configuration.get("fail_hook", "")) == hook:
            return {"success": false, "reason": "Fake Handler 提交失败"}
        return {"success": true}

class PassiveCounterProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var stable_id: String

    func _init(id_value: String = "passive_counter_probe") -> void:
        stable_id = id_value

    func behavior_id() -> String:
        return stable_id

    func supported_hooks() -> Array[String]:
        return [
            "battle_completed",
            "inner_skill_forget_value_query",
        ] as Array[String]

    func validate_configuration(_configuration: Dictionary) -> Array[String]:
        return []

    func counter_definitions(configuration: Dictionary) -> Array:
        var definition := {
            "counter_id": configuration.get("counter_id", "battle_progress"),
            "default_value": configuration.get("default_value", 0),
            "minimum": configuration.get("minimum", 0),
            "retention_policy": configuration.get(
                "retention_policy", "while_owned"),
        }
        if configuration.has("maximum"):
            definition["maximum"] = configuration["maximum"]
        return [definition]

    func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
        var counter_id := str(configuration.get(
            "counter_id", "battle_progress"))
        if hook == "inner_skill_forget_value_query":
            var progress: int = context.counter_read_port.read(counter_id)
            return {
                "success": true,
                "value": int(context.payload.get("current_value", 0)) \
                    + progress * int(configuration.get("query_multiplier", 3)),
            }
        var port = context.counter_mutation_port
        if str(configuration.get("mode", "")) == "undeclared":
            port.increment("missing_counter", 1)
            return {"success": true}
        var before: int = port.read(counter_id)
        var non_default_before: bool = port.has_non_default_value(counter_id)
        var incremented: Dictionary = port.increment(
            counter_id, configuration.get("increment_amount", 1))
        if not incremented.get("success", false):
            return incremented
        if str(configuration.get("mode", "")) == "mutation_failure":
            return context.payload["effect_ports"].apply_effects([{
                "op": "missing_counter_test_operation",
            }])
        if str(configuration.get("mode", "")) == "fail":
            return {"success": false, "reason": "Fake 计数器事件失败"}
        return {
            "success": true,
            "before": before,
            "after": int(incremented.get("value", before)),
            "capped": bool(incremented.get("capped", false)),
            "non_default_before": non_default_before,
        }

class BattleLifecycleProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var calls: Array[Dictionary] = []

    func behavior_id() -> String:
        return "battle_lifecycle_probe"

    func supported_hooks() -> Array[String]:
        return [
            "action_preview",
            "battle_start", "round_start", "turn_start",
            "before_normal_draw", "after_normal_draw",
            "action_window_start", "group_end", "action_window_end",
            "turn_end", "battle_end",
        ] as Array[String]

    func validate_configuration(_configuration: Dictionary) -> Array[String]:
        return []

    func battle_timing_bindings(configuration: Dictionary) -> Array:
        return configuration.get("bindings", [])

    func counter_definitions(configuration: Dictionary) -> Array:
        if not configuration.has("persistent_counter"):
            return []
        return [configuration["persistent_counter"]]

    func battle_counter_definitions(configuration: Dictionary) -> Array:
        return configuration.get("battle_counters", [])

    func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
        var battle_event: bool = context is BattlePassiveEventContextScript
        var result := {
            "success": true,
            "hook": hook,
            "owner_id": str(context.owner_id) if battle_event else str(context.owner.owner_id),
            "actor_id": (
                str(context.actor.owner_id) if context.actor != null else ""),
            "timing_serial": context.timing_serial if battle_event else -1,
            "execution_index": context.invocation.execution_index \
                if context.invocation != null else 0,
            "source_instance_key": context.source.source_instance_key \
                if context.source != null else "",
            "drawn_count": context.drawn_cards.size() if battle_event else 0,
            "winner_id": str(context.winner.owner_id) \
                if battle_event and context.winner != null else "",
            "battle_state": str(context.battle_state) \
                if battle_event else "",
            "persistent_mutation_available": (
                context.persistent_counter_mutation_port != null),
            "battle_mutation_available": (
                context.battle_counter_mutation_port != null),
        }
        var persistent = configuration.get("persistent_counter", {})
        if persistent is Dictionary and not persistent.is_empty():
            var counter_id := str(persistent.get("counter_id", ""))
            result["persistent_before"] = (
                context.persistent_counter_read_port.read(counter_id))
            if hook != "action_preview" \
                    and bool(configuration.get("increment_persistent", false)):
                var written: Dictionary = (
                    context.persistent_counter_mutation_port.increment(counter_id, 1))
                result["persistent_after"] = written.get(
                    "value", result["persistent_before"])
        var battle_before: Dictionary = {}
        var battle_after: Dictionary = {}
        var increment_ids: Array = configuration.get(
            "increments_by_hook", {}).get(
                hook, configuration.get("increment_battle_ids", []))
        for definition in configuration.get("battle_counters", []):
            var counter_id := str(definition.get("counter_id", ""))
            battle_before[counter_id] = context.battle_counter_read_port.read(
                counter_id)
            if hook != "action_preview" \
                    and increment_ids.has(counter_id):
                var written: Dictionary = (
                    context.battle_counter_mutation_port.increment(counter_id, 1))
                battle_after[counter_id] = written.get(
                    "value", battle_before[counter_id])
        result["battle_before"] = battle_before
        result["battle_after"] = battle_after
        calls.append(result.duplicate(true))
        if str(configuration.get("fail_hook", "")) == hook \
                and int(configuration.get("fail_execution_index", 0)) \
                    == int(result["execution_index"]):
            return {"success": false, "reason": "Fake 战斗生命周期失败"}
        return result

class InvalidBattleBindingProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    func behavior_id() -> String:
        return "invalid_battle_binding_probe"

    func supported_hooks() -> Array[String]:
        return ["battle_start"] as Array[String]

    func battle_timing_bindings(configuration: Dictionary) -> Array:
        return configuration.get("bindings", [])

    func handle(_hook: String, _context, _configuration: Dictionary) -> Dictionary:
        return {"success": true}

class BattleFineGrainedProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var calls: Array[Dictionary] = []

    func behavior_id() -> String:
        return "battle_fine_grained_probe"

    func supported_hooks() -> Array[String]:
        var result: Array[String] = []
        result.append_array(PassiveRuleHandlerRegistryScript.BATTLE_COMMITTED_EVENT_HOOKS)
        result.append_array(PassiveRuleHandlerRegistryScript.BATTLE_INT_QUERY_HOOKS)
        return result

    func counter_definitions(_configuration: Dictionary) -> Array:
        return [{
            "counter_id": "committed_total", "default_value": 0,
            "minimum": 0, "retention_policy": "run",
        }]

    func battle_counter_definitions(_configuration: Dictionary) -> Array:
        return [{
            "counter_id": "committed_total", "default_value": 0,
            "minimum": 0, "reset_scope": "battle",
        }]

    func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
        if hook in PassiveRuleHandlerRegistryScript.BATTLE_INT_QUERY_HOOKS:
            var current := int(context.payload.get("current_value", 0))
            calls.append({
                "kind": "query", "hook": hook,
                "owner_id": str(context.owner.owner_id),
                "current_value": current,
                "execution_index": int(context.invocation.execution_index),
                "persistent_mutation_available": (
                    context.persistent_counter_mutation_port != null),
                "battle_mutation_available": (
                    context.battle_counter_mutation_port != null),
                "action_token": str(context.payload.get(
                    "int_query").action_token),
            })
            if str(configuration.get("fail_query", "")) == hook \
                    and (
                        not bool(configuration.get("fail_query_on_confirm", false))
                        or str(context.payload.get("int_query").action_token) != ""):
                return {"success": false, "reason": "Fake 战斗查询失败"}
            if bool(configuration.get("mutate_query_state", false)):
                context.owner.defense += 9
                var cards: Array = context.owner.all_zone_cards()
                if not cards.is_empty():
                    cards[0].reshape_enhancement = "query_mutation_probe"
                    cards[0].anomalies["buffs"]["query_mutation_probe"] = 1
                if context.owner.status_system != null:
                    context.owner.status_system.delayed_records.append({
                        "id": "query_mutation_probe",
                    })
                    context.owner.status_system._rng.randi()
            var absolute_values: Dictionary = configuration.get("query_values", {})
            if absolute_values.has(hook):
                return {"success": true, "value": int(absolute_values[hook])}
            return {
                "success": true,
                "value": current + int(configuration.get(
                    "query_deltas", {}).get(hook, 0)),
            }
        var committed_context: bool = (
            context is BattlePassiveCommittedEventContextScript)
        var persistent_before: int = int(context.persistent_counter_read_port.read(
            "committed_total"))
        var battle_before: int = int(context.battle_counter_read_port.read(
            "committed_total"))
        if bool(configuration.get("increment_events", true)):
            context.persistent_counter_mutation_port.increment(
                "committed_total", 1)
            context.battle_counter_mutation_port.increment(
                "committed_total", 1)
        calls.append({
            "kind": "event", "hook": hook,
            "typed_context": committed_context,
            "owner_id": str(context.owner_id),
            "actor_id": str(context.actor.owner_id) if context.actor != null else "",
            "target_id": str(context.target.owner_id) if context.target != null else "",
            "event_token": str(context.event_token),
            "action_token": str(context.action_token),
            "card_instance_id": str(context.card_instance_id),
            "draw_reason": str(context.draw_reason),
            "from_zone": str(context.from_zone),
            "reason": str(context.reason),
            "explicit_discard": bool(context.explicit_discard),
            "normal_play": bool(context.normal_play),
            "requested_amount": int(context.requested_amount),
            "final_amount": int(context.final_amount),
            "defense_lost": int(context.defense_lost),
            "life_lost": int(context.life_lost),
            "true_damage": bool(context.true_damage),
            "synchronized": bool(context.synchronized),
            "effective_amount": int(context.effective_amount),
            "defense_before": int(context.defense_before),
            "defense_after": int(context.defense_after),
            "technique_triggered": bool(context.technique_triggered),
            "action_succeeded": bool(context.action_succeeded),
            "persistent_before": persistent_before,
            "battle_before": battle_before,
            "execution_index": int(context.invocation.execution_index),
        })
        if str(configuration.get("fail_event", "")) == hook \
                and int(configuration.get("fail_execution_index", 0)) \
                    == int(context.invocation.execution_index):
            return {"success": false, "reason": "Fake 已提交事件失败"}
        return {"success": true}

class DirectCardTriggerProbe:
    extends RefCounted

    var target_card
    var calls: Array[Dictionary] = []

    func _init(card_value) -> void:
        target_card = card_value

    func on_qualified_card_trigger(source: Dictionary) -> Dictionary:
        if source.get("source_card") != target_card \
                or str(source.get("source_trigger", "")) != "card_played":
            return {"success": true, "applied": false}
        calls.append({
            "source_card_instance_id": str(
                source.get("source_card_instance_id", "")),
            "source_trigger": str(source.get("source_trigger", "")),
            "action_token": str(source.get("action_token", "")),
            "replay_depth": int(source.get("replay_depth", 0)),
            "trigger_sequence": int(source.get("trigger_sequence", 0)),
        })
        source["holder"].add_defense(2)
        return {"success": true, "applied": true, "defense": 2}

class RunEffectProbeHandler:
    extends RefCounted

    var _operation_ids: Array
    var _fail_on_apply: bool

    func _init(operation_ids_value: Array, fail_on_apply: bool = false) -> void:
        _operation_ids = operation_ids_value.duplicate()
        _fail_on_apply = fail_on_apply

    func operation_ids() -> Array:
        return _operation_ids.duplicate()

    func validate_effect(effect: Dictionary, validator, scope: String) -> void:
        if not effect.get("amount") is int:
            validator.report_error(scope + ".amount", "探针 amount 必须是整数")

    func apply(effect: Dictionary, context) -> Dictionary:
        if _fail_on_apply:
            return {"success": false, "reason": "探针按约定失败"}
        var amount := int(effect["amount"])
        context.growth.experience += amount
        return {
            "success": true,
            "applied": {
                "op": str(effect["op"]),
                "kind": "test_probe",
                "amount": amount,
            },
        }

class CardReshapeProbeHandler:
    extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

    var id: String

    func _init(id_value: String = "probe_add_value") -> void:
        id = id_value

    func behavior_id() -> String:
        return id

    func triggers() -> Array[String]:
        return ["card_contribution"]

    func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
        if not behavior.get("amount") is int:
            validator.report_error(scope + ".amount", "探针 amount 必须是整数")

    func execute(behavior: Dictionary, context) -> Dictionary:
        context.value += int(behavior.get("amount", 0))
        return {"success": true, "value": context.value}

class ConsumableProbeHandler:
    extends RefCounted

    var _operation_ids: Array
    var _fail_on_apply: bool

    func _init(operation_ids_value: Array, fail_on_apply: bool = false) -> void:
        _operation_ids = operation_ids_value.duplicate()
        _fail_on_apply = fail_on_apply

    func operation_ids() -> Array:
        return _operation_ids.duplicate()

    func validate_effect(effect: Dictionary, context, scope: String) -> void:
        if not effect.get("amount") is int:
            context.report_error(scope + ".amount", "探针 amount 必须是整数")

    func apply(effect: Dictionary, context) -> Dictionary:
        if _fail_on_apply:
            return {"success": false, "reason": "探针按约定失败"}
        var amount := int(effect["amount"])
        context.growth.experience += amount
        return {
            "success": true,
            "applied": {
                "op": str(effect["op"]),
                "kind": "consumable_probe",
                "amount": amount,
                "details": ["探针消耗品效果 +%d" % amount],
            },
        }

class BattleWorkingStateMutationProbeHandler:
    extends RefCounted

    func operation_ids() -> Array:
        return ["battle_working_state_mutation"]

    func validate_effect(effect: Dictionary, context, scope: String) -> void:
        if not effect.get("amount") is int:
            context.report_error(scope + ".amount", "探针 amount 必须是整数")

    func apply(_effect: Dictionary, context) -> Dictionary:
        context.growth.learned_inner_skill_ids.append("rollback_inner")
        context.growth.forgotten_inner_skill_count += 1
        context.growth.consumable_use_sequence += 1
        context.growth.last_recallable_consumable_id = "rollback_consumable"
        context.growth.used_unique_consumable_ids.append("rollback_unique")
        context.growth.source_marker_store.write(
            "inner_skill", "rollback:inner:0", "rollback_inner",
            "rollback_marker", "run", "add", 1)
        return {
            "success": true,
            "applied": {
                "op": "battle_working_state_mutation",
                "details": ["修改战斗可提交工作状态"],
            },
        }

class ConsumableOrderProbeHandler:
    extends RefCounted

    var calls: Array[String] = []

    func operation_ids() -> Array:
        return ["transaction_order_a", "transaction_order_b"]

    func validate_effect(_effect: Dictionary, _context, _scope: String) -> void:
        pass

    func apply(effect: Dictionary, context) -> Dictionary:
        var source_key := str(context.metadata.get("source_instance_key", ""))
        calls.append("%s:%s" % [
            "battle" if source_key.begins_with("battle-") else "run",
            str(effect.get("op", "")),
        ])
        return {
            "success": true,
            "applied": {
                "op": str(effect.get("op", "")),
                "details": [str(effect.get("op", ""))],
            },
        }

class NodeInteractionProbeHandler:
    extends RefCounted

    var kind: String
    var effects: Array
    var prepare_calls: int = 0
    var commit_calls: int = 0
    var duplicate_choices: bool = false
    var invalid_configuration: bool = false

    func _init(kind_value: String = "probe_interaction", effects_value: Array = []) -> void:
        kind = kind_value
        effects = effects_value.duplicate(true)

    func interaction_kind() -> String:
        return kind

    func validate_configuration(configuration: Dictionary, validation) -> void:
        if invalid_configuration or bool(configuration.get("invalid", false)):
            validation.report_error(
                "node_content.interaction.configuration",
                "测试交互配置无效")

    func prepare(context) -> Dictionary:
        prepare_calls += 1
        var frozen_roll: int = context.rng.randi_range(1, 1000000)
        var choices: Array = [{
            "id": "accept",
            "label": "接受",
            "description": "应用测试交互",
            "enabled": true,
            "metadata": {"frozen_roll": frozen_roll},
        }, {
            "id": "disabled",
            "label": "不可选",
            "description": "测试禁用项",
            "enabled": false,
            "disabled_reason": "测试选项已禁用",
            "metadata": {},
        }]
        if duplicate_choices:
            choices.append(choices[0].duplicate(true))
        return {
            "success": true,
            "title": "测试交互",
            "description": "冻结一次选择",
            "choices": choices,
            "minimum_choices": 1,
            "maximum_choices": 1,
            "metadata": {"frozen_roll": frozen_roll},
        }

    func commit(
            _context,
            prepared_interaction: Dictionary,
            choice_id: String,
            choice_payload: Dictionary) -> Dictionary:
        commit_calls += 1
        if choice_id != "accept" or not bool(choice_payload.get("confirmed", false)):
            return {"success": false, "reason": "测试提交重新校验失败"}
        return {
            "success": true,
            "effects": effects.duplicate(true),
            "result": {
                "choice_id": choice_id,
                "description": "测试交互已提交",
                "frozen_roll": prepared_interaction.get("metadata", {}).get(
                    "frozen_roll", -1),
            },
        }

class RunContentProbeCatalog:
    extends RefCounted

    var formal_ids := {
        "technique": ["formal_technique"],
        "inner_skill": ["formal_inner_skill"],
        "consumable": ["formal_consumable"],
        "item": ["formal_item"],
    }
    var known_non_formal_ids := {
        "item": ["design_only_item"],
    }

    func has_id(content_type: String, content_id: String) -> bool:
        return formal_ids.get(content_type, []).has(content_id) \
            or known_non_formal_ids.get(content_type, []).has(content_id)

    func is_formally_obtainable(content_type: String, content_id: String) -> bool:
        return formal_ids.get(content_type, []).has(content_id)

class ValueSpecProbeHandler:
    extends RefCounted

    var stable_kind: String

    func _init(kind_value: String = "probe_value") -> void:
        stable_kind = kind_value

    func kind_ids() -> Array[String]:
        return [stable_kind]

    func validate(
            _kind: String, spec: Dictionary, registry,
            report_error: Callable, scope: String) -> bool:
        if registry.is_integer(spec.get("value")):
            return true
        report_error.call(scope + ".value", "必须是整数")
        return false

    func resolve(
            _kind: String, spec: Dictionary, _runtime,
            _resolver, _registry) -> int:
        return int(spec.get("value", 0)) + 1

class TargetQueryProbeHandler:
    extends RefCounted

    var stable_field: String

    func _init(field_value: String = "probe_even_rank") -> void:
        stable_field = field_value

    func field_definitions() -> Dictionary:
        return {stable_field: {"validation": "bool"}}

    func validate(
            _field: String, value, definition: Dictionary, registry,
            report_error: Callable, scope: String) -> bool:
        return registry.validate_value(value, definition, report_error, scope)

    func matches(
            _field: String, value, card, _facts,
            _match_context: Dictionary, _registry) -> bool:
        return (int(card.current_rank_order()) % 2 == 0) == bool(value)

class TargetQueryPortsProbe:
    extends RefCounted

    var effective_values: Dictionary = {}
    var denied_anomaly_card_ids: Dictionary = {}

    func zone_cards(side, zone_id: String) -> Array:
        match zone_id:
            "hand": return side.hand.duplicate()
            "draw_pile": return side.draw_pile.duplicate()
            "staging": return side.staging.duplicate()
            "discard_pile": return side.discard_pile.duplicate()
        return []

    func current_effective_qi(
            _side, card, _context: Dictionary = {}) -> int:
        return int(effective_values.get(
            str(card.id), card.current_base_qi_value()))

    func can_explicit_discard(_side, card) -> Dictionary:
        return {"allowed": not card.has_anomaly("mark", "void")}

    func can_apply_card_anomaly(
            card, _category: String, _anomaly_id: String,
            _replace_state: bool = false) -> Dictionary:
        return {"allowed": not denied_anomaly_card_ids.has(str(card.id))}

var failures: Array[String] = []
var assertions: int = 0
var card_serial: int = 0
var tracked_combat_engines: Array = []

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_content_catalog_and_validator()
    _test_condition_spec_registry_contract()
    _test_value_spec_registry_contract()
    _test_target_query_field_registry_contract()
    _test_passive_rule_registry_and_content_contract()
    _test_card_reshape_behavior_registry()
    _test_enemy_pool_content_and_repository()
    _test_formal_enemy_pool_battle_setup()
    _test_starter_build_assembly_and_composition_root()
    _test_node_reward_service_contract()
    _test_run_effect_platform_contract()
    _test_run_card_workshop_effects()
    _test_awakening_origin_persistence_contract()
    _test_qi_instance_state_contract()
    _test_run_deck_contract()
    _test_card_zone_service_contract()
    _test_battle_flow_coordinator_contract()
    _test_battle_timing_system_contract_and_integration()
    _test_defense_retention_policy_and_round_decay()
    _test_passive_runtime_capacity_suppression_invocations_and_items()
    _test_run_passive_queries_events_and_transactions()
    _test_run_passive_persistent_counters_and_state_ports()
    _test_battle_passive_lifecycle_bridge_and_temporary_counters()
    _test_battle_fine_grained_events_and_int_queries()
    _test_battle_card_policy_ports()
    _test_technique_and_cooperation_permission_wiring()
    _test_unified_passive_effect_execution()
    _test_effect_source_neutrality_runtime_paths()
    _test_awakening_battle_runtime()
    _test_f2d2_formal_enhancement_runtime()
    _test_f2d2_opportunity_freeze_and_progress_sync()
    _test_f2e1_formal_imprint_runtime_and_persistence()
    _test_status_behavior_registry_contract()
    _test_status_system_contract()
    _test_action_controller_boundaries_and_strategy()
    _test_remote_ai_module_contract()
    _test_enemy_candidate_reduction_and_hidden_intents()
    _test_chat_completions_provider_contract()
    _test_ai_settings_and_conversation_disk_contract()
    _test_remote_ai_action_window_session_gate()
    _test_ai_protocol_v3_information_trace_and_report_contract()
    _test_effect_handler_registry_contract()
    _test_effect_extension_entry_contract()
    _test_standard_deck()
    _test_pool_structure_and_turn_draw_rules()
    _test_active_hand_types_and_same_attribute_rules()
    _test_same_qi_rule_and_action_wiring()
    _test_power_calculation()
    _test_damage_resolver_rules_and_facade()
    _test_structured_game_log_channels()
    _test_action_preview_service_matches_engine_facade()
    _test_no_automatic_damage_or_draw()
    _test_representative_damage_draw_discard()
    _test_multi_damage_and_consecutive_chase()
    _test_visible_queue_left_to_right()
    _test_inner_skill_equipment_and_extra_qi_defense()
    _test_inner_skill_preview_and_enemy_plan()
    _test_consumable_shared_slots_and_generation_limit()
    _test_unified_run_and_battle_consumable_order_and_records()
    _test_battle_unique_consumable_and_query_purity()
    _test_battle_consumable_multi_effect_rollback()
    _test_zengyuan_pill_enhancement_and_preview()
    _test_simple_reshape_behaviors()
    _test_battle_consumable_reshape_persists_via_run_deck()
    _test_consumable_effect_registry_contract()
    _test_consumable_effect_validation_scope()
    _test_run_consumable_zengyuan_pill()
    _test_run_consumable_origin_and_save()
    _test_run_consumable_invalid_targets()
    _test_run_consumable_transaction_rollback()
    _test_run_consumable_failed_use_keeps_randomness()
    _test_run_consumable_slot_release_order()
    _test_s2f2f1_formal_pills_and_transactions()
    _test_s2f2f2_formal_curios_and_protocols()
    _test_s2f2f3_practice_shop_packs_items_and_migration()
    _test_run_consumable_phase_gate()
    _test_run_consumable_save_round_trip()
    _test_consumable_no_central_op_branches()
    _test_run_save_life_round_trip_legacy_defaults_and_validation()
    _test_battle_session_commands_snapshots_and_events()
    _test_snapshot_boundaries_are_typed()
    _test_map_generation_is_deterministic_and_constrained()
    _test_map_routes_reach_boss_without_crossing()
    _test_node_dispatcher_is_data_driven_and_deterministic()
    _test_run_state_node_and_practice_gate()
    _test_run_service_boundaries_and_progress_snapshot()
    _test_battle_run_progress_working_state_protocol()
    _test_node_interaction_platform_contract()
    _test_run_session_commands_snapshots_events_and_logs()
    _test_battle_outcome_aggregate_transaction_contract()
    _test_run_terminal_result_contract_and_closure()
    _test_inner_skill_loadout_and_forgetting()
    _test_experience_interest_node_settlement()
    _test_boss_chest_flow()
    _test_layered_life_progression_and_battle_persistence()
    _test_run_state_battle_growth_persistence()
    _test_run_build_query_dto_and_empty_formal_pools()
    _test_run_build_consumable_target_selection_and_cancel()
    _test_run_build_prepared_preview_and_enum_protocol()
    _test_run_build_technique_removals_and_independent_drafts()
    _test_s2f6a_repeated_technique_slot_index_operations()
    _test_run_build_inner_skill_draft_and_forgetting()
    _test_run_build_read_only_layout_and_ui_domain_boundary()
    _test_map_practice_and_battle_scene_integration()
    _test_battle_scene_prefers_injected_session_and_keeps_standalone_fallback()
    _test_front_menu_and_starter_build_flow()
    _test_synchronized_defense_before_damage()
    _test_synchronized_lethal_and_battle_results()
    _release_tracked_mutation_scopes()
    if failures.is_empty():
        print("TEST PASS: %d assertions" % assertions)
        quit(0)
    else:
        for failure in failures:
            push_error("TEST FAIL: %s" % failure)
        print("TEST FAILURES: %d / %d assertions" % [failures.size(), assertions])
        quit(1)

func _tracked_combat_engine(
        game_log_override = null,
        content_catalog_override = null,
        passive_rule_registry_override = null):
    var engine = CombatEngineScript.new(
        game_log_override,
        content_catalog_override,
        passive_rule_registry_override)
    tracked_combat_engines.append(engine)
    return engine

func _release_tracked_mutation_scopes() -> void:
    for engine in tracked_combat_engines:
        if engine == null or engine.battle_mutation_scope_service == null:
            continue
        engine.battle_mutation_scope_service.abort_active(
            "主测试组结束")
        engine.player.use_battle_mutation_scope_service(null)
        engine.enemy.use_battle_mutation_scope_service(null)
        engine.effect_ports.use_mutation_scope_service(null)
        engine.technique_resolution_service.use_mutation_scope_service(null)
        if engine.consumable_service != null:
            engine.consumable_service.use_mutation_scope_service(null)
        engine.battle_mutation_scope_service = null
    tracked_combat_engines.clear()

func _card(rank: String, attribute: String = "wind"):
    card_serial += 1
    var order: int
    match rank:
        "J": order = 11
        "Q": order = 12
        "K": order = 13
        "A": order = 14
        _: order = int(rank)
    var qi: int = 12 if rank == "A" else (11 if rank in ["J", "Q", "K"] else int(rank))
    var attribute_name: String = {"wind": "风", "forest": "林", "fire": "火", "mountain": "山"}[attribute]
    return QiCardScript.new("test_%d" % card_serial, rank, order, qi, attribute, attribute_name)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)

func _contains_object_value(value) -> bool:
    if value is Object:
        return true
    if value is Array:
        for child in value:
            if _contains_object_value(child):
                return true
    elif value is Dictionary:
        for child in value.values():
            if _contains_object_value(child):
                return true
    return false

func _run_build_ui_fixture(
        editable: bool,
        include_techniques: bool) -> RunBuildDTO:
    var names := {
        "high_card": "高牌", "pair": "一对", "two_pair": "两对",
        "three_kind": "三条", "straight": "顺子",
        "full_house": "葫芦", "four_kind": "四条", "five_kind": "五条",
    }
    var hand_loadouts: Array = []
    for hand_id in GrowthInventoryScript.HAND_IDS:
        var sequence: Array = []
        var available: Array = []
        if include_techniques:
            match hand_id:
                "pair":
                    sequence = [{"id": "pair_a", "name": "对子甲", "description": "", "pool": "pair", "status": "formal_complete", "effective_loadout_limit": 1, "equipped_total_count": 1, "eligible": true, "disabled_reason": "已装配 1/1"}]
                    available = [{"id": "pair_b", "name": "对子乙", "description": "", "pool": "pair", "status": "formal_complete", "effective_loadout_limit": 1, "equipped_total_count": 0, "eligible": true, "disabled_reason": ""}]
                "four_kind":
                    sequence = [{"id": "four_base", "name": "四条甲", "description": "", "pool": "bomb", "status": "formal_complete", "effective_loadout_limit": 1, "equipped_total_count": 1, "eligible": true, "disabled_reason": "已装配 1/1"}]
                    available = [{"id": "bomb_shared", "name": "炸弹候选", "description": "", "pool": "bomb", "status": "formal_complete", "effective_loadout_limit": 1, "equipped_total_count": 0, "eligible": true, "disabled_reason": ""}]
                "five_kind":
                    sequence = [{"id": "five_base", "name": "五条甲", "description": "", "pool": "bomb", "status": "formal_complete", "effective_loadout_limit": 1, "equipped_total_count": 1, "eligible": true, "disabled_reason": "已装配 1/1"}]
                    available = [{"id": "bomb_shared", "name": "炸弹候选", "description": "", "pool": "bomb", "status": "formal_complete", "effective_loadout_limit": 1, "equipped_total_count": 0, "eligible": true, "disabled_reason": ""}]
        hand_loadouts.append({
            "hand_id": hand_id,
            "hand_name": names[hand_id],
            "slot_count": 2,
            "sequence": sequence,
            "available_techniques": available,
            "editable": editable,
            "blocked_reason": "节点进行中" if not editable else "",
        })
    return RunBuildDTOScript.new().configure({
        "editable": editable,
        "blocked_reason": "节点进行中" if not editable else "",
        "cards": [
            {
                "instance_id": "card:1", "definition_id": "wind_2",
                "display_name": "风·2", "attribute": "wind",
                "attribute_name": "风", "rank": "2", "rank_order": 2,
                "qi_value": 2, "origin": {}, "origin_name": "",
                "enhancement": "", "enhancement_name": "",
                "imprint": "", "imprint_name": "", "others": {},
                "other_names": [],
            },
        ],
        "consumable_limit": 3,
        "consumables": [
            {"slot_index": 0, "id": "probe_pill", "name": "探针丹", "kind": "pill", "description": "", "status": "formal"},
            {"slot_index": 1, "id": "", "name": "空槽", "kind": "", "description": "", "status": "empty"},
            {"slot_index": 2, "id": "", "name": "空槽", "kind": "", "description": "", "status": "empty"},
        ],
        "items": [],
        "hand_loadouts": hand_loadouts,
        "inner_skill_loadout": {
            "learned": [
                {
                    "id": "inner_a", "name": "内功甲", "total_count": 2,
                    "equipped_count": 1, "unequipped_count": 1,
                    "base_forget_value": 4, "forget_value": 4,
                    "can_forget": true, "status": "formal",
                },
                {
                    "id": "inner_b", "name": "内功乙", "total_count": 1,
                    "equipped_count": 0, "unequipped_count": 1,
                    "base_forget_value": null, "forget_value": null,
                    "can_forget": false, "status": "candidate",
                },
            ],
            "equipped": [{
                "slot_index": 0, "inner_skill_id": "inner_a",
                "name": "内功甲", "occurrence_index": 1,
                "combat_source_order": 0,
            }],
            "equipped_inner_skill_ids": ["inner_a"],
            "technique_slot_index": 1,
            "inner_skill_limit": 6,
            "editable": editable,
            "blocked_reason": "节点进行中" if not editable else "",
        },
        "experience": 9,
    })

func _catalog_definitions(catalog) -> Dictionary:
    var result: Dictionary = {}
    for key in ContentCatalogScript.CONTENT_ORDER:
        result[key] = catalog.definition(key)
    return result

func _array_contains_text(values: Array, wanted: String) -> bool:
    for value in values:
        if str(value).contains(wanted):
            return true
    return false

func _find_opportunity_seed(pattern: Array) -> int:
    var probe := RandomNumberGenerator.new()
    for seed in range(1, 100000):
        probe.seed = seed
        var actual: Array = []
        for _index in range(pattern.size() / 2):
            actual.append(probe.randi_range(1, 5) == 1)
            actual.append(probe.randi_range(1, 10) == 1)
        if actual == pattern:
            return seed
    return -1

func _count_status_changes(history: Array, status_id: String) -> int:
    var count := 0
    for change in history:
        if str(change.get("status_id", "")) == status_id \
                and str(change.get("change_type", "")) == "card_anomaly_apply":
            count += 1
    return count

func _test_card_reshape_behavior_registry() -> void:
    var registry = CardReshapeBehaviorRegistryScript.new()
    var probe = CardReshapeProbeHandler.new()
    _assert_true(registry.register_handler(probe), "测试重塑行为可以注入注册表")
    var invalid_registry = CardReshapeBehaviorRegistryScript.new()
    invalid_registry.register_handler(CardReshapeProbeHandler.new())
    _assert_true(
        not invalid_registry.register_handler(CardReshapeProbeHandler.new()),
        "重复重塑行为 ID 注册失败")
    _assert_true(
        not invalid_registry.register_handler(CardReshapeProbeHandler.new("Bad-ID")),
        "非法重塑行为 ID 注册失败")
    _assert_true(
        not invalid_registry.register_handler(CardReshapeProbeHandler.new("")),
        "空重塑行为 ID 注册失败")

    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, registry)
    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "建立重塑行为测试基线内容目录")
    var values := _catalog_definitions(base_catalog)
    values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "card_contribution",
        "priority": 100,
        "handler": "probe_add_value",
        "amount": 5,
    }]
    _assert_true(
        catalog.load_from_definitions(values, base_catalog.paths),
        "内容定义可以绑定测试重塑行为")
    var probe_card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "probe:wind_7")
    catalog.card_reshape_rules.bind_card(probe_card)
    probe_card.set_enhancement("qi_boost")
    var preview_values := PowerCalculatorScript.calculate(
        HandEvaluatorScript.evaluate([probe_card]))
    _assert_equal(
        preview_values["card_total"], 12,
        "测试重塑 Handler 可以改变真实功法值而不改 PowerCalculator")

    var wild_card = DeckFactoryScript.create_card_instance(
        base_catalog.get_by_id("card", "wind_7"), "reshape:hunyuan")
    base_catalog.card_reshape_rules.bind_card(wild_card)
    wild_card.set_enhancement("hunyuan")
    _assert_true(
        wild_card.is_attribute("wind") and wild_card.is_attribute("fire"),
        "混元通过行为绑定同时识别所有属性")
    var boosted_card = DeckFactoryScript.create_card_instance(
        base_catalog.get_by_id("card", "wind_7"), "reshape:qi_boost")
    base_catalog.card_reshape_rules.bind_card(boosted_card)
    boosted_card.set_enhancement("qi_boost")
    _assert_equal(boosted_card.effective_qi_value(), 15, "增元通过行为绑定增加八点有效真气")
    var momentum_card = DeckFactoryScript.create_card_instance(
        base_catalog.get_by_id("card", "wind_7"), "reshape:momentum")
    base_catalog.card_reshape_rules.bind_card(momentum_card)
    momentum_card.set_enhancement("momentum")
    _assert_equal(momentum_card.reshape_multiplier_bonus(), 1, "乘势通过行为绑定增加一点功法倍率")

    var unknown_values := _catalog_definitions(base_catalog)
    unknown_values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "card_contribution",
        "handler": "missing_reshape_handler",
        "amount": 1,
    }]
    var unknown_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_catalog.load_from_definitions(unknown_values, base_catalog.paths),
        "未知重塑行为处理器在内容加载阶段失败")
    _assert_true(
        _array_contains_text(unknown_catalog.errors, "card_states.enhancements[0].behaviors[0].handler"),
        "未知重塑行为错误报告内容路径")

    var bad_parameter_values := _catalog_definitions(base_catalog)
    bad_parameter_values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "card_contribution",
        "handler": "add_card_contribution",
        "amount": "two",
    }]
    var bad_parameter_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_parameter_catalog.load_from_definitions(
            bad_parameter_values, base_catalog.paths),
        "重塑行为参数错误在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            bad_parameter_catalog.errors,
            "card_states.enhancements[0].behaviors[0].amount"),
        "重塑行为参数错误报告内容路径")

    var missing_priority_values := _catalog_definitions(base_catalog)
    missing_priority_values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "effective_qi",
        "handler": "add_effective_qi",
        "amount": 2,
    }]
    var missing_priority_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_priority_catalog.load_from_definitions(
            missing_priority_values, base_catalog.paths),
        "数值重塑行为缺少 priority 时内容加载失败")
    _assert_true(
        _array_contains_text(
            missing_priority_catalog.errors,
            "card_states.enhancements[0].behaviors[0].priority"),
        "数值优先级错误稳定报告内容路径")

    var unknown_anomaly_values := _catalog_definitions(base_catalog)
    for behavior in unknown_anomaly_values["card_states"]["origins"][2]["behaviors"]:
        if behavior.get("handler", "") == "apply_anomaly":
            behavior["anomaly"] = "missing_anomaly"
    var unknown_anomaly_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_anomaly_catalog.load_from_definitions(
            unknown_anomaly_values, base_catalog.paths),
        "重塑行为引用未知异状时内容加载失败")
    _assert_true(
        _array_contains_text(
            unknown_anomaly_catalog.errors,
            "card_states.origins[2].behaviors[3].anomaly"),
        "重塑异状引用错误稳定报告内容路径")

func _test_condition_spec_registry_contract() -> void:
    var registry = ConditionSpecRegistryScript.new()
    var validation_errors: Array[String] = []
    var report_error := func(scope: String, message: String) -> void:
        validation_errors.append(scope + ":" + message)

    for drift_field in [
            "group_snapshot_flag_value",
            "group_has_no_common_attribute",
            "group_all_active_permanent_reshape"]:
        _assert_true(
            registry.condition_fields().has(drift_field),
            "运行中出现过的漂移字段已进入唯一 ConditionSpec 注册表：%s" % drift_field)

    var first: QiCard = _card("6", "wind")
    var second: QiCard = _card("6", "wind")
    first.reshape_enhancement = "condition_probe"
    second.reshape_imprint = "condition_probe"
    var runtime_context = TechniqueEffectContextScript.new().configure({
        "hand_result": {"id": "pair", "contributing": [first, second]},
        "played_cards": [first, second],
        "actual_hand_id": "pair",
        "group_snapshot": {
            "played_cards": [first, second],
            "common_attributes": [],
            "probe_flag": false,
        },
    })
    var recursive_condition := {
        "all": [
            {"any": [
                {"exact_hand_id": "straight"},
                {"exact_hand_id": "pair"},
            ]},
            {"not": {"group_has_common_attribute": "any"}},
            {
                "group_snapshot_flag": "probe_flag",
                "group_snapshot_flag_value": false,
            },
            {"group_has_no_common_attribute": true},
            {"group_all_active_permanent_reshape": true},
        ],
    }
    _assert_true(
        registry.validate_condition(
            recursive_condition, report_error, "condition_probe"),
        "all/any/not 递归条件由注册表完成结构校验")
    _assert_equal(validation_errors, [], "合法递归条件没有校验错误")
    _assert_true(
        registry.evaluate(recursive_condition, runtime_context),
        "all/any/not 与漂移字段由同一注册表完成运行判断")
    _assert_true(
        not registry.evaluate({"unknown_runtime_field": true}, runtime_context),
        "运行时未知条件字段不会静默视为满足")

    validation_errors.clear()
    _assert_true(
        not registry.validate_condition({
            "all": [{"not": {"unknown_nested_field": true}}],
        }, report_error, "nested_unknown"),
        "递归结构中的未知条件字段被拒绝")
    _assert_true(
        _array_contains_text(validation_errors, "unknown_nested_field"),
        "递归未知字段错误稳定定位到嵌套路径")
    validation_errors.clear()
    _assert_true(
        not registry.validate_condition({
            "capture_count_equals": {"capture": "cards"},
        }, report_error, "bad_shape"),
        "ConditionSpec 注册表校验字段内部结构")
    _assert_true(
        _array_contains_text(validation_errors, "缺少必填字段"),
        "条件内部结构缺字段报告明确错误")

    var repository = TechniqueRepositoryScript.new()
    var technique_condition := {
        "pool": "high",
        "condition": {"attribute": "wind", "minimum": 2},
    }
    _assert_true(
        repository.conditions_met(
            technique_condition,
            {"id": "pair", "contributing": [first, second]}, null, true)["ok"],
        "功法自身属性数量条件由 ConditionSpec 注册表运行")
    technique_condition["condition"]["minimum"] = 3
    _assert_true(
        not repository.conditions_met(
            technique_condition,
            {"id": "pair", "contributing": [first, second]}, null, true)["ok"],
        "功法自身条件不满足时注册表拒绝启动")

    validation_errors.clear()
    var event_filters := {
        "event_actor_is_owner": true,
        "source_kind_in": ["technique", "response"],
        "actual_life_loss_positive": true,
        "owner": "actor",
    }
    _assert_true(
        registry.validate_event_filters(
            event_filters, report_error, "event_filters"),
        "事件 filters 由注册表完成结构校验")
    var event_owner = RefCounted.new()
    var event_opponent = RefCounted.new()
    _assert_true(
        registry.event_matches(event_filters, {
            "actor": event_owner,
            "source_kind": "technique",
            "actual_life_loss": 2,
        }, event_owner, event_opponent, {"actor": event_owner}),
        "同一事件字段定义同时用于运行匹配")
    _assert_true(
        not registry.event_matches(event_filters, {
            "actor": event_opponent,
            "source_kind": "technique",
            "actual_life_loss": 2,
        }, event_owner, event_opponent, {"actor": event_owner}),
        "事件关系筛选在运行时拒绝不匹配事件")
    _assert_true(
        not registry.event_matches(
            {"unknown_event_filter": true}, {}, event_owner),
        "运行时未知事件筛选字段不会静默通过")
    var resolved_capture_filters := registry.resolve_event_filters({
        "source_tokens_from_capture": "block_sources",
        "max_triggers": 1,
    }, {
        "block_sources": [{"source_token": "block-probe"}],
    })
    _assert_equal(
        resolved_capture_filters.get("source_tokens", []),
        ["block-probe"],
        "捕获引用型事件筛选按注册定义解析为运行字段")
    _assert_true(
        not resolved_capture_filters.has("source_tokens_from_capture")
            and registry.event_matches(
                resolved_capture_filters,
                {"source_token": "block-probe"}, event_owner),
        "事件筛选捕获解析与运行匹配不再由 StatusSystem 维护字段分支")
    validation_errors.clear()
    _assert_true(
        not registry.validate_event_filters({
            "source_kind_in": "technique",
            "unknown_event_filter": true,
        }, report_error, "bad_event_filters"),
        "事件 filters 同时拒绝未知字段和错误结构")
    _assert_true(
        _array_contains_text(validation_errors, "未知事件筛选字段")
            and _array_contains_text(validation_errors, "非空字符串数组"),
        "事件 filters 校验错误由注册定义稳定报告")

    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "ConditionSpec 内容探针先载入合法基线")
    var bad_technique_condition_values := _catalog_definitions(base_catalog)
    var basic_index := _content_entry_index(
        bad_technique_condition_values["techniques"]["techniques"],
        "basic_scatter")
    bad_technique_condition_values["techniques"]["techniques"][basic_index]["condition"] = {
        "unknown_technique_condition": true,
    }
    var bad_technique_condition_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_technique_condition_catalog.load_from_definitions(
            bad_technique_condition_values, base_catalog.paths),
        "ContentValidator 校验功法自身 condition")
    _assert_true(
        _array_contains_text(
            bad_technique_condition_catalog.errors,
            "condition.unknown_technique_condition"),
        "功法 condition 未知字段错误稳定定位")

    var bad_effect_condition_values := _catalog_definitions(base_catalog)
    basic_index = _content_entry_index(
        bad_effect_condition_values["techniques"]["techniques"],
        "basic_scatter")
    bad_effect_condition_values["techniques"]["techniques"][basic_index]["effects"][0]["when"] = {
        "all": [{"not": {"unknown_effect_condition": true}}],
    }
    var bad_effect_condition_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_effect_condition_catalog.load_from_definitions(
            bad_effect_condition_values, base_catalog.paths),
        "effect.when 继续使用同一递归 ConditionSpec 校验")
    _assert_true(
        _array_contains_text(
            bad_effect_condition_catalog.errors,
            "unknown_effect_condition"),
        "effect.when 递归未知字段稳定报错")

    var bad_event_filter_values := _catalog_definitions(base_catalog)
    var trigger_patched := false
    for technique in bad_event_filter_values["techniques"]["techniques"]:
        for effect in technique.get("effects", []):
            if effect.get("op", "") != "register_response":
                continue
            effect["filters"]["unknown_event_filter"] = true
            trigger_patched = true
            break
        if trigger_patched:
            break
    _assert_true(trigger_patched, "正式内容中存在动态响应供事件筛选校验探针使用")
    var bad_event_filter_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_event_filter_catalog.load_from_definitions(
            bad_event_filter_values, base_catalog.paths),
        "ContentValidator 通过统一注册表校验事件 filters")
    _assert_true(
        _array_contains_text(
            bad_event_filter_catalog.errors,
            "filters.unknown_event_filter"),
        "事件未知 filters 字段稳定定位")

func _test_value_spec_registry_contract() -> void:
    var registry = ValueSpecRegistryScript.new()
    _assert_equal(
        registry.registration_errors(), [],
        "内建 ValueSpec 处理器没有重复或非法 kind")
    _assert_equal(
        registry.kind_ids().size(), 68,
        "第一批实际 ValueSpec kind 全部迁入处理器注册框架")
    for kind in registry.kind_ids():
        var handler = registry.handler_for_kind(kind)
        _assert_true(
            handler != null and handler.has_method("validate") \
                and handler.has_method("resolve"),
            "ValueSpec kind 同时注册校验与解析处理器：%s" % kind)

    _assert_true(
        registry.register_handler(ValueSpecProbeHandler.new()),
        "新 ValueSpec kind 通过单个处理器同时接入注册、校验和解析")
    _assert_true(
        not registry.register_handler(ValueSpecProbeHandler.new()),
        "ValueSpec 注册表拒绝重复 kind")
    _assert_true(
        not registry.register_handler(ValueSpecProbeHandler.new("Bad-Kind")),
        "ValueSpec 注册表拒绝不稳定 kind ID")

    var validation_errors: Array[String] = []
    var report_error := func(scope: String, message: String) -> void:
        validation_errors.append(scope + ":" + message)
    var condition_registry = ConditionSpecRegistryScript.new()
    var vocabulary := {
        "attribute_ids": ContentValidatorScript.ATTRIBUTE_IDS,
        "anomaly_category_ids": ContentValidatorScript.ANOMALY_CATEGORY_IDS,
        "hand_ids": ContentValidatorScript.HAND_IDS,
    }
    registry.configure_validation(
        vocabulary,
        func(condition: Dictionary, scope: String) -> bool:
            return condition_registry.validate_condition(
                condition, report_error, scope))

    var recursive_spec := {
        "kind": "add",
        "values": [
            {"kind": "constant", "value": 2},
            {"kind": "multiply", "values": [
                3,
                {"kind": "subtract", "left": 10, "right": 4},
            ]},
            {"kind": "max", "values": [
                1,
                {"kind": "conditional", "when": {"actor_alive": true},
                    "then": {"kind": "divide_ceil", "value": 5, "divisor": 2},
                    "else": 0},
            ]},
        ],
    }
    _assert_true(
        registry.validate_amount_spec(
            recursive_spec, report_error, "recursive_value"),
        "add/subtract/multiply/max/conditional 由处理器递归完成结构校验")
    _assert_equal(validation_errors, [], "合法递归 ValueSpec 没有校验错误")
    validation_errors.clear()
    _assert_true(
        not registry.validate_amount_spec(
            {"kind": "unknown_value_kind"}, report_error, "unknown_value"),
        "未注册 ValueSpec kind 在内容校验入口失败")
    _assert_true(
        _array_contains_text(validation_errors, "unknown_value_kind"),
        "未知 ValueSpec kind 返回稳定诊断")

    var actor := BattleSideScript.new("value-actor", "value-actor")
    var target := BattleSideScript.new("value-target", "value-target")
    actor.hand_technique_progression = {
        "high_card": {"sequence": ["source_tech"]},
    }
    actor.source_marker_store.write(
        "technique", "slot-a", "source_tech", "charge",
        "battle", "set", 9)
    actor.source_marker_store.write(
        "technique", "slot-b", "other_source", "charge",
        "battle", "set", 4)
    var runtime = TechniqueEffectContextScript.new().configure({
        "actor": actor,
        "target": target,
        "power": 5,
        "initial_power": 5,
        "slot_instance_id": "slot-a",
        "captures": {
            "results": [{"amount": 4}, {"amount": 7}],
            "event": [{"effective_amount": 6}],
        },
    })
    var resolver = EffectValueResolverScript.new()
    _assert_equal(
        resolver.resolve(recursive_spec, runtime), 23,
        "递归 ValueSpec 组合保持既有运行语义")
    _assert_equal(
        resolver.resolve({
            "kind": "capture_field_sum", "capture": "results", "field": "amount"},
            runtime),
        11,
        "capture 聚合由捕获处理器解析")
    _assert_equal(
        resolver.resolve({"kind": "event_field", "field": "effective_amount"}, runtime),
        6,
        "事件 capture 默认键语义保持")
    _assert_equal(
        resolver.resolve({
            "kind": "source_marker_value", "marker_id": "charge", "scope": "battle"},
            runtime),
        9,
        "来源标识按当前稳定槽位解析")
    _assert_equal(
        resolver.resolve({
            "kind": "equipped_source_marker_sum", "marker_id": "charge",
            "scope": "battle"}, runtime),
        9,
        "装备来源标识聚合保持 content_id 边界")
    _assert_equal(
        resolver.resolve({
            "kind": "power_fraction", "numerator": 1, "denominator": 2}, runtime),
        2,
        "功法值分数继续向下取整")
    _assert_equal(
        resolver.resolve({"kind": "divide_floor", "value": -5, "divisor": 2}, runtime),
        -3,
        "负数除法继续按 floor 取整")
    _assert_equal(
        resolver.resolve({"kind": "divide_ceil", "value": -5, "divisor": 2}, runtime),
        -2,
        "负数除法继续按 ceil 取整")
    _assert_equal(
        resolver.resolve({"kind": "divide_floor", "value": -5, "divisor": 0}, runtime),
        -5,
        "除零保护继续把除数钳制为一")
    _assert_equal(
        registry.resolve({"kind": "probe_value", "value": 8}, runtime, resolver),
        9,
        "动态注册 ValueSpec 处理器直接参与运行解析")

func _test_target_query_field_registry_contract() -> void:
    var registry = TargetQueryFieldRegistryScript.new()
    var expected_fields := [
        "anomalies", "anomaly", "anomaly_any", "anomaly_layers_at_least", "attributes",
        "base_attributes", "can_apply_anomaly", "card_kind", "definition_ids",
        "duplicate_rank", "effective_above_base", "effective_qi_at_least",
        "effective_qi_at_most", "exclude_attributes",
        "exclude_base_attributes", "exclude_base_attributes_from_capture",
        "exclude_rank_orders", "exclude_rank_orders_from_capture",
        "explicit_discard_allowed", "has_active_any_reshape",
        "has_active_permanent_reshape", "has_any_anomaly", "has_any_reshape",
        "has_non_attribute_identity", "has_permanent_reshape", "rank_names",
        "rank_orders", "reshape", "temporarily_transferred", "temporary",
    ]
    expected_fields.sort()
    _assert_equal(
        registry.registration_errors(), [],
        "内建 TargetQuery 字段处理器没有重复或非法注册")
    _assert_equal(
        registry.field_ids(), expected_fields,
        "全部实际 TargetQuery filters 字段迁入唯一注册表")
    for field in registry.field_ids():
        var handler = registry.handler_for_field(field)
        _assert_true(
            handler != null and handler.has_method("validate") \
                and handler.has_method("matches"),
            "TargetQuery 字段同时注册参数校验与运行匹配：%s" % field)

    _assert_true(
        registry.register_handler(TargetQueryProbeHandler.new()),
        "新增 TargetQuery 字段只注册一个处理器即可接入校验和运行")
    _assert_true(
        not registry.register_handler(TargetQueryProbeHandler.new()),
        "TargetQuery 注册表拒绝重复字段")
    _assert_true(
        not registry.register_handler(TargetQueryProbeHandler.new("Bad-Field")),
        "TargetQuery 注册表拒绝不稳定字段 ID")

    var validation_errors: Array[String] = []
    var report_error := func(scope: String, message: String) -> void:
        validation_errors.append(scope + ":" + message)
    _assert_true(
        not registry.validate_filters({
            "rank_orders": ["9"],
            "explicit_discard_allowed": "yes",
            "unknown_query_filter": true,
        }, report_error, "query.filters"),
        "TargetQuery 注册表同时拒绝错误参数与未知筛选字段")
    _assert_true(
        _array_contains_text(validation_errors, "rank_orders[0]") \
            and _array_contains_text(validation_errors, "必须是布尔值") \
            and _array_contains_text(validation_errors, "未知目标查询筛选字段"),
        "TargetQuery 参数与未知字段错误稳定定位")

    var actor := BattleSideScript.new("查询方", "target-query-actor")
    var target := BattleSideScript.new("目标方", "target-query-target")
    var ports := TargetQueryPortsProbe.new()
    var identity_card = _card("7", "wind")
    identity_card.temporary_reshapes["attribute"] = "fire"
    var ranked_card = _card("9", "forest")
    ranked_card.temporary_reshapes["rank"] = {
        "rank_name": "Q", "rank_order": 12, "qi_value": 11,
    }
    var state_card = _card("8", "mountain")
    state_card.set_anomaly("state", "poison")
    state_card.reshape_enhancement = "query_probe"
    var void_card = _card("6", "fire")
    void_card.set_anomaly("mark", "void")
    var safe_fire = _card("4", "fire")
    var temporary_card = _card("5", "forest")
    temporary_card.temporary_card = true
    var tie_first = _card("10", "wind")
    var tie_second = _card("10", "forest")
    var lower = _card("3", "mountain")
    actor.hand = [
        identity_card, ranked_card, state_card, void_card, safe_fire,
        temporary_card, tie_first, tie_second, lower,
    ]
    ports.effective_values[str(ranked_card.id)] = 16
    ports.effective_values[str(tie_first.id)] = 20
    ports.effective_values[str(tie_second.id)] = 20
    ports.effective_values[str(lower.id)] = 10
    ports.denied_anomaly_card_ids[str(safe_fire.id)] = true
    var context = TechniqueEffectContextScript.new().configure({
        "actor": actor,
        "target": target,
        "ports": ports,
        "captures": {
            "frozen_ranks": [{"rank_order": 12}],
            "frozen_attributes": [{"base_attribute": "mountain"}],
        },
    })

    var identity_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {"attributes": ["fire"], "base_attributes": ["wind"]},
    }).resolve(context)
    _assert_equal(
        _ids(identity_result.get("cards", [])), [identity_card.id],
        "有效属性与基础属性由同一字段处理器保持不同语义")

    var rank_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {
            "rank_names": ["Q"], "rank_orders": [12],
            "effective_qi_at_least": 15, "effective_above_base": true,
        },
    }).resolve(context)
    _assert_equal(
        _ids(rank_result.get("cards", [])), [ranked_card.id],
        "临时牌阶与有效真气筛选使用注册字段运行")

    var state_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {
            "anomaly": {"category": "state", "id": "poison"},
            "reshape": {"category": "enhancement", "id": "query_probe"},
            "has_any_anomaly": true,
            "has_active_permanent_reshape": true,
        },
    }).resolve(context)
    _assert_equal(
        _ids(state_result.get("cards", [])), [state_card.id],
        "异状与重塑筛选的校验和运行来自同一处理器")

    var temporary_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {"temporary": true},
    }).resolve(context)
    _assert_equal(
        _ids(temporary_result.get("cards", [])), [temporary_card.id],
        "临时真气筛选保持原语义")

    var discard_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {
            "base_attributes": ["fire"],
            "explicit_discard_allowed": true,
        },
    }).resolve(context)
    _assert_equal(
        _ids(discard_result.get("cards", [])), [safe_fire.id],
        "明确弃置权限筛选排除虚无真气")

    var anomaly_permission_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {
            "base_attributes": ["fire"],
            "can_apply_anomaly": {"category": "state", "id": "poison"},
        },
    }).resolve(context)
    _assert_equal(
        _ids(anomaly_permission_result.get("cards", [])), [void_card.id],
        "异状施加权限继续通过运行端口筛选")

    var capture_exclusion_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {
            "exclude_rank_orders_from_capture": "frozen_ranks",
            "exclude_base_attributes_from_capture": "frozen_attributes",
        },
    }).resolve(context)
    _assert_true(
        not _ids(capture_exclusion_result.get("cards", [])).has(ranked_card.id) \
            and not _ids(capture_exclusion_result.get("cards", [])).has(state_card.id) \
            and _ids(capture_exclusion_result.get("cards", [])).has(safe_fire.id),
        "capture 排除字段直接由注册处理器运行，不再由牌区处理器改写")

    actor.hand = [tie_first, tie_second, lower]
    var stable_ties: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand",
        "order": "highest_effective_qi", "limit": 2, "filters": {},
    }).resolve(context)
    _assert_equal(
        _ids(stable_ties.get("cards", [])), [tie_second.id, tie_first.id],
        "非随机并列继续按原牌区位置确定性逆序")

    var tie_rng_a := RandomNumberGenerator.new()
    tie_rng_a.seed = 72341
    var tie_rng_b := RandomNumberGenerator.new()
    tie_rng_b.seed = 72341
    var random_ties_a: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand",
        "order": "highest_effective_qi_random_ties", "limit": 2,
        "filters": {},
    }).resolve(context, tie_rng_a)
    var random_ties_b: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand",
        "order": "highest_effective_qi_random_ties", "limit": 2,
        "filters": {},
    }).resolve(context, tie_rng_b)
    _assert_equal(
        _ids(random_ties_a.get("cards", [])),
        _ids(random_ties_b.get("cards", [])),
        "随机并列在相同种子下保持确定性")
    _assert_true(
        _ids(random_ties_a.get("cards", [])).has(tie_first.id) \
            and _ids(random_ties_a.get("cards", [])).has(tie_second.id),
        "随机并列只打乱同值组且 limit 保持原语义")

    var random_rng_a := RandomNumberGenerator.new()
    random_rng_a.seed = 72342
    var random_rng_b := RandomNumberGenerator.new()
    random_rng_b.seed = 72342
    var random_a: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "random",
        "limit": -1, "filters": {},
    }).resolve(context, random_rng_a)
    var random_b: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "random",
        "limit": -1, "filters": {},
    }).resolve(context, random_rng_b)
    _assert_equal(
        _ids(random_a.get("cards", [])), _ids(random_b.get("cards", [])),
        "普通随机查询在相同种子下保持确定性")

    var dynamic_registry = TargetQueryFieldRegistryScript.new()
    _assert_true(
        dynamic_registry.register_handler(TargetQueryProbeHandler.new()),
        "独立注册表可接入动态字段处理器")
    actor.hand = [safe_fire, temporary_card]
    var dynamic_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {"probe_even_rank": true},
        "target_query_field_registry": dynamic_registry,
    }).resolve(context)
    _assert_equal(
        _ids(dynamic_result.get("cards", [])), [safe_fire.id],
        "动态字段的一次注册同时驱动查询校验与 matches")

    var unknown_runtime: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand", "order": "zone", "limit": -1,
        "filters": {"unknown_runtime_filter": true},
    }).resolve(context)
    _assert_true(
        not unknown_runtime.get("success", true),
        "运行入口同样拒绝未注册 TargetQuery 字段")

    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "TargetQuery 内容探针先载入合法基线")
    var bad_values := _catalog_definitions(base_catalog)
    var query_patched := false
    for technique in bad_values["techniques"]["techniques"]:
        for effect in technique.get("effects", []):
            if not effect.get("query") is Dictionary:
                continue
            var filters: Dictionary = effect["query"].get("filters", {}).duplicate(true)
            filters["unknown_content_filter"] = true
            effect["query"]["filters"] = filters
            query_patched = true
            break
        if query_patched:
            break
    _assert_true(query_patched, "正式内容中存在 TargetQuery 供未知字段探针使用")
    var bad_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_catalog.load_from_definitions(bad_values, base_catalog.paths),
        "未注册 TargetQuery 字段在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            bad_catalog.errors, "filters.unknown_content_filter"),
        "内容校验稳定定位未知 TargetQuery 字段")

func _test_passive_rule_registry_and_content_contract() -> void:
    var invalid_registry = PassiveRuleHandlerRegistryScript.new(false)
    _assert_true(
        not invalid_registry.register_handler(PassiveCapacityProbeHandler.new("")),
        "空 behavior ID 注册失败")
    _assert_true(
        not invalid_registry.register_handler(PassiveCapacityProbeHandler.new("Bad-ID")),
        "非法 behavior ID 注册失败")
    _assert_true(
        invalid_registry.register_handler(PassiveCapacityProbeHandler.new()),
        "合法 Fake Handler 可以注入")
    _assert_true(
        not invalid_registry.register_handler(PassiveCapacityProbeHandler.new()),
        "重复 behavior ID 注册失败")

    var registry = PassiveRuleHandlerRegistryScript.new()
    _assert_true(registry.register_handler(PassiveCapacityProbeHandler.new()), "注册容量查询 Fake Handler")
    _assert_true(registry.register_handler(PassiveStateProbeHandler.new()), "注册事件 Fake Handler")
    _assert_true(registry.register_handler(PassiveRepeatProbeHandler.new()), "注册重复规划 Fake Handler")
    var base_catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(base_catalog.load_all(), "建立被动规则内容测试基线")
    var values := _catalog_definitions(base_catalog)
    values["inner_skills"]["inner_skills"].append_array([
        {
            "id": "state_inner", "name": "状态探针内功", "status": "candidate",
            "description": "测试事件 invocation。",
            "behaviors": [{"id": "state_probe", "configuration": {}}],
        },
        {
            "id": "capacity_inner", "name": "容量探针内功", "status": "candidate",
            "description": "测试 proposed 配装容量。",
            "behaviors": [{"id": "capacity_probe", "configuration": {"amount": 1}}],
        },
        {
            "id": "behaviorless_candidate", "name": "无行为候选", "status": "candidate",
            "description": "候选内容允许暂不接行为。",
        },
    ])
    values["items"]["items"].append_array([
        {
            "id": "capacity_item", "name": "容量物品探针", "kind": "item",
            "status": "candidate", "unique": true, "description": "测试物品容量查询。",
            "behaviors": [{"id": "capacity_probe", "configuration": {"amount": 1}}],
        },
        {
            "id": "repeat_item", "name": "重复物品探针", "kind": "item",
            "status": "candidate", "unique": true, "description": "测试 invocation 规划。",
            "behaviors": [{
                "id": "repeat_probe",
                "configuration": {"target_content_id": "state_inner"},
            }],
        },
    ])
    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        catalog.load_from_definitions(values, base_catalog.paths),
        "内功与物品 behaviors 由同一 Registry 校验")
    var runtime = PassiveRuleRuntimeScript.new(registry, catalog)
    _assert_true(
        catalog.passive_rule_registry == registry and runtime.registry == registry,
        "内容校验与运行时复用同一个 Registry 实例")
    _assert_equal(catalog.definition("inner_skills")["version"], 2, "内功内容协议为 version 2")
    _assert_equal(catalog.definition("items")["version"], 2, "物品内容协议为 version 2")
    _assert_true(
        catalog.get_by_id("inner_skill", "behaviorless_candidate").get("behaviors", []).is_empty(),
        "candidate 可以暂时没有 behavior")

    var unknown_values := values.duplicate(true)
    unknown_values["inner_skills"]["inner_skills"][0]["behaviors"][0]["id"] = "missing_passive"
    var unknown_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not unknown_catalog.load_from_definitions(unknown_values, base_catalog.paths),
        "未注册 behavior 在内容加载阶段失败")
    var invalid_configuration := values.duplicate(true)
    invalid_configuration["inner_skills"]["inner_skills"][0]["behaviors"][0]["configuration"] = {"effects": []}
    var invalid_configuration_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not invalid_configuration_catalog.load_from_definitions(
            invalid_configuration, base_catalog.paths),
        "非法 behavior configuration 在内容加载阶段失败")
    var formal_inner_missing := values.duplicate(true)
    formal_inner_missing["inner_skills"]["inner_skills"].append({
        "id": "formal_without_behavior", "name": "缺行为正式内功",
        "status": "formal", "description": "非法探针", "forget_value": 1,
    })
    var formal_inner_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not formal_inner_catalog.load_from_definitions(formal_inner_missing, base_catalog.paths),
        "正式内功缺少 behavior 加载失败")
    var formal_item_missing := values.duplicate(true)
    formal_item_missing["items"]["items"].append({
        "id": "formal_item_without_behavior", "name": "缺行为正式物品",
        "kind": "item", "status": "formal", "unique": true,
        "description": "非法探针", "price": 1,
    })
    var formal_item_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not formal_item_catalog.load_from_definitions(formal_item_missing, base_catalog.paths),
        "正式物品缺少 behavior 加载失败")
    var legacy_values := values.duplicate(true)
    legacy_values["inner_skills"]["inner_skills"][0]["timing"] = "on_play_resolve"
    legacy_values["inner_skills"]["inner_skills"][0]["effects"] = [{"op": "defense", "amount": 1}]
    var legacy_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not legacy_catalog.load_from_definitions(legacy_values, base_catalog.paths),
        "旧顶层 timing/effects 被拒绝")
    var duplicate_behavior := values.duplicate(true)
    duplicate_behavior["inner_skills"]["inner_skills"][0]["behaviors"].append(
        duplicate_behavior["inner_skills"]["inner_skills"][0]["behaviors"][0].duplicate(true))
    var duplicate_behavior_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not duplicate_behavior_catalog.load_from_definitions(
            duplicate_behavior, base_catalog.paths),
        "同一内容重复声明 behavior ID 加载失败")

    var resolver_source := FileAccess.get_file_as_string("res://core/action_resolver.gd")
    var preview_source := FileAccess.get_file_as_string("res://core/action_preview_service.gd")
    _assert_true(
        not resolver_source.contains("inner_skill_repository")
        and not resolver_source.contains("get(\"timing\""),
        "ActionResolver 不再读取内功仓库或解释旧 timing 字段")
    _assert_true(
        not preview_source.contains("inner_skill_repository")
        and not preview_source.contains("get(\"behaviors\""),
        "ActionPreviewService 不直接解释内功 behavior")

func _test_passive_runtime_capacity_suppression_invocations_and_items() -> void:
    var registry = PassiveRuleHandlerRegistryScript.new()
    registry.register_handler(PassiveCapacityProbeHandler.new())
    registry.register_handler(PassiveStateProbeHandler.new())
    registry.register_handler(PassiveRepeatProbeHandler.new())
    var base_catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(base_catalog.load_all(), "建立被动 Runtime 测试基线")
    var values := _catalog_definitions(base_catalog)
    values["inner_skills"]["inner_skills"].append_array([
        {
            "id": "state_inner", "name": "状态探针内功", "status": "candidate",
            "description": "测试事件 invocation。",
            "behaviors": [{"id": "state_probe", "configuration": {}}],
        },
        {
            "id": "capacity_inner", "name": "容量探针内功", "status": "candidate",
            "description": "测试 proposed 配装容量。",
            "behaviors": [{"id": "capacity_probe", "configuration": {"amount": 1}}],
        },
    ])
    values["items"]["items"].append_array([
        {
            "id": "capacity_item", "name": "容量物品探针", "kind": "item",
            "status": "candidate", "unique": true, "description": "测试容量。",
            "behaviors": [{"id": "capacity_probe", "configuration": {"amount": 1}}],
        },
        {
            "id": "repeat_item", "name": "重复物品探针", "kind": "item",
            "status": "candidate", "unique": true, "description": "测试额外执行。",
            "behaviors": [{"id": "repeat_probe", "configuration": {"target_content_id": "state_inner"}}],
        },
    ])
    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(catalog.load_from_definitions(values, base_catalog.paths), "Fake 被动测试内容通过校验")
    var runtime = PassiveRuleRuntimeScript.new(registry, catalog)

    var growth = GrowthInventoryScript.new(catalog, false)
    var inner_repository = InnerSkillRepositoryScript.new()
    inner_repository.configure(catalog.definition("inner_skills"))
    growth.learned_inner_skill_ids.assign([
        "state_inner", "state_inner", "state_inner", "state_inner",
        "state_inner", "state_inner", "state_inner", "capacity_inner"])
    var loadout = InnerSkillLoadoutServiceScript.new(
        growth, inner_repository, null, runtime)
    var base_capacity: Dictionary = runtime.resolve_inner_skill_capacity(growth, [])
    _assert_equal(base_capacity["base_capacity"], 6, "动态容量唯一基础值为六")
    _assert_equal(base_capacity["effective_capacity"], 6, "无修正时有效容量为六")
    var seven_state := [
        "state_inner", "state_inner", "state_inner", "state_inner",
        "state_inner", "state_inner", "state_inner"]
    var rejected: Dictionary = loadout.set_loadout(seven_state, 7)
    _assert_true(not rejected["success"], "默认七门配装失败")
    _assert_equal(growth.equipped_inner_skill_ids, [], "容量不足不自动装备或截断")
    _assert_equal(growth.technique_slot_index, 0, "容量失败不移动功法位置")
    growth.item_ids.append("capacity_item")
    var item_capacity: Dictionary = runtime.resolve_inner_skill_capacity(growth, seven_state)
    _assert_equal(item_capacity["effective_capacity"], 7, "Fake Item +1 后有效容量为七")
    _assert_true(loadout.set_loadout(seven_state, 7)["success"], "Fake Item +1 后可装备七门")
    growth.item_ids.clear()
    var proposed := [
        "capacity_inner", "state_inner", "state_inner", "state_inner",
        "state_inner", "state_inner", "state_inner"]
    _assert_true(
        loadout.set_loadout(proposed, 1)["success"],
        "proposed loadout 中占一格且容量 +1 的内功参与查询")
    var before_query := JSON.stringify(growth.to_progress_snapshot().to_dict())
    var first_query := runtime.resolve_inner_skill_capacity(growth, proposed)
    var second_query := runtime.resolve_inner_skill_capacity(growth, proposed)
    _assert_equal(first_query, second_query, "相同容量查询输入返回相同结果")
    _assert_equal(
        JSON.stringify(growth.to_progress_snapshot().to_dict()), before_query,
        "容量纯查询不修改本局状态")
    var dto: Dictionary = loadout.get_loadout().to_dict()
    _assert_equal(dto["base_inner_skill_capacity"], 6, "DTO 公开基础容量")
    _assert_equal(dto["effective_inner_skill_capacity"], 7, "DTO 公开有效容量")
    _assert_equal(dto["inner_skill_limit"], 7, "兼容字段映射当前有效容量")

    var actor = BattleSideScript.new("探针", "probe")
    actor.use_passive_rule_runtime(runtime)
    _assert_true(actor.configure_items(["repeat_item"])["success"], "物品独立装配到被动来源")
    _assert_true(
        actor.configure_inner_skills(["state_inner", "state_inner"], 1)["success"],
        "同 ID 两个副本分别装备")
    var frozen_battle_sources := runtime.capture_source_snapshot({"owner": actor})
    _assert_true(actor.configure_items([])["success"], "战斗工作状态可以实时移除物品来源")
    _assert_equal(
        runtime.build_execution_plan(
            "action_resolve", {"actor": actor}).invocations.size(),
        2,
        "后续尚未开始的战斗事件读取移除后的最新来源")
    _assert_equal(
        runtime.build_execution_plan("action_resolve", {
            "actor": actor,
            "source_snapshot": frozen_battle_sources,
        }).invocations.size(),
        4,
        "已捕获的战斗事件来源快照不因工作状态变化而改变")
    _assert_true(actor.configure_items(["repeat_item"])["success"], "恢复后续战斗事件来源")
    var dispatch: Dictionary = runtime.dispatch_event("action_resolve", {
        "actor": actor,
        "payload": {"direct_runtime_probe": true},
    })
    _assert_true(dispatch["success"], "重复 invocation 执行成功")
    _assert_equal(dispatch["results"].size(), 4, "两个副本各由 Fake Repeat Provider 连续执行两次")
    _assert_equal(actor.defense, 15, "后续 invocation 读取前次执行后的最新防御状态")
    _assert_equal(
        dispatch["plan"].invocations[0].source.source_instance_key,
        dispatch["plan"].invocations[1].source.source_instance_key,
        "同 source 的两次 invocation 相邻")
    _assert_true(
        dispatch["plan"].invocations[0].source.source_instance_key
        != dispatch["plan"].invocations[2].source.source_instance_key,
        "同 ID 多副本是两个不同 source")
    _assert_equal(
        dispatch["plan"].invocations[0].execution_count, 2,
        "额外执行不会递归放大自身，单 source 固定两次")
    actor.defense = 0
    var preview_dispatch: Dictionary = runtime.dispatch_event("action_preview", {"actor": actor})
    var preview_defense := 0
    for entry in preview_dispatch["results"]:
        preview_defense += int(entry["result"].get("intent", {}).get("defense", 0))
    _assert_equal(preview_defense, 4, "预览使用与实际相同的 execution count")
    _assert_equal(actor.defense, 0, "预览纯查询不执行正式效果")

    var first_key := "inner:probe:0:state_inner"
    _assert_true(runtime.suppression_service.apply({
        "suppression_id": "single-copy",
        "target_instance_key": first_key,
        "blocked_hooks": ["action_preview", "action_resolve"],
        "reason": "单副本封功",
        "source_id": "test",
    })["success"], "压制可精确选择一个副本")
    var suppressed_plan = runtime.build_execution_plan("action_resolve", {"actor": actor})
    _assert_equal(suppressed_plan.invocations.size(), 2, "被压制副本即使有重复修正也生成零次 invocation")
    _assert_equal(actor.equipped_inner_skill_ids.size(), 2, "压制不删除或卸下内功")
    runtime.suppression_service.remove("single-copy")
    _assert_equal(
        runtime.build_execution_plan("action_resolve", {"actor": actor}).invocations.size(), 4,
        "压制移除后来源自然恢复触发")
    runtime.suppression_service.apply({
        "suppression_id": "all-copies",
        "target_source_kind": "inner_skill",
        "target_content_id": "state_inner",
        "blocked_hooks": ["action_resolve"],
        "reason": "同 ID 全副本封功",
        "expiry": {"through_round": 1},
    })
    _assert_equal(
        runtime.build_execution_plan("action_resolve", {"actor": actor, "round_number": 1}).invocations.size(),
        0,
        "同 ID 全副本压制与单副本选择器语义不同")
    _assert_equal(
        runtime.build_execution_plan("action_resolve", {"actor": actor, "round_number": 2}).invocations.size(),
        4,
        "压制到期自动失效")
    var delayed_probe := [{"source": "already-built"}]
    runtime.suppression_service.apply({
        "suppression_id": "late-suppression",
        "target_source_kind": "inner_skill",
        "blocked_hooks": [],
        "reason": "后续封功",
    })
    _assert_equal(delayed_probe.size(), 1, "之后施加压制不撤销已进入其他系统的延迟效果")
    runtime.suppression_service.clear()

    var engine = _tracked_combat_engine(null, catalog, registry)
    engine.setup(2308, false)
    engine.player.configure_items(["repeat_item"])
    engine.player.configure_inner_skills(["state_inner", "state_inner"], 1)
    engine.apply_passive_suppression({
        "suppression_id": "snapshot-copy",
        "target_instance_key": "inner:player:0:state_inner",
        "blocked_hooks": ["action_preview", "action_resolve"],
        "reason": "快照封功",
    })
    var battle_session = BattleSessionScript.new(engine, RuntimeProfileScript.test())
    var side_snapshot = battle_session.snapshot().player
    _assert_true(not side_snapshot.equipped_inner_skills[0]["active"], "快照区分已装备但失效的副本")
    _assert_equal(side_snapshot.equipped_inner_skills[0]["inactive_reason"], "快照封功", "快照公开具体失效原因")
    _assert_equal(side_snapshot.equipped_inner_skills[0]["execution_count_preview"], 0, "失效副本预览执行次数为零")
    _assert_equal(side_snapshot.equipped_inner_skills[1]["execution_count_preview"], 2, "未失效副本保留重复预览次数")

    var setup_service = BattleSetupServiceScript.new(catalog)
    var progress = RunProgressSnapshotScript.from_dict({
        "item_ids": ["capacity_item"],
        "equipped_inner_skill_ids": seven_state,
        "technique_slot_index": 7,
    })
    var progress_side = BattleSideScript.new("进度", "progress")
    progress_side.use_passive_rule_runtime(runtime)
    _assert_true(
        setup_service.apply_non_deck_progress(progress_side, progress)["success"],
        "item IDs 先进入战斗并为七门玩家配装提供容量")
    _assert_equal(progress_side.item_ids, ["capacity_item"], "item IDs 不进入内功或消耗品栏")
    _assert_equal(progress_side.consumable_ids, [], "物品与 consumable IDs 保持独立")
    var run_deck = setup_service.run_deck_from_progress(null)
    var captured = setup_service.capture_progress(progress_side, run_deck)
    _assert_equal(captured.item_ids, ["capacity_item"], "战后 item IDs 原样回传本局快照")
    var duplicate_items = RunProgressSnapshotScript.from_dict({
        "item_ids": ["capacity_item", "capacity_item"],
    })
    _assert_true(
        not setup_service.apply_non_deck_progress(progress_side, duplicate_items)["success"],
        "重复 item ID 明确失败")
    _assert_equal(progress_side.item_ids, ["capacity_item"], "重复物品失败保持原物品装配")
    var legacy_side = BattleSideScript.new("旧快照", "legacy")
    legacy_side.use_passive_rule_runtime(runtime)
    _assert_true(
        setup_service.apply_non_deck_progress(
            legacy_side, RunProgressSnapshotScript.from_dict({}))["success"],
        "旧快照缺少 item IDs 兼容为空")

func _test_run_passive_queries_events_and_transactions() -> void:
    var registry = PassiveRuleHandlerRegistryScript.new()
    var probe_handler = RunPassiveProbeHandler.new()
    _assert_true(registry.register_handler(probe_handler), "注册本局查询与事件 Fake Handler")
    _assert_true(
        registry.register_handler(PassiveRepeatProbeHandler.new()),
        "本局查询复用额外 Invocation Fake Handler")
    for hook in [
            "practice_price_query", "inner_skill_forget_value_query",
            "meditation_cost_query", "pack_offer_count_query",
            "pack_choose_count_query", "practice_opened",
            "practice_purchase_committed", "practice_pack_opened",
            "meditation_committed", "inner_skill_forgotten",
            "battle_completed", "node_completed"]:
        _assert_true(registry.has_hook(hook), "Registry 登记稳定 Hook %s" % hook)

    var base_catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(base_catalog.load_all(), "建立 F5B 内容测试基线")
    var values := _catalog_definitions(base_catalog)
    values["items"]["items"].append_array([
        {
            "id": "run_policy_probe", "name": "本局策略探针",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "测试本局查询与事件。", "price": 9,
            "behaviors": [{
                "id": "run_passive_probe",
                "configuration": {
                    "target_id": "zengyuan_pill", "price_delta": -3,
                    "forget_delta": 3, "meditation_delta": -5,
                    "offer_delta": 1, "choose_delta": 1,
                },
            }],
        },
        {
            "id": "self_price_probe", "name": "自身价格探针",
            "kind": "item", "status": "formal", "unique": true,
            "description": "未持有时不能修改自己的价格。", "price": 9,
            "behaviors": [{
                "id": "run_passive_probe",
                "configuration": {"target_id": "self_price_probe", "price_delta": -9},
            }],
        },
        {
            "id": "event_source_granter", "name": "事件来源授予探针",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "事件执行中增加来源，验证当前计划固定。", "price": 1,
            "behaviors": [{
                "id": "run_passive_probe",
                "configuration": {
                    "grant_item_id": "self_price_probe",
                    "grant_hook": "battle_completed",
                },
            }],
        },
        {
            "id": "reward_source_probe", "name": "奖励来源探针",
            "kind": "item", "status": "formal", "unique": true,
            "description": "验证奖励来源不追溯触发自身事件。", "price": 1,
            "behaviors": [{
                "id": "run_passive_probe",
                "configuration": {},
            }],
        },
        {
            "id": "event_failure_probe", "name": "事件失败探针",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "先修改工作副本再失败。", "price": 1,
            "behaviors": [{
                "id": "run_passive_probe",
                "configuration": {
                    "event_experience": 4,
                    "fail_hook": "practice_purchase_committed",
                },
            }],
        },
        {
            "id": "forget_query_failure_probe", "name": "遗忘查询失败探针",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "遗忘查询失败时保持事务不变。", "price": 1,
            "behaviors": [{
                "id": "run_passive_probe",
                "configuration": {"fail_hook": "inner_skill_forget_value_query"},
            }],
        },
        {
            "id": "run_repeat_probe", "name": "本局重复探针",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "额外执行目标来源一次。", "price": 1,
            "behaviors": [{
                "id": "repeat_probe",
                "configuration": {"target_content_id": "run_policy_probe"},
            }],
        },
    ])
    values["inner_skills"]["inner_skills"].append({
        "id": "forget_policy_fixture", "name": "统一遗忘测试内功",
        "status": "formal", "description": "测试遗忘查询。", "forget_value": 7,
        "behaviors": [{
            "id": "on_play_effects",
            "configuration": {"effects": [{
                "op": "defense",
                "amount": {"kind": "constant", "value": 1},
            }]},
        }],
    })
    values["practice_shop"]["items"]["candidate_ids"].append_array([
        "self_price_probe", "reward_source_probe",
    ])
    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        catalog.load_from_definitions(values, base_catalog.paths),
        "F5B Fake 内容通过共享 Registry 校验：%s" % "；".join(
            catalog.errors))
    var runtime = PassiveRuleRuntimeScript.new(registry, catalog)
    var int_resolver = PassiveIntPolicyResolverScript.new(runtime)
    var mutation_service = RunMutationServiceScript.new(
        RunEffectHandlerRegistryScript.new(), catalog)
    var event_service = RunPassiveEventServiceScript.new(
        runtime, mutation_service)

    var growth = GrowthInventoryScript.new(catalog, false)
    growth.experience = 20
    growth.item_ids.assign(["run_policy_probe"])
    growth.practice_shop_state = {
        "shop_index": 1, "act": 1,
        "normal": [{
            "id": "zengyuan_pill", "kind": "consumable", "price": 3,
        }],
        "packs": [], "items": [],
        "meditation_count": 0, "next_meditation_cost": 5,
        "pack_open_sequence": 0,
    }
    var event_state = RunStateScript.new(null, growth)
    var practice = PracticeServiceScript.new(catalog)
    practice.use_passive_services(int_resolver, event_service, event_state)
    var state_before_queries := growth.capture_mutation_state()
    var first_price: Dictionary = practice.resolve_price(
        growth, "consumable", "zengyuan_pill", 3)
    var second_price: Dictionary = practice.resolve_price(
        growth, "consumable", "zengyuan_pill", 3)
    _assert_equal(first_price, second_price, "相同价格查询重复执行结果完全相同")
    _assert_equal(first_price.get("effective_price"), 0, "Fake Handler 可把有效价格改为零")
    _assert_equal(
        growth.capture_mutation_state(), state_before_queries,
        "价格查询不修改成长、商店或随机序号")
    var free_purchase := practice.purchase(
        growth, "normal", 0, true, {"run_seed": 41, "act": 1})
    _assert_true(free_purchase.get("success", false), "有效价格为零时正式购买成功")
    _assert_equal(free_purchase.get("base_price"), 3, "购买保留基础价格")
    _assert_equal(free_purchase.get("effective_price"), 0, "展示与提交共用零元有效价格")
    _assert_equal(growth.experience, 20, "免费购买不扣历练")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "practice_purchase_committed").size(),
        1,
        "成功购买只触发一次 practice_purchase_committed")

    var self_growth = GrowthInventoryScript.new(catalog, false)
    self_growth.experience = 20
    self_growth.practice_shop_state = {
        "shop_index": 2, "normal": [], "packs": [],
        "items": [{
            "id": "self_price_probe", "kind": "item", "price": 9,
        }],
    }
    var self_state = RunStateScript.new(null, self_growth)
    practice.use_passive_services(int_resolver, event_service, self_state)
    var self_purchase := practice.purchase(
        self_growth, "items", 0, true, {"run_seed": 41, "act": 1})
    _assert_true(self_purchase.get("success", false), "未持有物品可以正常购买")
    _assert_equal(self_purchase.get("effective_price"), 9, "新买物品不能修改自己的购买价格")
    _assert_equal(self_growth.experience, 11, "自身价格未生效时按基础价格扣费")
    _assert_equal(
        self_purchase.get("passive_event", {}).get("results", []).size(),
        0,
        "新买物品不追溯成为本次购买事件来源")

    var repository = InnerSkillRepositoryScript.new()
    repository.configure(catalog.definition("inner_skills"))
    growth.learned_inner_skill_ids.assign([
        "forget_policy_fixture", "forget_policy_fixture"])
    growth.equipped_inner_skill_ids.assign(["forget_policy_fixture"])
    practice.use_passive_services(int_resolver, event_service, event_state)
    var loadout = InnerSkillLoadoutServiceScript.new(
        growth, repository, null, runtime)
    loadout.use_passive_services(
        runtime, int_resolver, event_service, event_state)
    var forget_display := loadout.query_forget_value("forget_policy_fixture")
    var forget_commit := loadout.forget_inner_skill(
        "forget_policy_fixture", {"run_seed": 41, "act": 1})
    _assert_equal(forget_display.get("forget_value"), 10, "遗忘展示经过统一查询链")
    _assert_true(forget_commit.get("success", false), "统一遗忘查询成功提交")
    _assert_equal(forget_commit.get("forget_value"), 10, "遗忘展示与正式获得值一致")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "inner_skill_forgotten").size(),
        1,
        "普通遗忘成功后只触发一次 inner_skill_forgotten")

    var forget_failure_growth = GrowthInventoryScript.new(catalog, false)
    forget_failure_growth.experience = 6
    forget_failure_growth.item_ids.assign(["forget_query_failure_probe"])
    forget_failure_growth.learned_inner_skill_ids.assign([
        "forget_policy_fixture", "forget_policy_fixture"])
    forget_failure_growth.equipped_inner_skill_ids.assign([
        "forget_policy_fixture"])
    var forget_failure_state = RunStateScript.new(null, forget_failure_growth)
    var forget_failure_loadout = InnerSkillLoadoutServiceScript.new(
        forget_failure_growth, repository, null, runtime)
    forget_failure_loadout.use_passive_services(
        runtime, int_resolver, event_service, forget_failure_state)
    var forget_failure_before := forget_failure_growth.capture_mutation_state()
    _assert_true(
        not forget_failure_loadout.forget_inner_skill(
            "forget_policy_fixture").get("success", false),
        "遗忘整数查询失败时正式遗忘被拒绝")
    _assert_equal(
        forget_failure_growth.capture_mutation_state(), forget_failure_before,
        "遗忘查询失败不删除库存、不发历练且不增加计数")

    growth.practice_shop_state = {
        "shop_index": 3, "act": 1, "normal": [], "packs": [], "items": [],
        "meditation_count": 0, "next_meditation_cost": 5,
        "pack_open_sequence": 0,
    }
    var meditation := practice.meditate(
        growth, 41, 1, true, {"run_seed": 41, "act": 1})
    _assert_true(meditation.get("success", false), "零元冥想成功")
    _assert_equal(meditation.get("effective_cost"), 0, "冥想有效费用可为零")
    _assert_equal(
        growth.practice_shop_state.get("next_meditation_cost"), 6,
        "免费冥想后基础费用仍从五推进到六")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "meditation_committed").size(),
        1,
        "成功冥想只触发一次 meditation_committed")

    var pack: Dictionary = catalog.definition("practice_shop").get(
        "packs", {}).get("candidates", [])[0].duplicate(true)
    growth.practice_shop_state = {
        "shop_index": 4, "act": 1, "normal": [], "packs": [pack], "items": [],
        "meditation_count": 0, "next_meditation_cost": 5,
        "pack_open_sequence": 0,
    }
    growth.consumable_ids.clear()
    var pack_events_before: int = probe_handler.event_calls.filter(
        func(value): return value["hook"] == "practice_pack_opened").size()
    var preview := practice.open_pack(growth, "packs", 0, [], true, 41, 1)
    _assert_true(preview.get("success", false), "补充包策略预览成功")
    _assert_equal(
        preview.get("effective_offer_count"),
        int(preview.get("base_offer_count")) + 1,
        "补充包准备令牌冻结有效展示数量")
    _assert_equal(
        preview.get("effective_choose_count"),
        int(preview.get("base_choose_count")) + 1,
        "补充包准备令牌冻结有效选择数量")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "practice_pack_opened").size(),
        pack_events_before,
        "补充包预览不触发 practice_pack_opened")
    var pack_commit := practice.open_pack(
        growth, "packs", 0, [preview["preview"][0]], true, 41, 1,
        str(preview["preparation_token"]))
    _assert_true(pack_commit.get("success", false), "冻结补充包正式确认成功")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "practice_pack_opened").size(),
        pack_events_before + 1,
        "补充包正式开启只触发一次事件")

    var battle_events_before: int = probe_handler.event_calls.filter(
        func(value): return value["hook"] == "battle_completed").size()
    var victory_session: RunSession = RunSessionScript.new(
        null, null, null, null, catalog)
    victory_session.execute({"type": "setup_run", "seed": 4341})
    victory_session.configure_passive_services(
        runtime, int_resolver, event_service)
    victory_session.growth.item_ids.assign(["event_source_granter"])
    var victory_node := str(victory_session.snapshot().available_node_ids[0])
    var victory_begin := victory_session.execute({
        "type": "begin_node", "node_id": victory_node})
    var victory_dispatch: Dictionary = victory_begin.payload_value("dispatch", {})
    var victory_progress_values := victory_session.progress_snapshot().to_dict()
    victory_progress_values["item_ids"] = [
        "event_source_granter", "run_policy_probe"]
    var victory_result := victory_session.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            victory_dispatch, "player_victory", "F5B Fake 胜利", 3),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            victory_progress_values),
    })
    _assert_true(victory_result.success, "胜利正式结果触发本局结算")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "battle_completed").size(),
        battle_events_before + 2,
        "battle_completed 使用合入战斗进度后的两个有效来源")
    _assert_equal(
        victory_session.growth.item_ids,
        ["event_source_granter", "run_policy_probe", "self_price_probe"],
        "事件执行中获得的新来源立即进入工作状态")
    _assert_equal(
        victory_result.payload_value("passive_event", {}).get(
            "invocation_count"),
        null,
        "战斗事件由同步事务消费，不泄漏为节点建立结果字段")

    var node_events_before: int = probe_handler.event_calls.filter(
        func(value): return value["hook"] == "node_completed").size()
    victory_session._pending_reward._data["entries"].append({
        "kind": "special",
        "op": "grant_items",
        "item_ids": ["reward_source_probe"],
    })
    var reward_bundle: Dictionary = victory_session.snapshot().reward.get(
        "bundle", {})
    var claim := victory_session.execute({
        "type": "claim_reward",
        "bundle_id": str(reward_bundle.get("id", "")),
    })
    _assert_true(claim.success, "节点奖励、功行与完成事件完整提交")
    var node_event: Dictionary = claim.payload_value("passive_event", {})
    _assert_equal(
        node_event.get("invocation_count"), 3,
        "node_completed 固定奖励应用前已有的三个来源")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "node_completed").size(),
        node_events_before + 3,
        "奖励新来源不追溯加入同一次 node_completed")
    _assert_true(
        victory_session.growth.item_ids.has("reward_source_probe"),
        "奖励来源在 node_completed 后提交到当前 growth")
    var last_node_call: Dictionary = probe_handler.event_calls.filter(
        func(value): return value["hook"] == "node_completed")[-1]
    _assert_equal(
        last_node_call.get("growth", {}).get("experience"),
        claim.payload_value("experience"),
        "node_completed Handler 观察到奖励与功行均已结算")
    _assert_true(
        claim.payload_value("phase", "") != "awaiting_reward",
        "node_completed 成功后才推进离开奖励阶段")
    var next_event := victory_session._dispatch_run_passive_event(
        "practice_opened", victory_session.growth, {
            "transaction_token": "practice_opened:event-source-next",
            "payload": {},
        })
    _assert_equal(
        next_event.get("invocation_count"), 4,
        "下一事件重新读取并包含事件内与奖励中新获得的来源")
    var node_count_after_claim: int = probe_handler.event_calls.filter(
        func(value): return value["hook"] == "node_completed").size()
    _assert_true(not victory_session.execute({
        "type": "claim_reward", "bundle_id": str(reward_bundle.get("id", "")),
    }).success, "同一节点令牌不能重复提交")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "node_completed").size(),
        node_count_after_claim,
        "同一节点重复命令不重复触发 node_completed")

    var defeat_session: RunSession = RunSessionScript.new(
        null, null, null, null, catalog)
    defeat_session.execute({"type": "setup_run", "seed": 4342})
    defeat_session.configure_passive_services(runtime, int_resolver, event_service)
    defeat_session.growth.item_ids.assign(["run_policy_probe"])
    var defeat_node := str(defeat_session.snapshot().available_node_ids[0])
    var defeat_begin := defeat_session.execute({
        "type": "begin_node", "node_id": defeat_node})
    var defeat_dispatch: Dictionary = defeat_begin.payload_value("dispatch", {})
    var defeat_progress_values := defeat_session.progress_snapshot().to_dict()
    defeat_progress_values["item_ids"] = []
    _assert_true(defeat_session.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            defeat_dispatch, "player_defeat", "F5B Fake 战败", 4),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            defeat_progress_values),
    }).success, "战败正式结果触发本局终局")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "battle_completed").size(),
        battle_events_before + 2,
        "战斗进度中已移除的来源不参与 battle_completed")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "node_completed").size(),
        node_count_after_claim,
        "战败节点不触发 node_completed")

    for terminal_state in ["unresolved_draw", "scenario_error"]:
        var terminal_session: RunSession = RunSessionScript.new(
            null, null, null, null, catalog)
        terminal_session.execute({"type": "setup_run", "seed": 4350})
        terminal_session.configure_passive_services(
            runtime, int_resolver, event_service)
        terminal_session.growth.item_ids.assign(["run_policy_probe"])
        var terminal_node := str(
            terminal_session.snapshot().available_node_ids[0])
        var terminal_begin := terminal_session.execute({
            "type": "begin_node", "node_id": terminal_node})
        var terminal_dispatch: Dictionary = terminal_begin.payload_value(
            "dispatch", {})
        _assert_true(terminal_session.execute({
            "type": "resolve_battle_result",
            "battle_result": _battle_final_result_for_test(
                terminal_dispatch, terminal_state, terminal_state, 5),
        }).success, "%s 正式终止但不成长" % terminal_state)
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "battle_completed").size(),
        battle_events_before + 2,
        "unresolved_draw 与 scenario_error 均不触发 battle_completed")

    var boss_navigation = MapNavigationServiceScript.new()
    boss_navigation.setup(4351)
    boss_navigation.current_node_id = str(boss_navigation.graph.get("boss_id", ""))
    boss_navigation.phase = "boss_chest"
    var boss_growth = GrowthInventoryScript.new(catalog)
    boss_growth.item_ids.assign(["run_policy_probe"])
    var boss_session: RunSession = RunSessionScript.new(
        RunStateScript.new(boss_navigation, boss_growth),
        null, null, null, catalog)
    boss_session.configure_passive_services(runtime, int_resolver, event_service)
    var boss_completed := boss_session.execute({"type": "complete_boss_chest"})
    _assert_true(boss_completed.success, "Boss 宝箱事件使用自身结算命令")
    _assert_equal(
        boss_completed.payload_value("passive_event", {}).get(
            "invocation_count"),
        1,
        "Boss 宝箱在自身结算修改前读取当时的当前来源")

    var suppressed_growth = GrowthInventoryScript.new(catalog, false)
    suppressed_growth.item_ids.assign(["run_policy_probe"])
    runtime.suppression_service.apply({
        "suppression_id": "run-query-suppression",
        "target_content_id": "run_policy_probe",
        "blocked_hooks": ["practice_price_query", "practice_opened"],
        "reason": "本局查询压制",
    })
    _assert_equal(
        practice.resolve_price(
            suppressed_growth, "consumable", "zengyuan_pill", 3).get(
                "effective_price"),
        3,
        "压制来源不参与本局整数查询")
    var suppressed_plan = runtime.build_execution_plan(
        "practice_opened", {"owner": suppressed_growth})
    _assert_equal(suppressed_plan.invocations.size(), 0, "压制来源不参与本局事件")
    runtime.suppression_service.clear()

    var repeated_growth = GrowthInventoryScript.new(catalog, false)
    repeated_growth.item_ids.assign(["run_policy_probe", "run_repeat_probe"])
    var repeated_plan = runtime.build_execution_plan(
        "inner_skill_forget_value_query", {"owner": repeated_growth})
    _assert_equal(repeated_plan.invocations.size(), 2, "新增查询 Hook 保留额外执行一次")
    _assert_equal(
        repeated_plan.invocations[0].source.source_instance_key,
        repeated_plan.invocations[1].source.source_instance_key,
        "新增查询的额外 Invocation 在同来源位置连续且不递归")

    var failure_growth = GrowthInventoryScript.new(catalog, false)
    failure_growth.experience = 10
    failure_growth.item_ids.assign(["event_failure_probe"])
    failure_growth.practice_shop_state = {
        "shop_index": 5, "normal": [{
            "id": "zengyuan_pill", "kind": "consumable", "price": 3,
        }], "packs": [], "items": [],
    }
    var failure_state = RunStateScript.new(null, failure_growth)
    practice.use_passive_services(int_resolver, event_service, failure_state)
    var failure_before := failure_growth.capture_mutation_state()
    var failed_purchase := practice.purchase(
        failure_growth, "normal", 0, true, {"run_seed": 41, "act": 1})
    _assert_true(not failed_purchase.get("success", false), "事件 Handler 失败使购买失败")
    _assert_equal(
        failure_growth.capture_mutation_state(), failure_before,
        "Handler 先修改端口再失败时不留下扣费、内容或被动修改")
    _assert_true(
        failure_state.committed_passive_event_tokens.is_empty(),
        "失败事件不留下去重令牌")

    var opened_session: RunSession = RunSessionScript.new(
        null, null, null, null, catalog)
    _assert_true(opened_session.execute({
        "type": "setup_run", "seed": 4141}).success, "建立修习打开事件测试本局")
    opened_session.configure_passive_services(
        runtime, int_resolver, event_service)
    opened_session.growth.item_ids.assign(["run_policy_probe"])
    var opened_before: int = probe_handler.event_calls.filter(
        func(value): return value["hook"] == "practice_opened").size()
    opened_session.snapshot()
    opened_session.snapshot()
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "practice_opened").size(),
        opened_before,
        "snapshot 与 UI 刷新不触发 practice_opened")
    _assert_true(opened_session.execute({"type": "open_practice"}).success, "首次打开修习成功")
    _assert_true(opened_session.execute({"type": "open_practice"}).success, "重复打开命令幂等成功")
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "practice_opened").size(),
        opened_before + 1,
        "修习从关闭到打开只触发一次 practice_opened")
    opened_session.execute({"type": "close_practice"})
    opened_session.execute({"type": "open_practice"})
    _assert_equal(
        probe_handler.event_calls.filter(
            func(value): return value["hook"] == "practice_opened").size(),
        opened_before + 2,
        "关闭后再次主动打开属于新一次 practice_opened")

    var old_save_session: RunSession = RunSessionScript.new(
        null, null, null, null, catalog)
    _assert_true(old_save_session.execute({
        "type": "setup_run", "seed": 4242}).success, "建立旧存档兼容测试本局")
    var old_save_values: Dictionary = RunSaveDataScript.new().capture(
        old_save_session).to_dict()
    _assert_true(
        not old_save_values["node_state"].has("node_passive_source_snapshot")
        and not old_save_values["node_state"].has(
            "node_passive_source_node_id"),
        "新 RunSaveData 不再写入可派生的节点来源列表")
    old_save_session.growth.item_ids.assign(["run_policy_probe"])
    old_save_values["growth"]["item_ids"] = ["run_policy_probe"]
    old_save_values["node_state"]["node_passive_source_snapshot"] = (
        event_service.capture_source_snapshot(old_save_session.growth))
    old_save_values["node_state"]["node_passive_source_node_id"] = "legacy-node"
    for field in [
            "practice_is_open", "practice_open_sequence",
            "committed_passive_event_tokens"]:
        old_save_values["node_state"].erase(field)
    var legacy_restore := RunSaveDataScript.new(old_save_values).restore_session(
        catalog)
    _assert_true(legacy_restore.get("success", false), "schema v1 旧节点来源字段仍可校验并载入")
    var resaved_legacy: Dictionary = RunSaveDataScript.new().capture(
        legacy_restore.get("run_session")).to_dict()
    _assert_true(
        not resaved_legacy["node_state"].has("node_passive_source_snapshot")
        and not resaved_legacy["node_state"].has(
            "node_passive_source_node_id"),
        "旧来源字段恢复后被忽略并在下一次保存自然移除")

func _test_run_passive_persistent_counters_and_state_ports() -> void:
    var registry = PassiveRuleHandlerRegistryScript.new()
    _assert_true(
        registry.register_handler(PassiveCounterProbeHandler.new()),
        "注册 F5C 有状态 Fake Handler")
    _assert_true(
        registry.register_handler(
            PassiveCounterProbeHandler.new("passive_counter_probe_two")),
        "注册 F5C 重复命名空间校验 Handler")
    _assert_true(
        registry.register_handler(PassiveRepeatProbeHandler.new()),
        "注册 F5C 额外执行 Fake Handler")

    var base_catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(base_catalog.load_all(), "建立 F5C 内容测试基线")
    var values := _catalog_definitions(base_catalog)
    values["inner_skills"]["inner_skills"].append({
        "id": "counter_inner", "name": "计数器测试内功",
        "status": "formal", "description": "仅用于测试持久整数状态。",
        "forget_value": 7,
        "behaviors": [{
            "id": "passive_counter_probe",
            "state_key": "stable_growth",
            "configuration": {
                "counter_id": "battle_progress",
                "minimum": 0,
                "maximum": 2,
                "retention_policy": "while_owned",
                "query_multiplier": 3,
            },
        }],
    })
    values["items"]["items"].append_array([
        {
            "id": "run_counter_item", "name": "整局计数器测试物品",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "测试 run 保留策略。", "price": 1,
            "behaviors": [{
                "id": "passive_counter_probe", "state_key": "run_growth",
                "configuration": {
                    "counter_id": "victory_progress", "minimum": 0,
                    "retention_policy": "run", "query_multiplier": 0,
                },
            }],
        },
        {
            "id": "counter_repeat_item", "name": "计数器重复测试物品",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "令目标 Invocation 额外执行一次。", "price": 1,
            "behaviors": [{
                "id": "repeat_probe",
                "configuration": {"target_content_id": "counter_inner"},
            }],
        },
        {
            "id": "counter_failure_item", "name": "计数器失败测试物品",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "写入后令 Handler 失败。", "price": 1,
            "behaviors": [{
                "id": "passive_counter_probe", "state_key": "failure_growth",
                "configuration": {
                    "counter_id": "failed_progress", "minimum": 0,
                    "retention_policy": "while_owned", "mode": "fail",
                    "query_multiplier": 0,
                },
            }],
        },
        {
            "id": "counter_mutation_failure_item",
            "name": "计数器领域端口失败测试物品",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "写入后令 RunMutationService 失败。", "price": 1,
            "behaviors": [{
                "id": "passive_counter_probe", "state_key": "mutation_growth",
                "configuration": {
                    "counter_id": "failed_progress", "minimum": 0,
                    "retention_policy": "while_owned",
                    "mode": "mutation_failure", "query_multiplier": 0,
                },
            }],
        },
        {
            "id": "counter_undeclared_item", "name": "未声明访问测试物品",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "尝试访问其他计数器。", "price": 1,
            "behaviors": [{
                "id": "passive_counter_probe", "state_key": "declared_growth",
                "configuration": {
                    "counter_id": "declared_progress", "minimum": 0,
                    "retention_policy": "while_owned", "mode": "undeclared",
                    "query_multiplier": 0,
                },
            }],
        },
        {
            "id": "counter_below_minimum_item", "name": "下界测试物品",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "尝试写入下界以下。", "price": 1,
            "behaviors": [{
                "id": "passive_counter_probe", "state_key": "minimum_growth",
                "configuration": {
                    "counter_id": "bounded_progress", "minimum": 0,
                    "retention_policy": "while_owned", "increment_amount": -1,
                    "query_multiplier": 0,
                },
            }],
        },
        {
            "id": "counter_non_integer_item", "name": "非整数测试物品",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "尝试用非整数增加计数器。", "price": 1,
            "behaviors": [{
                "id": "passive_counter_probe", "state_key": "integer_growth",
                "configuration": {
                    "counter_id": "integer_progress", "minimum": 0,
                    "retention_policy": "while_owned", "increment_amount": 1.5,
                    "query_multiplier": 0,
                },
            }],
        },
    ])
    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        catalog.load_from_definitions(values, base_catalog.paths),
        "F5C Fake 内容通过计数器定义与 state_key 校验")

    var missing_state_key_values := values.duplicate(true)
    missing_state_key_values["inner_skills"]["inner_skills"][-1][
        "behaviors"][0].erase("state_key")
    var missing_state_key_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not missing_state_key_catalog.load_from_definitions(
            missing_state_key_values, base_catalog.paths),
        "有状态 behavior 缺少 state_key 时内容加载失败")
    var invalid_counter_values := values.duplicate(true)
    invalid_counter_values["inner_skills"]["inner_skills"][-1][
        "behaviors"][0]["configuration"]["maximum"] = -1
    var invalid_counter_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not invalid_counter_catalog.load_from_definitions(
            invalid_counter_values, base_catalog.paths),
        "计数器 maximum 小于 minimum 时内容加载失败")
    var invalid_retention_values := values.duplicate(true)
    invalid_retention_values["inner_skills"]["inner_skills"][-1][
        "behaviors"][0]["configuration"]["retention_policy"] = "battle"
    var invalid_retention_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not invalid_retention_catalog.load_from_definitions(
            invalid_retention_values, base_catalog.paths),
        "未知计数器保留策略在内容加载阶段失败")
    var duplicate_namespace_values := values.duplicate(true)
    duplicate_namespace_values["inner_skills"]["inner_skills"][-1][
        "behaviors"].append({
            "id": "passive_counter_probe_two",
            "state_key": "stable_growth",
            "configuration": {
                "counter_id": "battle_progress", "minimum": 0,
                "retention_policy": "while_owned",
            },
        })
    var duplicate_namespace_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not duplicate_namespace_catalog.load_from_definitions(
            duplicate_namespace_values, base_catalog.paths),
        "同一状态命名空间重复 counter_id 时内容加载失败")
    for invalid_definition_configuration in [
            {"counter_id": "Bad-ID", "default_value": 0, "minimum": 0,
                "retention_policy": "run"},
            {"counter_id": "typed_progress", "default_value": "0",
                "minimum": 0, "retention_policy": "run"},
            {"counter_id": "typed_progress", "default_value": 0,
                "minimum": "0", "retention_policy": "run"},
            {"counter_id": "typed_progress", "default_value": 0,
                "minimum": 0, "maximum": "2", "retention_policy": "run"}]:
        _assert_true(
            not registry.validate_counter_definitions(
                "passive_counter_probe",
                invalid_definition_configuration).is_empty(),
            "Registry 拒绝非法 ID 或非整数计数器定义")

    var runtime = PassiveRuleRuntimeScript.new(registry, catalog)
    var int_resolver = PassiveIntPolicyResolverScript.new(runtime)
    var mutation_service = RunMutationServiceScript.new(
        RunEffectHandlerRegistryScript.new(), catalog)
    var event_service = RunPassiveEventServiceScript.new(
        runtime, mutation_service)
    var growth = GrowthInventoryScript.new(catalog, false)
    growth.learned_inner_skill_ids.assign(["counter_inner", "counter_inner"])
    growth.equipped_inner_skill_ids.assign(["counter_inner", "counter_inner"])
    var event_state = RunStateScript.new(null, growth)
    var first_event := event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": growth,
            "outcome": "player_victory",
            "transaction_token": "f5c:battle:1",
        }), growth, event_state)
    _assert_true(first_event.get("success", false), "两副本计数器事件成功")
    _assert_equal(first_event.get("invocation_count"), 2, "同 ID 两副本仍分别建立 Invocation")
    _assert_equal(
        first_event["results"][0]["result"].get("before"), 0,
        "第一 Invocation 读取共享计数器初值")
    _assert_true(
        not first_event["results"][0]["result"].get(
            "non_default_before", true),
        "has_non_default_value 在初值时为 false")
    _assert_equal(
        first_event["results"][1]["result"].get("before"), 1,
        "第二 Invocation 读取第一 Invocation 已提交的新值")
    _assert_true(
        first_event["results"][1]["result"].get(
            "non_default_before", false),
        "has_non_default_value 在首次增长后为 true")
    var shared_state: Dictionary = growth.passive_counter_store.capture_state()
    _assert_equal(shared_state["entries"].size(), 1, "同 ID 多副本只保存一个内容级计数器")
    _assert_equal(shared_state["entries"][0]["value"], 2, "共享计数器连续增长并达到上限")
    var duplicate_event := event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": growth,
            "transaction_token": "f5c:battle:1",
        }), growth, event_state)
    _assert_true(duplicate_event.get("duplicate", false), "重复事务令牌返回 duplicate")
    _assert_equal(
        growth.passive_counter_store.capture_state(), shared_state,
        "重复事务令牌不重复增长计数器")

    growth.equipped_inner_skill_ids.assign(["counter_inner"])
    var repository = InnerSkillRepositoryScript.new()
    repository.configure(catalog.definition("inner_skills"))
    var loadout = InnerSkillLoadoutServiceScript.new(
        growth, repository, null, runtime)
    loadout.use_passive_services(
        runtime, int_resolver, event_service, event_state)
    var query_state_before := growth.capture_mutation_state()
    var forget_query_one := loadout.query_forget_value("counter_inner")
    var forget_query_two := loadout.query_forget_value("counter_inner")
    _assert_equal(forget_query_one.get("forget_value"), 13, "纯查询读取 progress 并计算 base + progress × 3")
    _assert_equal(forget_query_one, forget_query_two, "重复纯查询结果确定且一致")
    _assert_equal(growth.capture_mutation_state(), query_state_before, "纯查询不修改计数器或其他成长状态")
    _assert_true(
        runtime.build_execution_plan(
            "inner_skill_forget_value_query", {"owner": growth}).is_valid(),
        "ExecutionPlan 不因计数器变化重新规划")
    var capped_event := event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": growth,
            "transaction_token": "f5c:battle:capped",
        }), growth, event_state)
    _assert_true(
        capped_event["results"][0]["result"].get("capped", false),
        "超过声明 maximum 时采用明确封顶语义")

    var set_loadout_result := loadout.set_loadout([], 0)
    _assert_true(set_loadout_result.get("success", false), "卸下有状态内功成功")
    _assert_equal(
        growth.passive_counter_store.capture_state(), shared_state,
        "卸下内功不清除 while_owned 进度")
    runtime.suppression_service.apply({
        "suppression_id": "f5c-counter-suppression",
        "target_content_id": "counter_inner",
        "blocked_hooks": ["battle_completed"],
        "reason": "F5C 临时压制",
    })
    _assert_equal(
        growth.passive_counter_store.capture_state(), shared_state,
        "临时压制不清除已有进度")
    runtime.suppression_service.clear()

    var suppression_growth = GrowthInventoryScript.new(catalog, false)
    suppression_growth.learned_inner_skill_ids.assign(["counter_inner"])
    suppression_growth.equipped_inner_skill_ids.assign(["counter_inner"])
    var suppression_state = RunStateScript.new(null, suppression_growth)
    _assert_true(event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": suppression_growth,
            "transaction_token": "f5c:suppression:seed",
        }), suppression_growth, suppression_state).get("success", false),
        "建立压制恢复测试进度")
    var suppression_progress: Dictionary = (
        suppression_growth.passive_counter_store.capture_state())
    runtime.suppression_service.apply({
        "suppression_id": "f5c-counter-suppression-active",
        "target_content_id": "counter_inner",
        "blocked_hooks": ["battle_completed"],
        "reason": "F5C Invocation 压制",
    })
    var suppressed_event := event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": suppression_growth,
            "transaction_token": "f5c:suppression:blocked",
        }), suppression_growth, suppression_state)
    _assert_equal(
        suppressed_event.get("invocation_count"), 0,
        "被压制来源不建立 Invocation")
    _assert_equal(
        suppression_growth.passive_counter_store.capture_state(),
        suppression_progress,
        "压制期间不增长也不删除计数器")
    runtime.suppression_service.clear()
    _assert_true(event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": suppression_growth,
            "transaction_token": "f5c:suppression:restored",
        }), suppression_growth, suppression_state).get("success", false),
        "压制解除后来源恢复执行")
    _assert_equal(
        suppression_growth.passive_counter_store.capture_state()[
            "entries"][0]["value"],
        2,
        "压制解除后从原有进度继续增长")

    var repeated_growth = GrowthInventoryScript.new(catalog, false)
    repeated_growth.learned_inner_skill_ids.assign(["counter_inner"])
    repeated_growth.equipped_inner_skill_ids.assign(["counter_inner"])
    repeated_growth.item_ids.assign(["counter_repeat_item"])
    var repeated_state = RunStateScript.new(null, repeated_growth)
    var repeated_event := event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": repeated_growth,
            "transaction_token": "f5c:repeat:1",
        }), repeated_growth, repeated_state)
    _assert_equal(repeated_event.get("invocation_count"), 2, "额外执行产生相邻的第二次 Invocation")
    _assert_equal(repeated_event["results"][1]["result"].get("before"), 1, "额外执行读取第一次修改后的最新值")

    for failure_case in [
            ["counter_failure_item", "f5c:failure:handler"],
            ["counter_mutation_failure_item", "f5c:failure:mutation"],
            ["counter_undeclared_item", "f5c:failure:undeclared"],
            ["counter_below_minimum_item", "f5c:failure:minimum"],
            ["counter_non_integer_item", "f5c:failure:integer"]]:
        var failure_growth = GrowthInventoryScript.new(catalog, false)
        failure_growth.item_ids.assign([str(failure_case[0])])
        var failure_state = RunStateScript.new(null, failure_growth)
        var failure_before := failure_growth.capture_mutation_state()
        var failed := event_service.dispatch(
            RunPassiveEventContextScript.new().configure({
                "hook": "battle_completed", "owner": failure_growth,
                "transaction_token": str(failure_case[1]),
            }), failure_growth, failure_state)
        _assert_true(not failed.get("success", false), "%s 明确失败" % str(failure_case[0]))
        _assert_equal(failure_growth.capture_mutation_state(), failure_before, "失败后计数器与其他成长字段完整回滚")
        _assert_true(failure_state.committed_passive_event_tokens.is_empty(), "失败事件不留下去重令牌")
    var undeclared_growth = GrowthInventoryScript.new(catalog, false)
    undeclared_growth.item_ids.assign(["counter_undeclared_item"])
    var undeclared_state = RunStateScript.new(null, undeclared_growth)
    var undeclared_result := event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": undeclared_growth,
            "transaction_token": "f5c:undeclared:detail",
        }), undeclared_growth, undeclared_state)
    _assert_true(
        str(undeclared_result.get("reason", "")).contains("counter_undeclared_item")
            and str(undeclared_result.get("reason", "")).contains("passive_counter_probe")
            and str(undeclared_result.get("reason", "")).contains("declared_growth")
            and str(undeclared_result.get("reason", "")).contains("missing_counter"),
        "未声明访问错误包含内容、behavior、state_key 与 counter_id")

    var ownership_growth = GrowthInventoryScript.new(catalog, false)
    ownership_growth.learned_inner_skill_ids.assign(["counter_inner", "counter_inner"])
    ownership_growth.equipped_inner_skill_ids.assign(["counter_inner"])
    var ownership_state = RunStateScript.new(null, ownership_growth)
    _assert_true(event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": ownership_growth,
            "transaction_token": "f5c:ownership:seed",
        }), ownership_growth, ownership_state).get("success", false),
        "建立 while_owned 遗忘测试进度")
    ownership_growth.equipped_inner_skill_ids.clear()
    var ownership_loadout = InnerSkillLoadoutServiceScript.new(
        ownership_growth, repository, null, runtime)
    ownership_loadout.use_passive_services(
        runtime, int_resolver, event_service, ownership_state)
    _assert_true(ownership_loadout.forget_inner_skill("counter_inner").get("success", false), "遗忘第一副本成功")
    _assert_equal(
        ownership_growth.passive_counter_store.capture_state()["entries"].size(),
        1,
        "仍持有同 ID 另一副本时 while_owned 进度保留")
    _assert_true(ownership_loadout.forget_inner_skill("counter_inner").get("success", false), "遗忘最后副本成功")
    _assert_true(
        ownership_growth.passive_counter_store.capture_state()["entries"].is_empty(),
        "最后一个副本永久失去后集中清除 while_owned 进度")

    var run_growth = GrowthInventoryScript.new(catalog, false)
    run_growth.item_ids.assign(["run_counter_item"])
    var run_state = RunStateScript.new(null, run_growth)
    _assert_true(event_service.dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed", "owner": run_growth,
            "transaction_token": "f5c:run:seed",
        }), run_growth, run_state).get("success", false),
        "建立 run 保留策略进度")
    var run_counter_state: Dictionary = run_growth.passive_counter_store.capture_state()
    var without_item := run_growth.capture_mutation_state()
    without_item["item_ids"] = []
    _assert_true(run_growth.replace_mutation_state(without_item).is_empty(), "永久失去 run 来源内容事务成功")
    _assert_equal(
        run_growth.passive_counter_store.capture_state(), run_counter_state,
        "run 计数器在来源失去后仍保留到本局结束")

    var full_snapshot = run_growth.to_progress_snapshot()
    _assert_true(full_snapshot.has_passive_counter_state, "完整本局快照携带计数器绝对状态")
    var snapshot_target = GrowthInventoryScript.new(catalog, false)
    snapshot_target.apply_progress_snapshot(full_snapshot)
    _assert_equal(snapshot_target.passive_counter_store.capture_state(), run_counter_state, "带字段快照绝对替换计数器")
    snapshot_target.apply_progress_snapshot(full_snapshot)
    _assert_equal(snapshot_target.passive_counter_store.capture_state(), run_counter_state, "同一绝对快照应用两次不重复增长")
    snapshot_target.apply_progress_snapshot(
        RunProgressSnapshotScript.from_dict({"experience": 99}))
    _assert_equal(snapshot_target.passive_counter_store.capture_state(), run_counter_state, "缺失计数器字段的部分快照不清空现有状态")
    snapshot_target.apply_progress_snapshot(
        RunProgressSnapshotScript.from_dict({
            "passive_counter_state": {"version": 1, "entries": []},
        }))
    _assert_true(snapshot_target.passive_counter_store.capture_state()["entries"].is_empty(), "带字段空状态执行绝对清空")
    _assert_true(
        not RunProgressSnapshotScript.from_dict({"life": 1}).has_passive_counter_state,
        "战斗侧未拥有计数器时不会伪造空字段")
    var battle_return_snapshot = BattleSetupServiceScript.new(
        catalog).capture_progress(
            BattleSideScript.new("F5C 战斗快照", "f5c-battle"),
            RunDeckScript.new(catalog))
    _assert_true(
        not battle_return_snapshot.has_passive_counter_state,
        "当前战斗回传快照不以空计数器覆盖本局状态")

    var save_session: RunSession = RunSessionScript.new(
        null, null, null, null, catalog)
    _assert_true(save_session.execute({
        "type": "setup_run", "seed": 5451}).success, "建立 F5C 存档测试本局")
    save_session.growth.item_ids.assign(["run_counter_item"])
    save_session.growth.replace_mutation_state(run_growth.capture_mutation_state())
    var save_values: Dictionary = RunSaveDataScript.new().capture(
        save_session).to_dict()
    _assert_equal(
        save_values["growth"]["passive_counter_state"], run_counter_state,
        "存档输出版本化、稳定排序的计数器 entries")
    var restored := RunSaveDataScript.new(save_values).restore_session(catalog)
    _assert_true(restored.get("success", false), "计数器存档可验证并恢复")
    _assert_equal(
        restored["run_session"].growth.passive_counter_store.capture_state(),
        run_counter_state,
        "读档恢复绝对计数器状态")
    var old_save_values := save_values.duplicate(true)
    old_save_values["growth"].erase("passive_counter_state")
    var old_restored := RunSaveDataScript.new(old_save_values).restore_session(catalog)
    _assert_true(old_restored.get("success", false), "旧存档缺少计数器字段时兼容为空集合")
    _assert_true(
        old_restored["run_session"].growth.passive_counter_store.capture_state()["entries"].is_empty(),
        "旧存档不会继承外部计数器状态")
    for corrupt_state in [
            {"version": 1, "entries": [
                run_counter_state["entries"][0],
                run_counter_state["entries"][0],
            ]},
            {"version": 1, "entries": [{
                "source_kind": "item", "content_id": "missing_item",
                "state_key": "run_growth", "counter_id": "victory_progress",
                "value": 1,
            }]},
            {"version": 1, "entries": [{
                "source_kind": "inner_skill", "content_id": "counter_inner",
                "state_key": "stable_growth", "counter_id": "battle_progress",
                "value": 3,
            }]}]:
        var corrupt_save := save_values.duplicate(true)
        corrupt_save["growth"]["passive_counter_state"] = corrupt_state
        _assert_true(
            not RunSaveDataScript.new(corrupt_save).validate(catalog).is_empty(),
            "重复键、未知定义或越界值的计数器存档明确失败")

    run_growth.reset("f5c-reset", null, 100)
    _assert_true(
        run_growth.passive_counter_store.capture_state()["entries"].is_empty(),
        "新本局 reset 清空所有 run 与 while_owned 计数器")

func _test_battle_passive_lifecycle_bridge_and_temporary_counters() -> void:
    var handler := BattleLifecycleProbeHandler.new()
    var registry = PassiveRuleHandlerRegistryScript.new()
    _assert_true(registry.register_handler(handler), "注册 F5D1 战斗生命周期 Fake Handler")
    _assert_true(
        registry.register_handler(InvalidBattleBindingProbeHandler.new()),
        "注册 F5D1 无效绑定校验 Handler")
    _assert_true(
        registry.register_handler(PassiveRepeatProbeHandler.new()),
        "注册 F5D1 额外 Invocation Handler")
    for hook in PassiveRuleHandlerRegistryScript.BATTLE_TIMING_HOOKS:
        _assert_true(registry.has_hook(hook), "Registry 登记正式战斗 Hook：%s" % hook)
    _assert_true(
        registry.validate_battle_timing_bindings(
            "battle_lifecycle_probe", {
                "bindings": [{"hook": "after_normal_draw", "order": 700}],
            }).is_empty(),
        "Handler 可以代码声明合法 hook 与全局整数 order")
    _assert_true(
        not registry.validate_battle_timing_bindings(
            "invalid_battle_binding_probe", {
                "bindings": [{"hook": "turn_start", "order": 1}],
            }).is_empty(),
        "binding hook 未进入 supported_hooks 时校验失败")
    _assert_true(
        not registry.validate_battle_timing_bindings(
            "invalid_battle_binding_probe", {
                "bindings": [{"hook": "battle_start", "order": 1.5}],
            }).is_empty(),
        "binding order 非整数时校验失败")
    _assert_true(
        not registry.validate_battle_timing_bindings(
            "invalid_battle_binding_probe", {
                "bindings": [
                    {"hook": "battle_start", "order": 1},
                    {"hook": "battle_start", "order": 1},
                ],
            }).is_empty(),
        "同一 Handler 重复 hook + order 时校验失败")

    var battle_counter_definitions := [
        {
            "counter_id": "battle_total", "default_value": 0,
            "minimum": 0, "reset_scope": "battle",
        },
        {
            "counter_id": "turn_total", "default_value": 0,
            "minimum": 0, "reset_scope": "turn",
        },
        {
            "counter_id": "window_total", "default_value": 0,
            "minimum": 0, "reset_scope": "action_window",
        },
    ]
    var persistent_definition := {
        "counter_id": "run_total", "default_value": 0,
        "minimum": 0, "retention_policy": "run",
    }
    var items: Array = []
    for hook_index in range(
            PassiveRuleHandlerRegistryScript.BATTLE_TIMING_HOOKS.size()):
        var hook: String = (
            PassiveRuleHandlerRegistryScript.BATTLE_TIMING_HOOKS[hook_index])
        items.append(_battle_passive_test_item(
            "lifecycle_%s" % hook,
            [{"hook": hook, "order": 600}],
            {}))
    items.append(_battle_passive_test_item("no_timing_binding", [], {}))
    items.append(_battle_passive_test_item(
        "counter_item",
        [
            {"hook": "round_start", "order": 250},
            {"hook": "turn_start", "order": 250},
            {"hook": "action_window_start", "order": 250},
        ],
        {
            "battle_counters": battle_counter_definitions,
            "persistent_counter": persistent_definition,
            "increment_persistent": true,
            "increments_by_hook": {
                "round_start": ["battle_total"],
                "turn_start": ["turn_total"],
                "action_window_start": ["window_total"],
            },
        }))
    items.append(_battle_passive_test_item(
        "same_order_first",
        [{"hook": "after_normal_draw", "order": 700}], {}))
    items.append(_battle_passive_test_item(
        "same_order_second",
        [{"hook": "after_normal_draw", "order": 700}], {}))
    items.append(_battle_passive_test_item(
        "battle_end_state",
        [
            {"hook": "battle_start", "order": 350},
            {"hook": "battle_end", "order": 350},
        ],
        {
            "battle_counters": [{
                "counter_id": "end_visible", "default_value": 0,
                "minimum": 0, "reset_scope": "battle",
            }],
            "increments_by_hook": {
                "battle_start": ["end_visible"],
                "battle_end": ["end_visible"],
            },
        }))
    items.append({
        "id": "repeat_copy_item", "name": "战斗 Invocation 重复探针",
        "kind": "item", "status": "candidate", "unique": true,
        "description": "仅用于 F5D1 测试。", "price": 1,
        "behaviors": [{
            "id": "repeat_probe",
            "configuration": {"target_content_id": "copy_inner"},
        }],
    })
    items.append({
        "id": "repeat_group_item", "name": "group_end 重复探针",
        "kind": "item", "status": "candidate", "unique": true,
        "description": "仅用于 F5D1 测试。", "price": 1,
        "behaviors": [{
            "id": "repeat_probe",
            "configuration": {"target_content_id": "failure_group"},
        }],
    })
    items.append_array([
        _battle_passive_test_item(
            "failure_battle_start",
            [{"hook": "battle_start", "order": 400}],
            {"fail_hook": "battle_start"}),
        _battle_passive_test_item(
            "failure_turn_start",
            [{"hook": "turn_start", "order": 400}],
            {"fail_hook": "turn_start"}),
        _battle_passive_test_item(
            "failure_group",
            [{"hook": "group_end", "order": 400}],
            {
                "fail_hook": "group_end", "fail_execution_index": 1,
                "battle_counters": [{
                    "counter_id": "failed_battle", "default_value": 0,
                    "minimum": 0, "reset_scope": "battle",
                }],
                "persistent_counter": persistent_definition,
                "increment_persistent": true,
                "increment_battle_ids": ["failed_battle"],
            }),
        _battle_passive_test_item(
            "failure_battle_end",
            [{"hook": "battle_end", "order": 400}],
            {
                "fail_hook": "battle_end",
                "battle_counters": [{
                    "counter_id": "failed_end", "default_value": 0,
                    "minimum": 0, "reset_scope": "battle",
                }],
                "persistent_counter": persistent_definition,
                "increment_persistent": true,
                "increment_battle_ids": ["failed_end"],
            }),
        _battle_passive_test_item(
            "snapshot_probe",
            [{"hook": "battle_start", "order": 300}],
            {
                "persistent_counter": persistent_definition,
                "increment_persistent": true,
            }),
    ])
    var inner_skills := [{
        "id": "copy_inner", "name": "同 ID 战斗副本探针",
        "status": "candidate", "description": "仅用于 F5D1 测试。",
        "forget_value": 1,
        "behaviors": [{
            "id": "battle_lifecycle_probe", "state_key": "copy_state",
            "configuration": {
                "bindings": [{"hook": "battle_start", "order": 300}],
                "battle_counters": [{
                    "counter_id": "copy_battle", "default_value": 0,
                    "minimum": 0, "reset_scope": "battle",
                }],
                "persistent_counter": persistent_definition,
                "increment_persistent": true,
                "increment_battle_ids": ["copy_battle"],
            },
        }],
    }]
    var catalog_result := _battle_passive_test_catalog(
        registry, items, inner_skills)
    var catalog = catalog_result["catalog"]
    _assert_true(catalog_result["success"], "F5D1 Fake 内容通过统一内容校验")

    var base_values: Dictionary = catalog_result["base_values"]
    for invalid_case in [
            [{"hook": "turn_start", "order": 1}, "supported_hooks"],
            [{"hook": "battle_start", "order": 1.5}, "order"],
            [
                [
                    {"hook": "battle_start", "order": 1},
                    {"hook": "battle_start", "order": 1},
                ],
                "重复声明",
            ],
        ]:
        var invalid_values := base_values.duplicate(true)
        var bindings = invalid_case[0]
        if bindings is Dictionary:
            bindings = [bindings]
        invalid_values["items"]["items"].append({
            "id": "invalid_binding_content", "name": "无效绑定内容",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "仅用于校验。", "price": 1,
            "behaviors": [{
                "id": "invalid_battle_binding_probe",
                "configuration": {"bindings": bindings},
            }],
        })
        var invalid_catalog = ContentCatalogScript.new(
            RuntimeProfileScript.test(), null, null, null, null, null, registry)
        _assert_true(
            not invalid_catalog.load_from_definitions(
                invalid_values, catalog_result["paths"]),
            "非法战斗 binding 在内容校验阶段失败：%s" % str(invalid_case[1]))

    var lifecycle_ids: Array[String] = []
    for hook in PassiveRuleHandlerRegistryScript.BATTLE_TIMING_HOOKS:
        lifecycle_ids.append("lifecycle_%s" % hook)
    lifecycle_ids.append_array([
        "no_timing_binding", "counter_item",
        "same_order_first", "same_order_second", "battle_end_state",
    ])
    var engine = _battle_passive_test_engine(catalog, registry, lifecycle_ids)
    handler.calls.clear()
    var first_draw: Array = engine.start_player_turn()
    _assert_true(not first_draw.is_empty(), "单方生命周期桥接成功进入首次补牌")
    _assert_true(
        engine.battle_passive_timing_bridge.registered_binding_snapshot().any(
            func(entry): return entry["handler_id"] == \
                "passives.after_normal_draw.700"),
        "Bridge 使用 passives.<hook>.<order> 稳定注册 ID")
    var after_draw_calls := handler.calls.filter(
        func(call): return call["hook"] == "after_normal_draw")
    _assert_true(
        after_draw_calls.any(func(call): return int(call["drawn_count"]) == first_draw.size()),
        "after_normal_draw Context 携带实际抽到的卡牌")
    _assert_true(
        not handler.calls.any(
            func(call): return str(call["source_instance_key"]).contains(
                "no_timing_binding")),
        "未声明 timing binding 的 Handler 不会被 Bridge 执行")
    var after_draw_history: Array = engine.battle_passive_timing_bridge.execution_history.filter(
        func(entry): return entry["hook"] == "after_normal_draw")
    _assert_true(
        int(after_draw_history[0]["order"]) < int(after_draw_history[-1]["order"]),
        "不同 order 按 BattleTimingSystem 全局时序执行")
    var same_order_history: Array = after_draw_history.filter(
        func(entry): return int(entry["order"]) == 700)
    _assert_true(
        str(same_order_history[0]["source_instance_key"]).contains(
            "same_order_first")
            and str(same_order_history[1]["source_instance_key"]).contains(
                "same_order_second"),
        "同一 order 内保持物品稳定来源顺序")
    var play_result: Dictionary = engine.confirm_play([
        str(engine.player.hand[0].id)])
    _assert_true(play_result.get("success", false), "实际行动触发 group_end 被动桥接")
    if engine.battle_state == "active":
        engine.end_player_turn()
    engine.enemy.life = 0
    engine._update_battle_state()
    var seen_hooks: Dictionary = {}
    for call in handler.calls:
        seen_hooks[str(call["hook"])] = true
    for hook in PassiveRuleHandlerRegistryScript.BATTLE_TIMING_HOOKS:
        _assert_true(seen_hooks.has(hook), "实际战斗执行正式生命周期 Hook：%s" % hook)
    var battle_end_calls := handler.calls.filter(
        func(call): return call["hook"] == "battle_end")
    _assert_true(
        battle_end_calls.any(func(call):
            return call["winner_id"] == "player" \
                and call["battle_state"] == "player_victory"),
        "battle_end Context 使用 BattleOutcomeService 的明确 winner 与 battle_state")
    var end_state_call: Dictionary = battle_end_calls.filter(
        func(call): return str(call["source_instance_key"]).contains(
            "battle_end_state"))[0]
    _assert_equal(
        end_state_call["battle_before"]["end_visible"], 1,
        "battle_end Handler 执行时仍可读取本场临时计数")
    _assert_true(
        engine.player.battle_passive_counter_store.is_empty(),
        "battle_end 全部处理器结束后清空战斗临时 Store")

    var counter_engine = _battle_passive_test_engine(
        catalog, registry, ["counter_item"])
    handler.calls.clear()
    counter_engine.start_player_turn()
    counter_engine.end_player_turn()
    counter_engine.apply_passive_suppression({
        "suppression_id": "f5d1-round-suppression",
        "target_content_id": "counter_item",
        "blocked_hooks": ["round_start"],
        "reason": "F5D1 测试压制",
    })
    counter_engine.start_player_turn()
    counter_engine.end_player_turn()
    counter_engine.remove_passive_suppression("f5d1-round-suppression")
    counter_engine.start_player_turn()
    var counter_calls := handler.calls.filter(
        func(call): return str(call["source_instance_key"]).contains(
            "counter_item"))
    var round_calls := counter_calls.filter(
        func(call): return call["hook"] == "round_start")
    _assert_equal(round_calls.size(), 2, "被压制来源不建立 Invocation，解除后恢复")
    _assert_equal(
        round_calls[1]["battle_before"]["battle_total"], 1,
        "battle 计数跨回合和压制保留")
    var turn_calls := counter_calls.filter(
        func(call): return call["hook"] == "turn_start")
    _assert_true(
        turn_calls.all(func(call):
            return int(call["battle_before"]["turn_total"]) == 0),
        "turn 计数只在对应 actor 的 turn_start Handler 前重置")
    var window_calls := counter_calls.filter(
        func(call): return call["hook"] == "action_window_start")
    _assert_true(
        window_calls.all(func(call):
            return int(call["battle_before"]["window_total"]) == 0),
        "action_window 计数只在新窗口 Handler 前重置")
    var preview_state_before: Dictionary = (
        counter_engine.player.battle_passive_counter_store.capture_state())
    var preview_one: Dictionary = counter_engine.passive_rule_runtime.dispatch_event(
        "action_preview", {"actor": counter_engine.player})
    var preview_two: Dictionary = counter_engine.passive_rule_runtime.dispatch_event(
        "action_preview", {"actor": counter_engine.player})
    _assert_true(
        preview_one.get("success", false) and preview_two.get("success", false),
        "action_preview 可重复读取两类计数")
    var counter_preview: Dictionary = preview_one["results"].filter(
        func(entry): return entry["source"].content_id == "counter_item")[0]["result"]
    _assert_true(
        not counter_preview["persistent_mutation_available"]
            and not counter_preview["battle_mutation_available"],
        "action_preview 只获得持久与临时只读端口")
    _assert_equal(
        counter_engine.player.battle_passive_counter_store.capture_state(),
        preview_state_before,
        "重复预览和 AI 候选式查询不修改临时计数")
    counter_engine.use_external_enemy_actions(false)
    _assert_true(
        counter_engine.player.battle_passive_counter_store.is_empty(),
        "战斗关闭时清空临时计数并注销旧 Bridge 绑定")

    var copy_engine = _battle_passive_test_engine(
        catalog, registry, ["repeat_copy_item"],
        ["copy_inner", "copy_inner"])
    handler.calls.clear()
    copy_engine.start_player_turn()
    var copy_calls := handler.calls.filter(
        func(call): return call["hook"] == "battle_start" \
            and str(call["source_instance_key"]).contains("copy_inner"))
    _assert_equal(copy_calls.size(), 4, "两副本各自保留额外 Invocation")
    _assert_equal(
        copy_calls.map(func(call): return int(call["execution_index"])),
        [0, 1, 0, 1],
        "额外 Invocation 在原来源位置连续执行")
    _assert_equal(
        copy_engine.player.battle_passive_counter_store.capture_state()[
            "entries"].size(),
        2,
        "同 ID 两个副本按 source_instance_key 拥有独立战斗临时计数")
    var copy_persistent: Dictionary = (
        copy_engine.player.passive_counter_store.capture_state())
    _assert_equal(copy_persistent["entries"].size(), 1, "F5C 持久计数仍按内容级身份共享")
    _assert_equal(copy_persistent["entries"][0]["value"], 4, "连续 Invocation 读取此前已提交持久值")
    var entering_snapshot = BattleSetupServiceScript.new(catalog).capture_progress(
        copy_engine.player, RunDeckScript.new(catalog))
    var imported_engine = _battle_passive_test_engine(catalog, registry, [])
    var imported: Dictionary = BattleSetupServiceScript.new(
        catalog).apply_non_deck_progress(
            imported_engine.player, entering_snapshot)
    _assert_true(imported.get("success", false), "RunProgressSnapshot 持久计数绝对装配进 BattleSide 副本")
    _assert_equal(
        imported_engine.player.passive_counter_store.capture_state(),
        copy_persistent,
        "战斗开始前持久 Store 与本局快照完全一致")
    imported_engine.start_player_turn()
    _assert_equal(
        imported_engine.player.passive_counter_store.capture_state()[
            "entries"][0]["value"],
        8,
        "战斗 Handler 在独立副本中读取旧值并连续增长")
    _assert_equal(
        copy_engine.player.passive_counter_store.capture_state(),
        copy_persistent,
        "战斗副本修改不直接写回原本局状态")

    var gate_engine = _battle_passive_test_engine(
        catalog, registry, ["lifecycle_battle_start"])
    _assert_true(
        gate_engine.enemy.configure_items([
            "lifecycle_battle_start"]).get("success", false),
        "为敌方配置同 Hook 门禁夹具")
    gate_engine.start_player_turn()
    _assert_equal(gate_engine.battle_state, "scenario_error", "双方同 Hook 时拒绝正式战斗装配")
    _assert_true(
        gate_engine.battle_state_detail.contains(
            "unconfirmed_cross_side_passive_order")
            and gate_engine.battle_state_detail.contains("battle_start")
            and gate_engine.battle_state_detail.contains("player")
            and gate_engine.battle_state_detail.contains("enemy"),
        "跨阵营门禁错误包含 code、hook 与双方 owner_id")

    var battle_start_failure = _battle_passive_test_engine(
        catalog, registry, ["failure_battle_start"])
    battle_start_failure.start_player_turn()
    _assert_equal(battle_start_failure.battle_state, "scenario_error", "battle_start 失败进入 scenario_error")
    _assert_equal(
        battle_start_failure.timing_system.history.size(), 0,
        "battle_start 失败回滚自身 history 且不继续 round_start 或抽牌")
    var turn_failure = _battle_passive_test_engine(
        catalog, registry, ["failure_turn_start"])
    turn_failure.start_player_turn()
    _assert_equal(turn_failure.battle_state, "scenario_error", "turn_start 失败进入 scenario_error")
    _assert_true(turn_failure.player.hand.is_empty(), "turn_start 失败后不会继续正常抽牌")

    var group_failure = _battle_passive_test_engine(
        catalog, registry, ["failure_group", "repeat_group_item"])
    handler.calls.clear()
    group_failure.start_player_turn()
    var group_state_before: Dictionary = group_failure.player.passive_counter_store.capture_state()
    var group_battle_before: Dictionary = (
        group_failure.player.battle_passive_counter_store.capture_state())
    var hand_id := str(HandEvaluatorScript.evaluate([
        group_failure.player.hand[0]])["id"])
    var technique_before: String = group_failure.sequence_book.current_id(hand_id)
    group_failure.confirm_play([str(group_failure.player.hand[0].id)])
    _assert_equal(group_failure.battle_state, "scenario_error", "group_end 第二 Invocation 失败进入 scenario_error")
    _assert_true(
        group_failure.battle_state_detail.contains("hook=group_end")
            and group_failure.battle_state_detail.contains("order=400")
            and group_failure.battle_state_detail.contains("failure_group")
            and group_failure.battle_state_detail.contains(
                "battle_lifecycle_probe")
            and group_failure.battle_state_detail.contains(
                "Fake 战斗生命周期失败"),
        "时点失败诊断包含 hook、order、source_instance_key、behavior_id 与原因")
    _assert_equal(
        group_failure.player.passive_counter_store.capture_state(),
        group_state_before,
        "group_end 失败回滚该时点全部持久计数修改")
    _assert_equal(
        group_failure.player.battle_passive_counter_store.capture_state(),
        group_battle_before,
        "group_end 失败回滚该时点全部临时计数修改")
    _assert_equal(
        group_failure.sequence_book.current_id(hand_id), technique_before,
        "order 400 被动失败后不会继续 order 500 功法序列推进")

    var end_failure = _battle_passive_test_engine(
        catalog, registry, ["failure_battle_end"])
    end_failure.start_player_turn()
    var end_persistent_before: Dictionary = end_failure.player.passive_counter_store.capture_state()
    var end_battle_before: Dictionary = end_failure.player.battle_passive_counter_store.capture_state()
    end_failure.enemy.life = 0
    end_failure._update_battle_state()
    _assert_equal(end_failure.battle_state, "scenario_error", "battle_end 失败不返回正常胜利")
    _assert_equal(
        end_failure.player.passive_counter_store.capture_state(),
        end_persistent_before,
        "battle_end 失败回滚持久计数")
    _assert_equal(
        end_failure.player.battle_passive_counter_store.capture_state(),
        end_battle_before,
        "battle_end 失败回滚临时计数")

    var victory_snapshot = BattleSetupServiceScript.new(catalog).capture_progress(
        engine.player, RunDeckScript.new(catalog))
    _assert_true(victory_snapshot.has_passive_counter_state, "胜利战斗快照携带持久计数绝对状态")
    var snapshot_growth = GrowthInventoryScript.new(catalog, false)
    snapshot_growth.apply_progress_snapshot(victory_snapshot)
    var synced_state: Dictionary = snapshot_growth.passive_counter_store.capture_state()
    snapshot_growth.apply_progress_snapshot(victory_snapshot)
    _assert_equal(
        snapshot_growth.passive_counter_store.capture_state(), synced_state,
        "同一战斗绝对快照同步两次不会重复增加")
    var defeat_engine = _battle_passive_test_engine(
        catalog, registry, ["snapshot_probe"])
    defeat_engine.start_player_turn()
    defeat_engine.player.life = 0
    defeat_engine._update_battle_state()
    var defeat_snapshot = BattleSetupServiceScript.new(catalog).capture_progress(
        defeat_engine.player, RunDeckScript.new(catalog))
    _assert_equal(defeat_engine.battle_state, "player_defeat", "建立战败持久状态回写夹具")
    _assert_true(
        defeat_snapshot.has_passive_counter_state \
            and not defeat_snapshot.passive_counter_state["entries"].is_empty(),
        "战败绝对快照同样保留战斗内增长的持久计数")

    _assert_true(
        not registry.validate_battle_counter_definitions(
            "battle_lifecycle_probe", {
                "battle_counters": [{
                    "counter_id": "Bad-ID", "default_value": 0,
                    "minimum": 0, "reset_scope": "battle",
                }],
            }).is_empty(),
        "临时计数器 ID、整数范围与 reset_scope 由 Registry 集中校验")

func _test_battle_fine_grained_events_and_int_queries() -> void:
    var handler := BattleFineGrainedProbeHandler.new()
    var registry = PassiveRuleHandlerRegistryScript.new()
    _assert_true(registry.register_handler(handler), "注册 F5D2 Fake Handler")
    _assert_true(
        registry.register_handler(PassiveRepeatProbeHandler.new()),
        "F5D2 复用额外 Invocation 规划 Handler")
    _assert_equal(
        PassiveRuleHandlerRegistryScript.BATTLE_COMMITTED_EVENT_HOOKS.size(),
        38,
        "Registry 明确登记三十八个细粒度已提交事件")
    _assert_equal(
        PassiveRuleHandlerRegistryScript.BATTLE_INT_QUERY_HOOKS.size(),
        19,
        "Registry 从唯一目录登记十九个战斗整数查询")
    for hook in PassiveRuleHandlerRegistryScript.BATTLE_COMMITTED_EVENT_HOOKS:
        _assert_true(registry.has_hook(hook), "登记细粒度事件 Hook：%s" % hook)
    for hook in PassiveRuleHandlerRegistryScript.BATTLE_INT_QUERY_HOOKS:
        _assert_true(registry.has_hook(hook), "登记战斗整数查询 Hook：%s" % hook)

    var probe_configuration := {
        "increment_events": true,
        "query_deltas": {
            "hand_limit_query": 2,
            "power_base_fixed_query": 1,
            "power_multiplier_bonus_query": 1,
            "power_fixed_query": 3,
            "power_amp_percent_query": 10,
            "outgoing_damage_query": 2,
            "incoming_damage_query": 3,
            "defense_gain_query": 4,
            "defense_retention_percent_query": 50,
        },
    }
    var items := [
        _f5d2_probe_item("f5d2_probe", probe_configuration),
        _f5d2_probe_item("f5d2_event_failure", {
            "increment_events": true,
            "fail_event": "action_confirmed",
            "fail_execution_index": 1,
        }),
        _f5d2_probe_item("f5d2_hand_query_failure", {
            "fail_query": "hand_limit_query",
        }),
        _f5d2_probe_item("f5d2_defense_query_failure", {
            "fail_query": "defense_gain_query",
        }),
        _f5d2_probe_item("f5d2_power_query_failure", {
            "fail_query": "power_fixed_query",
            "fail_query_on_confirm": true,
        }),
        _f5d2_probe_item("f5d2_damage_query_failure", {
            "fail_query": "outgoing_damage_query",
        }),
        _f5d2_probe_item("f5d2_retention_query_failure", {
            "fail_query": "defense_retention_percent_query",
        }),
        _f5d2_probe_item("f5d2_query_mutation", {
            "mutate_query_state": true,
        }),
        {
            "id": "f5d2_repeat_probe", "name": "F5D2 查询重复探针",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "仅用于 F5D2 自动化测试。", "price": 1,
            "behaviors": [{
                "id": "repeat_probe",
                "configuration": {"target_content_id": "f5d2_probe"},
            }],
        },
        {
            "id": "f5d2_repeat_failure", "name": "F5D2 失败重复探针",
            "kind": "item", "status": "candidate", "unique": true,
            "description": "仅用于 F5D2 自动化测试。", "price": 1,
            "behaviors": [{
                "id": "repeat_probe",
                "configuration": {"target_content_id": "f5d2_event_failure"},
            }],
        },
    ]
    var catalog_result := _battle_passive_test_catalog(registry, items, [])
    _assert_true(catalog_result["success"], "F5D2 Fake 内容通过统一内容校验")
    var catalog = catalog_result["catalog"]

    var engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_probe"])
    _assert_true(
        engine.enemy.configure_items(["f5d2_probe"])["success"],
        "受击方装配同一 Fake 查询来源")
    handler.calls.clear()
    var normal_draw: Array = engine.start_player_turn()
    _assert_equal(engine.player.base_hand_limit(), 8, "基础手牌上限保持独立字段")
    _assert_equal(engine.player.current_hand_limit(), 10, "有效手牌上限经过统一查询")
    _assert_equal(normal_draw.size(), 10, "正常补牌使用有效手牌上限")
    var drawn_calls := handler.calls.filter(
        func(call): return call["kind"] == "event" and call["hook"] == "card_drawn")
    _assert_equal(drawn_calls.size(), 10, "每张实际进入手牌的真气触发一次 card_drawn")
    _assert_true(
        drawn_calls.all(func(call):
            return call["typed_context"] and call["draw_reason"] == "normal_draw"),
        "card_drawn 使用有界 Context 并携带 draw_reason")
    var events_before_preview := handler.calls.filter(
        func(call): return call["kind"] == "event").size()
    var counter_before_preview: Dictionary = (
        engine.player.battle_passive_counter_store.capture_state())
    var preview_one: Dictionary = engine.preview([str(engine.player.hand[0].id)])
    var preview_two: Dictionary = engine.preview([str(engine.player.hand[0].id)])
    _assert_true(preview_one["valid"] and preview_two["valid"], "重复预览纯查询成功")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "event").size(),
        events_before_preview,
        "preview 与 AI 候选式枚举不触发已提交事件")
    _assert_equal(
        engine.player.battle_passive_counter_store.capture_state(),
        counter_before_preview,
        "重复预览不修改战斗临时计数")
    _assert_equal(
        preview_one["values"]["passive_power_queries"]["base_fixed"]["effective_value"],
        1,
        "power_base_fixed_query 只归并 base_fixed 阶段输入")
    _assert_equal(
        preview_one["values"]["passive_power_queries"]["multiplier_bonus"]["effective_value"],
        1,
        "power_multiplier_bonus_query 固定为第二阶段")
    _assert_equal(
        preview_one["values"]["passive_power_queries"]["power_fixed"]["effective_value"],
        3,
        "power_fixed_query 固定为第三阶段")
    _assert_equal(
        preview_one["values"]["passive_power_queries"]["power_amp_percent"]["effective_value"],
        10,
        "power_amp_percent_query 固定为第四阶段")
    _assert_true(
        handler.calls.filter(func(call): return call["kind"] == "query").all(
            func(call): return not call["persistent_mutation_available"] \
                and not call["battle_mutation_available"]),
        "所有战斗整数查询只获得两类只读计数端口")

    var played_card = engine.player.hand[0]
    var play_result: Dictionary = engine.confirm_play([str(played_card.id)])
    _assert_true(play_result.get("success", false), "实际行动完成确认与结算")
    var confirmed_calls := handler.calls.filter(
        func(call): return call["kind"] == "event" \
            and call["hook"] == "action_confirmed" \
            and call["actor_id"] == "player")
    var resolved_calls := handler.calls.filter(
        func(call): return call["kind"] == "event" \
            and call["hook"] == "action_resolved" \
            and call["actor_id"] == "player")
    _assert_equal(confirmed_calls.size(), 1, "主行动组 action_confirmed 只提交一次")
    _assert_equal(resolved_calls.size(), 1, "主行动组 action_resolved 只提交一次")
    _assert_equal(
        confirmed_calls[0]["action_token"], resolved_calls[0]["action_token"],
        "确认与完成共享同一稳定行动 token")
    _assert_true(
        bool(play_result["preview"].get("passive_action_confirmed", false)),
        "行动记录保存正式确认冻结标记")
    _assert_true(
        not play_result["preview"]["values"]["passive_power_queries"].is_empty(),
        "正式确认值保留四阶段来源明细与指纹")
    var normal_entered := handler.calls.filter(
        func(call): return call["kind"] == "event" \
            and call["hook"] == "card_entered_discard" \
            and call["card_instance_id"] == str(played_card.id))
    _assert_equal(normal_entered.size(), 1, "正常打出只触发一次 entered_discard")
    _assert_true(normal_entered[0]["normal_play"], "正常入堆 Context 标记 normal_play")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "card_explicitly_discarded" \
            and call["card_instance_id"] == str(played_card.id)).size(),
        0,
        "正常打出不触发 explicitly_discarded")
    var normal_enter_index := handler.calls.find(normal_entered[0])
    var resolved_index := handler.calls.find(resolved_calls[0])
    _assert_true(
        normal_enter_index < resolved_index \
            and engine.player.staging.is_empty(),
        "action_resolved 位于卡牌入堆和 group_end 序列处理之后")

    var explicit_card = engine.player.hand[0]
    var event_count_before_discard := handler.calls.size()
    var discarded: Array = engine.player.discard_all()
    _assert_true(discarded.has(explicit_card), "明确弃牌移动成功")
    var explicit_slice: Array = handler.calls.slice(event_count_before_discard).filter(
        func(call): return call["kind"] == "event" \
            and call["hook"] in [
                "card_entered_discard", "card_explicitly_discarded"] \
            and call["card_instance_id"] == str(explicit_card.id))
    _assert_equal(
        explicit_slice.map(func(call): return call["hook"]),
        ["card_entered_discard", "card_explicitly_discarded"],
        "明确弃牌固定先 entered_discard 后 explicitly_discarded")
    _assert_true(
        explicit_slice.all(func(call):
            return call["explicit_discard"] and call["from_zone"] == "hand"),
        "明确弃牌 Context 携带来源区与语义标志")

    var defense_events_before := handler.calls.filter(
        func(call): return call["kind"] == "event" and call["hook"] == "defense_gained").size()
    var defense_before: int = int(engine.player.defense)
    var gained: int = int(engine.effect_ports.add_defense(
        engine.player, 2, "test_defense", "defense-action"))
    _assert_equal(gained, 6, "正式防御增加经过 defense_gain_query")
    var defense_call: Dictionary = handler.calls.filter(
        func(call): return call["kind"] == "event" \
            and call["hook"] == "defense_gained")[-1]
    _assert_equal(defense_call["requested_amount"], 2, "防御事件记录请求值")
    _assert_equal(defense_call["effective_amount"], 6, "防御事件记录实际增加值")
    _assert_equal(defense_call["defense_before"], defense_before, "防御事件记录写入前值")
    _assert_equal(defense_call["defense_after"], defense_before + 6, "防御事件记录写入后值")
    engine.effect_ports.add_defense(engine.player, 0, "zero_defense")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "defense_gained").size(),
        defense_events_before + 1,
        "请求或最终增加为零时不触发 defense_gained")

    engine.enemy.life = 100
    engine.enemy.defense = 5
    var ordinary_hit: Dictionary = engine.deal_damage(
        engine.player, engine.enemy, 10, "test_damage")
    _assert_equal(ordinary_hit["final_amount"], 15, "普通伤害依次经过 status/outgoing/incoming")
    _assert_equal(ordinary_hit["defense_lost"], 5, "普通伤害写入后记录实际防御损失")
    _assert_equal(ordinary_hit["life_lost"], 10, "普通伤害写入后记录实际生命损失")
    var damage_calls := handler.calls.filter(
        func(call): return call["kind"] == "event" \
            and call["hook"] == "damage_resolved" \
            and call["requested_amount"] == 10)
    _assert_equal(damage_calls.size(), 2, "造成方与受击方来源都接收 damage_resolved")
    _assert_true(
        damage_calls.all(func(call): return call["final_amount"] == 15),
        "damage_resolved Context 携带最终实际伤害")
    var normal_query_count := handler.calls.filter(
        func(call): return call["kind"] == "query" \
            and call["hook"] in ["outgoing_damage_query", "incoming_damage_query"]).size()
    engine.deal_damage(engine.player, engine.enemy, 4, "test_true", true)
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "query" \
            and call["hook"] in ["outgoing_damage_query", "incoming_damage_query"]).size(),
        normal_query_count,
        "真实伤害不进入普通伤害查询")
    _assert_true(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "damage_resolved")[-1]["true_damage"],
        "真实伤害仍在实际写入后提交 damage_resolved")

    var sync_events_before := handler.calls.filter(
        func(call): return call["kind"] == "event" and call["hook"] == "damage_resolved").size()
    var sync_queries_before := handler.calls.filter(
        func(call): return call["kind"] == "query" \
            and call["hook"] in ["outgoing_damage_query", "incoming_damage_query"]).size()
    engine.begin_synchronized_damage([{"actor": engine.player}])
    engine.deal_damage(engine.player, engine.enemy, 7, "sync_probe")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "damage_resolved").size(),
        sync_events_before,
        "同步伤害 shadow preview 不提交 damage_resolved")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "query" \
            and call["hook"] in ["outgoing_damage_query", "incoming_damage_query"]).size(),
        sync_queries_before,
        "同步 shadow 不执行动态伤害查询")
    _assert_true(engine.flush_synchronized_damage().get("success", false),
        "同步伤害结构化 flush 成功")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "query" \
            and call["hook"] in ["outgoing_damage_query", "incoming_damage_query"]).size(),
        sync_queries_before + 2,
        "同步伤害只在实际 flush 执行一次 outgoing/incoming")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "damage_resolved").size(),
        sync_events_before + 2,
        "flush 后双方来源各接收一次实际 damage_resolved")
    _assert_true(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "damage_resolved")[-1]["synchronized"],
        "同步实际事件明确标记 synchronized")

    engine.player.defense = 3
    var retention: Dictionary = engine.defense_retention_policy.apply_decay(
        engine.player, {"round_number": engine.turn_number})
    _assert_equal(retention["retention_percent"], 100, "保留率基础 50 经 Fake Handler 得到 100")
    _assert_equal(engine.player.defense, 3, "有效保留率 100 时防御完全不衰减")
    var snapshot = BattleSessionScript.new(engine).snapshot()
    _assert_equal(snapshot.player.base_hand_limit, 8, "战斗快照公开基础手牌上限")
    _assert_equal(snapshot.player.hand_limit, 10, "战斗快照与 AI/UI 共用有效手牌上限")

    var duplicate_token := "f5d2-duplicate-event"
    var duplicate_values := {
        "event_token": duplicate_token,
        "actor": engine.player, "owner": engine.player,
        "action_token": "duplicate-action",
    }
    var persistent_before_duplicate: Dictionary = (
        engine.player.passive_counter_store.capture_state())
    var first_duplicate: Dictionary = engine.battle_passive_event_service.commit(
        "action_confirmed", duplicate_values)
    var state_after_duplicate: Dictionary = (
        engine.player.passive_counter_store.capture_state())
    var second_duplicate: Dictionary = engine.battle_passive_event_service.commit(
        "action_confirmed", duplicate_values)
    _assert_true(first_duplicate["success"] and second_duplicate["reused"], "稳定 token 去重重复 finalizer")
    _assert_true(
        persistent_before_duplicate != state_after_duplicate \
            and engine.player.passive_counter_store.capture_state() == state_after_duplicate,
        "重复提交不重复增长持久计数")

    engine.apply_passive_suppression({
        "suppression_id": "f5d2-suppression",
        "target_content_id": "f5d2_probe",
        "blocked_hooks": ["hand_limit_query", "card_drawn"],
        "reason": "F5D2 测试压制",
    })
    _assert_equal(engine.player.current_hand_limit(), 8, "被压制来源不参与查询")
    var draw_events_before_suppressed := handler.calls.filter(
        func(call): return call["kind"] == "event" and call["hook"] == "card_drawn").size()
    engine.effect_ports.draw(engine.player, 1, "suppressed_draw")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "card_drawn").size(),
        draw_events_before_suppressed,
        "被压制来源不接收已提交事件")
    engine.remove_passive_suppression("f5d2-suppression")
    _assert_equal(engine.player.current_hand_limit(), 10, "解除压制后查询恢复")

    var repeat_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_probe", "f5d2_repeat_probe"])
    var repeat_limit: Dictionary = repeat_engine.player.effective_hand_limit_result()
    _assert_equal(repeat_limit["effective_value"], 12, "额外 Invocation 在来源位置连续归并")
    _assert_equal(
        repeat_limit["source_breakdown"].size(), 2,
        "额外 Invocation 不递归增加执行次数")

    var cooperation_main := [
        _card("6", "wind"), _card("6", "forest"), _card("6", "fire")]
    var cooperation_cards := [_card("4", "wind"), _card("4", "mountain")]
    var cooperation_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_probe"])
    cooperation_engine.player.hand = cooperation_main + cooperation_cards
    cooperation_engine.player.draw_pile.clear()
    cooperation_engine.actions_available = 1
    cooperation_engine.repository.techniques["f5d2_cooperation_main"] = {
        "id": "f5d2_cooperation_main", "name": "F5D2 协同主组",
        "pool": "three", "effects": [],
        "cooperation": {
            "hand_id": "pair", "max_groups": 1,
            "power_rule": "shared_half",
            "post_commit": {"destination": "own_discard"},
        },
    }
    cooperation_engine.repository.techniques["f5d2_cooperation_pair"] = {
        "id": "f5d2_cooperation_pair", "name": "F5D2 协同组",
        "pool": "pair", "effects": [],
    }
    cooperation_engine.sequence_book.configure({
        "three_kind": ["f5d2_cooperation_main"],
        "pair": ["f5d2_cooperation_pair"],
    })
    handler.calls.clear()
    var cooperation_result: Dictionary = cooperation_engine.confirm_play(
        _ids(cooperation_main), _ids(cooperation_cards))
    _assert_true(cooperation_result.get("success", false), "协同实际路径结算成功")
    var cooperation_confirmed := handler.calls.filter(
        func(call): return call["kind"] == "event" and call["hook"] == "action_confirmed")
    var cooperation_resolved := handler.calls.filter(
        func(call): return call["kind"] == "event" and call["hook"] == "action_resolved")
    _assert_equal(cooperation_confirmed.size(), 2, "主组与协同组分别确认一次")
    _assert_equal(cooperation_resolved.size(), 2, "主组与协同组分别完成一次")
    _assert_true(
        cooperation_confirmed[0]["action_token"] != cooperation_confirmed[1]["action_token"],
        "协同组拥有独立 action token 与冻结值")

    var wait_selected = _card("8", "wind")
    var wait_reserve = _card("3", "forest")
    var wait_reserve_second = _card("5", "fire")
    var wait_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_probe"])
    wait_engine.player.hand = [wait_selected, wait_reserve, wait_reserve_second]
    wait_engine.player.draw_pile.clear()
    wait_engine.actions_available = 1
    wait_engine.repository.techniques["f5d2_wait_probe"] = {
        "id": "f5d2_wait_probe", "name": "F5D2 等待探针", "pool": "high",
        "effects": [{
            "op": "select_cards", "choice_id": "wait_once",
            "prompt": "请选择保留手牌", "chooser": "actor",
            "minimum": 1, "maximum": 1,
            "insufficient_policy": "fail",
            "query": {"side": "actor", "zone": "hand", "order": "zone"},
            "capture": "waited",
        }],
    }
    wait_engine.sequence_book.configure({"high_card": ["f5d2_wait_probe"]})
    var wait_permission_calls: Array = []
    wait_engine.battle_permission_service.register_provider(
        func(hook, _context):
            wait_permission_calls.append(hook)
            return {"allowed": true},
        "f5f_wait_permission_probe", 10,
        ["technique_activation_permission_query"])
    handler.calls.clear()
    var wait_start: Dictionary = wait_engine.confirm_play([str(wait_selected.id)])
    _assert_true(
        wait_start.get("pending_choice", false),
        "行动进入等待选择：%s" % str(wait_start))
    var wait_confirmed_before := handler.calls.filter(
        func(call): return call["kind"] == "event" and call["hook"] == "action_confirmed").size()
    var wait_power_query_before := handler.calls.filter(
        func(call): return call["kind"] == "query" \
            and str(call["hook"]) in [
                "power_base_fixed_query", "power_multiplier_bonus_query",
                "power_fixed_query", "power_amp_percent_query"] \
            and str(call["action_token"]) != "").size()
    var wait_permission_before: int = wait_permission_calls.size()
    var wait_request: Dictionary = wait_start["choice_request"]
    var wait_finish: Dictionary = wait_engine.resolve_effect_choice(
        str(wait_request["request_id"]), [str(wait_reserve.id)])
    _assert_true(wait_finish.get("success", false), "等待选择恢复后完成行动")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "event" \
            and call["hook"] == "action_confirmed").size(),
        wait_confirmed_before,
        "等待恢复不重复 action_confirmed")
    _assert_equal(
        handler.calls.filter(func(call): return call["kind"] == "query" \
            and str(call["hook"]) in [
                "power_base_fixed_query", "power_multiplier_bonus_query",
                "power_fixed_query", "power_amp_percent_query"] \
            and str(call["action_token"]) != "").size(),
        wait_power_query_before,
        "等待恢复复用已冻结四阶段功法值")
    _assert_equal(
        wait_permission_calls.size(), wait_permission_before,
        "等待功法目标选择恢复不重复查询启动权限")

    var hand_failure_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_hand_query_failure"])
    var failed_draw: Array = hand_failure_engine.start_player_turn()
    _assert_true(failed_draw.is_empty(), "hand_limit 查询失败时不补牌")
    _assert_equal(hand_failure_engine.player.hand.size(), 0, "失败前未修改手牌")
    _assert_equal(hand_failure_engine.battle_state, "scenario_error", "手牌查询失败进入 scenario_error")

    var defense_failure_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_defense_query_failure"])
    var defense_failure_before: int = int(defense_failure_engine.player.defense)
    _assert_equal(
        defense_failure_engine.effect_ports.add_defense(
            defense_failure_engine.player, 5, "failure_probe"),
        0,
        "defense_gain 查询失败返回零实际增加")
    _assert_equal(
        defense_failure_engine.player.defense,
        defense_failure_before,
        "defense_gain 查询失败发生在防御写入前")
    _assert_equal(defense_failure_engine.battle_state, "scenario_error", "防御查询失败进入 scenario_error")

    var power_failure_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_power_query_failure"])
    power_failure_engine.start_player_turn()
    var power_failure_card = power_failure_engine.player.hand[0]
    var power_failure_actions: int = int(power_failure_engine.actions_available)
    var power_failure_sequence: Dictionary = (
        power_failure_engine.sequence_book.positions.duplicate(true))
    var power_failure_result: Dictionary = power_failure_engine.confirm_play([
        str(power_failure_card.id)])
    _assert_true(not power_failure_result.get("success", true), "正式确认 power 查询失败拒绝行动")
    _assert_true(power_failure_engine.player.hand.has(power_failure_card), "功法查询失败后卡牌返回手牌")
    _assert_true(power_failure_engine.player.staging.is_empty(), "功法查询失败不保留待出区卡牌")
    _assert_equal(power_failure_engine.actions_available, power_failure_actions, "功法查询失败不消耗行动次数")
    _assert_equal(power_failure_engine.sequence_book.positions, power_failure_sequence, "功法查询失败不推进功法序列")
    _assert_equal(power_failure_engine.battle_state, "active", "功法确认查询失败保持行动窗口可重试")

    var damage_failure_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_damage_query_failure"])
    var damage_failure_life: int = int(damage_failure_engine.enemy.life)
    var damage_failure_defense: int = int(damage_failure_engine.enemy.defense)
    var damage_failure_result: Dictionary = damage_failure_engine.deal_damage(
        damage_failure_engine.player, damage_failure_engine.enemy, 9, "failure_probe")
    _assert_true(not damage_failure_result.get("success", true), "伤害查询失败拒绝实际伤害")
    _assert_equal(damage_failure_engine.enemy.life, damage_failure_life, "伤害查询失败不写生命")
    _assert_equal(damage_failure_engine.enemy.defense, damage_failure_defense, "伤害查询失败不写防御")
    _assert_equal(damage_failure_engine.battle_state, "scenario_error", "伤害查询失败进入 scenario_error")

    var retention_failure_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_retention_query_failure"])
    retention_failure_engine.player.defense = 7
    var retention_failure: Dictionary = (
        retention_failure_engine.defense_retention_policy.apply_decay(
            retention_failure_engine.player, {"round_number": 1}))
    _assert_true(not retention_failure.get("success", true), "防御保留率查询失败拒绝衰减")
    _assert_equal(retention_failure_engine.player.defense, 7, "保留率查询失败保持原防御")
    _assert_equal(retention_failure_engine.battle_state, "scenario_error", "保留率查询失败进入 scenario_error")

    var mutation_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_query_mutation"])
    var mutation_card = mutation_engine.player.draw_pile[0]
    var mutation_card_state := {
        "enhancement": str(mutation_card.reshape_enhancement),
        "anomalies": mutation_card.anomalies.duplicate(true),
    }
    var mutation_defense: int = int(mutation_engine.player.defense)
    var mutation_delays: Array = (
        mutation_engine.status_system.delayed_records.duplicate(true))
    var mutation_rng_state: int = int(mutation_engine.rng.state)
    var mutation_query: Dictionary = (
        mutation_engine.player.effective_hand_limit_result())
    _assert_true(
        not mutation_query.get("success", true),
        "纯查询修改战斗状态时整个查询失败")
    _assert_equal(
        mutation_engine.player.defense, mutation_defense,
        "违规查询修改的防御被恢复")
    _assert_equal(
        {
            "enhancement": str(mutation_card.reshape_enhancement),
            "anomalies": mutation_card.anomalies.duplicate(true),
        }, mutation_card_state,
        "违规查询修改的卡牌重塑与异状被恢复")
    _assert_equal(
        mutation_engine.status_system.delayed_records, mutation_delays,
        "违规查询写入的延迟状态被恢复")
    _assert_equal(
        mutation_engine.rng.state, mutation_rng_state,
        "违规查询推进的战斗 RNG 被恢复")
    _assert_equal(
        mutation_engine.battle_state, "scenario_error",
        "纯查询违规进入 scenario_error")

    var event_failure_engine = _battle_passive_test_engine(
        catalog, registry, ["f5d2_event_failure", "f5d2_repeat_failure"])
    var failure_result: Dictionary = event_failure_engine.battle_passive_event_service.commit(
        "action_confirmed", {
            "event_token": "f5d2-failure-token",
            "actor": event_failure_engine.player,
            "owner": event_failure_engine.player,
            "action_token": "f5d2-failure-action",
        })
    _assert_true(not failure_result.get("success", true), "第二个 Invocation 失败终止已提交事件")
    _assert_true(
        event_failure_engine.player.passive_counter_store.capture_state()["entries"].is_empty(),
        "事件失败回滚持久计数器")
    _assert_true(
        event_failure_engine.player.battle_passive_counter_store.capture_state()["entries"].is_empty(),
        "事件失败回滚战斗临时计数器")
    _assert_equal(event_failure_engine.battle_state, "scenario_error", "事件失败进入 scenario_error")

func _test_unified_passive_effect_execution() -> void:
    _assert_unified_passive_effect_entry()
func _test_effect_source_neutrality_runtime_paths() -> void:
    var registry = PassiveRuleHandlerRegistryScript.new()
    var shared_effects := [
        {"op": "damage", "amount": {"kind": "constant", "value": 2}},
        {"op": "draw", "count": 1, "capture": "source_drawn"},
        {
            "op": "apply_card_anomaly_to_captured",
            "capture": "source_drawn",
            "category": "mark",
            "anomaly": "return_to_origin",
            "result_capture": "source_marked",
        },
        {
            "op": "move_captured",
            "capture": "source_drawn",
            "from_zone": "hand",
            "to_zone": "discard_pile",
            "reason": "explicit_discard",
            "result_capture": "source_moved",
        },
    ]
    var inner_definition := {
        "id": "source_neutral_inner",
        "name": "来源中立内功",
        "status": "candidate",
        "behaviors": [{
            "id": "on_play_effects",
            "configuration": {"effects": shared_effects.duplicate(true)},
        }],
    }
    var item_definition := {
        "id": "source_neutral_item",
        "name": "来源中立物品",
        "kind": "item",
        "status": "candidate",
        "unique": true,
        "description": "仅用于统一效果来源正式行动路径测试。",
        "price": 1,
        "behaviors": [{
            "id": "on_play_effects",
            "configuration": {"effects": shared_effects.duplicate(true)},
        }],
    }
    var catalog_result := _battle_passive_test_catalog(
        registry, [item_definition], [inner_definition])
    _assert_true(
        catalog_result["success"],
        "统一来源内功与物品内容通过共享效果校验：%s" % str(
            catalog_result["catalog"].errors))
    if not catalog_result["success"]:
        return
    var catalog = catalog_result["catalog"]

    for source_case in [
            {
                "kind": "inner_skill",
                "id": "source_neutral_inner",
                "name": "来源中立内功",
                "items": [],
                "inner_skills": ["source_neutral_inner"],
            },
            {
                "kind": "item",
                "id": "source_neutral_item",
                "name": "来源中立物品",
                "items": ["source_neutral_item"],
                "inner_skills": [],
            },
        ]:
        var engine = _battle_passive_test_engine(
            catalog, registry, source_case["items"], source_case["inner_skills"])
        engine.sequence_book.configure({
            "high_card": ["high_wind_three_breath_return"],
        })
        var wind_slot: Dictionary = engine.sequence_book.current_slot("high_card")
        var wind_slot_id := str(wind_slot.get("slot_instance_id", ""))
        var committed_events: Array = []
        engine.battle_passive_event_service.event_committed.connect(
            func(kind: String, values: Dictionary, _receipt: Dictionary):
                if str(values.get("source_id", "")) == str(source_case["id"]):
                    committed_events.append({
                        "kind": kind,
                        "values": values.duplicate(true),
                    }))
        engine.start_player_turn()
        var selected = engine.player.hand[0]
        engine.actions_available = 1
        var result: Dictionary = engine.confirm_play([str(selected.id)])
        _assert_true(
            result.get("success", false),
            "%s on_play_effects 通过真实出牌路径完成" % source_case["kind"])

        for event_kind in ["damage_resolved", "card_drawn", "card_entered_discard"]:
            var matching: Array = committed_events.filter(
                func(entry): return str(entry["kind"]) == event_kind)
            _assert_equal(
                matching.size(), 1,
                "%s 正式路径提交一次 %s" % [source_case["kind"], event_kind])
            if matching.is_empty():
                continue
            var values: Dictionary = matching[0]["values"]
            _assert_equal(
                str(values.get("source_kind", "")), str(source_case["kind"]),
                "%s 的 %s 保留统一来源类别" % [source_case["kind"], event_kind])
            _assert_equal(
                str(values.get("source_name", "")), str(source_case["name"]),
                "%s 的 %s 保留来源名称" % [source_case["kind"], event_kind])
            _assert_true(
                str(values.get("source_instance_key", "")).contains(
                    str(source_case["id"])),
                "%s 的 %s 公开稳定来源实例键" % [source_case["kind"], event_kind])
            _assert_equal(
                str(values.get("trigger_mode", "")), "manual",
                "%s 的 %s 把出牌触发方式与来源类别分离" % [
                    source_case["kind"], event_kind])

        _assert_equal(
            engine.effect_ports.technique_draw_count(engine.player), 0,
            "%s 抽牌不计入功法效果抽牌" % source_case["kind"])
        _assert_equal(
            engine.player.source_marker_store.value(
                "technique", wind_slot_id, "technique_draw_count", "battle"),
            0,
            "三息回风不被%s抽牌推进" % source_case["kind"])
        var anomaly_history: Array = engine.status_system.history_snapshot().filter(
            func(change):
                return str(change.get("change_type", "")) == "card_anomaly_apply" \
                    and str(change.get("status_id", "")) == "return_to_origin" \
                    and str(change.get("source", "")) == str(source_case["name"]))
        _assert_equal(
            anomaly_history.size(), 1,
            "%s 施加真气异状的状态日志不显示为功法" % source_case["kind"])
        if not anomaly_history.is_empty():
            _assert_equal(
                str(anomaly_history[0].get("metadata", {}).get(
                    "source_kind", "")),
                str(source_case["kind"]),
                "%s 异状日志元数据保留统一来源类别" % source_case["kind"])
        var source_damage_logs: Array = engine.trigger_queue.history.filter(
            func(entry):
                return str(entry.get("timing", "")) == "damage_segment" \
                    and str(entry.get("source", "")) == str(source_case["kind"]))
        _assert_equal(
            source_damage_logs.size(), 1,
            "%s 伤害日志来源不显示为 technique" % source_case["kind"])
        _dispose_source_neutrality_engine(engine)

    var invalid_values: Dictionary = catalog_result["base_values"].duplicate(true)
    invalid_values["items"]["items"].append({
        "id": "invalid_item_source_marker",
        "name": "非法物品来源标识",
        "kind": "item",
        "status": "candidate",
        "unique": true,
        "description": "应被内容校验明确拒绝。",
        "price": 1,
        "behaviors": [{
            "id": "on_play_effects",
            "configuration": {"effects": [{
                "op": "write_source_marker",
                "marker_id": "invalid_item_marker",
                "operation": "add",
                "amount": 1,
            }]},
        }],
    })
    var invalid_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(
        not invalid_catalog.load_from_definitions(
            invalid_values, catalog_result["paths"]),
        "物品未声明来源标识在内容校验阶段明确拒绝")
    _assert_true(
        "\n".join(invalid_catalog.errors).contains(
            "物品只能读写自身已声明的 marker"),
        "物品未声明来源标识拒绝诊断不允许静默降级")

func _dispose_source_neutrality_engine(engine) -> void:
    engine.battle_passive_timing_bridge.close_battle()
    engine.battle_passive_event_service.close_battle()
    engine.passive_rule_runtime.close_battle_effect_commands()
    engine.effect_ports.use_hand_retrigger_callback(Callable())
    engine.battle_passive_event_service._scenario_error = Callable()
    engine.battle_rule_query_service._scenario_error = Callable()
    engine.passive_rule_runtime._battle_effect_scenario_error = Callable()
    engine.player.use_committed_event_service(null)
    engine.enemy.use_committed_event_service(null)
    engine.player.use_battle_rule_query_service(null)
    engine.enemy.use_battle_rule_query_service(null)
    engine.player.use_status_system(null)
    engine.enemy.use_status_system(null)
    engine.player.use_card_state_lifecycle(null)
    engine.enemy.use_card_state_lifecycle(null)
    engine.player.use_card_reshape_runtime(null)
    engine.enemy.use_card_reshape_runtime(null)
    engine.player.use_card_policies(null, null)
    engine.enemy.use_card_policies(null, null)
    engine.player.use_battle_permission_service(null)
    engine.enemy.use_battle_permission_service(null)
    engine.status_system.reset()
    engine.status_system.use_effect_ports(null)
    engine.status_system.use_effect_executor(null)
    engine.status_system.use_card_trigger_replay_service(null)
    engine.status_system.use_battle_permission_service(null)
    engine.effect_ports._sides.clear()

func _assert_unified_passive_effect_entry() -> void:
    var registry = PassiveRuleHandlerRegistryScript.new()
    _assert_true(registry.has_handler("battle_effects"),
        "默认注册来源中立 battle_effects 行为")
    var shared_damage_and_draw := [
        {"op": "damage", "from_side": "owner", "to_side": "opponent",
            "amount": 4},
        {"op": "draw", "side": "owner", "count": 1},
    ]
    var standard_effects := [
        {"op": "capture_query", "capture": "picked", "query": {
            "side": "owner", "zone": "hand", "order": "left", "limit": 1,
            "filters": {},
        }},
        {"op": "apply_card_anomaly_to_captured", "capture": "picked",
            "category": "mark", "anomaly": "return_to_origin",
            "when": {"capture_nonempty": "picked"}},
        {"op": "move_captured", "capture": "picked",
            "from_side": "owner", "to_side": "owner",
            "from_zone": "hand", "to_zone": "discard_pile",
            "reason": "explicit_discard",
            "when": {"capture_nonempty": "picked"}},
        {"op": "defense", "side": "owner", "amount": {
            "kind": "event_field", "field": "requested_amount"},
            "when": {"value_at_least": {
                "value": {"kind": "event_field", "field": "requested_amount"},
                "minimum": 3,
            }}},
        {"op": "write_momentum", "side": "owner",
            "operation": "add", "amount": 2},
        {"op": "write_same_qi", "side": "owner",
            "operation": "add", "amount": 1,
            "receipt_key": "unified_passive_probe"},
    ]
    var inner_damage := _standard_passive_inner(
        "anonymous_inner_damage", "action_resolved",
        shared_damage_and_draw)
    var item_damage := _standard_passive_item(
        "anonymous_item_damage", "action_resolved",
        shared_damage_and_draw)
    var lifecycle_item := _standard_passive_item(
        "anonymous_lifecycle_item", "battle_start", [
            {"op": "draw", "side": "owner", "count": 1},
            {"op": "defense", "side": "owner", "amount": 2},
        ], 25)
    var lifecycle_inner := _standard_passive_inner(
        "anonymous_lifecycle_inner", "battle_start", [
            {"op": "draw", "side": "owner", "count": 1},
            {"op": "defense", "side": "owner", "amount": 2},
        ], 25)
    var standard_item := _standard_passive_item(
        "anonymous_standard_ops", "action_confirmed", standard_effects)
    var preview_item := _standard_passive_item(
        "anonymous_preview", "action_resolve", [
            {"op": "defense", "side": "owner", "amount": 5},
        ])
    var duplicate_item := _standard_passive_item(
        "anonymous_duplicate_item", "action_resolved", [
            {"op": "defense", "side": "owner", "amount": 1},
        ])
    var duplicate_item_second := _standard_passive_item(
        "anonymous_duplicate_item_second", "action_resolved", [
            {"op": "defense", "side": "owner", "amount": 1},
        ])
    var duplicate_inner := _standard_passive_inner(
        "anonymous_duplicate_inner", "action_resolved", [
            {"op": "defense", "side": "owner", "amount": 1},
        ])
    var receipt_item := _standard_passive_item(
        "anonymous_receipt", "action_confirmed", [
            {"op": "defense", "side": "owner", "amount": 3},
        ])
    var failure_item := _standard_passive_item(
        "anonymous_failure", "action_confirmed", [
            {"op": "select_cards", "choice_id": "must_fail",
                "prompt": "必须有一张牌", "chooser": "owner",
                "minimum": 1, "maximum": 1, "insufficient_policy": "fail",
                "query": {"side": "owner", "zone": "hand",
                    "order": "zone", "filters": {}},
                "capture": "selected"},
            {"op": "defense", "side": "owner", "amount": 99},
        ])
    var overflow_effects: Array = []
    for _index in range(65):
        overflow_effects.append({
            "op": "defense", "side": "owner", "amount": 0})
    var overflow_item := _standard_passive_item(
        "anonymous_overflow", "action_confirmed", overflow_effects)
    var waiting_item := _standard_passive_item(
        "anonymous_waiting", "action_resolve", [
            {"op": "discard_random", "side": "owner", "count": 1,
                "capture": "random_discarded"},
            {"op": "select_cards", "choice_id": "resume_once",
                "prompt": "选择一张剩余手牌", "chooser": "owner",
                "minimum": 1, "maximum": 1, "insufficient_policy": "fail",
                "query": {"side": "owner", "zone": "hand",
                    "order": "zone", "filters": {}},
                "capture": "selected"},
        ])
    var catalog_result := _battle_passive_test_catalog(registry, [
        item_damage, lifecycle_item, standard_item, preview_item,
        duplicate_item, duplicate_item_second, receipt_item, failure_item,
        overflow_item, waiting_item,
    ], [inner_damage, lifecycle_inner, duplicate_inner])
    _assert_true(catalog_result["success"],
        "匿名通用被动效果内容通过同一 EffectSpecValidator：%s" % str(
            catalog_result["catalog"].errors))
    if not catalog_result["success"]:
        return
    var catalog = catalog_result["catalog"]

    var technique_engine = _battle_passive_test_engine(catalog, registry, [])
    var technique_events: Array = []
    var technique_draw_events: Array = []
    technique_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "damage_resolved" \
                    and str(values.get("source_id", "")) == "anonymous_technique":
                technique_events.append(values.duplicate(true))
            if kind == "card_drawn" \
                    and str(values.get("source_id", "")) == "anonymous_technique":
                technique_draw_events.append(values.duplicate(true)))
    var technique_life_before := int(technique_engine.enemy.life)
    var technique_context = TechniqueEffectContextScript.new().configure({
        "ports": technique_engine.effect_ports,
        "actor": technique_engine.player,
        "target": technique_engine.enemy,
        "owner": technique_engine.player,
        "opponent": technique_engine.enemy,
        "action_token": "anonymous-technique-action",
        "source_kind": "technique",
        "source_id": "anonymous_technique",
        "source_name": "匿名功法",
        "source_instance_key": "technique:anonymous_technique",
        "trigger_mode": "manual",
    })
    _assert_true(technique_engine.effect_executor.execute_all(
        shared_damage_and_draw, technique_context).get("success", false),
        "匿名功法执行共享 damage 与 draw")
    _assert_equal(technique_life_before - technique_engine.enemy.life, 4,
        "功法共享 damage 领域结果为4")
    _assert_equal(technique_events.size(), 1, "功法共享 damage 提交一次来源事件")
    _assert_equal(technique_draw_events.size(), 1,
        "功法共享 draw 提交一次来源事件")
    _assert_equal(technique_engine.effect_ports.technique_draw_count(
        technique_engine.player), 1, "只有功法来源抽牌计入功法抽牌")
    _dispose_source_neutrality_engine(technique_engine)

    for source_case in [
            ["inner_skill", "anonymous_inner_damage", [],
                ["anonymous_inner_damage"]],
            ["item", "anonymous_item_damage", ["anonymous_item_damage"], []],
        ]:
        var engine = _battle_passive_test_engine(
            catalog, registry, source_case[2], source_case[3])
        var damage_events: Array = []
        var draw_events: Array = []
        engine.battle_passive_event_service.event_committed.connect(
            func(kind: String, values: Dictionary, _receipt: Dictionary):
                if kind == "damage_resolved" \
                        and str(values.get("source_id", "")) == source_case[1]:
                    damage_events.append(values.duplicate(true))
                if kind == "card_drawn" \
                        and str(values.get("source_id", "")) == source_case[1]:
                    draw_events.append(values.duplicate(true)))
        var life_before := int(engine.enemy.life)
        var committed := _commit_f5e_probe_event(
            engine, "action_resolved", "anonymous-%s-damage" % source_case[0], {
                "actor": engine.player, "target": engine.enemy,
                "owner": engine.player,
                "action_token": "anonymous-%s-action" % source_case[0],
            })
        _assert_true(committed.get("success", false),
            "%s 已提交事件执行共享 damage" % source_case[0])
        _assert_equal(life_before - engine.enemy.life, 4,
            "%s 与功法共享相同伤害领域语义" % source_case[0])
        _assert_equal(damage_events.size(), 1,
            "%s 伤害只提交一次来源事件" % source_case[0])
        _assert_equal(draw_events.size(), 1,
            "%s 抽牌只提交一次来源事件" % source_case[0])
        _assert_equal(engine.effect_ports.technique_draw_count(engine.player), 0,
            "%s 共享 draw 不计入功法抽牌" % source_case[0])
        if not damage_events.is_empty():
            _assert_equal(str(damage_events[0].get("source_kind", "")),
                source_case[0], "%s 伤害保留独立来源类别" % source_case[0])
            _assert_equal(str(damage_events[0].get("trigger_mode", "")),
                "direct", "%s 已提交 Hook 使用 direct trigger_mode" % source_case[0])
        _dispose_source_neutrality_engine(engine)

    for lifecycle_case in [
            ["item", "anonymous_lifecycle_item",
                ["anonymous_lifecycle_item"], []],
            ["inner_skill", "anonymous_lifecycle_inner", [],
                ["anonymous_lifecycle_inner"]],
        ]:
        var lifecycle_engine = _battle_passive_test_engine(
            catalog, registry, lifecycle_case[2], lifecycle_case[3])
        var lifecycle_draw_events: Array = []
        lifecycle_engine.battle_passive_event_service.event_committed.connect(
            func(kind: String, values: Dictionary, _receipt: Dictionary):
                if kind == "card_drawn" \
                        and str(values.get("source_id", "")) == lifecycle_case[1]:
                    lifecycle_draw_events.append(values.duplicate(true)))
        lifecycle_engine.start_player_turn()
        _assert_equal(lifecycle_engine.player.defense, 2,
            "%s 在生命周期 Hook 通过共享 defense 生效" % lifecycle_case[0])
        _assert_equal(lifecycle_draw_events.size(), 1,
            "%s 在生命周期 Hook 通过共享 draw 生效" % lifecycle_case[0])
        _assert_equal(lifecycle_engine.effect_ports.technique_draw_count(
            lifecycle_engine.player), 0,
            "%s 生命周期抽牌不计功法抽牌" % lifecycle_case[0])
        _dispose_source_neutrality_engine(lifecycle_engine)

    var standard_engine = _battle_passive_test_engine(
        catalog, registry, ["anonymous_standard_ops"])
    var standard_card = _card("7", "forest")
    standard_engine.player.hand = [standard_card]
    standard_engine.player.draw_pile.clear()
    var standard_result := _commit_f5e_probe_event(
        standard_engine, "action_confirmed", "anonymous-standard-event", {
            "actor": standard_engine.player, "target": standard_engine.enemy,
            "owner": standard_engine.player,
            "action_token": "anonymous-standard-action",
            "requested_amount": 3,
        })
    _assert_true(standard_result.get("success", false),
        "弃牌、牌区移动、异状、防御、连势和同气走共享效果链")
    _assert_true(standard_engine.player.discard_pile.has(standard_card),
        "TargetQuery 捕获后由 move_captured 移入弃牌堆")
    _assert_true(standard_card.has_anomaly("mark", "return_to_origin"),
        "被动来源正常执行共享异状 Handler")
    _assert_equal(standard_engine.player.defense, 3,
        "ValueSpec event_field 与 ConditionSpec 在被动来源下生效")
    _assert_equal(standard_engine.player.momentum_value, 2,
        "连势通过共享 write_momentum 生效")
    _assert_equal(standard_engine.player.same_qi_value, 1,
        "同气通过共享 write_same_qi 生效")
    _assert_true(not FileAccess.file_exists(
        "res://core/passives/battle_passive_effect_ports.gd"),
        "BattlePassiveEffectPorts 第二写入口已经删除")
    _dispose_source_neutrality_engine(standard_engine)

    var preview_engine = _battle_passive_test_engine(
        catalog, registry, ["anonymous_preview"])
    var preview_defense := int(preview_engine.player.defense)
    var preview_rng := int(preview_engine.rng.state)
    var preview_result: Dictionary = preview_engine.passive_rule_runtime.dispatch_event(
        "action_preview", {
            "owner": preview_engine.player,
            "actor": preview_engine.player,
            "target": preview_engine.enemy,
            "payload": {"effect_executor": preview_engine.effect_executor,
                "damage_percent": 0, "captures_by_source": {}},
        })
    _assert_true(preview_result.get("success", false),
        "action_preview 只生成共享效果意图")
    _assert_equal(preview_engine.player.defense, preview_defense,
        "action_preview 不写防御")
    _assert_equal(preview_engine.rng.state, preview_rng,
        "action_preview 不推进战斗 RNG")
    _assert_true(preview_result["results"][0]["result"]["intent"].get(
        "defense", 0) == 5, "action_preview 返回只读防御意图")
    _dispose_source_neutrality_engine(preview_engine)

    for duplicate_case in [
            [["anonymous_duplicate_item", "anonymous_duplicate_item_second"],
                [], "item"],
            [[], ["anonymous_duplicate_inner", "anonymous_duplicate_inner"],
                "inner_skill"],
        ]:
        var duplicate_engine = _battle_passive_test_engine(
            catalog, registry, duplicate_case[0], duplicate_case[1])
        var duplicate_result := _commit_f5e_probe_event(
            duplicate_engine, "action_resolved",
            "anonymous-duplicate-%s" % duplicate_case[2], {
                "actor": duplicate_engine.player,
                "target": duplicate_engine.enemy,
                "owner": duplicate_engine.player,
            })
        _assert_true(duplicate_result.get("success", false),
            "多副本%s分别建立 Invocation" % duplicate_case[2])
        _assert_equal(duplicate_engine.player.defense, 2,
            "多副本%s各执行一次共享效果" % duplicate_case[2])
        var duplicate_context = BattlePassiveCommittedEventContextScript.new().configure({
            "hook": "action_resolved", "event_kind": "action_resolved",
            "event_token": "anonymous-duplicate-plan-%s" % duplicate_case[2],
            "actor": duplicate_engine.player, "target": duplicate_engine.enemy,
            "owner": duplicate_engine.player,
        })
        var duplicate_plan = duplicate_engine.passive_rule_runtime.build_execution_plan(
            "action_resolved", duplicate_context)
        var keys: Array = duplicate_plan.invocations.map(
            func(invocation): return str(invocation.source.source_instance_key))
        _assert_equal(keys.size(), 2, "多副本%s建立两个 Invocation" % duplicate_case[2])
        if keys.size() == 2:
            _assert_true(keys[0] != keys[1],
                "多副本%s使用不同稳定实例键" % duplicate_case[2])
            if duplicate_case[2] == "item":
                _assert_equal(keys, [
                    "item:player:anonymous_duplicate_item",
                    "item:player:anonymous_duplicate_item_second",
                ], "多物品地址不依赖库存槽位且保持来源顺序")
            else:
                _assert_true(
                    keys[0].contains(":0:") and keys[1].contains(":1:"),
                    "多副本%s 按稳定槽位顺序建立 Invocation" % duplicate_case[2])
        _dispose_source_neutrality_engine(duplicate_engine)

    var receipt_engine = _battle_passive_test_engine(
        catalog, registry, ["anonymous_receipt"])
    var receipt_context = BattlePassiveCommittedEventContextScript.new().configure({
        "hook": "action_confirmed", "event_kind": "action_confirmed",
        "event_token": "anonymous-receipt-event",
        "action_token": "anonymous-receipt-action",
        "actor": receipt_engine.player, "target": receipt_engine.enemy,
        "owner": receipt_engine.player,
        "owner_id": receipt_engine.player.owner_id,
    })
    var receipt_plan = receipt_engine.passive_rule_runtime.build_execution_plan(
        "action_confirmed", receipt_context)
    var receipt_invocation = receipt_plan.invocations[0]
    var first_receipt: Dictionary = receipt_engine.passive_rule_runtime.execute_invocation(
        receipt_invocation, receipt_context.for_invocation(receipt_invocation),
        "mutation")
    var second_receipt: Dictionary = receipt_engine.passive_rule_runtime.execute_invocation(
        receipt_invocation, receipt_context.for_invocation(receipt_invocation),
        "mutation")
    _assert_true(first_receipt.get("success", false) \
            and second_receipt.get("success", false),
        "重复 Invocation 返回稳定成功收据")
    _assert_true(second_receipt["result"].get("reused", false),
        "重复 Invocation 复用标准效果收据")
    _assert_equal(receipt_engine.player.defense, 3,
        "稳定收据阻止标准效果重复写入")
    _dispose_source_neutrality_engine(receipt_engine)

    var failure_engine = _battle_passive_test_engine(
        catalog, registry, ["anonymous_failure"])
    failure_engine.player.hand.clear()
    failure_engine.player.draw_pile.clear()
    var failure_result := _commit_f5e_probe_event(
        failure_engine, "action_confirmed", "anonymous-failure-event", {
            "actor": failure_engine.player, "target": failure_engine.enemy,
            "owner": failure_engine.player,
        })
    _assert_true(not failure_result.get("success", true),
        "Effect Handler 失败终止当前 Invocation")
    _assert_equal(failure_engine.player.defense, 0,
        "失败后不执行同一 Invocation 的后续效果")
    _dispose_source_neutrality_engine(failure_engine)

    var overflow_engine = _battle_passive_test_engine(
        catalog, registry, ["anonymous_overflow"])
    var overflow_result := _commit_f5e_probe_event(
        overflow_engine, "action_confirmed", "anonymous-overflow-event", {
            "actor": overflow_engine.player, "target": overflow_engine.enemy,
            "owner": overflow_engine.player,
        })
    _assert_true(not overflow_result.get("success", true),
        "共享 EffectExecutor 保留单链64命令上限")
    _dispose_source_neutrality_engine(overflow_engine)

    var waiting_engine = _battle_passive_test_engine(
        catalog, registry, ["anonymous_waiting"])
    waiting_engine.start_player_turn()
    waiting_engine.actions_available = 1
    var waiting_selected = waiting_engine.player.hand[0]
    var waiting_start: Dictionary = waiting_engine.confirm_play([
        str(waiting_selected.id)])
    _assert_true(waiting_start.get("pending_choice", false),
        "action_resolve 通用被动效果可进入共享 continuation")
    if waiting_start.get("pending_choice", false):
        var discard_count: int = waiting_engine.player.discard_pile.size()
        var waiting_rng := int(waiting_engine.rng.state)
        var random_discarded_card = waiting_engine.player.discard_pile.back()
        var candidates: Array = waiting_start["choice_request"].get(
            "candidate_ids", [])
        var waiting_finish: Dictionary = waiting_engine.resolve_effect_choice(
            str(waiting_start["choice_request"]["request_id"]),
            [str(candidates[0])] if not candidates.is_empty() else [])
        _assert_true(waiting_finish.get("success", false),
            "等待选择从共享 EffectExecutor 恢复")
        _assert_equal(waiting_engine.player.discard_pile.size(), discard_count + 1,
            "恢复选择只提交行动牌，不重复执行前置随机弃牌")
        _assert_equal(waiting_engine.player.discard_pile.count(random_discarded_card), 1,
            "恢复选择不重复移动前置随机弃牌")
        _assert_equal(waiting_engine.rng.state, waiting_rng,
            "恢复选择不重掷统一战斗 RNG")
    _dispose_source_neutrality_engine(waiting_engine)

    var invalid_values: Dictionary = catalog_result["base_values"].duplicate(true)
    for invalid_definition in [
            _standard_passive_item("anonymous_invalid_op", "action_resolved", [
                {"op": "unknown_passive_effect"}]),
            _standard_passive_item("anonymous_invalid_value", "action_resolved", [
                {"op": "damage", "amount": {"kind": "unknown_value"}}]),
            _standard_passive_item("anonymous_invalid_condition", "action_resolved", [
                {"op": "damage", "amount": 1,
                    "when": {"unknown_condition": true}}]),
            _standard_passive_item("anonymous_invalid_target", "action_resolved", [
                {"op": "capture_query", "capture": "x", "query": {
                    "side": "owner", "zone": "hand", "order": "zone",
                    "filters": {"unknown_target_field": true}}}]),
            _standard_passive_item("anonymous_invalid_hook", "arbitrary_hook", [
                {"op": "defense", "amount": 1}]),
            _standard_passive_item("anonymous_invalid_phase", "action_resolved", [
                {"op": "defense", "phase": "prepare", "amount": 1}]),
            _standard_passive_item("anonymous_forged_source", "action_resolved", [
                {"op": "damage", "amount": 1,
                    "source_id": "forged", "event_token": "forged"}]),
        ]:
        invalid_values["items"]["items"].append(invalid_definition)
    var invalid_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    _assert_true(not invalid_catalog.load_from_definitions(
        invalid_values, catalog_result["paths"]),
        "非法 op、ValueSpec、ConditionSpec、TargetQuery、Hook 与伪造来源均在加载期失败")
    var invalid_text := "\n".join(invalid_catalog.errors)
    for expected_error in [
            "未知效果操作码", "未知数值规格 kind", "未知条件字段",
            "未知目标查询筛选字段", "不是正式可写战斗 Hook",
            "只允许 action_resolve 参与功法阶段编排", "内容不得伪造"]:
        _assert_true(invalid_text.contains(expected_error),
            "加载期诊断包含：%s" % expected_error)

    for core_path in [
            "res://core/action_resolver.gd",
            "res://core/passives/passive_rule_runtime.gd",
            "res://core/effects/damage_effect_handler.gd",
            "res://core/effects/card_zone_effect_handler.gd"]:
        var core_text := FileAccess.get_file_as_string(core_path)
        for anonymous_id in [
                "anonymous_inner_damage", "anonymous_item_damage",
                "anonymous_standard_ops"]:
            _assert_true(not core_text.contains(anonymous_id),
                "%s 不按匿名内容 ID 分支" % core_path)

func _standard_passive_item(
        content_id: String,
        hook: String,
        effects: Array,
        order: int = 100) -> Dictionary:
    var configuration := {
        "hook": hook,
        "effects": effects.duplicate(true),
    }
    if hook in PassiveRuleHandlerRegistryScript.BATTLE_TIMING_HOOKS:
        configuration["order"] = order
    return {
        "id": content_id,
        "name": "匿名物品·%s" % content_id,
        "kind": "item",
        "status": "candidate",
        "unique": true,
        "description": "仅用于统一被动效果入口测试。",
        "price": 1,
        "behaviors": [{
            "id": "battle_effects",
            "configuration": configuration,
        }],
    }

func _standard_passive_inner(
        content_id: String,
        hook: String,
        effects: Array,
        order: int = 100) -> Dictionary:
    var configuration := {
        "hook": hook,
        "effects": effects.duplicate(true),
    }
    if hook in PassiveRuleHandlerRegistryScript.BATTLE_TIMING_HOOKS:
        configuration["order"] = order
    return {
        "id": content_id,
        "name": "匿名内功·%s" % content_id,
        "status": "candidate",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": configuration,
        }],
    }

func _commit_f5e_probe_event(
        engine,
        event_kind: String,
        event_token: String,
        values: Dictionary) -> Dictionary:
    var payload := values.duplicate(false)
    payload["event_token"] = event_token
    payload["event_serial"] = engine.battle_passive_event_service.next_serial()
    return engine.battle_passive_event_service.commit(event_kind, payload)

func _battle_passive_test_item(
        content_id: String,
        bindings: Array,
        extra_configuration: Dictionary) -> Dictionary:
    var configuration := {"bindings": bindings.duplicate(true)}
    configuration.merge(extra_configuration, true)
    var behavior := {
        "id": "battle_lifecycle_probe",
        "configuration": configuration,
    }
    if configuration.has("persistent_counter") \
            or configuration.has("battle_counters"):
        behavior["state_key"] = "%s_state" % content_id
    return {
        "id": content_id,
        "name": "战斗被动测试·%s" % content_id,
        "kind": "item",
        "status": "candidate",
        "unique": true,
        "description": "仅用于 F5D1 自动化测试。",
        "price": 1,
        "behaviors": [behavior],
    }

func _f5d2_probe_item(
        content_id: String,
        configuration: Dictionary) -> Dictionary:
    return {
        "id": content_id,
        "name": "F5D2 战斗细粒度探针·%s" % content_id,
        "kind": "item", "status": "candidate", "unique": true,
        "description": "仅用于 F5D2 自动化测试。", "price": 1,
        "behaviors": [{
            "id": "battle_fine_grained_probe",
            "state_key": "%s_state" % content_id,
            "configuration": configuration.duplicate(true),
        }],
    }

func _battle_passive_test_catalog(
        registry,
        items: Array,
        inner_skills: Array) -> Dictionary:
    var base_catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    if not base_catalog.load_all():
        return {"success": false, "catalog": base_catalog}
    var values := _catalog_definitions(base_catalog)
    values["items"]["items"].append_array(items)
    values["inner_skills"]["inner_skills"].append_array(inner_skills)
    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, null, registry)
    var success := catalog.load_from_definitions(values, base_catalog.paths)
    return {
        "success": success,
        "catalog": catalog,
        "base_values": _catalog_definitions(base_catalog),
        "paths": base_catalog.paths.duplicate(true),
    }

func _battle_passive_test_engine(
        catalog,
        registry,
        item_ids: Array,
        inner_skill_ids: Array = []):
    var engine = _tracked_combat_engine(null, catalog, registry)
    engine.setup(5512, false)
    engine.player.configure_items(item_ids)
    engine.player.learned_inner_skill_ids.assign(inner_skill_ids)
    engine.player.configure_inner_skills(inner_skill_ids, 0)
    return engine

func _test_content_catalog_and_validator() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "统一内容目录一次性载入并通过全部校验")
    _assert_equal(catalog.errors, [], "当前内容数据没有校验错误")
    _assert_equal(catalog.definition("base_deck")["version"], 1, "内容数据带顶层版本")
    _assert_equal(catalog.definition("card_states")["version"], 10, "真气重塑与异状数据带顶层版本")
    _assert_equal(catalog.definition("starter_builds")["version"], 1, "初始构筑数据带顶层版本")
    _assert_equal(catalog.definition("consumables")["version"], 5, "消耗品与修习商品数据带顶层版本")
    var act_progression: Dictionary = catalog.definition("act_progression")
    _assert_equal(act_progression["acts"].size(), 3, "生命成长内容完整声明三层数据")
    _assert_equal(act_progression["acts"][0]["player"]["max_life"], 100, "第一层玩家生命上限来自成长内容")
    _assert_equal(act_progression["acts"][1]["enemies"]["elite"]["max_life"], 225, "成长内容同时保留第二层精英生命")
    _assert_equal(act_progression["acts"][2]["enemies"]["boss"]["max_life"], 450, "成长内容同时保留第三层 Boss 生命")
    _assert_equal(catalog.all_of("starter_build").size(), 1, "当前只开放一套初始构筑")
    _assert_equal(catalog.get_by_id("starter_build", "standard_52")["card_count"], 52, "唯一初始构筑为标准52张牌组")
    _assert_equal(
        catalog.get_by_id("starter_build", "standard_52")["card_ids"].size(),
        52,
        "标准初始构筑显式声明 52 个真气 ID")
    _assert_equal(catalog.all_of("card").size(), 52, "内容目录建立 52 张唯一基础真气索引")
    _assert_equal(catalog.all_of("origin").size(), 3, "内容目录建立三种正式本源索引")
    _assert_equal(catalog.all_of("enhancement").size(), 8, "内容目录建立八种正式强化索引")
    _assert_equal(catalog.all_of("imprint").size(), 4, "内容目录建立四种正式印记索引")
    _assert_equal(catalog.all_of("anomaly").size(), 17, "内容目录建立完整正式战斗异状索引")
    _assert_equal(catalog.all_of("actor_status").size(), 0, "内容目录不公开旧命名角色层数类型")
    _assert_equal(catalog.get_by_id("actor_status", "probe"), {}, "内容目录不为角色层数建立索引")
    _assert_equal(catalog.get_by_id("anomaly", "poison")["category"], "state", "毒归入唯一状态槽")
    _assert_equal(
        catalog.get_by_id("anomaly", "purification")["on_apply"],
        "purify_combat_state",
        "净化通过内容策略声明获得时生命周期")
    _assert_equal(catalog.all_of("technique").size(), 236, "统一功法目录包含236门正式功法")
    _assert_equal(catalog.definition("techniques")["resource_paths"].size(), 236, "正式功法资源路径包含236项")
    _assert_equal(catalog.definition("techniques")["integration_statuses"].size(), 236, "正式接入状态包含236门功法")
    var formal_technique_resource_count := 0
    for filename in DirAccess.get_files_at("res://data/techniques"):
        if str(filename).ends_with(".tres"):
            formal_technique_resource_count += 1
    _assert_equal(formal_technique_resource_count, 236, "正式功法资源目录包含236门功法")

    var candidate_path := ProjectSettings.globalize_path("res://").path_join(
        "../godot/docs/design-candidates/high-card-techniques-draft.md").simplify_path()
    _assert_true(FileAccess.file_exists(candidate_path), "28 门高牌候选稿已保存")
    var candidate_text := FileAccess.get_file_as_string(candidate_path)
    for candidate_name in [
            "探风式", "蕴林式", "引火式", "立山式",
            "散风", "聚林", "散火", "聚山",
            "惊风", "伏林", "燎火", "镇山",
            "风·引风", "林·培元", "火·附火", "山·蓄势",
            "风·换流", "林·凝气", "火·蓄势", "山·反震",
            "风·混流", "林·传功", "火·焚虚", "山·坚壁",
            "风·回风", "林·净元", "火·燃薪", "山·蓄劲"]:
        _assert_true(candidate_text.contains(candidate_name), "候选稿完整保留：%s" % candidate_name)
    var design_check_source := FileAccess.get_file_as_string(
        "res://tools/run_design_consistency_check.gd")
    _assert_true(
        design_check_source.contains("design-current/martial-arts")
            and not design_check_source.contains("design-candidates"),
        "设计一致性检查只读取权威目录，不读取候选稿")

    var nonempty_actor_status_values := _catalog_definitions(catalog)
    nonempty_actor_status_values["battle_statuses"]["actor_statuses"] = [{
        "id": "retired_actor_status_probe",
        "name": "退役角色状态探针",
    }]
    var nonempty_actor_status_catalog = ContentCatalogScript.new()
    _assert_true(
        not nonempty_actor_status_catalog.load_from_definitions(
            nonempty_actor_status_values),
        "兼容占位文件的 actor_statuses 非空时内容加载失败")
    _assert_true(
        _array_contains_text(
            nonempty_actor_status_catalog.errors,
            "旧命名角色层数已退役"),
        "非空角色层数数组报告明确退役原因")

    for retired_op in [
            "add_stack",
            "add_target_stack",
            "add_stack_per_captured_card",
            "set_stack_minimum",
            "register_turn_end_stack"]:
        var retired_op_values := _catalog_definitions(catalog)
        retired_op_values["techniques"]["techniques"].append({
            "id": "retired_op_probe_%s" % retired_op,
            "name": "退役操作探针",
            "pool": "high",
            "special": false,
            "effects": [{"op": retired_op}],
        })
        var retired_op_catalog = ContentCatalogScript.new()
        _assert_true(
            not retired_op_catalog.load_from_definitions(retired_op_values),
            "退役效果操作 %s 在内容加载时失败" % retired_op)
        _assert_true(
            _array_contains_text(
                retired_op_catalog.errors,
                "未知效果操作码 %s" % retired_op),
            "退役效果操作 %s 被识别为未知操作" % retired_op)

    var legacy_finish_values := _catalog_definitions(catalog)
    legacy_finish_values["card_states"]["reshape_categories"][0] = {
        "id": "finish", "capacity": 1, "replaceable": true}
    legacy_finish_values["card_states"]["finishes"] = [{"id": "foil", "name": "旧品相"}]
    var legacy_finish_catalog = ContentCatalogScript.new()
    _assert_true(
        not legacy_finish_catalog.load_from_definitions(legacy_finish_values),
        "旧 finish/finishes/foil 内容被明确拒绝")
    _assert_true(
        _array_contains_text(legacy_finish_catalog.errors, "旧品相字段已废弃"),
        "旧品相拒绝报告明确迁移原因")
    var legacy_consumable_values := _catalog_definitions(catalog)
    legacy_consumable_values["consumables"]["consumables"][1]["effects"] = [{
        "op": "apply_random_finish", "finishes": ["foil"]}]
    var legacy_consumable_catalog = ContentCatalogScript.new()
    _assert_true(
        not legacy_consumable_catalog.load_from_definitions(legacy_consumable_values),
        "旧随机品相消耗品语法被拒绝")
    _assert_true(
        _array_contains_text(legacy_consumable_catalog.errors, "未注册的消耗品效果操作：apply_random_finish"),
        "旧消耗品操作报告具名错误")

    var changed_query: Dictionary = catalog.get_by_id("consumable", "high_card_insight")
    changed_query["name"] = "外部篡改"
    _assert_true(
        catalog.get_by_id("consumable", "high_card_insight")["name"] != "外部篡改",
        "目录查询返回深复制")
    var changed_definition: Dictionary = catalog.definition("scripted_battle")
    changed_definition["enemy"]["opening_hand"][0] = "bad_card"
    _assert_equal(
        catalog.definition("scripted_battle")["enemy"]["opening_hand"][0],
        "fire_2",
        "整份定义查询同样保持深复制边界")

    var duplicate_values := _catalog_definitions(catalog)
    var duplicate_probe := {
        "id": "duplicate_probe", "name": "重复探针", "pool": "high",
        "special": false, "effects": []}
    duplicate_values["techniques"]["techniques"].append(duplicate_probe.duplicate(true))
    duplicate_values["techniques"]["techniques"].append(duplicate_probe.duplicate(true))
    var duplicate_catalog = ContentCatalogScript.new()
    _assert_true(not duplicate_catalog.load_from_definitions(duplicate_values), "重复内容 ID 被拒绝")
    _assert_true(_array_contains_text(duplicate_catalog.errors, "ID 重复：duplicate_probe"), "重复 ID 错误稳定定位")

    _assert_equal(
        ContentValidatorScript.POOL_IDS,
        ["high", "pair", "three", "straight", "bomb", "universal"],
        "运行内容承认五个普通池和基础通用归类")
    for old_pool_id in ["pair_two_pair", "three_full_house", "four_five"]:
        var legacy_pool_values := _catalog_definitions(catalog)
        legacy_pool_values["techniques"]["techniques"].append({
            "id": "legacy_pool_probe", "name": "旧池探针", "pool": old_pool_id,
            "special": false, "effects": []})
        var legacy_pool_catalog = ContentCatalogScript.new()
        _assert_true(
            not legacy_pool_catalog.load_from_definitions(legacy_pool_values),
            "旧功法池 ID %s 在正式内容加载时失败" % old_pool_id)
        _assert_true(
            _array_contains_text(legacy_pool_catalog.errors, "引用未知功法池 %s" % old_pool_id),
            "旧功法池 ID %s 报告明确错误" % old_pool_id)

    var missing_version_values := _catalog_definitions(catalog)
    missing_version_values["consumables"].erase("version")
    var missing_version_catalog = ContentCatalogScript.new()
    _assert_true(not missing_version_catalog.load_from_definitions(missing_version_values), "缺少内容版本被拒绝")
    _assert_true(_array_contains_text(missing_version_catalog.errors, "缺少版本字段 version"), "版本错误稳定定位")

    var unknown_target_zone_values := _catalog_definitions(catalog)
    unknown_target_zone_values["consumables"]["consumables"][0]["targeting"]["zone"] = "hand"
    var unknown_target_zone_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_target_zone_catalog.load_from_definitions(unknown_target_zone_values),
        "未知消耗品目标区域在加载阶段失败")
    _assert_true(
        _array_contains_text(unknown_target_zone_catalog.errors, "未知目标区域 hand"),
        "未知消耗品目标区域错误稳定定位")

    var unknown_target_selection_values := _catalog_definitions(catalog)
    unknown_target_selection_values["consumables"]["consumables"][0]["targeting"]["selection"] = "manual"
    var unknown_target_selection_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_target_selection_catalog.load_from_definitions(unknown_target_selection_values),
        "未知消耗品目标选择方式在加载阶段失败")
    _assert_true(
        _array_contains_text(unknown_target_selection_catalog.errors, "未知目标选择方式 manual"),
        "未知消耗品目标选择方式错误稳定定位")

    var none_minimum_values := _catalog_definitions(catalog)
    var none_index := _content_entry_index(
        none_minimum_values["consumables"]["consumables"], "suyi_pill")
    none_minimum_values["consumables"]["consumables"][none_index]["targeting"]["minimum"] = 1
    var none_minimum_catalog = ContentCatalogScript.new()
    _assert_true(
        not none_minimum_catalog.load_from_definitions(none_minimum_values),
        "none 区域 minimum 非零在加载阶段失败")
    _assert_true(
        _array_contains_text(none_minimum_catalog.errors, "none 区域 minimum 必须为 0"),
        "none 区域 minimum 错误稳定定位")

    var none_maximum_values := _catalog_definitions(catalog)
    none_maximum_values["consumables"]["consumables"][none_index]["targeting"]["maximum"] = 1
    var none_maximum_catalog = ContentCatalogScript.new()
    _assert_true(
        not none_maximum_catalog.load_from_definitions(none_maximum_values),
        "none 区域 maximum 非零在加载阶段失败")
    _assert_true(
        _array_contains_text(none_maximum_catalog.errors, "none 区域 maximum 必须为 0"),
        "none 区域 maximum 错误稳定定位")

    var run_deck_selection_values := _catalog_definitions(catalog)
    run_deck_selection_values["consumables"]["consumables"][1]["targeting"]["selection"] = "first"
    var run_deck_selection_catalog = ContentCatalogScript.new()
    _assert_true(
        not run_deck_selection_catalog.load_from_definitions(run_deck_selection_values),
        "run_deck 非法选择方式在加载阶段失败")
    _assert_true(
        _array_contains_text(run_deck_selection_catalog.errors, "未知目标选择方式 first"),
        "run_deck 非法选择方式错误稳定定位")

    var missing_life_values := _catalog_definitions(catalog)
    missing_life_values["act_progression"]["acts"][0]["player"].erase("max_life")
    var missing_life_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_life_catalog.load_from_definitions(missing_life_values),
        "生命成长缺少具名字段时内容加载失败")
    _assert_true(
        _array_contains_text(
            missing_life_catalog.errors,
            "act_progression.acts[0].player.max_life"),
        "生命成长缺字段错误稳定定位到玩家生命上限")

    var missing_act_values := _catalog_definitions(catalog)
    missing_act_values["act_progression"]["acts"].remove_at(2)
    var missing_act_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_act_catalog.load_from_definitions(missing_act_values),
        "生命成长层数不全时内容加载失败")
    _assert_true(
        _array_contains_text(missing_act_catalog.errors, "缺少第 3 层生命定义"),
        "生命成长缺层错误具名报告第三层")

    var unknown_values := _catalog_definitions(catalog)
    unknown_values["sequences"]["pair"] = ["missing_technique"]
    var unknown_catalog = ContentCatalogScript.new()
    _assert_true(not unknown_catalog.load_from_definitions(unknown_values), "序列中的未知功法被拒绝")
    _assert_true(_array_contains_text(unknown_catalog.errors, "引用未知功法 missing_technique"), "未知功法错误稳定定位")

    var wrong_pool_values := _catalog_definitions(catalog)
    wrong_pool_values["techniques"]["techniques"].append({
        "id": "wrong_pool_probe", "name": "错误池探针", "pool": "high",
        "special": false, "effects": []})
    wrong_pool_values["sequences"]["pair"] = ["wrong_pool_probe"]
    var wrong_pool_catalog = ContentCatalogScript.new()
    _assert_true(not wrong_pool_catalog.load_from_definitions(wrong_pool_values), "错误功法池资格被拒绝")
    _assert_true(_array_contains_text(wrong_pool_catalog.errors, "不属于 pair 的合格共用池"), "错误功法池错误稳定定位")

    var production_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.production())
    _assert_true(
        production_catalog.load_all(),
        "production 正式功法序列通过内容校验：%s" % str(production_catalog.errors))
    var production_repository = TechniqueRepositoryScript.new()
    _assert_true(
        production_repository.configure(
            production_catalog.definition("techniques"), true),
        "功法仓库载入显式接入档位")
    var production_sequences: Dictionary = production_catalog.definition("sequences")
    for hand_id in ContentValidatorScript.HAND_IDS:
        _assert_equal(
            production_sequences[hand_id],
            ["basic_scatter"],
            "production %s 正式序列默认散招" % hand_id)

    var fixture_values := _catalog_definitions(production_catalog)
    fixture_values["sequences"]["high_card"] = ["fire_sparks"]
    var fixture_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.production())
    _assert_true(
        not fixture_catalog.load_from_definitions(
            fixture_values,
            production_catalog.paths),
        "production 序列拒绝回归夹具功法")
    _assert_true(
        _array_contains_text(fixture_catalog.errors, "fire_sparks"),
        "归档功法 ID 重回 production 时明确报错")

    for abolished_hand_id in ["flush", "straight_flush", "royal_flush"]:
        var abolished_hand_values := _catalog_definitions(catalog)
        abolished_hand_values["sequences"][abolished_hand_id] = []
        var abolished_hand_catalog = ContentCatalogScript.new()
        _assert_true(
            not abolished_hand_catalog.load_from_definitions(abolished_hand_values),
            "废弃牌型 %s 序列键被拒绝" % abolished_hand_id)
        _assert_true(
            _array_contains_text(
                abolished_hand_catalog.errors,
                "包含未知精确牌型 %s" % abolished_hand_id),
            "废弃牌型 %s 错误稳定定位" % abolished_hand_id)

    var bad_op_values := _catalog_definitions(catalog)
    bad_op_values["techniques"]["techniques"].append({
        "id": "bad_op_probe", "name": "坏操作探针", "pool": "high",
        "special": false, "effects": [{"op": "unknown_op"}]})
    var bad_op_catalog = ContentCatalogScript.new()
    _assert_true(not bad_op_catalog.load_from_definitions(bad_op_values), "未知效果操作码被拒绝")
    _assert_true(_array_contains_text(bad_op_catalog.errors, "未知效果操作码 unknown_op"), "操作码错误稳定定位")

    var bad_kind_values := _catalog_definitions(catalog)
    bad_kind_values["techniques"]["techniques"].append({
        "id": "bad_kind_probe", "name": "坏数值探针", "pool": "high",
        "special": false, "effects": [{
            "op": "damage", "amount": {"kind": "unknown_kind"}}]})
    var bad_kind_catalog = ContentCatalogScript.new()
    _assert_true(not bad_kind_catalog.load_from_definitions(bad_kind_values), "未知数值规格被拒绝")
    _assert_true(_array_contains_text(bad_kind_catalog.errors, "未知数值规格 kind unknown_kind"), "数值规格错误稳定定位")

    var nested_kind_values := _catalog_definitions(catalog)
    nested_kind_values["techniques"]["techniques"].append({
        "id": "nested_kind_probe", "name": "嵌套数值探针", "pool": "high",
        "special": false, "effects": [{
            "op": "damage", "amount": {"kind": "max", "values": [
                {"kind": "constant", "value": 1},
                {"kind": "unknown_nested_kind"}]}}]})
    var nested_kind_catalog = ContentCatalogScript.new()
    _assert_true(not nested_kind_catalog.load_from_definitions(nested_kind_values), "递归 max.values 中的未知数值规格被拒绝")
    _assert_true(_array_contains_text(nested_kind_catalog.errors, "unknown_nested_kind"), "递归数值规格错误稳定定位")

    var bad_card_values := _catalog_definitions(catalog)
    bad_card_values["scripted_battle"]["enemy"]["opening_hand"][0] = "void_A"
    var bad_card_catalog = ContentCatalogScript.new()
    _assert_true(not bad_card_catalog.load_from_definitions(bad_card_values), "脚本战斗中的无效真气引用被拒绝")
    _assert_true(_array_contains_text(bad_card_catalog.errors, "引用未知真气 void_A"), "无效真气引用错误稳定定位")

    var bad_ai_policy_values := _catalog_definitions(catalog)
    bad_ai_policy_values["scripted_battle"]["enemy"]["ai"]["combo_folow_weight"] = 1.0
    var bad_ai_policy_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_ai_policy_catalog.load_from_definitions(bad_ai_policy_values),
        "敌方数据驱动策略拒绝拼写错误字段")
    _assert_true(
        _array_contains_text(bad_ai_policy_catalog.errors, "未知 AI 策略字段 combo_folow_weight"),
        "敌方策略字段错误稳定定位")

    var bad_ai_bias_values := _catalog_definitions(catalog)
    bad_ai_bias_values["scripted_battle"]["enemy"]["ai"]["next_technique_bias"] = {
        "missing_technique": 3.0,
    }
    var bad_ai_bias_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_ai_bias_catalog.load_from_definitions(bad_ai_bias_values),
        "敌方策略拒绝未知功法偏好")
    _assert_true(
        _array_contains_text(bad_ai_bias_catalog.errors, "引用未知功法 missing_technique"),
        "敌方功法偏好引用错误稳定定位")

    var bad_anomaly_lifecycle_values := _catalog_definitions(catalog)
    var poison_index := _content_entry_index(
        bad_anomaly_lifecycle_values["card_states"]["anomalies"], "poison")
    bad_anomaly_lifecycle_values["card_states"]["anomalies"][poison_index]["remove_on_enter_discard"] = false
    var bad_anomaly_lifecycle_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_anomaly_lifecycle_catalog.load_from_definitions(bad_anomaly_lifecycle_values),
        "状态毒不能关闭进入弃牌堆清理规则")
    _assert_true(
        _array_contains_text(bad_anomaly_lifecycle_catalog.errors, "状态进入弃牌堆时必须默认移除"),
        "异状生命周期错误稳定定位")

    var bad_anomaly_policy_values := _catalog_definitions(catalog)
    bad_anomaly_policy_values["card_states"]["anomalies"][-1]["on_apply"] = "unknown_policy"
    var bad_anomaly_policy_catalog = ContentCatalogScript.new()
    _assert_true(not bad_anomaly_policy_catalog.load_from_definitions(bad_anomaly_policy_values), "未知异状获得策略被拒绝")
    _assert_true(
        _array_contains_text(bad_anomaly_policy_catalog.errors, "未知异状获得策略 unknown_policy"),
        "异状获得策略错误稳定定位")

    var bad_status_handler_values := _catalog_definitions(catalog)
    var growth_index := _content_entry_index(
        bad_status_handler_values["card_states"]["anomalies"], "growth")
    bad_status_handler_values["card_states"]["anomalies"][growth_index]["behaviors"][0]["handler"] = "missing_status_handler"
    var bad_status_handler_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_status_handler_catalog.load_from_definitions(bad_status_handler_values),
        "异状拒绝未注册的状态处理器")
    _assert_true(
        _array_contains_text(bad_status_handler_catalog.errors, "未注册的状态处理器 missing_status_handler"),
        "状态处理器错误稳定定位")

    var bad_status_reference_values := _catalog_definitions(catalog)
    for anomaly in bad_status_reference_values["card_states"]["anomalies"]:
        if anomaly.get("id", "") == "growth":
            anomaly["behaviors"][0]["anomaly"] = "missing_anomaly"
    var bad_status_reference_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_status_reference_catalog.load_from_definitions(bad_status_reference_values),
        "状态行为拒绝未知异状引用")
    _assert_true(
        _array_contains_text(bad_status_reference_catalog.errors, "引用未知真气异状 missing_anomaly"),
        "状态行为引用错误稳定定位")

    var bad_anomaly_reference_values := _catalog_definitions(catalog)
    bad_anomaly_reference_values["techniques"]["techniques"].append({
        "id": "bad_anomaly_probe", "name": "坏异状探针", "pool": "high",
        "special": false, "effects": [{
            "op": "apply_random_card_anomaly", "category": "state",
            "anomaly": "missing_anomaly", "count": 1}]})
    var bad_anomaly_reference_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_anomaly_reference_catalog.load_from_definitions(bad_anomaly_reference_values),
        "功法引用未知异状被拒绝")
    _assert_true(
        _array_contains_text(bad_anomaly_reference_catalog.errors, "引用未知真气异状 missing_anomaly"),
        "未知异状引用错误稳定定位")

    var battle_start_reshape_values := _catalog_definitions(catalog)
    battle_start_reshape_values["card_states"]["other_reshapes"] = [{
        "id": "test_poison_seed",
        "name": "测试跨战斗毒种",
        "battle_start_anomalies": [{"category": "state", "anomaly": "poison"}],
    }]
    var battle_start_reshape_catalog = ContentCatalogScript.new()
    _assert_true(
        battle_start_reshape_catalog.load_from_definitions(battle_start_reshape_values),
        "重塑其他可以数据声明战斗开始异状")
    var battle_start_card = _card("5", "forest")
    battle_start_card.set_other_reshape("test_poison_seed")
    var battle_start_results: Array[Dictionary] = CardStateLifecycleScript.new(
        battle_start_reshape_catalog).on_battle_start(battle_start_card)
    _assert_true(battle_start_results[0]["success"], "战斗开始生命周期执行重塑声明")
    _assert_true(
        battle_start_card.has_anomaly("state", "poison"),
        "跨战斗重塑在新战斗生成毒而不是保存毒对象")

    var bad_battle_start_values := _catalog_definitions(catalog)
    bad_battle_start_values["card_states"]["other_reshapes"] = [{
        "id": "bad_poison_seed",
        "name": "错误毒种",
        "battle_start_anomalies": [{"category": "mark", "anomaly": "poison"}],
    }]
    var bad_battle_start_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_battle_start_catalog.load_from_definitions(bad_battle_start_values),
        "重塑战斗开始异状拒绝错误类别")
    _assert_true(
        _array_contains_text(bad_battle_start_catalog.errors, "poison 不属于类别 mark"),
        "重塑战斗开始异状错误稳定定位")

    var bad_enhancement_reference_values := _catalog_definitions(catalog)
    var enhancement_index := _content_entry_index(
        bad_enhancement_reference_values["consumables"]["consumables"],
        "jiyuan_pill")
    bad_enhancement_reference_values["consumables"]["consumables"][enhancement_index]["effects"][0]["enhancement"] = "missing_enhancement"
    var bad_enhancement_reference_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_enhancement_reference_catalog.load_from_definitions(bad_enhancement_reference_values),
        "消耗品引用未知强化被拒绝")
    _assert_true(
        _array_contains_text(bad_enhancement_reference_catalog.errors, "引用未知强化 missing_enhancement"),
        "未知强化引用错误稳定定位")

    var engine = _tracked_combat_engine(null, catalog)
    var run_session: RunSession = RunSessionScript.new(null, null, null, null, catalog)
    _assert_true(engine.content_catalog == catalog, "战斗核心使用注入的统一目录实例")
    _assert_true(run_session.execute({"type": "setup_run", "seed": 17}).success, "本局流程从同一目录装配地图与节点内容")
    var battle_session: BattleSession = run_session.create_battle_session()
    _assert_true(battle_session.engine.content_catalog == catalog, "本局创建的战斗会话继续共享同一目录实例")

func _test_enemy_pool_content_and_repository() -> void:
    var catalog := ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(catalog.load_all(), "敌人池内容随统一目录通过校验")
    var definition: Dictionary = catalog.definition("enemies")
    _assert_equal(definition["enemies"].size(), 9, "敌人池包含三名普通、两名精英、三名 Boss 与一个过渡占位条目")
    var repository := EnemyRepositoryScript.new(catalog)
    _assert_true(repository.configure(definition), "敌人仓库可消费已校验内容")
    var first: Dictionary = repository.select(1, "combat", 2)
    var second: Dictionary = repository.select(1, "combat", 2)
    _assert_true(first.get("success", false), "按层数和普通战斗可抽取敌人")
    _assert_equal(first["entry"]["id"], second["entry"]["id"], "相同种子抽取相同敌人")
    _assert_equal(first["entry"]["id"], "act1_gale_sleeve_adept", "第 1 层普通种子 2 抽到疾袖客")
    _assert_equal(first["cards"].size(), 20, "第一层普通敌人牌组按编码展开为 20 张")
    _assert_equal(first["cards"][0].id, second["cards"][0].id, "相同种子牌组实例 ID 稳定")
    _assert_true(
        first["cards"].all(func(card):
            var snapshot: Dictionary = card.anomaly_snapshot()
            return snapshot["buffs"].is_empty() \
                and snapshot["debuffs"].is_empty() \
                and snapshot["state"].is_empty() \
                and snapshot["marks"].is_empty()),
        "敌人牌组不预置战斗异状")
    var one_card_values := _catalog_definitions(catalog)
    one_card_values["enemies"]["enemies"][0]["deck"] = ["wind_2"]
    var one_card_catalog := ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(
        one_card_catalog.load_from_definitions(one_card_values),
        "一张牌的敌人牌组可以通过内容校验")
    var preset_origin := EnemyDeckEncodingScript.parse([{
        "definition_id": "wind_7",
        "reshapes": {
            "origin": {
                "id": "attribute_change",
                "payload": {"attribute": "mountain"},
            },
            "enhancement": "qi_boost",
        },
    }], catalog, "enemy-origin-test")
    _assert_true(preset_origin.get("success", false), "敌人可通过显式对象预置带参数本源")
    _assert_equal(preset_origin["cards"][0].definition_id, "mountain_7", "敌人预置转属更新基础定义")
    _assert_equal(preset_origin["cards"][0].reshape_origin["id"], "attribute_change", "敌人预置保存本源身份")
    _assert_equal(preset_origin["cards"][0].reshape_enhancement, "qi_boost", "敌人预置可同时声明强化")
    var ambiguous_origin_values := _catalog_definitions(catalog)
    ambiguous_origin_values["enemies"]["enemies"][0]["deck"] = [
        "wind_7+attribute_change"]
    var ambiguous_origin_catalog := ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(
        not ambiguous_origin_catalog.load_from_definitions(ambiguous_origin_values),
        "敌人不能用无 payload 的字符串预置本源")
    _assert_true(
        _array_contains_text(ambiguous_origin_catalog.errors, "必须显式提供 origin 与 payload 对象"),
        "敌人模糊本源编码报告明确错误")
    var no_match := repository.select(3, "event", 7301)
    _assert_true(not no_match.get("success", false), "敌人池无匹配节点组合时明确失败")
    _assert_true(
        _array_contains_text([str(no_match.get("reason", ""))], "第 3 层 / event"),
        "敌人池无匹配组合报告层数和节点类型")
    var seed_two := repository.select(1, "combat", 1)
    var seed_five := repository.select(1, "combat", 5)
    _assert_equal(seed_two["entry"]["id"], "act1_fourfold_roamer", "第 1 层普通种子 1 抽到四象散人")
    _assert_equal(seed_five["entry"]["id"], "act1_mountain_gu_warden", "第 1 层普通种子 5 抽到山蛊守")
    _assert_true(
        first["entry"]["id"] != seed_two["entry"]["id"]
        and seed_two["entry"]["id"] != seed_five["entry"]["id"],
        "第一层普通不同 content_seed 能抽到不同敌人")
    for selected in [first, seed_two, seed_five]:
        _assert_equal(int(selected["entry"]["acts"][0]), 1, "抽到的第一层敌人声明覆盖第 1 层")
        _assert_equal(str(selected["entry"]["node_types"][0]), "combat", "抽到的第一层敌人声明覆盖普通战斗")
    var elite_ids: Dictionary = {}
    for seed_value in range(256):
        var elite_result: Dictionary = repository.select(1, "elite", 41000 + seed_value)
        _assert_true(elite_result.get("success", false), "第 1 层精英候选可抽取")
        elite_ids[str(elite_result["entry"]["id"])] = true
    _assert_true(elite_ids.size() >= 2, "第 1 层精英候选至少有两个不同 ID")
    var boss_ids: Dictionary = {}
    var boss_variant_ids: Array[String] = []
    for variant in range(3):
        var boss_result: Dictionary = repository.select(1, "boss", 7301, variant)
        _assert_true(boss_result.get("success", false), "第 1 层 Boss 候选可抽取")
        boss_ids[str(boss_result["entry"]["id"])] = true
        boss_variant_ids.append(str(boss_result["entry"]["id"]))
        _assert_true(
            str(boss_result["entry"]["id"]) != "transitional_elite_boss_placeholder",
            "第 1 层 Boss 不抽到过渡占位条目")
    _assert_equal(boss_ids.size(), 3, "第 1 层 Boss 的 boss_variant 0/1/2 分别抽到三个不同 ID")
    print("S2-07 第一层 Boss 变体 seed=7301: variant0=%s, variant1=%s, variant2=%s" % boss_variant_ids)
    var stable_boss_a: Dictionary = repository.select(1, "boss", 7301, 1)
    var stable_boss_b: Dictionary = repository.select(1, "boss", 7301, 1)
    _assert_equal(
        stable_boss_a["entry"]["id"], stable_boss_b["entry"]["id"],
        "相同 content_seed 与 boss_variant 抽取结果稳定")
    for entry in definition["enemies"]:
        var proficiency: Dictionary = entry.get("hand_proficiency_fixed", {})
        _assert_equal(proficiency.size(), 8, "敌人完整声明八种牌型固定熟练度")
        for hand_id in entry.get("sequences", {}):
            _assert_equal(entry["sequences"][hand_id], [], "敌人正式功法序列合法为空")
    var placeholder: Dictionary = definition["enemies"][definition["enemies"].size() - 1]
    _assert_equal(placeholder["acts"].size(), 2, "过渡占位条目覆盖两层")
    _assert_equal(int(placeholder["acts"][0]), 2, "过渡占位条目覆盖第 2 层")
    _assert_equal(int(placeholder["acts"][1]), 3, "过渡占位条目覆盖第 3 层")
    _assert_equal(placeholder["name"], "第 2/3 层过渡占位精英首领", "占位条目名称明确层数范围")

func _test_formal_enemy_pool_battle_setup() -> void:
    var root := GameCompositionRootScript.new(RuntimeProfileScript.production())
    _assert_true(root.initialize(), "正式模式可装配敌人池")
    var run_session: RunSession = root.create_run_session()
    var battle_session: BattleSession = run_session.create_battle_session()
    _assert_true(
        battle_session.setup_battle({
            "act": 1,
            "node_type": "elite",
            "boss_variant": 0,
            "content_seed": 8112,
            "battle": {"use_enemy_ai": false},
        }),
        "正式第 1 层精英按层数、节点类型和种子完成敌人装配")
    _assert_equal(battle_session.engine.enemy.max_life, 150, "第一层精英敌人生命来自权威生命表")
    _assert_equal(battle_session.engine.enemy.life, 150, "第一层精英生命以查表上限开始")
    _assert_true(battle_session.engine.enemy.draw_pile.size() > 0, "正式精英使用非空自由牌组")
    _assert_true(
        battle_session.engine.enemy.name != "第 2/3 层过渡占位精英首领",
        "第一层精英不使用过渡占位条目")
    _assert_equal(
        battle_session.engine.enemy_sequence_book.current_id("high_card"),
        "",
        "正式精英功法序列为空")
    var boss_session: BattleSession = run_session.create_battle_session()
    _assert_true(
        boss_session.setup_battle({
            "act": 1,
            "node_type": "boss",
            "boss_variant": 2,
            "content_seed": 8112,
            "battle": {"use_enemy_ai": false},
        }),
        "正式第 1 层 Boss 完成战斗装配")
    _assert_equal(boss_session.engine.enemy.max_life, 200, "第一层 Boss 敌人生命来自权威生命表")
    _assert_equal(boss_session.engine.enemy.life, 200, "第一层 Boss 生命以查表上限开始")
    _assert_true(boss_session.engine.enemy.draw_pile.size() > 0, "正式 Boss 使用非空自由牌组")

func _test_starter_build_assembly_and_composition_root() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "构筑装配测试内容目录有效")
    var assembler = StarterBuildAssemblerScript.new(catalog)
    var assembled: Dictionary = assembler.assemble_into_run_deck({
        "id": "assembly_probe",
        "card_count": 2,
        "card_ids": ["wind_2", "fire_A"],
    }, "assembly-probe")
    _assert_true(assembled.get("success", false), "初始构筑装配器按显式 card_ids 建立 RunDeck")
    var assembled_deck: Object = assembled.get("run_deck")
    _assert_equal(assembled_deck.card_count(), 2, "装配器不会退回固定标准52张牌组")
    _assert_true(assembled_deck.has_card("wind_2"), "装配结果包含构筑声明的风2")
    _assert_true(assembled_deck.has_card("fire_A"), "装配结果包含构筑声明的火A")
    var rejected: Dictionary = assembler.assemble_card_ids({
        "card_count": 1,
        "card_ids": ["missing_card"],
    })
    _assert_true(not rejected.get("success", false), "构筑装配器拒绝未知真气引用")

    var composition_root: Object = GameCompositionRootScript.new()
    _assert_true(composition_root.initialize(), "游戏组合根一次性加载统一内容平台")
    var first_session: Object = composition_root.create_run_session()
    var second_session: Object = composition_root.create_run_session()
    _assert_true(first_session._content_catalog == composition_root.content_catalog, "本局会话复用组合根内容目录")
    _assert_true(second_session._content_catalog == composition_root.content_catalog, "多个本局会话不重复创建内容目录")
    _assert_true(first_session.game_log == composition_root.game_log, "本局与战斗流程复用组合根结构化日志")
    var setup_result = first_session.execute({
        "type": "setup_run",
        "seed": 2308,
        "starter_build_id": "standard_52",
    })
    _assert_true(setup_result.success, "组合根建立的本局可按初始构筑启动")
    _assert_equal(first_session.snapshot().growth["run_deck_count"], 52, "初始构筑装配结果进入本局权威牌组")

func _test_node_reward_service_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "奖励服务测试内容目录有效")
    var service = NodeRewardServiceScript.new(catalog.definition("node_rewards"))
    var combat = service.create_bundle(
        {"id": "0_1", "type": "combat"},
        {"seed": 2308, "act": 1})
    var combat_again = service.create_bundle(
        {"id": "0_1", "type": "combat"},
        {"seed": 2308, "act": 1})
    _assert_equal(combat.to_dict(), combat_again.to_dict(), "相同节点上下文生成确定性奖励包")
    _assert_equal(combat.total("experience"), 3, "普通战斗奖励包包含三点历练")
    _assert_equal(
        combat.entries()[0].get("op"),
        "gain_experience",
        "节点历练奖励通过明确的本局效果操作执行")
    var elite = service.create_bundle({"id": "5_2", "type": "elite"}, {"seed": 2308, "act": 1})
    var boss = service.create_bundle({"id": "boss", "type": "boss"}, {"seed": 2308, "act": 1})
    _assert_equal(elite.total("experience"), 4, "精英奖励包包含四点历练")
    _assert_equal(boss.total("experience"), 5, "Boss奖励包包含五点历练")
    var event = service.create_bundle({"id": "4_2", "type": "event"}, {"seed": 2308, "act": 1})
    _assert_true(event.entries().is_empty(), "未确认的事件奖励保持空包而不补设计")
    var growth = GrowthInventoryScript.new()
    var applied: Dictionary = service.apply_bundle(combat, growth)
    _assert_true(applied.get("success", false), "奖励服务可以应用已实现的历练奖励")
    _assert_equal(growth.experience, 3, "奖励服务通过成长库存发放历练")
    var elite_growth = GrowthInventoryScript.new()
    _assert_true(
        service.apply_bundle(elite, elite_growth).get("success", false),
        "精英奖励包通过同一本局事务执行")
    _assert_equal(elite_growth.experience, 4, "精英节点实际获得四点历练")
    var boss_growth = GrowthInventoryScript.new()
    _assert_true(
        service.apply_bundle(boss, boss_growth).get("success", false),
        "Boss奖励包通过同一本局事务执行")
    _assert_equal(boss_growth.experience, 5, "Boss节点实际获得五点历练")

func _test_run_effect_platform_contract() -> void:
    var registry = RunEffectHandlerRegistryScript.new()
    _assert_equal(
        registry.operation_ids(),
        [
            "add_run_card_instances",
            "add_run_cards",
            "apply_run_card_reshape",
            "copy_run_card",
            "copy_run_card_state",
            "gain_experience",
            "grant_consumables",
            "grant_free_meditation_charge",
            "grant_inner_skills",
            "grant_items",
            "grant_techniques",
            "heal_life",
            "remove_items",
            "remove_run_cards",
            "transform_run_card",
            "write_source_marker",
        ],
        "本局效果默认注册表按稳定顺序公开十六个正式操作")
    _assert_true(registry.has_handler("gain_experience"), "历练增加操作已注册")
    _assert_true(registry.has_handler("heal_life"), "生命回复操作已注册")
    _assert_true(registry.has_handler("write_source_marker"),
        "来源标识写入操作已注册")

    var invalid_id_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not invalid_id_registry.register_handler(
            RunEffectProbeHandler.new(["Bad-Operation"])),
        "非 snake_case 本局效果操作 ID 被拒绝")
    var empty_id_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not empty_id_registry.register_handler(RunEffectProbeHandler.new([""])),
        "空本局效果操作 ID 被拒绝")
    var duplicate_declaration_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not duplicate_declaration_registry.register_handler(
            RunEffectProbeHandler.new(["probe_duplicate", "probe_duplicate"])),
        "单个 Handler 重复声明同一操作 ID 被拒绝")
    var duplicate_registration_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        duplicate_registration_registry.register_handler(
            RunEffectProbeHandler.new(["probe_registered"])),
        "第一个测试 Handler 可以注册")
    _assert_true(
        not duplicate_registration_registry.register_handler(
            RunEffectProbeHandler.new(["probe_registered"])),
        "多个 Handler 重复注册同一操作 ID 被拒绝")
    var invalid_contract_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not invalid_contract_registry.register_handler(RefCounted.new()),
        "不符合 RunEffectHandler 契约的对象被拒绝")

    var custom_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        custom_registry.register_handler(
            RunEffectProbeHandler.new(["probe_experience"])),
        "测试专用 Handler 只通过注册接入")
    var custom_growth = GrowthInventoryScript.new()
    var custom_result: Dictionary = RunMutationServiceScript.new(
        custom_registry).apply_effects(
            [{"op": "probe_experience", "amount": 4}], custom_growth)
    _assert_true(custom_result.get("success", false), "注册后的测试操作可由事务服务执行")
    _assert_equal(custom_growth.experience, 4, "测试操作无需修改中央服务即可增加历练")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "本局效果平台测试内容目录有效")
    var unknown_values := _catalog_definitions(catalog)
    unknown_values["node_rewards"]["node_rewards"]["combat"][0]["op"] = "missing_run_effect"
    var unknown_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_catalog.load_from_definitions(unknown_values),
        "未注册本局效果操作在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            unknown_catalog.errors,
            "未注册的本局效果操作：missing_run_effect"),
        "未知本局效果错误包含具名操作 ID")
    var invalid_gain_values := _catalog_definitions(catalog)
    invalid_gain_values["node_rewards"]["node_rewards"]["combat"][0].erase("amount")
    var invalid_gain_catalog = ContentCatalogScript.new()
    _assert_true(
        not invalid_gain_catalog.load_from_definitions(invalid_gain_values),
        "gain_experience 缺少 amount 时内容加载失败")
    _assert_true(
        _array_contains_text(
            invalid_gain_catalog.errors,
            "gain_experience amount 必须是非负整数"),
        "历练操作参数错误由 Handler 具名报告")

    var mutation = RunMutationServiceScript.new(registry)
    var percent_growth = GrowthInventoryScript.new(catalog)
    percent_growth.life = 70
    var percent_result: Dictionary = mutation.apply_effects(
        [{"op": "heal_life", "max_life_percent": 30}], percent_growth)
    _assert_true(percent_result.get("success", false), "按最大生命百分比回复执行成功")
    _assert_equal(percent_growth.life, 100, "70/100 按最大生命30%回复到100/100")
    _assert_equal(
        percent_result.get("applied", [])[0].get("theoretical_amount"),
        30,
        "百分比回复记录理论回复量30")
    var amount_growth = GrowthInventoryScript.new(catalog)
    amount_growth.life = 90
    var amount_result: Dictionary = mutation.apply_effects(
        [{"op": "heal_life", "amount": 30}], amount_growth)
    _assert_true(amount_result.get("success", false), "固定生命回复执行成功")
    _assert_equal(amount_growth.life, 100, "90/100 回复30点不超过上限")
    _assert_equal(
        amount_result.get("applied", [])[0].get("actual_amount"),
        10,
        "固定回复记录实际回复量10")
    _assert_true(
        not mutation.apply_effects([{
            "op": "heal_life",
            "amount": 20,
            "max_life_percent": 30,
        }], amount_growth).get("success", false),
        "heal_life 同时提供两种参数被拒绝")
    _assert_true(
        not mutation.apply_effects(
            [{"op": "heal_life"}], amount_growth).get("success", false),
        "heal_life 未提供回复参数被拒绝")
    _assert_true(
        not mutation.apply_effects(
            [{"op": "gain_experience", "amount": -1}], amount_growth
        ).get("success", false),
        "gain_experience 拒绝负数消费历练")

    var rollback_registry = RunEffectHandlerRegistryScript.new()
    _assert_true(
        rollback_registry.register_handler(
            RunEffectProbeHandler.new(["fail_after_gain"], true)),
        "原子失败探针注册成功")
    var rollback_growth = GrowthInventoryScript.new(catalog)
    rollback_growth.experience = 11
    rollback_growth.life = 70
    rollback_growth.consumable_ids.append("transaction_probe_consumable")
    rollback_growth.practice_purchases["transaction_probe_purchase"] = true
    rollback_growth.practice_shop_state = {"shop_index": 9, "slots": [{"id": "probe"}]}
    rollback_growth.hand_technique_progression["pair"]["slot_count"] = 3
    var rollback_before: Dictionary = rollback_growth.capture_mutation_state()
    var rollback_result: Dictionary = RunMutationServiceScript.new(
        rollback_registry).apply_effects([
            {"op": "gain_experience", "amount": 5},
            {"op": "fail_after_gain", "amount": 1},
        ], rollback_growth)
    _assert_true(not rollback_result.get("success", false), "第二个效果失败会拒绝整组事务")
    _assert_equal(rollback_result.get("failed_effect_index"), 1, "失败结果定位第二个效果")
    _assert_equal(
        rollback_result.get("failed_operation_id"),
        "fail_after_gain",
        "失败结果报告具名操作 ID")
    _assert_equal(
        rollback_growth.capture_mutation_state(),
        rollback_before,
        "事务失败后历练、生命、牌组、库存与修习状态全部保持不变")

    var success_growth = GrowthInventoryScript.new(catalog)
    success_growth.experience = 1
    success_growth.life = 70
    var success_result: Dictionary = mutation.apply_effects([
        {"op": "gain_experience", "amount": 4, "source": "contract_probe"},
        {"op": "heal_life", "amount": 20},
    ], success_growth)
    _assert_true(success_result.get("success", false), "多效果全部成功后提交一次真实状态")
    _assert_true(success_result.get("changed", false), "成功事务报告状态发生变化")
    _assert_equal(success_result.get("applied", []).size(), 2, "成功事务按数据顺序返回两个结果")
    _assert_equal(success_growth.experience, 5, "成功事务一次提交历练结果")
    _assert_equal(success_growth.life, 90, "成功事务一次提交生命结果")

    var save_session: RunSession = RunSessionScript.new()
    _assert_true(
        save_session.execute({"type": "setup_run", "seed": 2401}).success,
        "本局效果存档探针建立正式本局")
    save_session.growth.life = 70
    var save_effect_result: Dictionary = mutation.apply_effects([
        {"op": "gain_experience", "amount": 9},
        {"op": "heal_life", "amount": 20},
    ], save_session.growth)
    _assert_true(save_effect_result.get("success", false), "存档前本局效果事务执行成功")
    var restored: Dictionary = RunSaveDataScript.new().capture(
        save_session).restore_session(save_session._content_catalog)
    _assert_true(restored.get("success", false), "新框架产生的状态可以存档并读回")
    _assert_equal(restored["run_session"].growth.experience, 9, "读档保留本局效果增加的历练")
    _assert_equal(restored["run_session"].growth.life, 90, "读档保留本局效果回复的生命")

    var composition_root = GameCompositionRootScript.new()
    _assert_true(composition_root.initialize(), "组合根为本局效果平台注册共享依赖")
    var composed_session: RunSession = composition_root.create_run_session()
    _assert_true(
        composed_session._node_reward_service.handler_registry \
            == composition_root.run_effect_registry,
        "内容校验与节点奖励执行复用组合根中的同一注册表")
    var node_reward_source := FileAccess.get_file_as_string(
        "res://core/node_reward_service.gd")
    _assert_true(
        not node_reward_source.contains("match ") \
            and not node_reward_source.contains("gain_experience") \
            and not node_reward_source.contains("heal_life"),
        "NodeRewardService 不按操作 ID 或内容 ID 分支")

func _test_run_card_workshop_effects() -> void:
    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "真气工坊测试载入统一内容目录")
    var content_values := _catalog_definitions(base_catalog)
    content_values["card_states"]["other_reshapes"].append({
        "id": "echo_reshape", "name": "回响重塑"})
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_from_definitions(content_values), "测试目录扩展印记与其他定义")
    var growth = GrowthInventoryScript.new(catalog)
    growth.run_deck.reset_standard("craft")
    var workshop = CardWorkshopServiceScript.new()

    var wind_seven_before: Dictionary = growth.run_deck.card_data("wind_7")
    var attribute_change: Dictionary = workshop.apply_run_card_origin(
        growth.run_deck, ["wind_7"], "attribute_change", {"attribute": "mountain"})
    _assert_true(attribute_change.get("success", false), "风7可以转属为山")
    var mountain_seven: Dictionary = growth.run_deck.card_data("wind_7")
    _assert_equal(mountain_seven["attribute"], "mountain", "转属改变基础属性")
    _assert_equal(mountain_seven["rank_name"], "7", "转属保持牌阶")
    _assert_equal(mountain_seven["qi_value"], wind_seven_before["qi_value"], "转属保持基础真气值")
    _assert_equal(mountain_seven["definition_id"], "mountain_7", "转属更新正式定义 ID")
    _assert_equal(mountain_seven["instance_id"], "wind_7", "转属保持实例 ID")
    _assert_true(
        not workshop.apply_run_card_origin(
            growth.run_deck, ["wind_7"], "rank_change", {"direction": "up"}
        ).get("success", false),
        "已有本源的真气不能再次易阶")

    _assert_true(workshop.apply_run_card_origin(
        growth.run_deck, ["wind_K"], "rank_change", {"direction": "up"}
    ).get("success", false), "风K可以升为风A")
    var wind_ace: Dictionary = growth.run_deck.card_data("wind_K")
    var ace_definition: Dictionary = catalog.get_by_id("card", "wind_A")
    _assert_equal(wind_ace["definition_id"], "wind_A", "易阶更新定义 ID")
    _assert_equal(wind_ace["qi_value"], ace_definition["qi"], "易阶真气值读取 base_deck")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, ["forest_A"], "rank_change", {"direction": "up"}
    ).get("success", false), "A 不能升阶")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, ["forest_2"], "rank_change", {"direction": "down"}
    ).get("success", false), "2 不能降阶")
    _assert_true(workshop.apply_run_card_origin(
        growth.run_deck, ["fire_6"], "rank_change", {"direction": "down"}
    ).get("success", false), "火6可以降阶")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, ["fire_6"], "attribute_change", {"attribute": "wind"}
    ).get("success", false), "易阶后不能再次转属")

    var atomic_before_k: Dictionary = growth.run_deck.card_data("mountain_K")
    var atomic_before_a: Dictionary = growth.run_deck.card_data("mountain_A")
    var atomic_failure: Dictionary = workshop.apply_run_card_origin(
        growth.run_deck, ["mountain_K", "mountain_A"],
        "rank_change", {"direction": "up"})
    _assert_true(not atomic_failure.get("success", false), "多目标含非法本源目标时失败")
    _assert_equal(growth.run_deck.card_data("mountain_K"), atomic_before_k, "原子失败不修改前置合法目标")
    _assert_equal(growth.run_deck.card_data("mountain_A"), atomic_before_a, "原子失败不修改非法目标")

    _assert_true(workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_7"], "enhancement", "qi_boost").get("success", false),
        "本源改造后仍可获得强化")
    _assert_true(workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_7"], "imprint", "enlightenment").get("success", false),
        "印记占用独立单值槽")
    _assert_true(workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_7"], "other", "echo_reshape", {"amount": 2}
    ).get("success", false), "其他重塑保存 payload")
    var source: Dictionary = growth.run_deck.card_data("wind_7")
    var copied: Dictionary = workshop.copy_run_card(growth.run_deck, "wind_7", 1)
    _assert_true(copied.get("success", false), "完整复制成功")
    var copied_id := str(copied.get("instance_ids", [""])[0])
    var copied_data: Dictionary = growth.run_deck.card_data(copied_id)
    _assert_true(copied_id != "wind_7", "复制品使用新实例 ID")
    _assert_equal(copied_data["definition_id"], source["definition_id"], "复制继承当前基础身份")
    _assert_equal(copied_data["reshapes"], source["reshapes"], "复制继承本源锁与全部本局重塑")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, [copied_id], "rank_change", {"direction": "up"}
    ).get("success", false), "复制品继承本源锁")

    var battle_cards: Array = growth.run_deck.create_battle_cards()
    var qi_boost_card = null
    for card in battle_cards:
        if card.id == "wind_7":
            qi_boost_card = card
            break
    _assert_equal(qi_boost_card.effective_qi_value(), 15, "增元由配置令有效真气值+8")
    var pair_cards := []
    for card in battle_cards:
        if card.id in ["forest_8", "fire_8"]:
            card.set_enhancement("momentum")
            pair_cards.append(card)
    var momentum_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate(pair_cards))
    _assert_equal(momentum_values["card_multiplier_bonus"], 2, "两张乘势分别令功法倍率合计+2")
    var mixed = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_9"), "hunyuan:test", catalog.card_reshape_rules)
    mixed.set_enhancement("hunyuan")
    _assert_true(
        mixed.is_attribute("wind") and mixed.is_attribute("forest")
        and mixed.is_attribute("fire") and mixed.is_attribute("mountain"),
        "混元同时满足四种属性识别")
    _assert_equal(mixed.attribute, "wind", "混元不改变基础属性")
    mixed.set_enhancement("momentum")
    _assert_equal(mixed.reshape_enhancement, "momentum", "新强化替换旧强化")

    var save_session = RunSessionScript.new(null, null, null, null, catalog)
    _assert_true(save_session.execute({"type": "setup_run", "seed": 7112}).success, "建立存档测试本局")
    _assert_true(workshop.apply_run_card_origin(
        save_session.growth.run_deck, ["wind_7"],
        "attribute_change", {"attribute": "mountain"}).get("success", false),
        "存档前施加本源")
    workshop.apply_run_card_reshape(
        save_session.growth.run_deck, ["wind_7"], "enhancement", "qi_boost")
    workshop.apply_run_card_reshape(
        save_session.growth.run_deck, ["wind_7"], "imprint", "enlightenment")
    var saved_deck: Dictionary = save_session.growth.run_deck.to_snapshot()
    var restored: Dictionary = RunSaveDataScript.new().capture(
        save_session).restore_session(catalog)
    _assert_true(restored.get("success", false), "新 DTO 本局存档可以读回")
    _assert_equal(restored["run_session"].growth.run_deck.to_snapshot(), saved_deck, "读档保留本源、锁、强化与印记")

func _test_qi_instance_state_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "新真气实例契约载入统一目录")
    var lifecycle = CardStateLifecycleScript.new(catalog)
    var card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "f3c:wind_7",
        catalog.card_reshape_rules)
    card.set_enhancement("qi_boost")
    card.set_imprint("enlightenment")

    _assert_true(lifecycle.apply_anomaly(card, "buff", "qi_heat", {}, 2)["success"], "炽气首次施加")
    _assert_true(lifecycle.apply_anomaly(card, "buff", "qi_heat", {}, 3)["success"], "炽气同名叠层")
    _assert_true(lifecycle.apply_anomaly(card, "buff", "growth", {}, 1)["success"], "成长与炽气共存")
    _assert_true(lifecycle.apply_anomaly(card, "debuff", "qi_wither", {}, 2)["success"], "枯气与增益共存")
    _assert_true(lifecycle.apply_anomaly(card, "debuff", "decay", {}, 1)["success"], "衰败与枯气共存")
    _assert_equal(card.anomaly_layers("buff", "qi_heat"), 5, "buff 层数为正整数并累加")
    _assert_equal(card.anomaly_layers("debuff", "qi_wither"), 2, "debuff 独立保存层数")
    _assert_equal(card.effective_qi_value(), 18, "增元后由炽气与枯气共同修改统一有效真气值")

    _assert_true(lifecycle.apply_anomaly(card, "state", "vulnerability")["success"], "单状态槽首次施加")
    _assert_true(not lifecycle.apply_anomaly(card, "state", "poison")["success"], "不同状态默认不能覆盖")
    _assert_true(lifecycle.apply_anomaly(card, "state", "poison", {}, 1, true)["success"], "replace_state 显式覆盖")
    _assert_equal(card.current_state()["id"], "poison", "状态槽只保存替换后的毒")
    _assert_true(lifecycle.apply_anomaly(card, "mark", "wind_lure")["success"], "不同标记可建立")
    _assert_true(lifecycle.apply_anomaly(card, "mark", "regroup")["success"], "多个标记共存")
    _assert_true(card.set_temporary_enhancement("momentum"), "临时强化独立写入")
    _assert_true(card.set_temporary_attribute("fire"), "临时属性独立写入")

    var run_data: Dictionary = QiCardInstanceDataScript.capture(card)
    _assert_equal(run_data["version"], 5, "QiCardInstanceData 提升到版本 5")
    _assert_true(not run_data.has("anomalies"), "普通 RunDeck DTO 不保存异状")
    _assert_true(not run_data.has("temporary_reshapes"), "普通 RunDeck DTO 不保存临时重塑")
    _assert_equal(QiCardInstanceDataScript.validate(run_data, catalog), [], "持久 DTO 通过校验")
    var battle_data: Dictionary = QiCardInstanceDataScript.capture(card, true)
    _assert_equal(battle_data["anomalies"]["state"]["payload"], {}, "战斗 DTO 保存状态 payload")
    _assert_equal(battle_data["temporary_reshapes"]["attribute"], "fire", "战斗 DTO 保存临时属性")
    _assert_equal(QiCardInstanceDataScript.validate(battle_data, catalog, true), [], "新战斗 DTO 通过严格校验")
    var restored = QiCardInstanceDataScript.restore(battle_data, catalog.card_reshape_rules)
    _assert_equal(restored.anomaly_snapshot(), card.anomaly_snapshot(), "战斗 DTO 完整恢复四类异状")
    _assert_equal(restored.temporary_reshapes, card.temporary_reshapes, "战斗 DTO 完整恢复临时重塑")

    var removed: Dictionary = lifecycle.on_enter_discard(restored)
    _assert_equal(removed["state"]["id"], "poison", "实际入弃牌堆移除状态")
    _assert_true(not restored.has_anomaly("buff", "growth"), "成长入弃牌堆移除")
    _assert_true(not restored.has_anomaly("debuff", "decay"), "衰败入弃牌堆移除")
    _assert_equal(restored.anomaly_layers("buff", "qi_heat"), 5, "炽气跨牌区保留")
    _assert_equal(restored.anomaly_layers("debuff", "qi_wither"), 2, "枯气跨牌区保留")
    _assert_true(restored.has_anomaly("mark", "regroup"), "普通入堆清理不擅自删除标记")

    var purified = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_9"), "f3c:purified",
        catalog.card_reshape_rules)
    purified.set_enhancement("qi_boost")
    purified.set_imprint("echo")
    lifecycle.apply_anomaly(purified, "buff", "qi_heat", {}, 2)
    lifecycle.apply_anomaly(purified, "state", "poison")
    lifecycle.apply_anomaly(purified, "debuff", "burned_out")
    purified.set_temporary_enhancement("momentum")
    purified.set_temporary_attribute("wind")
    _assert_true(lifecycle.apply_anomaly(purified, "mark", "purification")["success"], "首次净化合法")
    _assert_true(purified.reshape_enhancement == "qi_boost" and purified.reshape_imprint == "echo", "净化保留永久重塑")
    _assert_true(purified.anomaly_snapshot()["buffs"].is_empty() and purified.current_state().is_empty(), "净化清除 buff/debuff/state")
    _assert_equal(purified.anomaly_snapshot()["marks"].keys(), ["purification"], "净化最后只建立自身")
    _assert_equal(purified.temporary_reshapes, {
        "enhancement": "", "attribute": "", "rank": {}}, "净化清除临时重塑")
    _assert_true(not lifecycle.apply_anomaly(purified, "mark", "purification")["success"], "重复净化被拒绝且不再清理")
    _assert_true(lifecycle.apply_anomaly(purified, "state", "poison")["success"], "净化不是持续免疫")
    lifecycle.on_battle_end(purified)
    _assert_true(purified.anomaly_snapshot()["marks"].is_empty(), "战斗结束清除全部标记")
    _assert_equal(purified.reshape_enhancement, "qi_boost", "战斗结束永久强化保持")

    var legacy_battle := battle_data.duplicate(true)
    legacy_battle["anomalies"] = {
        "poison": "lethal_poison", "state": "", "marks": {}, "others": {}}
    _assert_true(
        not QiCardInstanceDataScript.validate(legacy_battle, catalog, true).is_empty(),
        "旧双毒战斗快照明确拒绝而不自动映射")

func _test_remote_ai_module_contract() -> void:
    var context = AiBattleContextScript.new().configure({
        "battle_id": "battle-ai-contract",
        "rules_version": "v0.30",
        "content_version": 2,
        "content_fingerprint": "contract-content-fingerprint",
        "ai_protocol_version": 3,
        "prompt_version": 3,
        "player_build": {
            "deck": ["wind_2", "forest_3"],
            "techniques": [],
        },
        "enemy_build": {"archetype": "mock_enemy"},
        "visibility": {"opponent_hand": false, "opponent_draw_order": false},
        "protocol": {
            "history_compression_rounds": 5,
            "credentials": {"api_key": "must-not-be-persisted"},
        },
    })
    _assert_true(context.is_valid(), "远程 AI 战斗上下文包含战斗 ID 与规则版本")

    var observation = AiDecisionObservationScript.new().configure({
        "decision_id": "decision-1",
        "window_id": "combo-window-1",
        "state_hash": "state-hash-1",
        "round_number": 1,
        "action_index": 2,
        "self_state": {"hand_cards": ["enemy:fire_2"], "life": 80},
        "opponent_public_state": {
            "life": 91,
            "defense": 7,
            "hand_count": 6,
            "draw_pile_count": 37,
            "hand_cards": ["player:wind_2"],
            "draw_order": ["player:forest_3"],
            "selected_card_ids": ["player:fire_4"],
            "rng_seed": 2308,
            "nested": {
                "public_status": "purification",
                "hand": ["player:hidden-nested"],
            },
        },
    })
    var observed_opponent: Dictionary = observation.snapshot()["opponent"]
    _assert_true(observation.is_valid(), "远程 AI 决策观察包含窗口状态凭据")
    _assert_equal(observed_opponent.get("life"), 91, "远程 AI 保留玩家公开生命")
    _assert_equal(observed_opponent.get("hand_count"), 6, "远程 AI 保留玩家公开手牌数量")
    _assert_true(not observed_opponent.has("hand_cards"), "远程 AI 观察移除玩家隐藏手牌身份")
    _assert_true(not observed_opponent.has("draw_order"), "远程 AI 观察移除玩家抽牌顺序")
    _assert_true(not observed_opponent.has("selected_card_ids"), "远程 AI 观察移除玩家选牌草稿")
    _assert_true(not observed_opponent.has("rng_seed"), "远程 AI 观察移除随机种子")
    _assert_equal(observed_opponent["nested"].get("public_status"), "purification", "递归脱敏保留嵌套公开状态")
    _assert_true(not observed_opponent["nested"].has("hand"), "递归脱敏移除嵌套隐藏手牌")

    var projector = AiHistoryProjectorScript.new()
    var projected_events: Array = projector.project_many([
        {
            "sequence": 10,
            "round_number": 1,
            "action_index": 1,
            "window_id": "player-only-combo",
            "event_type": "action_window_opened",
            "actor_id": "player",
            "visibility": "public",
            "payload": {"enemy_can_act": false},
        },
        {
            "sequence": 11,
            "round_number": 1,
            "action_index": 1,
            "window_id": "player-only-combo",
            "event_type": "cards_played",
            "actor_id": "player",
            "visibility": "hidden_random_target",
            "payload": {
                "hand_type": "high_card",
                "played_card_ids": ["player:wind_2"],
                "context": {
                    "target_card_ids": ["enemy:hidden-1", "enemy:hidden-2"],
                },
            },
        },
        {
            "sequence": 12,
            "round_number": 1,
            "event_type": "private_draw_order",
            "actor_id": "player",
            "visibility": "private",
            "payload": {"drawn_card_ids": ["player:forest_3"]},
        },
    ])
    _assert_equal(projected_events.size(), 2, "私有事件完全不进入远程 AI 历史")
    _assert_equal(projected_events[1]["payload"].get("hidden_target_count"), 2, "隐藏随机目标只公开命中数量")
    _assert_true(not projected_events[1]["payload"]["context"].has("target_card_ids"), "嵌套隐藏随机目标不公开真气身份")

    var conversation = AiBattleConversationScript.new().configure(context, {
        "compression_enabled": true,
        "compression_interval_rounds": 5,
        "max_retries": 1,
    })
    for event in projected_events:
        conversation.record_public_event(event)
    _assert_equal(conversation.exchanges.size(), 0, "敌方无行动机会时只积压历史且不建立接口请求")
    _assert_true(not conversation.complete_round(4), "默认第 4 个完整回合不压缩工作历史")

    var proposal = BattleActionProposalScript.new().configure_accept(
        "remote_ai",
        ["enemy:fire_2", "enemy:fire_3"],
        {"hand": {"id": "pair"}, "damage": 12})
    var candidate = AiCandidateScript.new().configure({
        "candidate_id": "candidate-pair-with-synergy",
        "groups": [
            {"group_index": 0, "kind": "main", "card_ids": ["enemy:fire_2", "enemy:fire_3"]},
            {"group_index": 1, "kind": "synergy", "card_ids": ["enemy:wind_4"]},
        ],
        "summary": {"damage_min": 10, "damage_max": 14, "defense": 0},
        "tags": ["pair", "synergy"],
    }, proposal)
    _assert_true(candidate.is_valid(), "远程 AI 合法候选有效")
    _assert_equal(candidate.public_snapshot()["groups"].size(), 2, "候选同时承载主组与协同组")

    var provider = MockAiProviderScript.new(true)
    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 3,
            "decision_id": "decision-1",
            "state_hash": "state-hash-1",
            "candidate_id": "not-a-local-candidate",
        },
    })
    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 3,
            "decision_id": "decision-1",
            "state_hash": "state-hash-1",
            "candidate_id": "candidate-pair-with-synergy",
            "reason_code": "resource_preservation",
            "confidence": 0.75,
        },
    })
    var gateway = AiDecisionGatewayScript.new(provider)
    var retry_count := [0]
    var ready_proposals: Array = []
    var ready_metadata: Array = []
    gateway.decision_retry.connect(func(_decision_id, _retry_index, _error):
        retry_count[0] = int(retry_count[0]) + 1)
    gateway.decision_ready.connect(func(_decision_id, ready_proposal, metadata):
        ready_proposals.append(ready_proposal)
        ready_metadata.append(metadata))
    var begin_result: Dictionary = gateway.begin_decision(conversation, observation, [candidate])
    _assert_true(begin_result.get("success", false), "远程 AI Gateway 接受异步决策任务")
    _assert_equal(provider.submitted_requests.size(), 2, "非法候选触发一次结构化纠错重试")
    _assert_equal(retry_count[0], 1, "Gateway 发出一次纠错重试事件")
    _assert_equal(ready_proposals.size(), 1, "合法回答只产生一个最终行动提案")
    _assert_true(ready_proposals[0] == proposal, "远程回答绑定本地 BattleActionProposal 而非直接动作")
    _assert_equal(ready_metadata[0].get("candidate_id"), candidate.candidate_id, "最终提案记录已验证候选 ID")
    var first_request: Dictionary = provider.submitted_requests[0]["payload"]
    var retry_request: Dictionary = provider.submitted_requests[1]["payload"]
    _assert_equal(first_request["history_delta"].size(), 2, "下次敌方出手收到此前无行动窗口的全部公开历史")
    _assert_equal(first_request["history_delta"][0]["window_id"], "player-only-combo", "单方连击窗口按原窗口 ID 上报")
    _assert_true(retry_request.has("correction"), "重试请求携带机器可读纠错信息")
    _assert_equal(retry_request["correction"].get("error_code"), "INVALID_CANDIDATE", "纠错明确指出非法候选")

    _assert_true(conversation.complete_round(5), "默认第 5 个完整回合压缩工作历史")
    _assert_equal(conversation.provider_epoch, 1, "压缩后推进 Provider 会话分段")
    _assert_equal(conversation.public_events.size(), 2, "压缩不删除本地完整公开事件")
    _assert_equal(conversation.work_summary.get("event_count"), 2, "工作摘要覆盖已积压事件")

    var next_observation = AiDecisionObservationScript.new().configure({
        "decision_id": "decision-2",
        "window_id": "round-6-main",
        "state_hash": "state-hash-2",
        "round_number": 6,
        "action_index": 0,
        "self_state": {"life": 80},
        "opponent_public_state": {"life": 91},
    })
    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 3,
            "decision_id": "decision-2",
            "state_hash": "state-hash-2",
            "candidate_id": "candidate-pair-with-synergy",
        },
    })
    gateway.begin_decision(conversation, next_observation, [candidate])
    var next_request: Dictionary = provider.submitted_requests[2]["payload"]
    _assert_equal(next_request.get("provider_epoch"), 1, "压缩后的下一次请求使用新 Provider epoch")
    _assert_true(next_request.has("battle_context"), "新 Provider epoch 重新发送战斗上下文")
    _assert_equal(next_request["history_delta"], [], "已压缩且已发送事件不在增量中重复发送")

    var store = AiConversationStoreScript.new()
    var conversation_snapshot: AiConversationSnapshot = conversation.snapshot()
    _assert_true(
        conversation_snapshot is AiConversationSnapshot
        and not conversation_snapshot.has_method("value"),
        "AI 对话快照按字段读取且不保留无类型旁路")
    var encoded: String = store.encode(conversation_snapshot)
    var decoded: Dictionary = store.decode(encoded)
    _assert_equal(
        decoded["context_snapshot"]["protocol"]["credentials"]["api_key"],
        "[REDACTED]",
        "AI 会话持久化递归脱敏 API Key")
    _assert_equal(decoded["battle_id"], conversation.battle_id, "AI 审计快照读取战斗 ID")
    _assert_equal(decoded["public_events"].size(), conversation.public_events.size(), "AI 审计快照读取完整公开事件数量")
    _assert_equal(decoded["public_events"][1]["window_id"], "player-only-combo", "AI 审计快照读取事件窗口")
    _assert_equal(int(decoded["public_events"][1]["sequence"]), 11, "AI 审计快照读取事件序号")
    _assert_equal(decoded["exchanges"].size(), conversation.exchanges.size(), "AI 审计快照读取请求回答链")
    provider.free()

func _test_remote_ai_action_window_session_gate() -> void:
    var provider = MockAiProviderScript.new(false)
    var session: BattleSession = BattleSessionScript.new()
    session.use_ai_provider(provider)
    var configuration := {
        "content_seed": 2308,
        "content_id": "remote-ai-window-contract",
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
            "use_remote_ai": true,
        },
        "ai_settings": {
            "timeout_msec": 30000,
            "max_retries": 1,
            "intent_visibility": "full",
        },
    }
    _assert_true(session.setup_battle(configuration), "远程 AI 行动窗口战斗建立成功")
    session.engine.sequence_book.configure_with_capacities(
        {"high_card": []}, {"high_card": 1})
    session.engine.enemy.hand = [
        _card("2", "wind"), _card("3", "wind"), _card("4", "wind"),
        _card("5", "wind"), _card("6", "wind")]
    session.engine.enemy.draw_pile.clear()
    session.engine.enemy.same_qi_value = 4
    _assert_true(session.execute({"type": "start_turn"}).success, "远程 AI 战斗开始首个行动窗口")
    var thinking_snapshot = session.snapshot()
    _assert_equal(thinking_snapshot.ai_decision["state"], "thinking", "行动窗口开始时敌方立即进入异步思考")
    _assert_true(not thinking_snapshot.ai_decision["can_player_confirm"], "敌方思考期间玩家确认门禁关闭")
    _assert_equal(thinking_snapshot.locked_enemy_card_count, 0, "AI 回答前敌方不提前移动或锁定真气")
    _assert_equal(provider.submitted_requests.size(), 1, "首个敌方出手机会只发送一次接口请求")
    var first_request: Dictionary = provider.submitted_requests[0]["payload"]
    _assert_true(first_request.get("candidates", []).size() in range(1, 6), "远程 AI 只收到 1～5 个本地压缩候选")
    _assert_equal(first_request["candidates"][0]["groups"][0]["kind"], "main", "普通候选使用第 0 主牌型组契约")
    _assert_true(first_request["observation"]["self"].has("same_qi_value"), "AI 观察包含自身当前同气")
    _assert_true(first_request["observation"]["opponent"].has("same_qi_capacity"), "AI 观察包含对手有效同气容量")
    _assert_true(first_request["candidates"][0]["summary"].has("same_qi_gain"), "AI 候选特征包含预计同气收益")
    for intent_value in thinking_snapshot.possible_enemy_intents:
        _assert_true(intent_value.has("same_qi_gain"), "玩家可见可能意图包含预计同气收益")
        _assert_true(not intent_value.has("candidate_id"), "可能意图不暴露 AI 最终候选身份")
    var same_qi_candidate_id := ""
    for candidate_value in first_request.get("candidates", []):
        var candidate: Dictionary = candidate_value
        if int(candidate.get("summary", {}).get(
                "same_qi_trigger_count", 0)) > 0:
            same_qi_candidate_id = str(candidate.get("candidate_id", ""))
            break
    _assert_true(same_qi_candidate_id != "", "压缩候选保留一个预计充满同气的方向")

    var player_hand_before: Array = thinking_snapshot.player.hand
    var blocked_play := session.execute({
        "type": "play_cards",
        "card_ids": [player_hand_before[0]["id"]],
    })
    _assert_true(not blocked_play.success, "敌方思考期间玩家出牌命令被应用层拒绝")
    _assert_true(blocked_play.reason.contains("思考"), "出牌门禁返回明确思考状态")
    _assert_equal(session.snapshot().player.staging_count, 0, "门禁拒绝不会把玩家真气移入待出区")
    var blocked_end := session.execute({"type": "end_turn"})
    _assert_true(not blocked_end.success, "敌方思考期间结束回合同样受门禁保护")

    var consumable_result := session.execute({
        "type": "use_consumable",
        "slot_index": 0,
        "card_ids": [],
    })
    _assert_true(consumable_result.success, "敌方思考期间仍可使用只影响我方的消耗品")
    _assert_equal(provider.submitted_requests.size(), 1, "思考期间使用我方消耗品不取消或重发当前请求")

    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 3,
            "decision_id": first_request["observation"]["decision_id"],
            "state_hash": first_request["observation"]["state_hash"],
            "candidate_id": same_qi_candidate_id,
        },
    })
    _assert_true(provider.complete(str(provider.submitted_requests[0]["request_id"])), "Mock Provider 完成首个远程回答")
    var ready_snapshot = session.snapshot()
    _assert_equal(ready_snapshot.ai_decision["state"], "ready", "合法回答通过后行动窗口转为思考完毕")
    _assert_true(ready_snapshot.ai_decision["can_player_confirm"], "敌方行动锁定后开放玩家确认")
    _assert_equal(ready_snapshot.locked_enemy_card_count, 0, "远程候选锁定后仍不泄露实际出牌张数")
    _assert_true(ready_snapshot.enemy_plan.is_empty(), "远程候选锁定后不公开实际伤害与防御")
    _assert_equal(
        ready_snapshot.possible_enemy_intents,
        thinking_snapshot.possible_enemy_intents,
        "AI 思考完成前后可能意图内容和冻结顺序完全一致")

    var mixed_ids: Array[String] = []
    var ready_hand: Array = ready_snapshot.player.hand
    for left_index in range(ready_hand.size()):
        for right_index in range(left_index + 1, ready_hand.size()):
            if ready_hand[left_index]["attribute"] != ready_hand[right_index]["attribute"]:
                mixed_ids = [
                    str(ready_hand[left_index]["id"]),
                    str(ready_hand[right_index]["id"]),
                ]
                break
        if not mixed_ids.is_empty():
            break
    _assert_equal(mixed_ids.size(), 2, "固定起手存在混属性选牌用于制造敌方单方连击窗口")
    var synchronized_result := session.execute({
        "type": "play_cards",
        "card_ids": mixed_ids,
    })
    _assert_true(synchronized_result.success, "双方提案都准备后才进入真实同步结算")
    _assert_equal(provider.submitted_requests.size(), 2, "敌方获得连击出手机会后立即发起第二次接口请求")
    var second_request: Dictionary = provider.submitted_requests[1]["payload"]
    var second_history_types: Array[String] = []
    for event in second_request.get("history_delta", []):
        second_history_types.append(str(event.get("event_type", "")))
    _assert_true(second_history_types.has("consumable_used"), "下一次请求补发思考期间的我方消耗品事件")
    _assert_true(second_history_types.has("cards_played"), "下一次请求包含双方上一击公开出牌历史")
    _assert_true(second_history_types.has("same_qi_changed"), "下一次请求包含结构化同气变化历史")
    _assert_true(second_history_types.has("action_resolved"), "下一次请求包含上一击生命防御结算结果")
    _assert_equal(session.snapshot().ai_decision["state"], "thinking", "敌方单方连击使用新的独立思考窗口")

    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 3,
            "decision_id": second_request["observation"]["decision_id"],
            "state_hash": second_request["observation"]["state_hash"],
            "candidate_id": second_request["candidates"][0]["candidate_id"],
        },
    })
    _assert_true(provider.complete(str(provider.submitted_requests[1]["request_id"])), "Mock Provider 完成敌方单方连击回答")
    _assert_equal(session.snapshot().enemy.discard_count, 3, "玩家无行动机会时敌方合法回答自动完成同气槽单方连动")
    _assert_equal(provider.submitted_requests.size(), 2, "第二击未再次充满同气时不额外请求")
    _assert_true(session.execute({"type": "end_turn"}).success, "双方行动耗尽后可以正常结束完整回合")

    var timeout_provider = MockAiProviderScript.new(false)
    var timeout_session: BattleSession = BattleSessionScript.new()
    timeout_session.use_ai_provider(timeout_provider)
    var timeout_configuration: Dictionary = configuration.duplicate(true)
    timeout_configuration["content_seed"] = 2309
    timeout_configuration["content_id"] = "remote-ai-timeout-contract"
    _assert_true(timeout_session.setup_battle(timeout_configuration), "远程 AI 超时保底战斗建立成功")
    timeout_session.execute({"type": "start_turn"})
    _assert_true(timeout_session.poll_ai_timeout(9223372036854775807), "到达截止时间后取消远程请求")
    var fallback_snapshot = timeout_session.snapshot()
    _assert_equal(fallback_snapshot.ai_decision["state"], "fallback_ready", "远程超时后由本地 Utility AI 接管")
    _assert_true(fallback_snapshot.ai_decision["can_player_confirm"], "本地接管成功后重新开放玩家确认")
    _assert_equal(timeout_provider.pending.size(), 0, "超时取消清理 Provider 待处理请求")
    var timeout_system_log: Array = fallback_snapshot.system_log
    var has_fallback_log := false
    for entry in timeout_system_log:
        if str(entry.get("category", "")) == "remote_ai_fallback":
            has_fallback_log = true
            break
    _assert_true(has_fallback_log, "远程超时降级进入统一系统日志")
    var timeout_exchange_kinds: Array[String] = []
    for exchange in timeout_session.ai_conversation_snapshot().exchanges:
        timeout_exchange_kinds.append(str(exchange.get("kind", "")))
    _assert_true(timeout_exchange_kinds.has("response"), "AI 会话持久记录超时取消响应")
    _assert_true(timeout_exchange_kinds.has("fallback_selected"), "AI 会话持久记录最终本地接管行动")
    provider.free()
    timeout_provider.free()

func _test_enemy_candidate_reduction_and_hidden_intents() -> void:
    var provider = MockAiProviderScript.new(false)
    var session: BattleSession = BattleSessionScript.new()
    session.use_ai_provider(provider)
    var configuration := {
        "content_seed": 2308,
        "content_id": "candidate-reduction-contract",
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
            "use_remote_ai": true,
        },
    }
    _assert_true(session.setup_battle(configuration), "候选压缩测试战斗建立")
    session.execute({"type": "start_turn"})
    var thinking = session.snapshot()
    var reduction: Dictionary = session.engine.enemy_planning_service.last_candidate_reduction
    _assert_true(int(reduction.get("full_count", 0)) > 5, "八张手牌的完整合法候选仍在本地枚举")
    _assert_true(int(reduction.get("reduced_count", 0)) in range(1, 6), "对外候选压缩为 1～5 个")
    _assert_equal(
        provider.submitted_requests[0]["payload"]["candidates"].size(),
        thinking.possible_enemy_intents.size(),
        "远程 AI 与玩家可能意图来自同一压缩集合")
    var public_ids: Dictionary = {}
    for intent in thinking.possible_enemy_intents:
        public_ids[str(intent["public_id"])] = true
        _assert_true(not intent.has("candidate_id"), "公开意图不含远程候选 ID")
        _assert_true(not intent.has("selected"), "公开意图不含选择标记")
        _assert_true(not intent.has("card_ids"), "公开意图不含敌方卡牌实例")
    _assert_equal(public_ids.size(), thinking.possible_enemy_intents.size(), "公开意图不制造重复项")

    var request: Dictionary = provider.submitted_requests[0]["payload"]
    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 3,
            "decision_id": request["observation"]["decision_id"],
            "state_hash": request["observation"]["state_hash"],
            "candidate_id": request["candidates"][0]["candidate_id"],
        },
    })
    provider.complete(str(provider.submitted_requests[0]["request_id"]))
    var ready = session.snapshot()
    _assert_equal(ready.possible_enemy_intents, thinking.possible_enemy_intents, "AI 锁定不移动或重排可能意图")
    _assert_equal(ready.locked_enemy_card_count, 0, "AI 锁定阶段不泄露实际出牌数量")
    _assert_true(ready.enemy_plan.is_empty(), "AI 锁定阶段不泄露实际伤防")

    var player_ids: Array[String] = [str(ready.player.hand[0]["id"])]
    var resolved := session.execute({"type": "play_cards", "card_ids": player_ids})
    _assert_true(resolved.success, "双方确认后进入正式揭示与结算")
    var revealed = session.snapshot()
    _assert_true(not revealed.last_enemy_preview.is_empty(), "正式揭示后公开实际敌方行动预览")
    _assert_true(revealed.locked_enemy_card_count > 0, "正式揭示后才公开实际出牌数量")
    _assert_true(revealed.enemy_plan.has("damage"), "正式揭示后才公开实际伤害与防御")

    var reducer = EnemyCandidateReducerScript.new()
    _assert_equal(reducer.normalize_policy({"candidate_limit": 0})["candidate_limit"], 1, "候选下限明确归一化为 1")
    _assert_equal(reducer.normalize_policy({"candidate_limit": 9})["candidate_limit"], 5, "候选上限明确归一化为 5")

    var one_actor = BattleSideScript.new("单选敌人", "single")
    var one_target = BattleSideScript.new("目标", "target")
    var only_card = _card("2", "wind")
    only_card.effective_qi_value()
    one_actor.hand = [only_card]
    one_actor.hand_limit = 8
    var one_observation = BattleObservationScript.new()
    one_observation.actor_hand = one_actor.hand
    one_observation.actor_life = 20
    one_observation.actor_max_life = 20
    one_observation.opponent_life = 20
    var only_preview := {
        "valid": true,
        "hand": {"id": "high_card", "contributing": [only_card]},
        "intent": {"damage": 2, "defense": 0, "combo": false},
        "condition": {"ok": true},
        "technique_id": "",
        "next_technique_id": "",
    }
    var only_proposal = BattleActionProposalScript.new().configure_accept(
        "test", [only_card.id], only_preview)
    var one_before := one_actor.capture_passive_query_state()
    var one_result: Dictionary = reducer.reduce(
        [only_proposal], one_observation, one_actor, one_target, {"candidate_limit": 5})
    _assert_equal(one_result["proposals"].size(), 1, "只有一个合法方案时只返回一个且不补重复")
    _assert_equal(
        one_actor.capture_passive_query_state(), one_before,
        "重复画像与压缩不移动卡牌、不修改状态或 RNG")

    var dominance = EnemyCandidateDominanceFilterScript.new()
    var prepare := EnemyCandidateFeaturesScript.empty()
    prepare["immediate"]["damage"] = 10
    prepare["card_flow"]["played_count"] = 2
    prepare["card_flow"]["retained_count"] = 3
    prepare["future"]["retained_hand_value"] = 8.0
    var cycle := prepare.duplicate(true)
    cycle["card_flow"]["played_count"] = 5
    cycle["card_flow"]["expected_next_normal_draw"] = 5
    cycle["card_state"]["negative_card_cleanup_value"] = 6.0
    cycle["future"]["retained_hand_value"] = 0.0
    var tradeoff_records := [
        {"features": prepare, "serial": 0},
        {"features": cycle, "serial": 1},
    ]
    _assert_equal(dominance.filter(tradeoff_records).size(), 2, "同伤害的两张蓄势与五张换气各有优势并同时保留")
    var worse := prepare.duplicate(true)
    worse["future"]["retained_hand_value"] = 2.0
    _assert_equal(dominance.filter([
        {"features": prepare, "serial": 0},
        {"features": worse, "serial": 1},
    ]).size(), 1, "同方向且所有关键维度全面更差的候选被帕累托淘汰")
    var lethal_feature := EnemyCandidateFeaturesScript.empty()
    lethal_feature["immediate"]["lethal"] = true
    var survival_feature := EnemyCandidateFeaturesScript.empty()
    survival_feature["immediate"]["avoids_immediate_death"] = true
    var ordinary_feature := EnemyCandidateFeaturesScript.empty()
    var hard_records := [
        {"features": lethal_feature, "serial": 0},
        {"features": survival_feature, "serial": 1},
        {"features": ordinary_feature, "serial": 2},
    ]
    reducer._mark_unique_hard_candidates(hard_records)
    _assert_true(
        lethal_feature["internal"]["hard_reasons"].has("lethal"),
        "唯一斩杀候选进入硬保护")
    _assert_true(
        survival_feature["internal"]["hard_reasons"].has("survival"),
        "唯一保命候选进入硬保护")
    var similar_left := prepare.duplicate(true)
    var similar_right := prepare.duplicate(true)
    similar_left["internal"]["card_ids"] = ["a", "b"]
    similar_right["internal"]["card_ids"] = ["a", "b"]
    _assert_true(
        reducer._similarity(similar_left, similar_right) >= 0.94,
        "高度重复画像达到 MMR 重复候选停止阈值")

    var query_actor = BattleSideScript.new("估值方", "query")
    var query_target = BattleSideScript.new("估值目标", "query_target")
    query_actor.defense = 3
    var query_service = EnemyAiValueQueryServiceScript.new()
    var fake = FakeEnemyAiValueProviderScript.new().configure({
        "ai_action_value_query": {
            "success": true,
            "estimated_value": 10.0,
            "progress_value": 4.0,
            "progress_entries": [{
                "source_kind": "inner_skill", "source_id": "fake",
                "counter_before": 2, "counter_after": 3,
                "trigger_ready": true, "estimated_value": 10,
            }],
        },
    })
    query_service.register_provider(fake, "fake_inner_skill", 50)
    var action_value := query_service.query("ai_action_value_query", {
        "actor": query_actor, "target": query_target,
    })
    _assert_equal(action_value["estimated_value"], 10.0, "内功即时触发通过纯查询进入估值")
    _assert_equal(action_value["progress_entries"][0]["counter_after"], 3, "内功计数临界信息进入结构化画像来源")
    _assert_equal(query_actor.defense, 3, "重复估值不修改战斗状态")
    var positive_card = _card("5", "fire")
    positive_card.set_anomaly("buff", "qi_heat", {}, 2)
    var negative_card = _card("6", "forest")
    negative_card.set_anomaly("debuff", "decay", {}, 2)
    negative_card.set_anomaly("state", "poison")
    var reshape_card = _card("7", "mountain")
    reshape_card.reshape_enhancement = "fake_play_enhancement"
    reshape_card.reshape_imprint = "fake_play_imprint"
    query_actor.hand = [positive_card, negative_card, reshape_card]
    var positive_retention := query_service.query(
        "ai_card_retention_value_query", {
            "actor": query_actor, "target": query_target, "card": positive_card,
        })
    var negative_play := query_service.query(
        "ai_card_play_value_query", {
            "actor": query_actor, "target": query_target, "card": negative_card,
        })
    var reshape_play := query_service.query(
        "ai_card_play_value_query", {
            "actor": query_actor, "target": query_target, "card": reshape_card,
        })
    _assert_true(
        float(positive_retention["estimated_value"]) > 0.0,
        "正面留手真气提高保留价值")
    _assert_true(
        float(negative_play["negative_card_cleanup_value"]) > 0.0,
        "负面留手真气提高换气或清理价值")
    _assert_true(
        float(reshape_play["estimated_value"]) > 0.0,
        "打出型强化与印记进入卡牌打出价值")
    var mutating = FakeEnemyAiValueProviderScript.new()
    mutating.mutate_actor = true
    var guarded_query = EnemyAiValueQueryServiceScript.new()
    guarded_query.register_provider(mutating, "mutating_fake", 10)
    var guarded_before := query_actor.capture_passive_query_state()
    var guarded_result := guarded_query.query("ai_action_value_query", {
        "actor": query_actor, "target": query_target,
    })
    _assert_true(not guarded_result["success"], "估值 Handler 修改战斗状态时查询明确失败")
    _assert_equal(
        query_actor.capture_passive_query_state(), guarded_before,
        "失败的估值查询恢复状态且不推进 RNG 或计数器")
    provider.free()

func _test_chat_completions_provider_contract() -> void:
    var defaults = AiProviderSettingsScript.new()
    _assert_equal(defaults.provider_id, "deepseek", "远程 AI 默认服务商为 DeepSeek")
    _assert_equal(defaults.base_url, "https://api.deepseek.com", "DeepSeek 默认 base_url 正确")
    _assert_equal(defaults.endpoint_url(), "https://api.deepseek.com/chat/completions", "OpenAI 兼容 Chat Completions 端点正确")
    _assert_equal(defaults.model, "deepseek-v4-flash", "频繁战斗窗口默认使用 Flash 模型")
    _assert_equal(defaults.reasoning_effort, "medium", "Flash 默认使用中等推理强度")
    _assert_true(defaults.thinking_enabled, "DeepSeek 默认开启 thinking")
    _assert_true(not defaults.public_snapshot().has("api_key"), "公开 Provider 设置不包含 API Key 字段")

    var pro = AiProviderSettingsScript.new({"model": "deepseek-v4-pro"})
    _assert_equal(pro.reasoning_effort, "high", "Pro 模型默认使用高推理强度")
    var custom = AiProviderSettingsScript.new({
        "provider_id": "custom_openai_compatible",
        "base_url": "https://example.invalid/v1/",
        "path": "/chat/completions",
        "model": "custom-strategist",
        "reasoning_effort": "low",
    })
    _assert_equal(custom.endpoint_url(), "https://example.invalid/v1/chat/completions", "通用 Provider 正确拼接自定义端点")
    _assert_equal(custom.model, "custom-strategist", "模型字符串允许玩家自由填写")
    _assert_true(custom.is_valid(), "自定义 OpenAI 兼容 Provider 设置通过基础校验")

    var prompt = AiPromptEncoderScript.new()
    var system_content := str(prompt.system_message()["content"])
    _assert_true(system_content.contains("最终胜率"), "通用提示词明确优化全局胜率而非即时最大伤害")
    _assert_true(system_content.contains("只能从 candidates"), "通用提示词限制 AI 只能选择本地候选")
    _assert_true(system_content.contains("隐藏手牌"), "通用提示词禁止猜测玩家隐藏信息")
    _assert_true(system_content.contains("candidate_id"), "通用提示词内置固定 JSON 返回字段")
    _assert_true(not system_content.contains("decision-provider-test"), "稳定系统提示不混入单次决策内容")

    var provider = ChatCompletionsAiProviderScript.new({
        "api_key": "unit-test-secret",
        "extra_body": {
            "temperature": 0.15,
            "model": "must-not-override",
            "messages": [{"role": "user", "content": "must-not-override"}],
            "stream": true,
            "api_key": "must-not-leak",
            "metadata": {"authorization": "nested-must-not-leak"},
        },
    })
    var decision_payload := {
        "schema_version": 3,
        "type": "battle_decision",
        "battle_id": "provider-contract-battle",
        "provider_epoch": 0,
        "observation": {
            "decision_id": "decision-provider-test",
            "state_hash": "provider-state-hash",
        },
        "history_summary": {},
        "history_delta": [],
        "candidates": [{"candidate_id": "candidate-000"}],
    }
    var request_body: Dictionary = provider.build_request_payload(decision_payload)
    _assert_equal(request_body["model"], "deepseek-v4-flash", "请求体使用配置模型")
    _assert_equal(request_body["thinking"], {"type": "enabled"}, "请求体使用 DeepSeek thinking 结构")
    _assert_equal(request_body["reasoning_effort"], "medium", "请求体携带通用推理强度")
    _assert_equal(request_body["stream"], false, "战斗决策默认使用非流式响应")
    _assert_equal(request_body["temperature"], 0.15, "通用附加请求字段进入请求体")
    _assert_true(not request_body.has("api_key"), "通用附加字段不能把凭据写入请求体")
    _assert_true(not JSON.stringify(request_body).contains("must-not-leak"), "嵌套附加字段中的凭据也不会进入请求或审计")
    _assert_equal(request_body["model"], "deepseek-v4-flash", "通用附加字段不能覆盖配置模型")
    _assert_equal(request_body["messages"].size(), 2, "首次请求只包含稳定系统提示和一个结构化用户消息")
    _assert_equal(request_body["messages"][0]["role"], "system", "Chat Completions 首条消息为系统提示")
    _assert_true(str(request_body["messages"][1]["content"]).contains("decision-provider-test"), "单次决策只进入结构化用户消息")
    _assert_true(not request_body.has("api_key"), "API Key 不进入 JSON 请求体")
    _assert_true(not provider.submitted_requests.any(func(entry): return JSON.stringify(entry).contains("unit-test-secret")), "Provider 审计请求不保存 API Key")

    var next_epoch_payload: Dictionary = decision_payload.duplicate(true)
    next_epoch_payload["provider_epoch"] = 1
    next_epoch_payload["observation"]["decision_id"] = "decision-provider-epoch-1"
    var next_epoch_body: Dictionary = provider.build_request_payload(next_epoch_payload)
    _assert_equal(next_epoch_body["messages"].size(), 2, "历史压缩推进 Provider epoch 后重建短会话前缀")

    provider._rollback_messages({
        "battle_id": "provider-contract-battle",
        "message_count_before": 1,
    })
    _assert_equal(provider._messages_by_battle["provider-contract-battle"].size(), 1, "取消或失败请求会回滚未获回答的用户消息")

    var decision_json := JSON.stringify({
        "schema_version": 3,
        "decision_id": "decision-provider-test",
        "state_hash": "provider-state-hash",
        "candidate_id": "candidate-000",
        "reason_code": "resource_preservation",
        "confidence": 0.8,
    })
    var parsed_response: Dictionary = provider.parse_provider_response(
        HTTPRequest.RESULT_SUCCESS,
        200,
        JSON.stringify({
            "choices": [{"message": {"content": decision_json}}],
            "usage": {"prompt_tokens": 120, "completion_tokens": 24},
        }))
    _assert_true(parsed_response["success"], "通用 Provider 解析 OpenAI 兼容成功响应")
    _assert_equal(parsed_response["body"], decision_json, "Provider 把 assistant content 交给本地协议验证器")
    _assert_equal(parsed_response["usage"]["completion_tokens"], 24, "Provider 保留用量供本地审计")
    var http_error: Dictionary = provider.parse_provider_response(
        HTTPRequest.RESULT_SUCCESS,
        401,
        JSON.stringify({"error": {"message": "invalid api key"}}))
    _assert_equal(http_error["error_code"], "HTTP_STATUS_401", "HTTP 错误转换为稳定 Provider 错误码")
    _assert_equal(http_error["message"], "invalid api key", "Provider 保留兼容服务返回的错误信息")

    var validator = AiResponseValidatorScript.new()
    var legacy_response: Dictionary = validator.validate({
        "schema_version": 1,
        "decision_id": "decision-provider-test",
        "state_hash": "provider-state-hash",
        "candidate_id": "candidate-000",
    }, decision_payload["observation"], ["candidate-000"])
    _assert_equal(
        legacy_response["error_code"], "INVALID_SCHEMA_VERSION",
        "隐藏意图远程协议明确拒绝旧 v1 响应")
    var unexpected_field: Dictionary = validator.validate({
        "schema_version": 3,
        "decision_id": "decision-provider-test",
        "state_hash": "provider-state-hash",
        "candidate_id": "candidate-000",
        "explanation": "不应返回的自然语言",
    }, decision_payload["observation"], ["candidate-000"])
    _assert_equal(unexpected_field["error_code"], "UNEXPECTED_FIELD", "本地协议拒绝提示词之外的额外返回字段")
    var factory_defaults: Dictionary = AiProviderFactoryScript.default_deepseek_config()
    _assert_equal(factory_defaults["provider_id"], "deepseek", "Provider 工厂公开 DeepSeek 默认配置")
    _assert_true(not factory_defaults.has("api_key"), "Provider 工厂默认配置不持久化密钥")
    provider.free()

func _test_ai_settings_and_conversation_disk_contract() -> void:
    var example := ConfigFile.new()
    _assert_equal(
        example.load("res://config/ai_settings.example.cfg"),
        OK,
        "仓库 AI 配置样例保持为可解析的 Godot ConfigFile")
    _assert_true(not bool(example.get_value("remote_ai", "enabled", true)), "AI 配置样例默认禁止联网")
    _assert_equal(example.get_value("provider", "api_key", "missing"), "", "AI 配置样例不携带真实密钥")
    var settings_path := "/tmp/taiwu-ai-settings-contract.cfg"
    if FileAccess.file_exists(settings_path):
        DirAccess.remove_absolute(settings_path)
    var settings_service = AiSettingsServiceScript.new(settings_path)
    _assert_true(settings_service.load_or_create(), "AI 设置服务自动建立可编辑配置文件")
    _assert_true(FileAccess.file_exists(settings_path), "AI 设置配置文件写入指定磁盘路径")
    var defaults: Dictionary = settings_service.public_snapshot()
    _assert_true(not defaults["enabled"], "远程 AI 默认关闭，避免测试和离线游玩意外联网")
    _assert_equal(defaults["provider"]["model"], "deepseek-v4-flash", "配置文件沿用 DeepSeek Flash 默认模型")
    _assert_true(not defaults["provider"].has("api_key"), "公开 AI 设置快照不暴露 API Key 字段")

    var editable := ConfigFile.new()
    _assert_equal(editable.load(settings_path), OK, "生成的 AI 配置可由 Godot ConfigFile 重新读取")
    editable.set_value("remote_ai", "enabled", true)
    editable.set_value("provider", "api_key", "settings-contract-secret")
    editable.set_value("provider", "model", "custom-compatible-model")
    editable.set_value("conversation", "compression_interval_rounds", 7)
    editable.set_value("storage", "conversation_directory", "/tmp/taiwu-ai-conversation-contract")
    editable.set_value("storage", "decision_trace_directory", "/tmp/taiwu-ai-trace-contract")
    _assert_equal(editable.save(settings_path), OK, "玩家可以直接修改并保存 AI 配置文件")
    _assert_true(settings_service.reload(), "AI 设置服务重新载入玩家编辑后的配置")
    var runtime_profile: Dictionary = settings_service.runtime_profile(true)
    _assert_true(runtime_profile["enabled"], "配置文件可以启用远程 AI")
    _assert_equal(runtime_profile["provider"]["api_key"], "settings-contract-secret", "运行时 Provider 可以读取配置文件 API Key")
    _assert_equal(runtime_profile["provider"]["model"], "custom-compatible-model", "配置文件允许任意兼容模型名")
    _assert_equal(runtime_profile["conversation"]["compression_interval_rounds"], 7, "配置文件控制历史压缩间隔")
    _assert_true(not JSON.stringify(settings_service.public_snapshot()).contains("settings-contract-secret"), "公开设置与日志投影不会泄露配置文件 API Key")

    var store = AiConversationStoreScript.new()
    var unsafe_battle_id := "battle/contract:01"
    var conversation_path: String = store.path_for_battle(
        unsafe_battle_id,
        "/tmp/taiwu-ai-conversation-contract")
    _assert_true(not conversation_path.get_file().contains("/"), "会话文件名会清理路径分隔符")
    _assert_true(store.save(conversation_path, {
        "schema_version": 3,
        "battle_id": unsafe_battle_id,
        "api_key": "conversation-secret",
        "nested": {"authorization": "Bearer conversation-secret"},
        "public_events": [{"sequence": 3, "event_type": "cards_played"}],
    }), "会话存储器自动创建目录并保存快照")
    _assert_true(FileAccess.file_exists(conversation_path), "脱敏 AI 会话实际写入磁盘")
    var raw_conversation := FileAccess.get_file_as_string(conversation_path)
    _assert_true(not raw_conversation.contains("conversation-secret"), "磁盘 AI 会话递归移除 API Key 与认证头")
    _assert_true(raw_conversation.contains(AiConversationStoreScript.REDACTED), "磁盘会话保留明确脱敏占位符供审计")
    var loaded_conversation: Dictionary = store.load(conversation_path)
    _assert_equal(loaded_conversation["battle_id"], unsafe_battle_id, "磁盘 AI 会话可以无损恢复公开身份")
    _assert_equal(loaded_conversation["public_events"][0]["sequence"], 3, "磁盘 AI 会话可以恢复公开历史序号")

    var mock_provider = MockAiProviderScript.new(false)
    var first_session = BattleSessionScript.new()
    first_session.configure_ai_runtime(runtime_profile)
    first_session.use_ai_provider(mock_provider)
    var battle_config := {
        "content_seed": 8811,
        "content_id": "ai-disk-contract",
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
            "use_remote_ai": false,
        },
    }
    _assert_true(first_session.setup_battle(battle_config), "配置文件启用状态可以为普通敌人开启远程 AI")
    first_session.execute({"type": "start_turn"})
    var autosave_path := first_session.ai_conversation_path()
    _assert_true(FileAccess.file_exists(autosave_path), "行动窗口变化自动保存脱敏 AI 会话")
    var first_saved: Dictionary = store.load(autosave_path)
    _assert_true(first_saved.get("public_events", []).size() > 0, "自动会话文件包含公开行动历史")
    _assert_true(first_saved.get("exchanges", []).size() > 0, "自动会话文件包含请求审计链")

    var restarted_session = BattleSessionScript.new()
    restarted_session.configure_ai_runtime(runtime_profile)
    var restarted_provider = MockAiProviderScript.new(false)
    restarted_session.use_ai_provider(restarted_provider)
    _assert_true(restarted_session.setup_battle(battle_config), "重新进入相同节点时从头建立新战斗")
    restarted_session.execute({"type": "start_turn"})
    var restarted_path := restarted_session.ai_conversation_path()
    _assert_true(restarted_path != autosave_path, "重新开始战斗会建立独立 AI 审计会话")
    _assert_true(FileAccess.file_exists(autosave_path), "旧战斗 AI 审计文件不会被新尝试覆盖")
    _assert_true(FileAccess.file_exists(restarted_path), "新战斗尝试拥有自己的 AI 审计文件")
    _assert_true(not restarted_session.has_method("load_ai_conversation"), "战斗会话不提供中途 AI 续接入口")
    _assert_true(not restarted_session.ai_coordinator.has_method("restore_conversation"), "行动窗口不从旧对话恢复")
    _assert_true(not restarted_session.ai_coordinator.conversation.has_method("resume_provider_session"), "Provider 会话不跨战斗尝试续接")
    _assert_true(not restarted_session.ai_coordinator.conversation.has_method("restore"), "AI 会话对象不提供续战恢复入口")
    mock_provider.free()
    restarted_provider.free()

func _test_ai_protocol_v3_information_trace_and_report_contract() -> void:
    var encoder = AiStableValueEncoderScript.new()
    var left := {"b": 2, "nested": {"z": 9, "a": 1}, "a": [3, 2, 1]}
    var right := {"a": [3, 2, 1], "nested": {"a": 1, "z": 9}, "b": 2}
    _assert_equal(encoder.sha256(left), encoder.sha256(right),
        "稳定 AI 编码不受 Dictionary 插入顺序影响")
    right["nested"]["a"] = 2
    _assert_true(encoder.sha256(left) != encoder.sha256(right),
        "稳定 AI 编码在语义字段变化时改变 SHA-256")

    var provider = MockAiProviderScript.new(false)
    var session: BattleSession = BattleSessionScript.new()
    session.use_ai_provider(provider)
    var configuration := {
        "content_seed": 9916,
        "content_id": "ai-v3-contract",
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
            "use_remote_ai": true,
        },
        "ai_settings": {
            "autosave_decision_trace": true,
            "decision_trace_path": "/tmp/taiwu-ai-v3-contract-trace.json",
        },
    }
    if FileAccess.file_exists(configuration["ai_settings"]["decision_trace_path"]):
        DirAccess.remove_absolute(configuration["ai_settings"]["decision_trace_path"])
    _assert_true(session.setup_battle(configuration), "AI v3 信息协议测试战斗建立")
    session.execute({"type": "start_turn"})
    var request: Dictionary = provider.submitted_requests[0]["payload"]
    _assert_equal(request["schema_version"], 3, "AI 请求统一升级为协议 v3")
    var context: Dictionary = request["battle_context"]
    for field in ["rules_version", "content_version", "content_fingerprint",
            "ai_protocol_version", "prompt_version"]:
        _assert_true(context.has(field), "战斗开始上下文包含版本字段 %s" % field)
    _assert_equal(context["ai_protocol_version"], 3, "战斗上下文声明 AI 协议 v3")
    _assert_equal(context["prompt_version"], 3, "战斗上下文声明提示词 v3")
    _assert_true(context["content_fingerprint"].length() == 64,
        "本场内容语义使用 SHA-256 指纹")
    _assert_true(not context["content_semantics"]["techniques"].is_empty(),
        "本场引用功法进入语义上下文")
    for technique in context["content_semantics"]["techniques"]:
        _assert_true(str(technique.get("name", "")) != ""
            and str(technique.get("description", "")) != "",
            "功法 ID 同时携带名称和玩家语义")
    _assert_true(not JSON.stringify(context).contains("handler"),
        "内容语义不暴露 Handler 类名或内部运行时")
    _assert_true(not context["player_build"].has("draw_order")
        and not context["enemy_build"].has("draw_order"),
        "双方完整构筑均不发送抽牌顺序")

    var observation: Dictionary = request["observation"]
    _assert_equal(observation["schema_version"], 3, "每窗口观察升级为 v3")
    _assert_equal(observation["self"]["hand_cards"].size(),
        session.engine.enemy.hand.size(), "敌人看到自身当前手牌实例")
    _assert_true(not observation["self"].has("draw_order"),
        "敌人也不能看到自身抽牌顺序")
    _assert_equal(observation["opponent"]["hand_count"],
        session.engine.player.hand.size(), "玩家当前手牌只公开数量")
    _assert_true(not observation["opponent"].has("hand_cards"),
        "玩家当前手牌实例不进入 AI 观察")
    for field in ["momentum", "hand_limit", "reflection_percent",
            "sequence_positions", "action_state", "public_statuses"]:
        _assert_true(observation["opponent"].has(field),
            "玩家公开状态包含 %s" % field)
    var threat: Dictionary = observation["opponent"]["opponent_threat"]
    _assert_true(int(threat["expected"]) >= 0 and int(threat["maximum"]) \
        >= int(threat["expected"]), "公开威胁估计形成合法确定区间")
    _assert_equal(threat["basis"], "public_build_history",
        "威胁估计只声明公开构筑和历史依据")
    _assert_true(session.engine.enemy_decision_observation().expected_incoming_damage >= 0,
        "F6B 保命画像不再读取永久 -1")
    _assert_true(str(observation["state_hash"]).length() == 64,
        "完整观察与候选生成稳定 SHA-256 状态哈希")
    _assert_true(not JSON.stringify(request).contains("candidate_diagnostics"),
        "F6B 完整诊断不进入远程请求")
    _assert_true(not JSON.stringify(session.snapshot().to_dict()).contains(
        "candidate_diagnostics"), "私有轨迹不进入 BattleSnapshot")

    var invalid_reason := AiResponseValidatorScript.new().validate({
        "schema_version": 3,
        "decision_id": observation["decision_id"],
        "state_hash": observation["state_hash"],
        "candidate_id": request["candidates"][0]["candidate_id"],
        "reason_code": "free_form_reason",
    }, observation, [request["candidates"][0]["candidate_id"]])
    _assert_equal(invalid_reason["error_code"], "INVALID_REASON_CODE",
        "非枚举 reason_code 触发协议校验失败")
    var unspecified := AiResponseValidatorScript.new().validate({
        "schema_version": 3,
        "decision_id": observation["decision_id"],
        "state_hash": observation["state_hash"],
        "candidate_id": request["candidates"][0]["candidate_id"],
    }, observation, [request["candidates"][0]["candidate_id"]])
    _assert_equal(unspecified["reason_code"], "unspecified",
        "缺少 reason_code 时规范化为 unspecified")
    _assert_true(unspecified["protocol_quality_issue"],
        "缺少 reason_code 记录为协议质量问题但不拒绝行动")
    var legacy_v2 := AiResponseValidatorScript.new().validate({
        "schema_version": 2,
        "decision_id": observation["decision_id"],
        "state_hash": observation["state_hash"],
        "candidate_id": request["candidates"][0]["candidate_id"],
    }, observation, [request["candidates"][0]["candidate_id"]])
    _assert_equal(legacy_v2["error_code"], "INVALID_SCHEMA_VERSION",
        "旧 schema_version=2 回答明确拒绝")

    provider.queue_result({"success": true, "body": {
        "schema_version": 3,
        "decision_id": observation["decision_id"],
        "state_hash": observation["state_hash"],
        "candidate_id": request["candidates"][0]["candidate_id"],
        "reason_code": "prepare", "confidence": 0.63,
    }, "usage": {"prompt_tokens": 40, "completion_tokens": 8}})
    provider.complete(str(provider.submitted_requests[0]["request_id"]))
    var ready = session.snapshot()
    _assert_equal(ready.ai_decision["state"], "ready",
        "v3 合法回答通过本地复核并锁定")
    var trace: Dictionary = session.ai_decision_trace_snapshot()
    _assert_equal(trace["windows"].size(), 1, "每个决策窗口建立一条私有轨迹")
    var window: Dictionary = trace["windows"][0]
    _assert_true(not window["candidate_diagnostics"].is_empty(),
        "私有轨迹直接复用 F6B 完整候选诊断")
    _assert_equal(window["candidate_map"][0]["public_candidate_id"],
        request["candidates"][0]["candidate_id"],
        "公开候选与诊断候选建立本地映射")
    _assert_equal(window["selected"]["source"], "remote",
        "远程选择记录到同一窗口轨迹")
    _assert_equal(window["selected"]["reason_code"], "prepare",
        "轨迹保留固定 reason_code")
    var resolved := session.execute({
        "type": "play_cards",
        "card_ids": [str(ready.player.hand[0]["id"])],
    })
    _assert_true(resolved.success, "真实双方行动完成正式揭示与结算")
    trace = session.ai_decision_trace_snapshot()
    window = trace["windows"][0]
    _assert_true(not window["actual_result"].is_empty(),
        "实际结算回填到同一 decision_id 私有轨迹")
    _assert_true(window["actual_result"].has("life_delta")
        and window["actual_result"].has("defense_delta")
        and window["actual_result"].has("battle_state_after"),
        "实际结果包含生命、防御差量与结算后状态")
    _assert_true(FileAccess.file_exists(
        configuration["ai_settings"]["decision_trace_path"]),
        "私有轨迹独立写入指定本地目录")

    var compact_events: Array = []
    for index in range(6):
        compact_events.append({
            "sequence": index,
            "round_number": mini(5, index + 1),
            "action_index": index,
            "window_id": "window-%d" % index,
            "event_type": "action_resolved",
            "actor_id": "system",
            "payload": {"player_life": 100 - index, "player_defense": index,
                "enemy_life": 90 - index, "enemy_defense": index * 2,
                "battle_state": "active", "state_delta": {}},
        })
    var compacted := AiHistoryCompactorScript.new(5).compact(compact_events, 5)
    _assert_equal(compacted["recent_action_tail"].size(), 4,
        "五回合摘要保留最近四次正式行动")
    _assert_equal(compacted["recent_action_tail"][0]["sequence"], 2,
        "历史压缩保留近期行动时序")
    _assert_equal(compacted,
        AiHistoryCompactorScript.new(5).compact(compact_events, 5),
        "相同公开事件产生完全相同历史摘要")

    var empty_report := AiTraceReporterScript.new().report_paths([],
        "/tmp/taiwu-ai-v3-empty")
    _assert_equal(empty_report["status"], "no_data",
        "离线报告空目录明确输出无数据")
    var damaged_path := "/tmp/taiwu-ai-v3-damaged.json"
    var damaged_file := FileAccess.open(damaged_path, FileAccess.WRITE)
    damaged_file.store_string("{not-json")
    damaged_file.close()
    var report := AiTraceReporterScript.new().report_paths([
        configuration["ai_settings"]["decision_trace_path"], damaged_path],
        "/tmp/taiwu-ai-v3-contract")
    _assert_equal(report["battle_count"], 1,
        "损坏轨迹不会阻断其他战斗汇总")
    _assert_equal(report["damaged_file_count"], 1,
        "损坏轨迹被单独结构化报告")
    _assert_true(str(report["human_summary"]) != ""
        and report["aggregate"] is Dictionary,
        "离线工具同时输出人类摘要和结构化 JSON 数据")
    provider.free()

func _test_effect_handler_registry_contract() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 814
    var executor = EffectExecutorScript.new(rng)
    _assert_true(not executor.registry.operation_ids().is_empty(), "运行时注册表公开稳定战斗效果 ID")
    _assert_equal(executor.registry.handler_group("damage"), "damage", "伤害操作进入伤害处理器")
    _assert_equal(executor.registry.handler_group("defense"), "defense", "防御操作进入防御处理器")
    _assert_equal(executor.registry.handler_group("draw"), "card_zone", "抽牌操作进入牌区处理器")
    _assert_equal(executor.registry.handler_group("apply_random_card_anomaly"), "card_anomaly", "真气异状进入异状处理器")
    for retired_op in [
            "add_stack", "add_target_stack", "add_stack_per_captured_card",
            "set_stack_minimum", "register_turn_end_stack"]:
        _assert_true(
            not executor.registry.has_handler(retired_op),
            "退役角色层数操作不再注册：%s" % retired_op)
    _assert_equal(executor.registry.handler_group("write_momentum"), "flow_delay", "统一连势写入进入流程处理器")
    for retired_flow_op in [
            "add_momentum", "set_momentum", "consume_momentum",
            "add_same_qi", "clear_same_qi_for_defense",
            "set_reflection_percent", "set_reflection_until_turn_end",
            "remove_all_defense"]:
        _assert_true(
            not executor.registry.has_handler(retired_flow_op),
            "重复操作码不再注册：%s" % retired_flow_op)
    _assert_equal(executor.registry.handler_group("register_attack_counter_delay"), "", "旧延迟反击端口已移除")

    var unknown_result: Dictionary = executor.execute_all([{"op": "not_registered"}], {})
    _assert_true(not unknown_result["success"], "未注册操作码在执行边界被安全拒绝")
    _assert_true(str(unknown_result["detail"]).contains("未注册"), "未知操作码返回明确诊断")

    var probe_handler := ProbeEffectHandlerScript.new()
    _assert_true(executor.registry.register_handler(probe_handler), "新处理器可通过注册接口扩展")
    _assert_true(not executor.registry.register_handler(ProbeEffectHandlerScript.new()), "重复操作码默认不能覆盖现有处理器")
    _assert_true(
        not executor.registry.register_handler(ProbeEffectHandlerScript.new(["duplicate_probe", "duplicate_probe"])),
        "单个效果处理器不能重复声明同一效果 ID")
    _assert_true(
        not executor.registry.register_handler(ProbeEffectHandlerScript.new(["Bad Effect ID"])),
        "效果 ID 必须使用稳定 snake_case")
    _assert_true(
        not executor.registry.register_handler(
            ProbeEffectHandlerScript.new(["unknown_phase_probe"], "after_damage")),
        "Handler 未知默认阶段在注册时失败")
    _assert_true(
        _array_contains_text(
            executor.registry.registration_errors,
            "未知默认阶段：after_damage"),
        "Handler 默认阶段错误返回稳定诊断")
    var probe_context := {}
    var probe_result: Dictionary = executor.execute_all([{"op": "probe_effect", "amount": 7}], probe_context)
    _assert_true(probe_result["success"], "动态注册处理器可以参与统一执行链")
    _assert_equal(probe_context["probe_count"], 1, "动态处理器只执行一次")
    _assert_equal(
        executor.summarize_intent([{"op": "probe_effect", "amount": 7}], {})["defense"],
        7,
        "动态处理器同时接入预览汇总链")

func _test_effect_extension_entry_contract() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 815
    var registry = EffectHandlerRegistryScript.new(rng)
    _assert_true(registry.register_handler(ProbeEffectHandlerScript.new()), "测试效果只在统一注册入口登记")
    var duplicate_registry = EffectHandlerRegistryScript.new(rng)
    _assert_true(duplicate_registry.register_handler(ProbeEffectHandlerScript.new()), "重复注册探针先登记一次")
    _assert_true(not duplicate_registry.register_handler(ProbeEffectHandlerScript.new()), "重复效果 ID 被注册表拒绝")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "效果扩展测试载入基线内容")
    var definitions: Dictionary = {}
    for key in ContentCatalogScript.CONTENT_ORDER:
        definitions[key] = catalog.definition(key)
    definitions["techniques"]["techniques"].append({
        "id": "effect_extension_probe",
        "name": "效果扩展探针",
        "pool": "high",
        "special": false,
        "effects": [{"op": "probe_effect", "amount": 9}],
    })
    var registered_catalog = ContentCatalogScript.new(null, registry)
    _assert_true(
        registered_catalog.load_from_definitions(definitions),
        "已注册效果在内容加载校验阶段可直接使用")
    var duplicate_catalog = ContentCatalogScript.new(null, duplicate_registry)
    _assert_true(not duplicate_catalog.load_from_definitions(definitions), "重复注册在内容校验阶段明确失败")
    _assert_true(
        _array_contains_text(duplicate_catalog.errors, "效果 ID 重复注册：probe_effect"),
        "重复注册错误包含稳定效果 ID")

    var invalid_definitions := definitions.duplicate(true)
    invalid_definitions["techniques"]["techniques"][-1]["effects"][0]["amount"] = 0
    var invalid_result: Dictionary = ContentValidatorScript.new(registry).validate(invalid_definitions)
    _assert_true(not invalid_result["valid"], "已注册效果的非法参数在内容校验阶段失败")
    _assert_true(
        _array_contains_text(invalid_result["errors"], "amount 必须是正整数"),
        "非法参数返回处理器声明的明确诊断")

    var invalid_condition_definitions := _catalog_definitions(catalog)
    invalid_condition_definitions["techniques"]["techniques"].append({
        "id": "invalid_condition_probe",
        "name": "非法条件探针",
        "pool": "high",
        "special": false,
        "effects": [{
            "op": "defense",
            "amount": {"kind": "constant", "value": 1},
            "when": {"actor_defense_equals": -1},
        }],
    })
    var invalid_condition_result: Dictionary = ContentValidatorScript.new().validate(
        invalid_condition_definitions)
    _assert_true(
        not invalid_condition_result["valid"],
        "非法防御条件在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            invalid_condition_result["errors"],
            "actor_defense_equals: 必须是非负整数"),
        "非法防御条件返回明确诊断：%s" % str(invalid_condition_result["errors"]))

    var missing_registry_catalog = ContentCatalogScript.new()
    _assert_true(not missing_registry_catalog.load_from_definitions(definitions), "缺失效果注册在内容校验阶段失败")
    _assert_true(
        _array_contains_text(missing_registry_catalog.errors, "未知效果操作码 probe_effect"),
        "缺失注册返回稳定效果 ID")

    var invalid_phase_definitions := _catalog_definitions(catalog)
    invalid_phase_definitions["techniques"]["techniques"].append({
        "id": "invalid_phase_probe",
        "name": "非法阶段探针",
        "pool": "high",
        "special": false,
        "effects": [{
            "op": "damage",
            "phase": "after_damage",
            "amount": {"kind": "constant", "value": 1},
        }],
    })
    var invalid_phase_catalog = ContentCatalogScript.new()
    _assert_true(
        not invalid_phase_catalog.load_from_definitions(
            invalid_phase_definitions),
        "未知 effect.phase 在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            invalid_phase_catalog.errors,
            "未知功法效果阶段 after_damage"),
        "未知 effect.phase 返回稳定字段诊断")

    var actor = BattleSideScript.new("效果探针行动方")
    var executor = EffectExecutorScript.new(rng, registry)
    var effect := {"op": "probe_effect", "amount": 9}
    var preview: Dictionary = executor.summarize_intent([effect], {"actor": actor})
    var resolved: Dictionary = executor.execute_all([effect], {"actor": actor})
    _assert_true(resolved["success"], "测试效果通过统一执行入口结算")
    _assert_equal(preview["defense"], actor.defense, "测试效果预览与实际结算结果一致")

func _test_card_zone_service_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F3C 牌区生命周期载入内容")
    var engine = _tracked_combat_engine(null, catalog)
    engine.setup(816, false)

    var discard_card = _card("6", "forest")
    catalog.card_reshape_rules.bind_card(discard_card)
    engine.player.hand = [discard_card]
    engine.player.draw_pile.clear()
    engine.player.discard_pile.clear()
    engine.status_system.apply_card_anomaly(discard_card, "state", "poison", {}, "测试")
    engine.status_system.apply_card_anomaly(discard_card, "buff", "growth", {}, "测试", 2)
    engine.status_system.apply_card_anomaly(discard_card, "buff", "qi_heat", {}, "测试", 3)
    _assert_true(engine.player.stage_cards([discard_card.id]), "真气进入待出区")
    engine.player.commit_staging()
    _assert_true(discard_card.current_state().is_empty(), "实际入弃牌堆后清除状态")
    _assert_true(not discard_card.has_anomaly("buff", "growth"), "实际入弃牌堆后清除成长")
    _assert_equal(discard_card.anomaly_layers("buff", "qi_heat"), 3, "炽气跨弃牌区保留")

    var regroup = _card("7", "mountain")
    catalog.card_reshape_rules.bind_card(regroup)
    engine.player.hand = [regroup]
    engine.player.discard_pile.clear()
    engine.status_system.apply_card_anomaly(regroup, "state", "vulnerability", {}, "测试")
    engine.status_system.apply_card_anomaly(regroup, "mark", "regroup", {}, "测试")
    engine.player.stage_cards([regroup.id])
    engine.player.commit_staging()
    _assert_true(engine.player.draw_pile.has(regroup), "重聚在普通入堆与清理后洗回牌库")
    _assert_true(regroup.current_state().is_empty(), "重聚发生前状态已经清理")
    _assert_true(not regroup.has_anomaly("mark", "regroup"), "重聚触发后移除自身")

    var alchemy_regroup = _card("8", "fire")
    catalog.card_reshape_rules.bind_card(alchemy_regroup)
    alchemy_regroup.set_imprint("alchemy")
    engine.status_system.apply_card_anomaly(alchemy_regroup, "mark", "regroup", {}, "测试")
    engine.player.hand = [alchemy_regroup]
    engine.player.consumable_ids.clear()
    engine.player.random_discard(1, engine.rng)
    _assert_equal(engine.player.consumable_ids.size(), 1, "化丹印先于重聚成立并获得丹药")
    _assert_true(engine.player.draw_pile.has(alchemy_regroup), "随后重聚不撤销化丹收益")

    var lure = _card("5", "forest")
    var wind_a = _card("2", "wind")
    var wind_b = _card("3", "wind")
    var untouched = _card("4", "fire")
    for entry in [lure, wind_a, wind_b, untouched]:
        catalog.card_reshape_rules.bind_card(entry)
    engine.player.hand.clear()
    engine.player.draw_pile = [untouched, wind_a, wind_b, lure]
    engine.status_system.apply_card_anomaly(lure, "mark", "wind_lure", {}, "测试")
    engine.player.draw(1)
    _assert_equal(engine.player.hand.size(), 2, "风引抽到时额外定向抽一张风真气")
    _assert_true(engine.player.hand[1].is_attribute("wind"), "风引不会改成普通抽牌库顶")
    _assert_true(engine.player.draw_pile.has(untouched), "风引未选中非风牌仍在原位")
    _assert_true(not lure.has_anomaly("mark", "wind_lure"), "风引触发后移除")

    var turbulence = _card("9", "forest")
    var wind_hand = _card("10", "wind")
    catalog.card_reshape_rules.bind_card(turbulence)
    catalog.card_reshape_rules.bind_card(wind_hand)
    engine.player.hand = [wind_hand]
    engine.player.draw_pile = [turbulence]
    engine.player.discard_pile.clear()
    engine.status_system.apply_card_anomaly(turbulence, "mark", "turbulence", {}, "测试")
    engine.player.draw(1)
    _assert_true(engine.player.discard_pile.has(turbulence), "乱流可选中刚抽到且不视为风的自身")
    _assert_true(engine.player.hand.has(wind_hand), "乱流不弃掉风属性合法保留牌")

    var temporary_target = wind_hand
    var temp_remove: Dictionary = engine.player.temporarily_remove_card(
        str(temporary_target.id), "void")
    _assert_true(temp_remove["success"], "临时消散进入独立临时移出区")
    _assert_true(not engine.player.discard_pile.has(temporary_target), "临时消散不进入弃牌堆")
    _assert_true(engine.player.all_cards_for_run_sync().has(temporary_target), "临时移出牌仍按既有协议归还 RunDeck")

func _test_battle_flow_coordinator_contract() -> void:
    var left = BattleSideScript.new("左方", "left")
    var right = BattleSideScript.new("右方", "right")
    var flow = BattleFlowCoordinatorScript.new()
    flow.reset([left, right])
    flow.begin_round([
        {"actor": left, "actions": 1},
        {"actor": right, "actions": 1},
    ])
    _assert_true(flow.can_act(left) and flow.can_act(right), "通用行动状态不区分玩家与敌人")
    _assert_true(flow.lock_intent(left, {"cards": ["left-card"]}), "任意行动方都可以锁定行动意图")
    _assert_equal(flow.resolution_mode(), "single", "只有一方有意图时使用单方结算")
    _assert_true(flow.lock_intent(right, {"cards": ["right-card"]}), "第二个行动方可以独立锁定意图")
    _assert_equal(flow.resolution_mode(), "synchronized", "至少两方都有意图时才使用同步结算")
    flow.clear_intents()
    _assert_equal(flow.resolution_mode(), "none", "行动窗口结束后清除全部锁定意图")
    _assert_true(flow.claim_combo(left, "generic_combo"), "通用连击状态首次占用成功")
    _assert_true(not flow.claim_combo(left, "generic_combo"), "同一行动方同一连击不能重复占用")

    flow.disable_next_rounds(right, "封招", 1)
    flow.begin_round([
        {"actor": left, "actions": 1},
        {"actor": right, "actions": 1},
    ])
    _assert_true(flow.can_act(left), "一方被禁用不会阻止另一方行动")
    _assert_true(not flow.can_act(right), "下回合禁用在下一行动轮生效")
    _assert_equal(flow.available_action_count(right), 0, "被禁用方对外显示零次可用行动")
    _assert_equal(flow.snapshot_for(right)["disabled_reasons"], ["封招"], "行动状态快照公开禁用原因")
    flow.grant_actions(right, 1)
    _assert_equal(flow.available_action_count(right), 0, "禁用期间获得行动次数也不能绕过行动资格")
    flow.enable_current_round(right, "封招")
    _assert_equal(flow.available_action_count(right), 2, "移除禁用后恢复尚未消耗的行动次数")
    flow.forfeit_remaining(right, "手牌数为 0")
    _assert_true(not flow.can_act(right), "无合法手牌可以通用地放弃剩余行动")
    _assert_equal(flow.snapshot_for(right)["last_forfeit_reason"], "手牌数为 0", "放弃行动保留结构化原因")

    flow.begin_round([
        {"actor": left, "actions": 1},
        {"actor": right, "actions": 1},
    ])
    _assert_true(flow.can_act(right), "一次性下回合禁用不会污染后续行动轮")

    var enemy_disabled = _tracked_combat_engine()
    _assert_true(enemy_disabled.setup_scripted_battle(2308), "敌方禁用集成测试载入脚本战斗")
    enemy_disabled.disable_actor_next_rounds(enemy_disabled.enemy, "封招", 1)
    enemy_disabled.start_player_turn()
    _assert_equal(enemy_disabled.enemy_actions_available, 0, "敌方下回合无法操作时不建立同步行动")
    var enemy_hand_before: int = enemy_disabled.enemy.hand.size()
    var player_result: Dictionary = enemy_disabled.confirm_play([enemy_disabled.player.hand[0].id])
    _assert_true(player_result["success"], "敌方被禁用时玩家仍能单方出招")
    _assert_true(player_result["enemy_played_cards"].is_empty(), "单方出招不会强制敌方陪同出牌")
    _assert_equal(enemy_disabled.enemy.hand.size(), enemy_hand_before, "被禁用敌方的手牌没有被消耗")

    var player_disabled = _tracked_combat_engine()
    _assert_true(player_disabled.setup_scripted_battle(2308), "玩家禁用集成测试载入脚本战斗")
    player_disabled.disable_actor_next_rounds(player_disabled.player, "封招", 1)
    player_disabled.start_player_turn()
    _assert_equal(player_disabled.actions_available, 0, "玩家下回合无法操作时对外显示零次行动")
    _assert_true(not player_disabled.last_enemy_action_cards.is_empty(), "玩家被禁用时敌方能够完成单方行动")

    var empty_enemy = _tracked_combat_engine()
    _assert_true(empty_enemy.setup_scripted_battle(
        2308, "res://data/scripted_battle.json", true), "零手牌集成测试载入调试 AI")
    empty_enemy.enemy.draw_pile.clear()
    empty_enemy.enemy.hand.clear()
    empty_enemy.start_player_turn()
    _assert_equal(empty_enemy.enemy_actions_available, 0, "敌方补牌后仍为零手牌时放弃剩余行动")
    _assert_equal(
        empty_enemy.actor_action_state(empty_enemy.enemy)["last_forfeit_reason"],
        "没有合法出牌方案",
        "零手牌通过通用行动资格记录原因而不是进入同步分支")

func _test_battle_timing_system_contract_and_integration() -> void:
    var game_log = GameLogScript.new()
    var queue = TriggerQueueScript.new(game_log)
    var timing = BattleTimingSystemScript.new(queue)
    var probe = TimingProbe.new()
    _assert_true(
        timing.register_handler(
            BattleTimingSystemScript.TURN_START,
            "right",
            200,
            Callable(probe, "record").bind("右"),
            true,
            "右侧时点探针",
            "测试"),
        "战斗时点可以注册处理器")
    _assert_true(
        timing.register_handler(
            BattleTimingSystemScript.TURN_START,
            "left",
            100,
            Callable(probe, "record").bind("左")),
        "同一战斗时点可以注册第二个处理器")
    _assert_true(
        not timing.register_handler(
            BattleTimingSystemScript.TURN_START,
            "left",
            300,
            Callable(probe, "record").bind("重复")),
        "同一时点拒绝重复处理器 ID")
    _assert_true(
        not timing.register_handler(
            "unknown_timing",
            "unknown",
            1,
            Callable(probe, "record").bind("未知")),
        "战斗时点拒绝未知生命周期名称")
    var timing_result: Dictionary = timing.emit_timing(
        BattleTimingSystemScript.TURN_START,
        {"round_number": 3, "metadata": {"test": true}})
    _assert_true(timing_result["success"], "战斗时点按已注册处理器完成分发")
    _assert_equal(probe.calls, ["turn_start:左:0", "turn_start:右:0"], "同一时点按 order 再按注册顺序稳定执行")
    _assert_equal(timing.history[0]["round_number"], 3, "时点历史保留结构化回合号")
    _assert_equal(timing.history[0]["metadata"], {"test": true}, "时点历史只公开显式元数据")
    _assert_equal(timing.history[0]["handler_results"][0]["handler_id"], "left", "时点历史记录实际处理器顺序")
    _assert_equal(queue.history[-1]["label"], "右侧时点探针", "标记为可见的时点处理器进入统一战斗日志")
    _assert_true(timing.unregister_handler(BattleTimingSystemScript.TURN_START, "left"), "战斗时点处理器可以按 ID 注销")
    _assert_true(not timing.emit_timing("bad")["success"], "分发未知战斗时点返回明确失败")

    var engine = _tracked_combat_engine()
    engine.setup(815, false)
    engine.start_player_turn()
    var opening_timings: Array = engine.timing_system.history.map(
        func(entry): return entry["timing"])
    _assert_equal(opening_timings, [
        "battle_start",
        "round_start",
        "turn_start",
        "before_normal_draw",
        "after_normal_draw",
        "action_window_start",
    ], "单方战斗以统一顺序进入战斗、回合、补牌和行动窗口时点")
    engine.end_player_turn()
    _assert_equal(engine.timing_system.history[-5]["timing"], "action_window_end", "结束回合先关闭行动窗口")
    _assert_equal(
        engine.timing_system.history.slice(-4, -2).map(
            func(entry): return entry["timing"]),
        ["defense_decay_resolved", "defense_decay_resolved"],
        "行动窗口关闭后分别公开双方防御自然衰减结果")
    _assert_equal(
        engine.timing_system.history.slice(-2).map(
            func(entry): return entry["actor_id"]),
        ["player", "enemy"],
        "行动窗口关闭后双方依次进入回合结束")
    engine.start_player_turn()
    var battle_start_count := 0
    for entry in engine.timing_system.history:
        if entry["timing"] == "battle_start":
            battle_start_count += 1
    _assert_equal(battle_start_count, 1, "同一场战斗的战斗开始时点只触发一次")

    var ending_card = _card("7", "forest")
    ending_card.set_anomaly("state", "poison")
    engine.player.hand = [ending_card]
    engine.player.momentum_value = 5
    engine.enemy.current_reflection_percent = 40
    engine.delayed_effects.append({"label": "未到期测试延迟"})
    engine.enemy.life = 0
    engine._update_battle_state()
    var battle_end_entry: Dictionary = engine.timing_system.history[-1]
    _assert_equal(battle_end_entry["timing"], "battle_end", "战斗终局统一进入战斗结束时点")
    _assert_equal(
        battle_end_entry["handler_results"].map(func(result): return result["handler_id"]),
        [
            "passives.battle_end.begin",
            "card_reshape_runtime.battle_victory",
            "status_system.transferred_card_return",
            "status_system.card_battle_end",
            "status_system.transient_battle_end",
            "combat_engine.flow_cleanup",
            "passives.battle_end.end",
        ],
        "战斗结束先结算胜利重塑，再清真气异状与临时战斗状态")
    _assert_true(ending_card.current_state().is_empty(), "战斗结束时点清除真气异状")
    _assert_equal(engine.player.momentum_value, 0, "战斗结束时点清除连势")
    _assert_equal(engine.enemy.current_reflection_percent, 0, "战斗结束时点清除反震")
    _assert_equal(engine.delayed_effects.size(), 0, "战斗结束时点清除未到期延迟记录")
    _assert_equal(engine.player.defense + engine.enemy.defense, 0, "战斗结束时点清除双方防御")

    var scripted = _tracked_combat_engine()
    _assert_true(scripted.setup_scripted_battle(2308), "双方时点集成测试载入脚本战斗")
    scripted.start_player_turn()
    var turn_start_actor_ids: Array = []
    for entry in scripted.timing_system.history:
        if entry["timing"] == "turn_start":
            turn_start_actor_ids.append(entry["actor_id"])
    _assert_equal(turn_start_actor_ids, ["player", "enemy"], "敌我通过同一种行动方回合开始时点进入正常补牌")

func _test_defense_retention_policy_and_round_decay() -> void:
    var side = BattleSideScript.new("保留规则测试", "retention_probe")
    var policy = DefenseRetentionPolicyScript.new()
    policy.use_remove_defense_port(func(
            target, amount: int, _context: Dictionary) -> Dictionary:
        var before := int(target.defense)
        var removed := mini(before, maxi(0, amount))
        target.defense = before - removed
        return {
            "success": true,
            "removed": removed,
            "before": before,
            "after": int(target.defense),
        })
    for test_case in [
        {"before": 1, "after": 0},
        {"before": 3, "after": 1},
        {"before": 20, "after": 10},
    ]:
        side.defense = int(test_case["before"])
        var result: Dictionary = policy.apply_decay(side)
        _assert_equal(result["before"], test_case["before"], "默认衰减记录衰减前防御")
        _assert_equal(result["after"], test_case["after"], "默认 50% 保留比例显式向下取整")
        _assert_equal(result["lost"], test_case["before"] - test_case["after"], "默认衰减记录失去防御")
        _assert_equal(result["retention_percent"], 50, "默认防御保留比例为 50%")
        _assert_true(not result["prevented"], "默认防御衰减未被阻止")
        _assert_true(result["side"] == side, "结构化衰减结果保留战斗方")

    var bonus_provider = DefenseRetentionProbe.new(side, 25)
    _assert_true(policy.register_provider("test.retention_bonus", bonus_provider), "保留比例提供者可以注册")
    _assert_true(
        not policy.register_provider("test.retention_bonus", bonus_provider),
        "保留比例提供者 ID 不可重复注册")
    side.defense = 20
    var bonus_result: Dictionary = policy.apply_decay(side)
    _assert_equal(bonus_result["retention_percent"], 75, "额外保留比例与默认比例相加")
    _assert_equal(bonus_result["after"], 15, "合并全部比例后只取整一次")

    var lower_provider = DefenseRetentionProbe.new(side, -200)
    _assert_true(policy.register_provider("test.retention_lower", lower_provider), "负向保留比例提供者可以注册")
    side.defense = 20
    var clamped_result: Dictionary = policy.apply_decay(side)
    _assert_equal(clamped_result["retention_percent"], 0, "最终保留比例下限为 0%")
    _assert_equal(clamped_result["after"], 0, "0% 保留不会产生负防御")
    _assert_true(policy.unregister_provider("test.retention_lower"), "负向保留比例提供者可以注销")

    var upper_provider = DefenseRetentionProbe.new(side, 200)
    _assert_true(policy.register_provider("test.retention_upper", upper_provider), "正向保留比例提供者可以注册")
    side.defense = 20
    var upper_result: Dictionary = policy.apply_decay(side)
    _assert_equal(upper_result["retention_percent"], 100, "最终保留比例上限为 100%")
    _assert_equal(upper_result["after"], 20, "比例上限保证防御不会增长")
    _assert_true(not upper_result["prevented"], "比例达到 100% 不伪装为不衰减覆盖")
    _assert_true(policy.unregister_provider("test.retention_upper"), "正向保留比例提供者可以注销")

    var prevent_provider = DefenseRetentionProbe.new(side, 0, true)
    _assert_true(policy.register_provider("test.retention_prevent", prevent_provider), "不衰减覆盖提供者可以注册")
    side.defense = 20
    var prevented_result: Dictionary = policy.apply_decay(side)
    _assert_equal(prevented_result["retention_percent"], 100, "不衰减覆盖最终比例为 100%")
    _assert_equal(prevented_result["after"], 20, "不衰减覆盖完整保留防御")
    _assert_true(prevented_result["prevented"], "结构化结果记录衰减被阻止")
    _assert_true(policy.unregister_provider("test.retention_prevent"), "保留比例提供者可以注销")
    _assert_true(not policy.unregister_provider("test.retention_prevent"), "重复注销提供者返回失败")

    var engine = _tracked_combat_engine()
    engine.setup(82301, false)
    engine.start_player_turn()
    _assert_equal(engine.current_round_actors, [engine.player], "非脚本模式敌方没有本回合行动资格")
    engine.player.defense = 20
    engine.enemy.defense = 5
    var lifecycle_observations: Array[String] = []
    engine.timing_system.register_handler(
        BattleTimingSystemScript.ACTION_WINDOW_END,
        "test.capture_defense_before_decay",
        1,
        func(_event):
            lifecycle_observations.append("action_window:%d:%d" % [
                engine.player.defense, engine.enemy.defense])
            return {"success": true})
    engine.timing_system.register_handler(
        BattleTimingSystemScript.TURN_END,
        "test.capture_defense_after_decay",
        1,
        func(event):
            lifecycle_observations.append("turn_end:%s:%d" % [
                event.actor.owner_id, event.actor.defense])
            if event.actor == engine.player:
                event.actor.add_defense(8)
            return {"success": true})
    engine.end_player_turn()
    _assert_equal(lifecycle_observations, [
        "action_window:20:5",
        "turn_end:player:10",
        "turn_end:enemy:2",
    ], "防御衰减位于行动窗口结束后、双方所有 TURN_END 效果前")
    _assert_equal(engine.player.defense, 18, "回合结束新获得防御不参与已完成的衰减")
    _assert_equal(engine.enemy.defense, 2, "无行动资格的一方同样完成一次衰减")
    _assert_equal(engine.last_defense_decay_results[0]["lost"], 10, "回合服务保留我方结构化衰减结果")
    _assert_equal(engine.last_defense_decay_results[1]["side_id"], "enemy", "回合服务保留敌方结构化衰减结果")
    var timing_count_after_round: int = engine.timing_system.history.size()
    engine.round_service.finish_round_end()
    _assert_equal(engine.player.defense, 18, "同一完整回合重复结束不会再次衰减")
    _assert_equal(engine.timing_system.history.size(), timing_count_after_round, "同一完整回合重复结束不重发 TURN_END")

    engine.timing_system.unregister_handler(
        BattleTimingSystemScript.TURN_END,
        "test.capture_defense_after_decay")
    engine.start_player_turn()
    engine.player.defense = 20
    engine.enemy.defense = 20
    var engine_provider = DefenseRetentionProbe.new(engine.player, 25)
    _assert_true(
        engine.register_defense_retention_provider(
            "test.engine_retention_bonus", engine_provider),
        "战斗引擎公开统一保留比例提供者入口")
    engine.end_player_turn()
    _assert_equal(engine.player.defense, 15, "引擎提供者入口只修改命中的持有方")
    _assert_equal(engine.enemy.defense, 10, "提供者默认不影响另一方")
    _assert_true(
        engine.unregister_defense_retention_provider(
            "test.engine_retention_bonus"),
        "战斗引擎公开统一保留比例提供者注销入口")
    _assert_true(
        engine.timing_system.unregister_handler(
            BattleTimingSystemScript.ACTION_WINDOW_END,
            "test.capture_defense_before_decay"),
        "时点测试完成后注销捕获处理器")

    engine.player.defense = 7
    engine.enemy.defense = 9
    engine.enemy.life = 0
    engine._update_battle_state()
    _assert_equal(engine.player.defense + engine.enemy.defense, 0, "战斗结束时双方防御清空")

func _test_status_behavior_registry_contract() -> void:
    var registry = StatusBehaviorRegistryScript.new()
    var probe = ProbeStatusBehaviorHandlerScript.new()
    _assert_true(registry.register_handler(probe), "状态行为注册表接收外部小型处理器")
    _assert_true(
        not registry.register_handler(ProbeStatusBehaviorHandlerScript.new()),
        "状态行为注册表拒绝重复处理器 ID")
    _assert_true(
        not registry.register_handler(ProbeStatusBehaviorHandlerScript.new(["dup", "dup"])),
        "单个处理器不能重复声明同一行为 ID")
    _assert_true(
        registry.register_handler(
            ProbeStatusBehaviorHandlerScript.new(["probe_status_behavior"]), true),
        "显式替换可以更新已登记状态处理器")
    var unknown: Dictionary = registry.execute({"handler": "missing_behavior"}, null)
    _assert_true(not unknown.get("success", true), "运行边界拒绝未知状态处理器")
    _assert_true(str(unknown.get("detail", "")).contains("未注册"), "未知处理器返回稳定诊断")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "状态注册覆盖测试载入内容目录")
    var system = StatusSystemScript.new(catalog)
    for definition in catalog.all_of("anomaly"):
        for behavior in definition.get("behaviors", []):
            _assert_true(
                system.behavior_registry.has_handler(str(behavior.get("handler", ""))),
                "anomaly.%s 的行为已登记：%s" % [
                    definition.get("id", ""),
                    behavior.get("handler", "")])

func _test_status_system_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F3C 状态系统载入正式内容")
    var engine = _tracked_combat_engine(GameLogScript.new(), catalog)
    engine.setup(815, false)
    var system = engine.status_system
    var card = _card("9", "fire")
    catalog.card_reshape_rules.bind_card(card)
    engine.player.hand = [card]

    _assert_true(system.apply_card_anomaly(card, "buff", "qi_heat", {}, "测试", 2)["success"], "状态系统施加炽气层数")
    _assert_true(system.apply_card_anomaly(card, "debuff", "qi_wither", {}, "测试", 1)["success"], "状态系统施加枯气层数")
    _assert_equal(system.effective_qi_value(card), 10, "炽气枯气走同一有效真气管线")
    system.apply_card_anomaly(card, "buff", "growth", {}, "测试", 2)
    system.apply_card_anomaly(card, "debuff", "decay", {}, "测试", 1)
    engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
        "actor": engine.player})
    _assert_equal(card.anomaly_layers("buff", "qi_heat"), 4, "成长留手按层产生炽气")
    _assert_equal(card.anomaly_layers("debuff", "qi_wither"), 2, "衰败留手按层产生枯气")

    var forbidden = _card("7", "forest")
    catalog.card_reshape_rules.bind_card(forbidden)
    engine.player.hand = [forbidden]
    _assert_true(system.apply_card_anomaly(forbidden, "state", "forbidden", {}, "测试", 2)["success"], "封禁两层首次施加")
    _assert_true(system.apply_card_anomaly(forbidden, "state", "forbidden", {}, "测试", 2)["success"], "封禁同名层数相加")
    _assert_equal(forbidden.anomaly_layers("state", "forbidden"), 4, "封禁累计四层")
    _assert_true(not system.can_play_card(engine.player, forbidden)["allowed"], "封禁层数大于零不可打出")
    engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {"actor": engine.player})
    _assert_equal(forbidden.anomaly_layers("state", "forbidden"), 3, "每个完整回合只减少一层封禁")

    var state_card = _card("6", "wind")
    catalog.card_reshape_rules.bind_card(state_card)
    _assert_true(system.apply_card_anomaly(state_card, "state", "vulnerability", {}, "测试")["success"], "先施加破绽")
    _assert_true(not system.apply_card_anomaly(state_card, "state", "poison", {}, "测试")["success"], "不同状态默认拒绝覆盖")
    _assert_equal(state_card.current_state()["id"], "vulnerability", "拒绝覆盖时旧状态保留")
    _assert_true(system.apply_card_anomaly(state_card, "state", "poison", {}, "测试", 1, true)["success"], "replace_state 原子替换")
    _assert_equal(state_card.current_state()["id"], "poison", "显式替换后毒成为唯一状态")
    _assert_true(system.apply_card_anomaly(state_card, "state", "poison", {}, "测试")["success"], "重复毒视为成功但不重复获得")
    _assert_equal(state_card.anomaly_layers("state", "poison"), 1, "毒不叠层")

    var poison_card = _card("7", "forest")
    catalog.card_reshape_rules.bind_card(poison_card)
    poison_card.set_enhancement("qi_boost")
    engine.player.life = 100
    engine.player.staging = [poison_card]
    system.apply_card_anomaly(poison_card, "state", "poison", {}, "测试")
    var poison_resolutions: Array = system.resolve_played_card_anomalies(
        engine.player, [poison_card], {"action_token": "poison"})
    _assert_equal(poison_resolutions[0]["damage"], 15, "毒冻结当前有效真气值伤害")
    _assert_equal(engine.player.life, 85, "毒伤作用于持有者")
    _assert_true(not poison_card.has_anomaly("state"), "毒伤后移除毒")
    var discarded_poison = _card("8", "mountain")
    catalog.card_reshape_rules.bind_card(discarded_poison)
    engine.player.hand = [discarded_poison]
    engine.player.staging.clear()
    system.apply_card_anomaly(discarded_poison, "state", "poison", {}, "测试")
    engine.player.random_discard(1, engine.rng)
    _assert_equal(engine.player.life, 85, "毒被明确弃掉不造成伤害")

    var acupoint_a = _card("2", "forest")
    var acupoint_b = _card("3", "forest")
    var vulnerable = _card("4", "mountain")
    for entry in [acupoint_a, acupoint_b, vulnerable]:
        catalog.card_reshape_rules.bind_card(entry)
    engine.player.hand = [acupoint_a, acupoint_b]
    engine.enemy.hand = [vulnerable]
    system.apply_card_anomaly(acupoint_a, "state", "acupoint_block", {}, "测试")
    system.apply_card_anomaly(acupoint_b, "state", "acupoint_block", {}, "测试")
    system.apply_card_anomaly(vulnerable, "state", "vulnerability", {}, "测试")
    engine.enemy.life = 1000
    engine.enemy.max_life = 1000
    engine.deal_damage(engine.player, engine.enemy, 100, "technique")
    _assert_equal(engine.enemy.life, 920, "两封穴一破绽按手牌张数合并为 -20%")

    var flawless = _card("5", "fire")
    catalog.card_reshape_rules.bind_card(flawless)
    flawless.set_enhancement("flawless")
    system.apply_card_anomaly(flawless, "state", "forbidden", {}, "测试")
    _assert_true(flawless.has_anomaly("state", "forbidden"), "无漏不阻止封禁")
    _assert_true(not system.apply_card_anomaly(
        flawless, "state", "poison", {}, "测试", 1, true)["success"], "无漏阻止 replace_state 的毒")
    _assert_equal(flawless.current_state()["id"], "forbidden", "替换被无漏阻止时旧状态不丢失")
    system.apply_card_anomaly(flawless, "mark", "return_to_origin", {}, "测试")
    _assert_true(system.apply_card_anomaly(
        flawless, "state", "poison", {}, "测试", 1, true)["success"], "归元期间无漏效果失效")

    var delayed_entries: Array = system.delayed_records
    var response_entries: Array = system.response_records
    var history_entries: Array = system.history
    system.delayed_records.append({"id": "runtime-state-delay"})
    system.response_records.append({"id": "runtime-state-response"})
    system.record_technique_card_flow(engine.player, "draw", 3)
    system.restore_runtime_record_serial(37)
    engine.rng.state = 123456789
    var runtime_state: Dictionary = system.capture_runtime_state()
    var restored_history: Array = runtime_state["history"].duplicate(true)
    var restored_rng_state := int(runtime_state["rng_state"])
    system.delayed_records.clear()
    system.response_records.clear()
    system.history.clear()
    system.record_technique_card_flow(engine.player, "draw", 4)
    system.restore_runtime_record_serial(0)
    engine.rng.randi()
    system.restore_runtime_state(runtime_state)
    _assert_equal(system.delayed_records, [{"id": "runtime-state-delay"}],
        "状态运行快照恢复延迟记录")
    _assert_equal(system.response_records, [{"id": "runtime-state-response"}],
        "状态运行快照恢复响应记录")
    _assert_equal(system.history, restored_history, "状态运行快照恢复历史且不追加记录")
    _assert_equal(system.runtime_record_serial(), 37, "状态运行快照恢复共享记录序号")
    _assert_equal(system.technique_draw_count(engine.player), 3,
        "状态运行快照恢复功法抽牌统计")
    _assert_equal(engine.rng.state, restored_rng_state, "状态运行快照恢复已注入 RNG")
    delayed_entries.append({"id": "runtime-state-array-identity"})
    _assert_equal(system.delayed_records.back()["id"],
        "runtime-state-array-identity", "延迟记录恢复保持公开 Array 实例")
    delayed_entries.pop_back()
    response_entries.append({"id": "runtime-state-array-identity"})
    _assert_equal(system.response_records.back()["id"],
        "runtime-state-array-identity", "响应记录恢复保持公开 Array 实例")
    response_entries.pop_back()
    history_entries.append({"change_type": "runtime-state-array-identity"})
    _assert_equal(system.history.back()["change_type"],
        "runtime-state-array-identity", "历史恢复保持公开 Array 实例")
    history_entries.pop_back()

    var snapshot = BattleSessionScript.new(engine).snapshot()
    _assert_equal(snapshot.status_history.size(), system.history.size(), "战斗快照公开完整状态变化历史")
    engine.player.hand = [flawless]
    engine.timing_system.emit_timing(BattleTimingSystemScript.BATTLE_END, {
        "actors": [engine.player, engine.enemy]})
    _assert_true(flawless.anomaly_snapshot()["marks"].is_empty(), "战斗结束清除新异状")
    _assert_equal(engine.player.momentum_value, 0, "F3B 连势战斗结束清理继续成立")
    _assert_equal(engine.player.current_reflection_percent, 0, "F3B 反震战斗结束清理继续成立")

func _array_contains_change_type(values: Array, wanted: String) -> bool:
    for value in values:
        if value is Dictionary and str(value.get("change_type", "")) == wanted:
            return true
    return false

func _test_action_controller_boundaries_and_strategy() -> void:
    var human = PlayerActionControllerScript.new()
    var selected_card = _card("7", "wind")
    var accepted = human.propose(
        [selected_card.id],
        func(_ids_value: Array): return {
            "valid": true,
            "hand": {"id": "high_card"},
            "intent": {"damage": 0, "defense": 0},
        })
    _assert_true(accepted.accepted, "玩家行动控制器把 UI 选牌转换为统一行动提案")
    _assert_equal(accepted.controller_id, "human", "玩家行动提案记录独立生成来源")
    var rejected = human.propose(
        [],
        func(_ids_value: Array): return {"valid": false, "reason": "必须选牌"})
    _assert_true(not rejected.accepted, "玩家行动控制器保留共享预览规则的拒绝结果")
    _assert_equal(rejected.rejection_reason, "必须选牌", "玩家行动拒绝原因来自共享规则核")

    var actor = BattleSideScript.new("观察者", "observer")
    var opponent = BattleSideScript.new("目标", "target")
    actor.hand = [_card("2", "fire")]
    actor.draw_pile = [_card("3", "fire")]
    opponent.hand = [_card("A", "mountain")]
    opponent.draw_pile = [_card("K", "mountain")]
    var sequence_book = preload("res://core/sequence_book.gd").new()
    sequence_book.configure({"high_card": ["probe_observation_technique"]})
    var flow = BattleFlowCoordinatorScript.new()
    flow.reset([actor, opponent])
    flow.begin_round([{"actor": actor, "actions": 1}])
    var observation = BattleObservationScript.new().capture(
        actor, opponent, sequence_book, flow)
    var public_observation: Dictionary = observation.public_snapshot()
    _assert_equal(observation.actor_hand[0].id, actor.hand[0].id, "决策器能读取自己真实手牌")
    _assert_equal(public_observation["opponent_hand_count"], 1, "决策观察只公开对方手牌数量")
    _assert_true(not public_observation.has("opponent_hand"), "决策观察不泄露对方手牌内容")
    _assert_true(not public_observation.has("actor_draw_pile"), "决策观察不泄露己方牌库顺序")
    _assert_true(not public_observation.has("opponent_draw_pile"), "决策观察不泄露对方牌库顺序")

    var rng := RandomNumberGenerator.new()
    rng.seed = 815
    var enemy_controller = EnemyActionControllerScript.new(rng)
    var lethal_card = _card("4", "fire")
    var defense_card = _card("5", "mountain")
    var lethal_observation = BattleObservationScript.new()
    lethal_observation.actor_hand = [lethal_card, defense_card]
    lethal_observation.actor_life = 100
    lethal_observation.actor_max_life = 100
    lethal_observation.opponent_life = 10
    lethal_observation.opponent_defense = 0
    var lethal_definitions := {
        _selection_key([lethal_card.id]): {
            "valid": true,
            "intent": {"damage": 10, "defense": 0, "combo": false},
            "values": {"technique_value": 10},
            "condition": {"ok": true},
            "technique_id": "lethal",
            "next_technique_id": "",
        },
        _selection_key([defense_card.id]): {
            "valid": true,
            "intent": {"damage": 0, "defense": 100, "combo": false},
            "values": {"technique_value": 100},
            "condition": {"ok": true},
            "technique_id": "guard",
            "next_technique_id": "",
        },
    }
    var lethal = enemy_controller.propose_utility(
        lethal_observation,
        Callable(self, "_fake_action_preview").bind(lethal_definitions),
        {"defense_weight": 100.0, "power_weight": 0.0})
    _assert_equal(lethal.card_ids, [str(lethal_card.id)], "敌方硬优先级不会因即时评分权重错过必杀")
    _assert_equal(lethal.diagnostics["priority"], 2, "必杀行动进入最高决策优先级")

    var survival_observation = BattleObservationScript.new()
    survival_observation.actor_hand = [lethal_card, defense_card]
    survival_observation.actor_life = 20
    survival_observation.actor_max_life = 100
    survival_observation.opponent_life = 100
    survival_observation.opponent_defense = 0
    survival_observation.expected_incoming_damage = 25
    var survival = enemy_controller.propose_utility(
        survival_observation,
        Callable(self, "_fake_action_preview").bind(lethal_definitions),
        {
            "damage_weight": 100.0,
            "defense_weight": 0.0,
            "power_weight": 0.0,
            "danger_life_ratio": 0.3,
        })
    _assert_equal(survival.card_ids, [str(defense_card.id)], "确认存在致命威胁时敌方优先选择能存活的防御")
    _assert_equal(survival.diagnostics["priority"], 1, "生存行动只在有公开威胁估计时进入硬优先级")

    var setup_card_a = _card("6", "wind")
    var setup_card_b = _card("7", "wind")
    var follow_card_a = _card("8", "fire")
    var follow_card_b = _card("9", "forest")
    var planning_observation = BattleObservationScript.new()
    planning_observation.actor_hand = [
        setup_card_a, setup_card_b, follow_card_a, follow_card_b]
    planning_observation.actor_life = 100
    planning_observation.actor_max_life = 100
    planning_observation.opponent_life = 100
    planning_observation.opponent_defense = 0
    var setup_ids := [setup_card_a.id, setup_card_b.id]
    var follow_ids := [follow_card_a.id, follow_card_b.id]
    var all_ids := setup_ids + follow_ids
    var planning_definitions := {
        _selection_key(setup_ids): {
            "valid": true,
            "intent": {"damage": 35, "defense": 0, "combo": true},
            "values": {"technique_value": 35},
            "condition": {"ok": true},
            "technique_id": "setup",
            "next_technique_id": "payoff",
        },
        _selection_key(follow_ids): {
            "valid": true,
            "intent": {"damage": 40, "defense": 0, "combo": false},
            "values": {"technique_value": 40},
            "condition": {"ok": true},
            "technique_id": "payoff",
            "next_technique_id": "",
        },
        _selection_key(all_ids): {
            "valid": true,
            "intent": {"damage": 50, "defense": 0, "combo": true},
            "values": {"technique_value": 50},
            "condition": {"ok": true},
            "technique_id": "burst",
            "next_technique_id": "",
        },
    }
    var planned = enemy_controller.propose_utility(
        planning_observation,
        Callable(self, "_fake_action_preview").bind(planning_definitions),
        {
            "card_cost": 0.0,
            "power_weight": 0.0,
            "combo_bonus": 0.0,
            "combo_follow_up_weight": 0.75,
            "combo_without_follow_up_penalty": 30.0,
        })
    _assert_equal(planned.card_ids, [str(setup_card_a.id), str(setup_card_b.id)], "敌方会为可立即连击的后续收益放弃当前最高伤害")
    _assert_true(float(planned.diagnostics["score_components"]["combo_follow_up"]) > 0.0, "敌方提案记录可审计的后续手牌价值")

func _selection_key(card_ids: Array) -> String:
    var values: Array[String] = []
    for card_id in card_ids:
        values.append(str(card_id))
    values.sort()
    return "|".join(values)

func _fake_action_preview(card_ids: Array, definitions: Dictionary) -> Dictionary:
    return definitions.get(
        _selection_key(card_ids),
        {"valid": false, "reason": "测试候选未定义"}).duplicate(true)

func _test_run_deck_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "RunDeck 新版本契约载入内容目录")
    var run_deck = RunDeckScript.new(catalog)
    run_deck.reset_standard("f3c-run")
    _assert_equal(run_deck.card_count(), 52, "RunDeck 建立标准 52 张")
    var cards: Array = run_deck.create_battle_cards()
    var source = cards.filter(func(card): return card.id == "wind_7")[0]
    _assert_true(CardOriginServiceScript.new(catalog).apply_to_card(
        source, "attribute_change", {"attribute": "mountain"})["success"], "战斗实例转属")
    source.set_enhancement("qi_boost")
    source.set_anomaly("buff", "qi_heat", {}, 3)
    source.set_anomaly("state", "poison")
    source.set_temporary_enhancement("momentum")
    source.set_temporary_attribute("fire")
    run_deck.sync_from_battle_cards(cards)
    var persistent: Dictionary = run_deck.card_data("wind_7")
    _assert_equal(persistent["version"], 5, "RunDeck 内部使用 QiCard DTO v5")
    _assert_equal(persistent["origin_base_identity"]["definition_id"], "wind_7", "持久 DTO 保存转属前基础身份")
    _assert_equal(persistent["definition_id"], "mountain_7", "持久 DTO 保存已物化转属身份")
    _assert_true(not persistent.has("anomalies"), "同步不写回战斗异状")
    _assert_true(not persistent.has("temporary_reshapes"), "同步不写回临时重塑")

    var copied: Dictionary = run_deck.copy_card("wind_7", 1)
    _assert_true(copied["success"], "完整复制成功")
    var copy_data: Dictionary = run_deck.card_data(copied["instance_ids"][0])
    _assert_true(not copy_data.has("anomalies") and not copy_data.has("temporary_reshapes"), "完整复制不复制战斗层")
    _assert_equal(copy_data["origin_base_identity"], persistent["origin_base_identity"], "完整复制保留永久身份")

    var snapshot: Dictionary = run_deck.to_snapshot()
    _assert_equal(snapshot["version"], 3, "RunDeck 快照版本提升为 3")
    var restored = RunDeckScript.new(catalog)
    _assert_equal(restored.restore_snapshot(snapshot), [], "RunDeck v3 快照恢复")
    _assert_equal(restored.to_snapshot(), snapshot, "RunDeck v3 往返稳定")

    var legacy = RunDeckScript.new(catalog)
    legacy.reset_from_card_ids(["wind_2"], "legacy")
    var legacy_snapshot: Dictionary = legacy.to_snapshot()
    legacy_snapshot["version"] = 2
    legacy_snapshot["cards"][0]["version"] = 4
    legacy_snapshot["cards"][0].erase("origin_base_identity")
    var migrated = RunDeckScript.new(catalog)
    _assert_equal(migrated.restore_snapshot(legacy_snapshot), [], "当前工作区无本源 v2/v4 快照明确迁移")
    _assert_equal(migrated.to_snapshot()["cards"][0]["version"], 5, "迁移后实例升级为 v5")

    var impossible_legacy: Dictionary = legacy_snapshot.duplicate(true)
    impossible_legacy["cards"][0]["reshapes"]["origin"] = {
        "id": "attribute_change", "payload": {"attribute": "fire"}}
    _assert_true(
        _array_contains_text(
            RunDeckScript.new(catalog).restore_snapshot(impossible_legacy),
            "不能静默猜测"),
        "缺少转属前属性的旧快照明确拒绝")
    var unsupported: Dictionary = snapshot.duplicate(true)
    unsupported["version"] = 1
    _assert_true(
        _array_contains_text(RunDeckScript.new(catalog).restore_snapshot(unsupported), "版本不受支持"),
        "更旧 RunDeck 版本仍明确拒绝")

func _test_awakening_origin_persistence_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "觉醒本源契约载入统一内容目录")
    _assert_equal(catalog.all_of("origin").size(), 3, "正式内容包含转属、易阶、觉醒三种本源")
    _assert_equal(catalog.all_of("enhancement").size(), 8, "F2D2 包含八种正式强化")
    _assert_equal(catalog.all_of("imprint").size(), 4, "正式内容录入四种印记")

    var card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "awakening:wind_7",
        catalog.card_reshape_rules)
    var identity_before := {
        "id": card.id,
        "definition_id": card.definition_id,
        "rank_name": card.rank_name,
        "rank_order": card.rank_order,
        "qi_value": card.qi_value,
        "attribute": card.attribute,
        "attribute_name": card.attribute_name,
    }
    var awakened: Dictionary = CardOriginServiceScript.new(catalog).apply_to_card(
        card, "awakening", {})
    _assert_true(awakened.get("success", false), "空 payload 觉醒读取当前基础属性")
    _assert_equal(
        card.reshape_origin,
        {"id": "awakening", "payload": {"attribute": "wind"}},
        "风牌觉醒持久保存 payload.attribute=wind")
    _assert_equal({
        "id": card.id,
        "definition_id": card.definition_id,
        "rank_name": card.rank_name,
        "rank_order": card.rank_order,
        "qi_value": card.qi_value,
        "attribute": card.attribute,
        "attribute_name": card.attribute_name,
    }, identity_before, "觉醒不改变实例、牌阶、基础属性或基础真气值")
    _assert_true(
        not CardOriginServiceScript.new(catalog).apply_to_card(
            card, "attribute_change", {"attribute": "fire"}).get("success", false),
        "觉醒后本源槽锁定并拒绝再次改造")

    var mismatch = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "awakening:mismatch",
        catalog.card_reshape_rules)
    _assert_true(
        not CardOriginServiceScript.new(catalog).apply_to_card(
            mismatch, "awakening", {"attribute": "fire"}).get("success", false),
        "风牌不能通过 payload 强制写成火觉醒")

    var captured: Dictionary = QiCardInstanceDataScript.capture(card)
    _assert_equal(
        QiCardInstanceDataScript.validate(captured, catalog), [],
        "觉醒真气实例通过统一持久化校验")
    var restored = QiCardInstanceDataScript.restore(captured, catalog.card_reshape_rules)
    _assert_equal(restored.reshape_origin, card.reshape_origin, "真气 DTO 往返保留觉醒属性")

    var run_deck = RunDeckScript.new(catalog)
    run_deck.reset_standard("awakening-run")
    _assert_true(
        run_deck.apply_card_origin(["wind_7"], "awakening", {}).get("success", false),
        "RunDeck 通过本源边界施加觉醒")
    var copied: Dictionary = run_deck.copy_card("wind_7")
    _assert_true(copied.get("success", false), "完整复制觉醒真气成功")
    _assert_equal(
        run_deck.card_data(str(copied["instance_ids"][0]))["reshapes"]["origin"],
        run_deck.card_data("wind_7")["reshapes"]["origin"],
        "完整复制保留觉醒属性与本源锁")
    var battle_cards: Array = run_deck.create_battle_cards()
    run_deck.sync_from_battle_cards(battle_cards)
    _assert_equal(
        run_deck.card_data("wind_7")["reshapes"]["origin"]["payload"]["attribute"],
        "wind",
        "战斗装配与战后同步保留觉醒属性")

    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 82101}).success, "觉醒存档测试建立本局")
    _assert_true(
        session.growth.run_deck.apply_card_origin(
            ["forest_7"], "awakening", {}).get("success", false),
        "本局牌组施加林觉醒")
    var save = RunSaveDataScript.new().capture(session)
    var save_restored: Dictionary = save.restore_session(catalog)
    _assert_true(save_restored.get("success", false), "带觉醒的本局存档可以恢复")
    _assert_equal(
        save_restored["run_session"].growth.run_deck.card_data(
            "forest_7")["reshapes"]["origin"]["payload"]["attribute"],
        "forest",
        "存档—读档保留觉醒属性")

    var enemy_awakened: Dictionary = EnemyDeckEncodingScript.parse([{
        "definition_id": "mountain_7",
        "reshapes": {
            "origin": {"id": "awakening", "payload": {"attribute": "mountain"}},
        },
    }], catalog, "awakening-enemy")
    _assert_true(enemy_awakened.get("success", false), "敌人可预置与基础属性一致的觉醒")
    _assert_equal(
        enemy_awakened["cards"][0].reshape_origin["payload"]["attribute"],
        "mountain",
        "敌人预置保留觉醒属性")
    var bad_enemy: Dictionary = EnemyDeckEncodingScript.parse([{
        "definition_id": "wind_7",
        "reshapes": {
            "origin": {"id": "awakening", "payload": {"attribute": "fire"}},
        },
    }], catalog, "awakening-enemy-bad")
    _assert_true(not bad_enemy.get("success", false), "敌人预置同样拒绝伪造觉醒属性")
    var inferred_enemy: Dictionary = EnemyDeckEncodingScript.parse([{
        "definition_id": "fire_7",
        "reshapes": {
            "origin": {"id": "awakening", "payload": {}},
        },
    }], catalog, "awakening-enemy-inferred")
    _assert_true(inferred_enemy.get("success", false), "敌人预置可用空 payload 读取基础属性")
    _assert_equal(
        inferred_enemy["cards"][0].reshape_origin["payload"]["attribute"],
        "fire",
        "敌人空 payload 觉醒在装配时持久化实际属性")

func _test_battle_card_policy_ports() -> void:
    var four_cards := [_card("2"), _card("3"), _card("4"), _card("5")]
    _assert_true(
        HandEvaluatorScript.evaluate(four_cards).get("id", "") != "straight",
        "默认识别仍只允许五张顺子")
    var recognition := HandRecognitionPolicyScript.new()
    recognition.register_provider(
        func(_owner, _context): return {"straight_allowed_sizes": [4]},
        "fake_four_card", 20)
    var four_options: Dictionary = recognition.resolve_options()
    _assert_true(four_options.get("success", false), "Fake 四张顺子选项查询成功")
    _assert_equal(
        HandEvaluatorScript.evaluate(four_cards, four_options["options"])["id"],
        "straight",
        "Fake 策略可以声明四张顺子")

    var gap_options = HandRecognitionOptionsScript.new().configure({
        "straight_allowed_sizes": [4], "straight_max_step": 2,
    })
    _assert_equal(
        HandEvaluatorScript.evaluate(
            [_card("2"), _card("4"), _card("6"), _card("8")],
            gap_options)["id"],
        "straight",
        "Fake 最大相邻间隔 2 生效")
    _assert_equal(
        HandEvaluatorScript.evaluate(
            [_card("A"), _card("2"), _card("3"), _card("4"), _card("5")])["id"],
        "straight",
        "默认 A 低端规则保持")
    _assert_equal(
        HandEvaluatorScript.evaluate(
            [_card("10"), _card("J"), _card("Q"), _card("K"), _card("A")])["id"],
        "straight",
        "默认 A 高端规则保持")

    var identity_card = _card("7", "wind")
    identity_card.is_true_qi = false
    var identity := CardIdentityPolicyScript.new()
    identity.register_provider(
        func(_card_value, _context): return {
            "facts": {
                "is_true_qi": true,
                "additional_effective_attributes": ["fire"],
                "card_kinds": ["true_origin"],
            },
        },
        "fake_true_origin", 20)
    var identity_result: Dictionary = identity.resolve(identity_card)
    _assert_true(identity_result.get("success", false), "Fake 身份查询成功")
    _assert_true(identity_result["facts"].is_true_qi, "Fake 普通真气可以临时视为真元")
    _assert_true(identity_result["facts"].has_attribute("fire"), "Fake 身份统一增加有效属性")
    _assert_true(identity_result["facts"].is_card_kind("true_origin"), "Fake 普通真气可以视为真元")
    _assert_equal(identity_card.attribute, "wind", "Fake 身份不修改原始属性字段")
    _assert_true(not identity_card.is_true_qi, "Fake 真元身份不写回原始真气标记")
    _assert_true(
        TechniqueRepositoryPolicyScript.is_pure_attribute(
            {"contributing": [identity_card]}, "fire", identity),
        "功法条件复用同一身份查询")
    var identity_side := BattleSideScript.new("identity", "identity")
    identity_side.hand.append(identity_card)
    var target_context = TechniqueEffectContextScript.new().configure({
        "actor": identity_side, "target": identity_side,
        "card_identity_policy": identity,
        "captures": {"probe": [identity_card]},
    })
    var target_query = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand",
        "filters": {"attributes": ["fire"]},
        "card_identity_policy": identity,
    }).resolve(target_context)
    _assert_true(target_query.get("success", false), "目标筛选复用同一身份查询")
    _assert_equal(target_query.get("cards", []).size(), 1, "视为身份参与目标筛选")
    var value_count := EffectValueResolverScript.new().resolve(
        {"kind": "capture_attribute_count", "capture": "probe", "attribute": "fire"},
        target_context)
    _assert_equal(value_count, 1, "效果值复用同一身份查询")
    identity.register_provider(
        func(_card_value, _context): return {"rank_tags": ["second_source"]},
        "fake_second", 30)
    var merged_identity: Dictionary = identity.resolve(identity_card)
    _assert_equal(
        merged_identity["source_breakdown"].map(func(entry): return entry["source_id"]),
        ["fake_true_origin", "fake_second"],
        "多个身份来源按稳定顺序合并")

    var conflicting_identity := CardIdentityPolicyScript.new()
    conflicting_identity.register_provider(
        func(_card_value, _context): return {"is_true_qi": false},
        "conflict_a", 10)
    conflicting_identity.register_provider(
        func(_card_value, _context): return {"is_true_qi": true},
        "conflict_b", 20)
    _assert_true(
        not conflicting_identity.resolve(identity_card).get("success", true),
        "冲突身份规则明确失败")

    var permission := BattlePermissionServiceScript.new()
    var permission_calls: Array[String] = []
    permission.register_provider(
        func(hook, _context):
            permission_calls.append(hook)
            return {"allowed": hook != "explicit_discard_permission_query", "reason": "Fake 否决"},
        "fake_permission", 10)
    _assert_true(
        permission.can_play_card(null, identity_card).get("allowed", false),
        "只有明确拒绝才阻断其他操作")
    _assert_true(
        not permission.can_explicit_discard(null, identity_card).get("allowed", true),
        "明确弃牌统一权限链可以拒绝")
    _assert_equal(
        permission_calls,
        ["card_play_permission_query", "explicit_discard_permission_query"],
        "普通出牌不触发明确弃牌权限")
    var failed_permission := BattlePermissionServiceScript.new()
    failed_permission.register_provider(
        func(_hook, _context): return {}, "broken_permission", 10)
    _assert_true(
        not failed_permission.can_play_card(null, identity_card).get("allowed", true),
        "权限查询失败不默认允许")

func _test_technique_and_cooperation_permission_wiring() -> void:
    var permission := BattlePermissionServiceScript.new()
    var typed_calls: Array = []
    permission.register_provider(
        func(hook, context):
            typed_calls.append({"hook": hook, "context": context})
            return {"allowed": true},
        "typed_permission", 10,
        ["technique_activation_permission_query", "cooperation_permission_query"])
    _assert_true(
        permission.can_activate_technique(null, "fake_technique", "pair")["allowed"],
        "功法启动权限提供类型化入口")
    _assert_true(
        permission.can_establish_cooperation(
            null, "fake_main", "three_kind", "fake_pair", "pair")["allowed"],
        "协同建立权限提供类型化入口")
    _assert_equal(typed_calls[0]["context"]["technique_id"], "fake_technique", "功法入口携带功法 ID")
    _assert_equal(typed_calls[1]["context"]["cooperation_hand_id"], "pair", "协同入口携带两组身份")

    var selected = _card("7", "wind")
    var denied_engine = _engine_with_hand([selected], [], 82501)
    denied_engine.repository.techniques["f5f_denied_probe"] = {
        "id": "f5f_denied_probe", "name": "F5F 启动拒绝探针",
        "pool": "high",
        "effects": [
            {"op": "damage", "amount": {"kind": "constant", "value": 9}},
            {"op": "defense", "amount": {"kind": "constant", "value": 6}},
        ],
    }
    denied_engine.sequence_book.configure({
        "high_card": ["f5f_denied_probe", "f5f_denied_probe"],
    })
    denied_engine.player.momentum_value = 8
    denied_engine.player.last_successful_technique_hand_id = "pair"
    var denied_calls: Array[String] = []
    denied_engine.battle_permission_service.register_provider(
        func(hook, _context):
            denied_calls.append(hook)
            return {
                "allowed": hook != "technique_activation_permission_query",
                "reason": "Fake 禁止功法启动",
            },
        "f5f_deny_technique", 10,
        ["technique_activation_permission_query"])
    var rng_before: int = int(denied_engine.rng.state)
    var denied_preview: Dictionary = denied_engine.preview([selected.id])
    _assert_true(denied_preview["valid"], "功法启动明确拒绝不使预览无效")
    _assert_true(denied_preview["technique_activation"]["checked"], "预览保存功法权限已查询")
    _assert_true(not denied_preview["technique_activation"]["allowed"], "预览保存结构化拒绝")
    _assert_equal(denied_preview["technique_id"], "f5f_denied_probe", "拒绝预览仍保留当前功法")
    _assert_equal(denied_preview["intent"]["damage"], 0, "拒绝功法不进入伤害意图")
    _assert_equal(denied_preview["intent"]["defense"], 0, "拒绝功法不进入防御意图")
    _assert_equal(denied_preview["values"]["momentum_used"], 0, "拒绝功法预览不读取连势")
    _assert_equal(denied_engine.rng.state, rng_before, "预览权限查询不推进 RNG")
    var stable_state: Dictionary = denied_engine.player.capture_passive_query_state()
    denied_engine.preview([selected.id])
    _assert_equal(denied_engine.player.capture_passive_query_state(), stable_state, "重复预览权限查询不修改战斗状态")
    var enemy_life_before: int = denied_engine.enemy.life
    var denied_result: Dictionary = denied_engine.confirm_play([selected.id])
    _assert_true(denied_result.get("success", false), "功法启动明确拒绝仍允许出牌")
    _assert_true(not denied_result.get("technique_triggered", true), "明确拒绝的功法未触发")
    _assert_equal(denied_engine.enemy.life, enemy_life_before, "拒绝功法伤害不结算")
    _assert_equal(denied_engine.player.defense, 0, "拒绝功法防御不结算")
    _assert_equal(denied_engine.player.discard_pile, [selected], "被拒绝功法的真气仍正常进入弃牌堆")
    _assert_equal(denied_engine.player.momentum_value, 8, "被拒绝功法不使用或清空连势")
    _assert_equal(denied_engine.player.last_successful_technique_hand_id, "pair", "被拒绝功法不更新成功牌型")
    _assert_equal(denied_engine.sequence_book.position("high_card"), 0, "被拒绝功法不推进序列")
    _assert_equal(denied_calls.size(), 4, "每次纯预览查询，正式确认只额外查询一次")

    var broken_card = _card("8", "forest")
    var broken_engine = _engine_with_hand([broken_card], [], 82502)
    broken_engine.repository.techniques["f5f_error_probe"] = {
        "id": "f5f_error_probe", "name": "F5F 查询错误探针",
        "pool": "high", "effects": [],
    }
    broken_engine.sequence_book.configure({"high_card": ["f5f_error_probe"]})
    var broken_calls := [0]
    broken_engine.battle_permission_service.register_provider(
        func(_hook, _context):
            broken_calls[0] += 1
            return {"allowed": true} if broken_calls[0] == 1 else {},
        "f5f_broken_permission", 10,
        ["technique_activation_permission_query"])
    var actions_before: int = broken_engine.actions_available
    var broken_result: Dictionary = broken_engine.confirm_play([broken_card.id])
    _assert_true(not broken_result.get("success", true), "正式权限查询错误使整个行动失败")
    _assert_true(broken_engine.player.hand.has(broken_card), "查询错误后牌返回手牌")
    _assert_true(broken_engine.player.staging.is_empty(), "查询错误后待出区清空")
    _assert_equal(broken_engine.actions_available, actions_before, "查询错误不消耗行动")

    var mutate_card = _card("9", "fire")
    var mutate_engine = _engine_with_hand([mutate_card], [], 82503)
    mutate_engine.repository.techniques["f5f_mutation_probe"] = {
        "id": "f5f_mutation_probe", "name": "F5F 纯度探针",
        "pool": "high", "effects": [],
    }
    mutate_engine.sequence_book.configure({"high_card": ["f5f_mutation_probe"]})
    mutate_engine.battle_permission_service.register_provider(
        func(_hook, context):
            context["target"].life -= 11
            return {"allowed": true},
        "f5f_mutating_permission", 10,
        ["technique_activation_permission_query"])
    var target_life_before: int = mutate_engine.enemy.life
    var mutate_preview: Dictionary = mutate_engine.preview([mutate_card.id])
    _assert_true(not mutate_preview.get("valid", true), "修改战斗状态的权限查询明确失败")
    _assert_equal(mutate_engine.enemy.life, target_life_before, "权限纯度失败恢复目标方状态")

    var main_cards := [_card("6", "wind"), _card("6", "forest"), _card("6", "fire")]
    var cooperation_cards := [_card("4", "wind"), _card("4", "mountain")]
    var cooperation_engine = _engine_with_hand(
        main_cards + cooperation_cards, [], 82504)
    cooperation_engine.repository.techniques["f5f_cooperation_main"] = {
        "id": "f5f_cooperation_main", "name": "F5F 协同主组",
        "pool": "three", "effects": [],
        "cooperation": {
            "hand_id": "pair", "max_groups": 1,
            "power_rule": "shared_half",
            "post_commit": {"destination": "own_discard"},
        },
    }
    cooperation_engine.repository.techniques["f5f_cooperation_pair"] = {
        "id": "f5f_cooperation_pair", "name": "F5F 协同组",
        "pool": "pair", "effects": [],
    }
    cooperation_engine.sequence_book.configure({
        "three_kind": ["f5f_cooperation_main"],
        "pair": ["f5f_cooperation_pair"],
    })
    var cooperation_calls := [0]
    cooperation_engine.battle_permission_service.register_provider(
        func(hook, _context):
            if hook == "cooperation_permission_query":
                cooperation_calls[0] += 1
                return {
                    "allowed": cooperation_calls[0] == 1,
                    "reason": "Fake 正式协同拒绝",
                }
            return {"allowed": true},
        "f5f_cooperation_permission", 10,
        ["technique_activation_permission_query", "cooperation_permission_query"])
    var cooperation_actions_before: int = cooperation_engine.actions_available
    var cooperation_receipts_before: int = (
        cooperation_engine.battle_passive_event_service.receipt_store.size())
    var cooperation_result: Dictionary = cooperation_engine.confirm_play(
        _ids(main_cards), _ids(cooperation_cards))
    _assert_true(not cooperation_result.get("success", true), "正式协同拒绝使整单失败")
    _assert_equal(cooperation_calls[0], 2, "协同候选与正式确认各查询一次")
    _assert_equal(cooperation_engine.player.hand.size(), 5, "正式协同拒绝后两组牌全部返回手牌")
    _assert_true(cooperation_engine.player.staging.is_empty(), "正式协同拒绝不保留待出牌")
    _assert_equal(cooperation_engine.actions_available, cooperation_actions_before, "正式协同拒绝不消耗行动")
    _assert_equal(cooperation_engine.sequence_book.position("three_kind"), 0, "正式协同拒绝不推进主序列")
    _assert_equal(cooperation_engine.sequence_book.position("pair"), 0, "正式协同拒绝不推进协同序列")
    _assert_equal(
        cooperation_engine.battle_passive_event_service.receipt_store.size(),
        cooperation_receipts_before,
        "正式协同拒绝前不发送 action_confirmed")

    var candidate_engine = _engine_with_hand(
        main_cards.duplicate() + cooperation_cards.duplicate(), [], 82505)
    candidate_engine.repository.techniques = cooperation_engine.repository.techniques.duplicate(true)
    candidate_engine.sequence_book.configure({
        "three_kind": ["f5f_cooperation_main"],
        "pair": ["f5f_cooperation_pair"],
    })
    candidate_engine.battle_permission_service.register_provider(
        func(hook, _context): return {
            "allowed": hook != "cooperation_permission_query",
            "reason": "Fake 候选协同拒绝",
        },
        "f5f_candidate_cooperation_deny", 10,
        ["technique_activation_permission_query", "cooperation_permission_query"])
    var candidate_rejected: Dictionary = candidate_engine.confirm_play(
        _ids(main_cards), _ids(cooperation_cards))
    _assert_true(not candidate_rejected.get("success", true), "候选阶段拒绝非法协同")
    var main_retry: Dictionary = candidate_engine.confirm_play(_ids(main_cards))
    _assert_true(main_retry.get("success", false), "候选协同被拒绝后主行动可单独重新提交")

    var own_main := [_card("5", "wind"), _card("5", "forest"), _card("5", "fire")]
    var own_cooperation := [_card("3", "wind"), _card("3", "mountain")]
    var own_engine = _engine_with_hand(own_main + own_cooperation, [], 82506)
    own_engine.repository.techniques["f5f_own_main"] = {
        "id": "f5f_own_main", "name": "F5F 主功法允许",
        "pool": "three",
        "effects": [{"op": "damage", "amount": {"kind": "constant", "value": 5}}],
        "cooperation": {
            "hand_id": "pair", "max_groups": 1,
            "power_rule": "shared_half",
            "post_commit": {"destination": "own_discard"},
        },
    }
    own_engine.repository.techniques["f5f_own_pair"] = {
        "id": "f5f_own_pair", "name": "F5F 协同功法拒绝",
        "pool": "pair",
        "effects": [{"op": "damage", "amount": {"kind": "constant", "value": 7}}],
    }
    own_engine.sequence_book.configure({
        "three_kind": ["f5f_own_main", "f5f_own_main"],
        "pair": ["f5f_own_pair", "f5f_own_pair"],
    })
    own_engine.battle_permission_service.register_provider(
        func(hook, context):
            if hook == "technique_activation_permission_query" \
                    and str(context.get("hand_id", "")) == "pair":
                return {"allowed": false, "reason": "Fake 协同组功法拒绝"}
            return {"allowed": true},
        "f5f_own_group_permission", 10,
        ["technique_activation_permission_query", "cooperation_permission_query"])
    var own_life_before: int = own_engine.enemy.life
    var own_result: Dictionary = own_engine.confirm_play(
        _ids(own_main), _ids(own_cooperation))
    _assert_true(own_result.get("success", false), "协同组功法拒绝不取消已允许协同")
    _assert_true(own_result.get("technique_triggered", false), "主功法仍正常触发")
    _assert_true(not own_result.get("cooperation_technique_triggered", true), "协同组自身功法未触发")
    _assert_equal(own_engine.enemy.life, own_life_before - 5, "只结算主功法伤害")
    _assert_equal(own_engine.player.discard_pile.size(), 5, "协同组牌仍正常打出并提交")
    _assert_equal(own_engine.sequence_book.position("three_kind"), 1, "主功法序列正常推进")
    _assert_equal(own_engine.sequence_book.position("pair"), 0, "协同组被拒绝后自身序列不推进")

    var record = denied_engine.action_resolver.make_action_record(
        denied_engine.player, denied_engine.enemy,
        denied_result["preview"], denied_engine.sequence_book, 100,
        denied_engine.turn_number)
    var record_snapshot: Dictionary = record.snapshot()
    _assert_true(record_snapshot["technique_activation_checked"], "行动记录保存启动权限已检查")
    _assert_true(not record_snapshot["technique_activation_allowed"], "行动记录保存冻结拒绝结果")
    _assert_equal(record_snapshot["technique_activation_reason"], "Fake 禁止功法启动", "行动快照保存拒绝原因")

func _test_awakening_battle_runtime() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "觉醒战斗运行时载入统一内容目录")
    var origin = CardOriginServiceScript.new(catalog)

    var wind_a = _card("7", "wind")
    var wind_b = _card("6", "wind")
    var wind_tail = _card("5", "forest")
    origin.apply_to_card(wind_a, "awakening", {})
    origin.apply_to_card(wind_b, "awakening", {})
    var wind_engine = _engine_with_hand([], [wind_tail, wind_b, wind_a], 82111)
    var wind_drawn: Array = wind_engine.player.draw(1)
    _assert_equal(wind_drawn.size(), 1, "最外层抽牌仍只报告请求抽到的一张")
    _assert_equal(wind_engine.player.hand.size(), 3, "连续风觉醒链式额外抽牌直到普通尾牌")
    _assert_equal(wind_engine.player.draw_pile.size(), 0, "风觉醒遇到空牌库自然停止")

    var forest_play = _card("7", "forest")
    var forest_discard = _card("6", "forest")
    var forest_effect = _card("5", "forest")
    var forest_direct = _card("4", "forest")
    for card in [forest_play, forest_discard, forest_effect, forest_direct]:
        origin.apply_to_card(card, "awakening", {})
    var forest_engine = _engine_with_hand([], [], 82112)
    forest_engine.player.staging = [forest_play]
    forest_engine.player.hand = [forest_discard, forest_effect]
    forest_engine.player.draw_pile = [forest_direct]
    forest_engine.player.card_zone_service.move_card(
        forest_engine.player, "staging", "discard_pile", forest_play, "normal_play")
    forest_engine.player.card_zone_service.move_card(
        forest_engine.player, "hand", "discard_pile", forest_discard, "explicit_discard")
    forest_engine.effect_ports.move_card(
        forest_engine.player, "hand", forest_engine.player, "discard_pile",
        forest_effect, "effect")
    _assert_true(
        forest_engine.player.draw_pile.has(forest_play)
        and forest_engine.player.draw_pile.has(forest_discard)
        and forest_engine.player.draw_pile.has(forest_effect),
        "林觉醒在正常打出、明确弃牌和效果入弃牌堆后回库并洗牌")
    forest_engine.player.card_zone_service.move_card(
        forest_engine.player, "draw_pile", "draw_pile", forest_direct, "gu_recycle")
    _assert_true(
        forest_engine.player.draw_pile.has(forest_direct),
        "未实际进入弃牌堆的直接回库不触发林觉醒改置")

    var fire_main = _card("7", "fire")
    var fire_extra = _card("2", "fire")
    origin.apply_to_card(fire_main, "awakening", {})
    origin.apply_to_card(fire_extra, "awakening", {})
    fire_main.set_enhancement("qi_boost")
    var fire_engine = _engine_with_hand([fire_main, fire_extra], [], 82113)
    fire_engine.repository.techniques["probe_awakening_group"] = {
        "id": "probe_awakening_group", "name": "觉醒组探针", "pool": "high",
        "special": false, "effects": []}
    fire_engine.sequence_book.configure({"high_card": ["probe_awakening_group"]})
    var fire_preview: Dictionary = fire_engine.preview(_ids([fire_main, fire_extra]))
    _assert_equal(fire_preview["values"]["card_total"], 30, "增元火觉醒按(7+8)×2参与数值计算")
    _assert_true(
        not fire_main.has_anomaly("debuff", "burned_out"),
        "预览保持纯计算且不施加燃尽")
    var fire_result: Dictionary = fire_engine.confirm_play(_ids([fire_main, fire_extra]))
    _assert_true(fire_result.get("success", false), "火觉醒真实功法组完成结算")
    _assert_true(fire_main.has_anomaly("debuff", "burned_out"), "参与最高牌型的火觉醒在组结束后燃尽")
    _assert_true(not fire_extra.has_anomaly("debuff", "burned_out"), "额外打出但未贡献的火觉醒不翻倍且不燃尽")
    _assert_equal(
        PowerCalculatorScript.calculate(
            HandEvaluatorScript.evaluate([fire_main]),
            {},
            Callable(fire_engine.status_system, "modify_card_contribution").bind(
                fire_engine.player))["card_total"],
        0,
        "燃尽令当前真气贡献为零")
    _assert_equal(
        fire_engine.status_system.effective_qi_value(fire_main),
        0,
        "战斗异状与效果读取同样把燃尽视为零有效真气")
    _assert_equal(
        _count_status_changes(fire_engine.status_system.history, "burned_out"),
        1,
        "一个功法组只为参与真气施加一次燃尽")
    var fire_group_events: Array = fire_engine.timing_system.history.filter(
        func(entry): return str(entry.get("timing", "")) == "group_end")
    _assert_equal(
        fire_group_events[-1]["handler_results"][-1]["handler_id"],
        "card_reshape_runtime.group_resolved",
        "火觉醒在功法与内功完成、序列推进之后响应组结束")
    fire_engine.status_system.apply_card_anomaly(
        fire_main, "mark", "purification", {}, "觉醒测试净化")
    _assert_true(not fire_main.has_anomaly("debuff", "burned_out"), "净化可清除燃尽")
    fire_engine.status_system.apply_card_anomaly(
        fire_extra, "debuff", "burned_out", {}, "觉醒测试战斗结束")
    fire_engine.timing_system.emit_timing(BattleTimingSystemScript.BATTLE_END, {
        "actors": [fire_engine.player, fire_engine.enemy],
    })
    _assert_true(not fire_extra.has_anomaly("debuff", "burned_out"), "战斗结束自动移除燃尽")

    var mountain_hand = _card("7", "mountain")
    var mountain_discard = _card("6", "mountain")
    var mountain_staging = _card("5", "mountain")
    var mountain_draw = _card("4", "mountain")
    for card in [mountain_hand, mountain_discard, mountain_staging, mountain_draw]:
        origin.apply_to_card(card, "awakening", {})
    mountain_hand.set_enhancement("qi_boost")
    var mountain_engine = _engine_with_hand([mountain_hand], [], 82114)
    mountain_engine.player.discard_pile = [mountain_discard]
    mountain_engine.player.staging = [mountain_staging]
    mountain_engine.player.draw_pile = [mountain_draw]
    var turn_end_result: Dictionary = mountain_engine.timing_system.emit_timing(
        BattleTimingSystemScript.TURN_END, {
            "actor": mountain_engine.player,
            "actors": [mountain_engine.player],
        })
    _assert_equal(mountain_engine.player.defense, 15, "山觉醒读取增元后的当前有效真气获得防御")
    var turn_end_handler_ids: Array = turn_end_result["results"].map(
        func(value): return str(value.get("handler_id", "")))
    _assert_true(
        turn_end_handler_ids.find("status_system.delayed_records") \
            < turn_end_handler_ids.find("card_reshape_runtime.turn_end") \
            and turn_end_handler_ids.find("card_reshape_runtime.turn_end") \
            < turn_end_handler_ids.find("status_system.card_turn_end_final"),
        "山觉醒排在现有回合结束状态与延迟效果之后、最终状态清理之前")
    mountain_engine.status_system.apply_card_anomaly(
        mountain_hand, "debuff", "burned_out", {}, "觉醒测试燃尽")
    mountain_engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
        "actor": mountain_engine.player,
        "actors": [mountain_engine.player],
    })
    _assert_equal(mountain_engine.player.defense, 15, "山觉醒读取燃尽后的零有效真气")

func _test_f2d2_formal_enhancement_runtime() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F3C 强化与归元测试载入内容")
    var lifecycle = CardStateLifecycleScript.new(catalog)

    var double_enhancement = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "f3c:double-enhancement",
        catalog.card_reshape_rules)
    double_enhancement.set_enhancement("qi_boost")
    double_enhancement.set_temporary_enhancement("qi_boost")
    _assert_equal(double_enhancement.effective_qi_value(), 23, "永久与同名临时强化作为两个来源分别生效")
    double_enhancement.set_temporary_enhancement("momentum")
    _assert_equal(double_enhancement.effective_qi_value(), 15, "同临时强化子槽新内容替换旧内容")
    _assert_equal(double_enhancement.reshape_enhancement, "qi_boost", "临时强化不替换永久强化")

    var temporary_attribute = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "forest_6"), "f3c:temporary-attribute",
        catalog.card_reshape_rules)
    temporary_attribute.set_temporary_attribute("wind")
    _assert_true(temporary_attribute.is_attribute("forest") and temporary_attribute.is_attribute("wind"), "临时属性只增加属性身份")
    _assert_equal(temporary_attribute.attribute, "forest", "临时属性不改变基础属性")
    temporary_attribute.set_temporary_attribute("fire")
    _assert_true(not temporary_attribute.is_attribute("wind") and temporary_attribute.is_attribute("fire"), "临时属性同槽替换")

    var burned = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_7"), "f3c:burned",
        catalog.card_reshape_rules)
    CardOriginServiceScript.new(catalog).apply_to_card(burned, "awakening", {})
    burned.set_enhancement("void_burst")
    burned.set_temporary_enhancement("qi_boost")
    lifecycle.apply_anomaly(burned, "buff", "qi_heat", {}, 20)
    lifecycle.apply_anomaly(burned, "debuff", "burned_out")
    _assert_equal(burned.effective_qi_value(false, {"participating": true}), 0, "燃尽最终覆盖增元、虚暴、觉醒与炽气")
    _assert_true(burned.is_card_kind("normal"), "燃尽牌仍属于普通真气")
    var burned_pair = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "f3c:burned-pair",
        catalog.card_reshape_rules)
    lifecycle.apply_anomaly(burned_pair, "debuff", "burned_out")
    _assert_equal(HandEvaluatorScript.evaluate([burned, burned_pair])["id"], "pair", "燃尽不改变牌阶或牌型识别")

    var changed = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "f3c:return-attribute",
        catalog.card_reshape_rules)
    CardOriginServiceScript.new(catalog).apply_to_card(
        changed, "attribute_change", {"attribute": "fire"})
    changed.set_enhancement("qi_boost")
    changed.set_imprint("echo")
    changed.set_temporary_enhancement("momentum")
    changed.set_temporary_attribute("mountain")
    lifecycle.apply_anomaly(changed, "mark", "return_to_origin")
    _assert_true(changed.is_attribute("wind") and not changed.is_attribute("fire"), "归元令转属恢复改造前属性识别")
    _assert_true(not changed.is_attribute("mountain"), "归元压制临时属性")
    _assert_equal(changed.effective_qi_value(), 7, "归元压制永久与临时强化")
    _assert_true(changed.origin_locked(), "归元期间本源槽仍锁定")
    changed.set_enhancement("void_burst")
    changed.set_temporary_enhancement("qi_boost")
    changed.remove_anomaly("mark", "return_to_origin")
    _assert_true(changed.is_attribute("fire") and changed.is_attribute("mountain"), "移除归元后转属与临时属性自动恢复")
    _assert_equal(changed.effective_qi_value(), 15, "移除归元后按最新永久虚暴与临时增元恢复")

    var ranked = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "forest_7"), "f3c:return-rank",
        catalog.card_reshape_rules)
    CardOriginServiceScript.new(catalog).apply_to_card(
        ranked, "rank_change", {"direction": "up"})
    _assert_equal(ranked.current_rank_order(), 8, "易阶正常物化新牌阶")
    lifecycle.apply_anomaly(ranked, "mark", "return_to_origin")
    _assert_equal(ranked.current_rank_order(), 7, "归元期间读取易阶前牌阶")
    _assert_equal(ranked.current_base_qi_value(), 7, "归元期间读取易阶前基础真气值")
    ranked.remove_anomaly("mark", "return_to_origin")
    _assert_equal(ranked.current_rank_order(), 8, "移除归元后恢复易阶结果")

    var awakened = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_5"), "f3c:return-awakening",
        catalog.card_reshape_rules)
    CardOriginServiceScript.new(catalog).apply_to_card(awakened, "awakening", {})
    _assert_equal(awakened.effective_qi_value(false, {"participating": true}), 10, "火觉醒正常生效")
    lifecycle.apply_anomaly(awakened, "mark", "return_to_origin")
    _assert_equal(awakened.effective_qi_value(false, {"participating": true}), 5, "归元压制觉醒行为")

    var start_void = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "mountain_6"), "f3c:start-void",
        catalog.card_reshape_rules)
    start_void.set_enhancement("void_burst")
    var engine = _tracked_combat_engine(null, catalog)
    engine.setup(82201, false)
    engine.player.draw_pile = [start_void]
    engine.player.hand.clear()
    engine.start_player_turn()
    _assert_true(start_void.has_anomaly("mark", "void"), "永久虚暴只在战斗开始施加虚无")
    start_void.set_enhancement("qi_boost")
    _assert_true(start_void.has_anomaly("mark", "void"), "战斗开始后替换虚暴不移除已获虚无")
    var midbattle = _card("4", "wind")
    catalog.card_reshape_rules.bind_card(midbattle)
    engine.player.hand = [midbattle]
    midbattle.set_enhancement("void_burst")
    _assert_true(not midbattle.has_anomaly("mark", "void"), "战斗中途获得虚暴本场不补发虚无")
    engine.status_system.apply_card_anomaly(midbattle, "mark", "void", {}, "测试")
    engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {"actor": engine.player})
    _assert_true(engine.player.hand.has(midbattle), "虚无不再因回合结束消散")
    _assert_true(midbattle.has_anomaly("mark", "void"), "回合结束保留虚无内容")
    var void_discard: Dictionary = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", midbattle, "explicit_discard")
    _assert_true(void_discard.get("dispersed", false), "虚无在成功明确弃置响应后消散")
    _assert_true(engine.player.temporarily_removed_cards.has(midbattle), "虚无明确弃置后进入临时移除区")
    _assert_true(not engine.player.discard_pile.has(midbattle), "虚无消散不进入弃牌堆")

func _test_f2d2_opportunity_freeze_and_progress_sync() -> void:
    var first = _card("7", "wind")
    var second = _card("7", "forest")
    first.set_enhancement("opportunity")
    second.set_enhancement("opportunity")
    var engine = _engine_with_hand([first, second], [], 82301)
    engine.sequence_book.configure({"pair": []})
    engine.player.experience = 5
    var preview_state: int = engine.rng.state
    var pure_preview: Dictionary = engine.preview(_ids([first, second]))
    var repeated_preview: Dictionary = engine.preview(_ids([first, second]))
    _assert_equal(repeated_preview, pure_preview, "重复预览保持完全一致")
    _assert_equal(engine.rng.state, preview_state, "重复预览不推进随机源")
    _assert_equal(engine.player.experience, 5, "重复预览不增加历练")

    var pattern := [true, false, false, true]
    var seed := _find_opportunity_seed(pattern)
    _assert_true(seed > 0, "找到机缘两张牌独立判定的确定性种子")
    engine.rng.seed = seed
    var result: Dictionary = engine.confirm_play(_ids([first, second]))
    _assert_true(result.get("success", false), "机缘牌正式确认行动成功")
    var frozen: Dictionary = result["preview"].get("reshape_action_results", {})
    _assert_equal(frozen[first.id]["multiplier_success"], true, "第一张机缘倍率判定成功")
    _assert_equal(frozen[first.id]["experience_success"], false, "第一张机缘历练判定失败")
    _assert_equal(frozen[second.id]["multiplier_success"], false, "第二张机缘倍率判定失败")
    _assert_equal(frozen[second.id]["experience_success"], true, "第二张机缘历练判定成功")
    _assert_equal(engine.player.experience, 25, "多张机缘历练结果独立累加")
    var expected_values: Dictionary = PowerCalculatorScript.apply_frozen_card_multiplier_bonus(
        pure_preview["values"], 1)
    for field in [
        "card_multiplier_bonus", "technique_multiplier",
        "initial_power", "pre_momentum_power", "technique_value"]:
        _assert_equal(
            result["preview"]["values"][field],
            expected_values[field],
            "机缘冻结后纯函数更新 %s" % field)
    _assert_equal(
        result["preview"]["values"]["baseline_value"],
        pure_preview["values"]["baseline_value"],
        "机缘不修改 baseline_value")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "战斗历练同步测试载入内容目录")
    var growth = GrowthInventoryScript.new(catalog)
    growth.experience = 7
    var battle_session: BattleSession = BattleSessionScript.new(
        _tracked_combat_engine(null, catalog))
    _assert_true(
        battle_session.setup_battle(
            {"content_seed": 82304}, growth.to_progress_snapshot()),
        "带历练的本局进度建立正式战斗")
    _assert_equal(battle_session.engine.player.experience, 7, "战斗装配读取本局绝对历练")
    battle_session.engine.effect_ports.gain_battle_experience(
        battle_session.engine.player, 20)
    var captured: RunProgressSnapshot = battle_session.player_progress_snapshot()
    _assert_equal(captured.experience, 27, "战斗快照捕获奖励后的绝对历练")
    growth.apply_progress_snapshot(captured)
    growth.apply_progress_snapshot(captured)
    _assert_equal(growth.experience, 27, "同一战斗历练快照同步两次不重复增加")
    var old_snapshot: RunProgressSnapshot = RunProgressSnapshotScript.from_dict({
        "life": 100,
        "max_life": 100,
    })
    growth.experience = 11
    growth.apply_progress_snapshot(old_snapshot)
    _assert_equal(growth.experience, 11, "旧快照不带 experience 时保持现有历练")

func _test_f2e1_formal_imprint_runtime_and_persistence() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F2E1 正式印记测试载入内容目录")
    var imprint_ids: Array = catalog.all_of("imprint").map(
        func(value): return str(value.get("id", "")))
    imprint_ids.sort()
    _assert_equal(
        imprint_ids,
        ["alchemy", "echo", "enlightenment", "innate"],
        "正式印记只包含悟道、化丹、先天与回响")

    var invalid_missing := _catalog_definitions(catalog)
    invalid_missing["card_states"]["imprints"].remove_at(0)
    var missing_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_catalog.load_from_definitions(invalid_missing),
        "缺少正式印记时内容加载失败")
    _assert_true(
        _array_contains_text(missing_catalog.errors, "缺少定义 enlightenment"),
        "缺失印记错误准确报告 ID")

    var invalid_mapping := _catalog_definitions(catalog)
    invalid_mapping["card_states"]["imprints"][0]["behaviors"][0]["mapping"][
        "pair"] = "zengyuan_pill"
    var mapping_catalog = ContentCatalogScript.new()
    _assert_true(
        not mapping_catalog.load_from_definitions(invalid_mapping),
        "悟道映射到非心得时启动校验失败")
    _assert_true(
        _array_contains_text(mapping_catalog.errors, "pair")
        and _array_contains_text(mapping_catalog.errors, "不是心得"),
        "错误悟道映射报告准确内容路径和类型")

    var unknown_mapping := _catalog_definitions(catalog)
    unknown_mapping["card_states"]["imprints"][0]["behaviors"][0]["mapping"][
        "pair"] = "missing_insight"
    unknown_mapping["card_states"]["imprints"][0]["behaviors"][0]["mapping"][
        "flush"] = "pair_insight"
    var unknown_mapping_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_mapping_catalog.load_from_definitions(unknown_mapping),
        "悟道未知消耗品或牌型在启动期失败")
    _assert_true(
        _array_contains_text(unknown_mapping_catalog.errors, "missing_insight")
        and _array_contains_text(unknown_mapping_catalog.errors, "未知牌型 flush"),
        "悟道未知引用分别具名报告")

    var invalid_kind := _catalog_definitions(catalog)
    invalid_kind["card_states"]["imprints"][1]["behaviors"][0]["kind"] = "relic"
    var kind_catalog = ContentCatalogScript.new()
    _assert_true(
        not kind_catalog.load_from_definitions(invalid_kind),
        "化丹引用空内容类别时启动校验失败")
    _assert_true(
        _array_contains_text(kind_catalog.errors, "kind=relic"),
        "化丹错误 kind 具名报告")

    var invalid_opening := _catalog_definitions(catalog)
    invalid_opening["card_states"]["imprints"][2]["behaviors"][0]["count"] = 1
    var opening_catalog = ContentCatalogScript.new()
    _assert_true(
        not opening_catalog.load_from_definitions(invalid_opening),
        "先天行为携带无关参数时启动校验失败")
    _assert_true(
        _array_contains_text(opening_catalog.errors, "不接受额外参数"),
        "先天额外参数错误具名报告")

    var extra_imprint := _catalog_definitions(catalog)
    extra_imprint["card_states"]["imprints"].append({
        "id": "red", "name": "旧赤印"})
    var extra_catalog = ContentCatalogScript.new()
    _assert_true(
        not extra_catalog.load_from_definitions(extra_imprint),
        "正式印记集合继续拒绝旧赤印")

    var normal_bottom = _card("2", "wind")
    var innate_second = _card("3", "forest")
    var normal_top = _card("4", "fire")
    var innate_first = _card("5", "mountain")
    innate_first.set_imprint("innate")
    innate_second.set_imprint("innate")
    var opening_engine = _engine_with_hand(
        [], [normal_bottom, innate_second, normal_top, innate_first], 82401)
    opening_engine.player.hand_limit = 4
    var opening_drawn: Array = opening_engine.start_player_turn()
    _assert_equal(opening_drawn.size(), 4, "先天不足手牌上限时由普通牌补足")
    _assert_equal(
        _ids(opening_drawn).slice(0, 2),
        [innate_first.id, innate_second.id],
        "多张先天按洗牌后原抽取顺序优先进入起始手牌")

    var many_innates: Array = []
    for rank in ["2", "3", "4", "5", "6"]:
        var innate_card = _card(rank, "wind")
        innate_card.set_imprint("innate")
        many_innates.append(innate_card)
    var overflow_normal = _card("A", "forest")
    var overflow_engine = _engine_with_hand(
        [], [overflow_normal] + many_innates.duplicate(), 82402)
    overflow_engine.player.hand_limit = 3
    var overflow_drawn: Array = overflow_engine.start_player_turn()
    _assert_equal(overflow_drawn.size(), 3, "先天超过上限时只抽到手牌上限")
    _assert_true(
        overflow_engine.player.draw_pile.back().reshape_imprint == "innate",
        "未抽到的先天继续留在牌库顶")
    overflow_engine.end_player_turn()
    var second_turn_innate = _card("7", "wind")
    second_turn_innate.set_imprint("innate")
    var second_turn_normal = _card("8", "forest")
    overflow_engine.player.hand.clear()
    overflow_engine.player.hand_limit = 1
    overflow_engine.player.draw_pile = [second_turn_innate, second_turn_normal]
    var second_turn_drawn: Array = overflow_engine.start_player_turn()
    _assert_equal(
        second_turn_drawn[0].id,
        second_turn_normal.id,
        "第二回合不重新执行先天置顶")

    var pair_cards := [_card("7", "wind"), _card("7", "forest")]
    var enlightenment_hand = _card("3", "fire")
    var enlightenment_draw = _card("4", "mountain")
    enlightenment_hand.set_imprint("enlightenment")
    enlightenment_draw.set_imprint("enlightenment")
    var enlightenment_engine = _engine_with_hand(
        pair_cards + [enlightenment_hand], [enlightenment_draw], 82403)
    enlightenment_engine.repository.techniques["f2e1_pair_probe"] = {
        "id": "f2e1_pair_probe",
        "name": "悟道对子探针",
        "pool": "pair",
        "effects": [],
    }
    enlightenment_engine.sequence_book.configure({
        "pair": ["f2e1_pair_probe"],
    })
    var pair_result: Dictionary = enlightenment_engine.confirm_play(_ids(pair_cards))
    _assert_true(pair_result.get("success", false), "成功对子出招建立悟道记录")
    enlightenment_engine.repository.techniques["f2e1_failed_gate"] = {
        "id": "f2e1_failed_gate",
        "name": "悟道失败条件探针",
        "pool": "high",
        "condition": {"pure_attribute": "wind"},
        "effects": [{"op": "defense", "amount": 1}],
    }
    var failed_card = _card("9", "fire")
    enlightenment_engine.player.hand.append(failed_card)
    enlightenment_engine.actions_available = 1
    enlightenment_engine.sequence_book.configure({
        "high_card": ["f2e1_failed_gate"],
    })
    var failed_result: Dictionary = enlightenment_engine.confirm_play([failed_card.id])
    _assert_true(failed_result.get("success", false), "条件失败组仍完成行动")
    _assert_true(
        not failed_result.get("technique_triggered", true),
        "条件失败组不覆盖最后成功牌型")
    enlightenment_engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [enlightenment_engine.player, enlightenment_engine.enemy],
            "winner": enlightenment_engine.player,
        })
    _assert_equal(
        enlightenment_engine.player.consumable_ids,
        ["pair_insight"],
        "最后成功对子为手牌中的悟道印生成 pair_insight")
    _assert_equal(
        enlightenment_engine.player.consumable_ids.size(),
        1,
        "抽牌堆中的悟道印不触发")

    var cooperation_main := [
        _card("6", "wind"), _card("6", "forest"), _card("6", "fire")]
    var cooperation_cards := [_card("4", "wind"), _card("4", "mountain")]
    var cooperation_mark = _card("A", "forest")
    cooperation_mark.set_imprint("enlightenment")
    var cooperation_engine = _engine_with_hand(
        cooperation_main + cooperation_cards + [cooperation_mark], [], 82404)
    cooperation_engine.repository.techniques["f2e1_cooperation_probe"] = {
        "id": "f2e1_cooperation_probe",
        "name": "悟道协同探针",
        "pool": "three",
        "cooperation": {
            "hand_id": "pair",
            "max_groups": 1,
            "power_rule": "shared_half",
            "post_commit": {"destination": "own_discard"},
        },
        "effects": [],
    }
    cooperation_engine.repository.techniques["f2e1_pair_probe"] = {
        "id": "f2e1_pair_probe",
        "name": "悟道对子探针",
        "pool": "pair",
        "effects": [],
    }
    cooperation_engine.sequence_book.configure({
        "three_kind": ["f2e1_cooperation_probe"],
        "pair": ["f2e1_pair_probe"],
    })
    var cooperation_result: Dictionary = cooperation_engine.confirm_play(
        _ids(cooperation_main), _ids(cooperation_cards))
    _assert_true(cooperation_result.get("success", false), "悟道记录覆盖协同组成功路径")
    _assert_equal(
        cooperation_engine.card_reshape_runtime.last_successful_hand_by_side[
            cooperation_engine.player.owner_id],
        "pair",
        "后完成的协同对子成为最后成功牌型")

    var no_success_mark = _card("2", "wind")
    no_success_mark.set_imprint("enlightenment")
    var no_success_engine = _engine_with_hand([no_success_mark], [], 82405)
    no_success_engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [no_success_engine.player, no_success_engine.enemy],
            "winner": no_success_engine.player,
        })
    _assert_true(
        no_success_engine.player.consumable_ids.is_empty(),
        "没有成功出招记录时悟道印不生成心得")

    var full_mark = _card("2", "forest")
    full_mark.set_imprint("enlightenment")
    var full_engine = _engine_with_hand([full_mark], [], 82406)
    full_engine.player.configure_consumables(["a", "b", "c"])
    full_engine.card_reshape_runtime.last_successful_hand_by_side[
        full_engine.player.owner_id] = "pair"
    full_engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [full_engine.player, full_engine.enemy],
            "winner": full_engine.player,
        })
    _assert_equal(
        full_engine.player.consumable_ids,
        ["a", "b", "c"],
        "悟道印满三格时不生成也不覆盖")

    var alchemy = _card("5", "fire")
    alchemy.set_imprint("alchemy")
    var alchemy_engine = _engine_with_hand([alchemy], [], 82407)
    var alchemy_discard: Dictionary = alchemy_engine.player.card_zone_service.move_card(
        alchemy_engine.player, "hand", "discard_pile", alchemy, "explicit_discard")
    _assert_true(alchemy_discard.get("success", false), "化丹牌成功明确弃掉")
    _assert_equal(alchemy_engine.player.consumable_ids.size(), 1, "化丹生成一种丹药")
    _assert_equal(
        catalog.get_by_id(
            "consumable", alchemy_engine.player.consumable_ids[0]).get("kind", ""),
        "pill",
        "化丹从完整正式 pill 池生成当前丹药")

    var normal_alchemy = _card("6", "fire")
    normal_alchemy.set_imprint("alchemy")
    var normal_engine = _engine_with_hand([normal_alchemy], [], 82408)
    normal_engine.player.card_zone_service.move_card(
        normal_engine.player, "hand", "discard_pile", normal_alchemy, "normal_play")
    _assert_true(normal_engine.player.consumable_ids.is_empty(), "正常打出不触发化丹")

    var void_alchemy = _card("7", "fire")
    void_alchemy.set_imprint("alchemy")
    void_alchemy.set_enhancement("void_burst")
    var void_engine = _engine_with_hand([void_alchemy], [], 82409)
    void_engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
        "actor": void_engine.player,
        "actors": [void_engine.player],
    })
    _assert_true(void_engine.player.consumable_ids.is_empty(), "虚无消散不触发化丹")

    var rock_alchemy = _card("8", "mountain")
    rock_alchemy.set_imprint("alchemy")
    rock_alchemy.set_enhancement("rock_solid")
    var rock_engine = _engine_with_hand([rock_alchemy], [], 82410)
    var rejected: Dictionary = rock_engine.player.card_zone_service.move_card(
        rock_engine.player, "hand", "discard_pile", rock_alchemy, "explicit_discard")
    _assert_true(not rejected.get("success", false), "磐石拒绝明确弃牌")
    _assert_true(rock_engine.player.consumable_ids.is_empty(), "未成功弃牌不触发化丹")

    var returning_alchemy = _card("9", "wind")
    returning_alchemy.set_imprint("alchemy")
    var returning_engine = _engine_with_hand([returning_alchemy], [], 82411)
    returning_engine.status_system.apply_card_anomaly(
        returning_alchemy, "mark", "regroup", {}, "化丹重聚测试")
    returning_engine.player.card_zone_service.move_card(
        returning_engine.player,
        "hand",
        "discard_pile",
        returning_alchemy,
        "explicit_discard")
    _assert_equal(returning_engine.player.consumable_ids.size(), 1, "回风改置后化丹仍生成一种丹药")
    _assert_equal(
        catalog.get_by_id(
            "consumable", returning_engine.player.consumable_ids[0]).get("kind", ""),
        "pill",
        "回风已改置牌区后化丹仍从正式池生成丹药")
    _assert_true(
        returning_engine.player.draw_pile.has(returning_alchemy),
        "化丹结算后仍保留重聚洗回牌库的结果")

    var full_alchemy = _card("10", "fire")
    full_alchemy.set_imprint("alchemy")
    var full_alchemy_engine = _engine_with_hand([full_alchemy], [], 82412)
    full_alchemy_engine.player.configure_consumables(["a", "b", "c"])
    var full_rng_state: int = full_alchemy_engine.rng.state
    full_alchemy_engine.player.card_zone_service.move_card(
        full_alchemy_engine.player,
        "hand",
        "discard_pile",
        full_alchemy,
        "explicit_discard")
    _assert_equal(full_alchemy_engine.rng.state, full_rng_state, "化丹满栏不推进 RNG")
    _assert_equal(
        full_alchemy_engine.player.consumable_ids,
        ["a", "b", "c"],
        "化丹满栏不覆盖已有消耗品")

    var empty_alchemy = _card("J", "fire")
    empty_alchemy.set_imprint("alchemy")
    var empty_engine = _engine_with_hand([empty_alchemy], [], 82413)
    for pill_id in empty_engine.consumable_repository.ids_by_kind("pill"):
        empty_engine.consumable_repository.consumables.erase(pill_id)
    var empty_rng_state: int = empty_engine.rng.state
    empty_engine.player.card_zone_service.move_card(
        empty_engine.player,
        "hand",
        "discard_pile",
        empty_alchemy,
        "explicit_discard")
    _assert_equal(empty_engine.rng.state, empty_rng_state, "化丹空候选池不推进 RNG")
    _assert_true(empty_engine.player.consumable_ids.is_empty(), "化丹空候选池不生成")

    var workshop = CardWorkshopServiceScript.new()
    var growth = GrowthInventoryScript.new(catalog)
    growth.run_deck.reset_standard("f2e1-sync")
    workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_2"], "imprint", "alchemy")
    workshop.apply_run_card_reshape(
        growth.run_deck, ["forest_3"], "imprint", "enlightenment")
    workshop.apply_run_card_reshape(
        growth.run_deck, ["fire_4"], "imprint", "innate")
    var battle_session: BattleSession = BattleSessionScript.new(
        _tracked_combat_engine(null, catalog))
    _assert_true(
        battle_session.setup_battle(
            {"content_seed": 82414}, growth.to_progress_snapshot()),
        "三种印记本局牌组装配进战斗")
    var alchemy_battle_card = null
    var enlightenment_battle_card = null
    for card in battle_session.engine.player.all_zone_cards():
        if card.id == "wind_2":
            alchemy_battle_card = card
        elif card.id == "forest_3":
            enlightenment_battle_card = card
    for card in [alchemy_battle_card, enlightenment_battle_card]:
        var location: Dictionary = battle_session.engine.player.card_zone_service \
            .find_active_location(battle_session.engine.player, str(card.id))
        if str(location.get("zone", "")) != "hand":
            battle_session.engine.player.card_zone_service.move_card(
                battle_session.engine.player,
                str(location["zone"]),
                "hand",
                card,
                "test_setup")
    battle_session.engine.player.card_zone_service.move_card(
        battle_session.engine.player,
        "hand",
        "discard_pile",
        alchemy_battle_card,
        "explicit_discard")
    _assert_equal(battle_session.engine.player.consumable_ids.size(), 1, "战斗同步测试化丹生成一种丹药")
    var battle_alchemy_id := str(
        battle_session.engine.player.consumable_ids[0])
    _assert_equal(
        catalog.get_by_id("consumable", battle_alchemy_id).get("kind", ""),
        "pill",
        "战斗同步测试化丹奖励来自完整 pill 池")
    battle_session.engine.card_reshape_runtime.last_successful_hand_by_side[
        battle_session.engine.player.owner_id] = "pair"
    battle_session.engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [battle_session.engine.player, battle_session.engine.enemy],
            "winner": battle_session.engine.player,
        })
    var captured: RunProgressSnapshot = battle_session.player_progress_snapshot()
    _assert_equal(
        captured.consumable_ids,
        [battle_alchemy_id, "pair_insight"],
        "悟道与化丹奖励进入玩家战斗进度快照")
    growth.apply_progress_snapshot(captured)
    growth.apply_progress_snapshot(captured)
    _assert_equal(
        growth.consumable_ids,
        [battle_alchemy_id, "pair_insight"],
        "同一绝对消耗品快照同步两次不重复生成")
    for imprint_spec in [
        ["wind_2", "alchemy"],
        ["forest_3", "enlightenment"],
        ["fire_4", "innate"],
    ]:
        _assert_equal(
            growth.run_deck.card_data(imprint_spec[0])["reshapes"]["imprint"],
            imprint_spec[1],
            "战斗同步保留 %s" % imprint_spec[1])

    var save_session = RunSessionScript.new(null, null, null, null, catalog)
    _assert_true(
        save_session.execute({"type": "setup_run", "seed": 82415}).success,
        "三印记存档测试建立本局")
    for imprint_spec in [
        ["wind_2", "alchemy"],
        ["forest_3", "enlightenment"],
        ["fire_4", "innate"],
    ]:
        workshop.apply_run_card_reshape(
            save_session.growth.run_deck,
            [imprint_spec[0]],
            "imprint",
            imprint_spec[1])
    var restored: Dictionary = RunSaveDataScript.new().capture(
        save_session).restore_session(catalog)
    _assert_true(restored.get("success", false), "三种印记存档后可以读回")
    for imprint_spec in [
        ["wind_2", "alchemy"],
        ["forest_3", "enlightenment"],
        ["fire_4", "innate"],
    ]:
        _assert_equal(
            restored["run_session"].growth.run_deck.card_data(
                imprint_spec[0])["reshapes"]["imprint"],
            imprint_spec[1],
            "存档读档保留 %s" % imprint_spec[1])
    var no_imprint_deck = RunDeckScript.new(catalog)
    no_imprint_deck.reset_standard("f2e1-old")
    var no_imprint_snapshot: Dictionary = no_imprint_deck.to_snapshot()
    _assert_equal(
        RunDeckScript.new(catalog).restore_snapshot(no_imprint_snapshot),
        [],
        "不含印记的旧本局牌组快照继续兼容")

func _test_standard_deck() -> void:
    var deck := DeckFactoryScript.create_standard_deck()
    _assert_equal(deck.size(), 52, "基础牌组共 52 张")
    var attribute_counts := {"wind": 0, "forest": 0, "fire": 0, "mountain": 0}
    var face_values := {}
    var rank_groups: Dictionary = {}
    for card in deck:
        attribute_counts[card.attribute] += 1
        if not rank_groups.has(card.rank_order):
            rank_groups[card.rank_order] = []
        rank_groups[card.rank_order].append(card)
        _assert_equal(card.definition_id, card.id, "基础牌兼容ID同时保留定义身份")
        if card.attribute == "wind":
            face_values[card.rank_name] = card.qi_value
    for attribute in attribute_counts:
        _assert_equal(attribute_counts[attribute], 13, "%s 属性 13 张" % attribute)
    _assert_equal(face_values["J"], 11, "J 真气值")
    _assert_equal(face_values["Q"], 11, "Q 真气值")
    _assert_equal(face_values["K"], 11, "K 真气值")
    _assert_equal(face_values["A"], 12, "A 真气值")
    for rank_order in rank_groups:
        _assert_equal(rank_groups[rank_order].size(), 4, "标准牌组每个牌阶只有四张真气")
        _assert_equal(
            HandEvaluatorScript.evaluate(rank_groups[rank_order])["id"],
            "four_kind",
            "标准牌组任一同牌阶组最多形成四条")

func _test_pool_structure_and_turn_draw_rules() -> void:
    var engine = _tracked_combat_engine()
    engine.setup(7, false)
    var unique_pools: Dictionary = {}
    for hand_id in engine.repository.pool_membership:
        for pool_id in engine.repository.pool_membership[hand_id]:
            unique_pools[pool_id] = true
    _assert_equal(unique_pools.size(), 5, "五类共用功法池")
    _assert_equal(
        engine.repository.pool_membership,
        {
            "high_card": ["high"],
            "pair": ["pair"],
            "two_pair": ["pair"],
            "three_kind": ["three"],
            "straight": ["straight"],
            "full_house": ["pair", "three"],
            "four_kind": ["bomb"],
            "five_kind": ["bomb"],
        },
        "八种精确牌型的功法池成员资格与权威表完全一致")
    _assert_equal(engine.sequence_book.sequences["straight"], [], "顺子正式序列合法为空")
    _assert_equal(engine.sequence_book.sequences["five_kind"], [], "五条使用独立空初始序列")
    engine.sequence_book.configure({"pair": ["a", "b"], "two_pair": ["a", "b"]})
    engine.sequence_book.advance("pair")
    _assert_equal(engine.sequence_book.position("pair"), 1, "一对序列独立推进")
    _assert_equal(engine.sequence_book.position("two_pair"), 0, "两对序列不受一对推进影响")
    var drawn := engine.start_player_turn()
    _assert_equal(drawn.size(), 8, "回合开始补至基础手牌上限 8")
    _assert_equal(engine.player.hand.size(), 8, "补牌后手牌为 8")
    engine.player.discard_pile = engine.player.hand.slice(0, 3)
    engine.player.hand.clear()
    engine.player.draw_pile.clear()
    engine.round_ended = true
    var empty_draw := engine.start_player_turn()
    _assert_equal(empty_draw.size(), 0, "牌库为空不从弃牌堆自动洗回")
    _assert_equal(engine.player.discard_pile.size(), 3, "弃牌堆保持不变")
    _assert_equal(engine.preview([])["valid"], false, "不能选择 0 张")
    engine.player.hand = [_card("2"), _card("3"), _card("4"), _card("5"), _card("6"), _card("7")]
    _assert_equal(engine.preview(_ids(engine.player.hand))["valid"], false, "不能选择超过 5 张")

func _test_active_hand_types_and_same_attribute_rules() -> void:
    var five_kind_cards := [
        _card("8", "wind"), _card("8", "forest"), _card("8", "fire"),
        _card("8", "mountain"), _card("8", "wind"),
    ]
    var cases := [
        {"id": "high_card", "cards": [_card("A"), _card("7", "forest"), _card("3", "fire")], "count": 1, "sum": 12},
        {"id": "pair", "cards": [_card("7"), _card("7", "forest"), _card("A", "fire"), _card("3")], "count": 2, "sum": 14},
        {"id": "two_pair", "cards": [_card("9"), _card("9", "forest"), _card("4"), _card("4", "fire"), _card("A")], "count": 4, "sum": 26},
        {"id": "three_kind", "cards": [_card("6"), _card("6", "forest"), _card("6", "fire"), _card("A")], "count": 3, "sum": 18},
        {"id": "straight", "cards": [_card("A"), _card("2", "forest"), _card("3", "fire"), _card("4", "mountain"), _card("5")], "count": 5, "sum": 26},
        {"id": "full_house", "cards": [_card("7"), _card("7", "forest"), _card("7", "fire"), _card("3"), _card("3", "forest")], "count": 5, "sum": 27},
        {"id": "four_kind", "cards": [_card("8"), _card("8", "forest"), _card("8", "fire"), _card("8", "mountain"), _card("A")], "count": 4, "sum": 32},
        {"id": "five_kind", "cards": five_kind_cards, "count": 5, "sum": 40},
    ]
    for test_case in cases:
        var result := HandEvaluatorScript.evaluate(test_case["cards"])
        _assert_equal(result["id"], test_case["id"], "识别 %s" % test_case["id"])
        _assert_equal(result["contributing"].size(), test_case["count"], "%s 参与张数" % test_case["id"])
        var qi_sum := 0
        for card in result["contributing"]:
            qi_sum += card.qi_value
        _assert_equal(qi_sum, test_case["sum"], "%s 参与真气值" % test_case["id"])
    var jq := HandEvaluatorScript.evaluate([_card("J"), _card("Q")])
    _assert_equal(jq["id"], "high_card", "J/Q 真气值相同但不成对")
    var same_attribute_cards := [
        _card("2", "fire"), _card("3", "fire"), _card("4", "fire"),
        _card("5", "fire"), _card("6", "fire"),
    ]
    var same_attribute_straight := HandEvaluatorScript.evaluate(same_attribute_cards)
    _assert_equal(same_attribute_straight["id"], "straight", "同属性顺子仍只识别为顺子")
    _assert_true(not same_attribute_straight.has("multiplier"), "牌型结果不再携带固定倍率")
    _assert_true(not HandEvaluatorScript.HANDS["straight"].has("multiplier"), "牌型定义只保留名称与强度")
    _assert_true(not HandEvaluatorScript.HANDS.has("flush"), "正式牌型表不再包含同花")
    _assert_true(not HandEvaluatorScript.HANDS.has("straight_flush"), "正式牌型表不再包含同花顺")

    var four_kind_result := HandEvaluatorScript.evaluate(five_kind_cards.slice(0, 4))
    var five_kind_result := HandEvaluatorScript.evaluate(five_kind_cards)
    _assert_true(not five_kind_result.has("multiplier"), "五条不再携带旧十二倍倍率")
    _assert_true(
        five_kind_result["strength"] > four_kind_result["strength"],
        "五条强度高于四条")
    var four_kind_values := PowerCalculatorScript.calculate(four_kind_result)
    var five_kind_values := PowerCalculatorScript.calculate(five_kind_result)
    _assert_true(
        is_equal_approx(
            float(five_kind_values["baseline_value"]) / float(four_kind_values["baseline_value"]),
            5.0 / 4.0),
        "同牌阶五条基准值只按五张贡献与四张贡献之比变化")

    var best_source := five_kind_cards + [_card("A", "forest")]
    var best_candidates := HandEvaluatorScript.evaluate_best_candidates(best_source)
    _assert_equal(best_candidates.size(), 1, "五条稳定排除同源四条候选")
    _assert_equal(HandEvaluatorScript.evaluate_best(best_source)["id"], "five_kind", "五条稳定成为最高牌型")

    var same_attribute_five := [
        _card("7", "wind"), _card("7", "wind"), _card("7", "wind"),
        _card("7", "wind"), _card("7", "wind"),
    ]
    var five_engine = _engine_with_hand(same_attribute_five)
    var same_attribute_five_preview: Dictionary = five_engine.preview(_ids(same_attribute_five))
    _assert_equal(same_attribute_five_preview["hand"]["id"], "five_kind", "同属性五张同牌阶仍识别为五条")
    _assert_true(not same_attribute_five_preview["values"].has("fixed_multiplier"), "固定牌型倍率字段完全退出")
    _assert_equal(same_attribute_five_preview["values"]["attribute_concentration"], 5, "同属性五条属性集中数为五")
    _assert_equal(same_attribute_five_preview["values"]["baseline_value"], 35, "牌型基准值只等于贡献 C")
    _assert_equal(same_attribute_five_preview["values"]["direct_power_percent"], 0, "旧同气百分比增幅彻底退出")

func _test_same_qi_rule_and_action_wiring() -> void:
    var identity := CardIdentityPolicyScript.new()
    for card_count in range(1, 6):
        var cards: Array = []
        for index in range(card_count):
            cards.append(_card(str(index + 2), "wind"))
        var result: Dictionary = SameQiRuleScript.analyze(
            cards, identity, {"source_kind": "same_qi_test"})
        _assert_true(result.get("success", false), "%d 张同气规则查询成功" % card_count)
        _assert_true(result.get("qualified", false), "%d 张风真气构成同气" % card_count)
        _assert_equal(
            result.get("gain", -1), card_count - 1,
            "%d 张同属性真气按组大小减一获得同气" % card_count)
        _assert_equal(result.get("common_attributes", []), ["wind"], "共同属性稳定排序")
        _assert_true(not result.has("power_amp_percent"), "旧同气百分比字段已退出")

    var mismatch := SameQiRuleScript.analyze(
        [_card("2", "wind"), _card("3", "fire")], identity)
    _assert_true(not mismatch.get("qualified", true), "属性不统一不构成同气")
    _assert_equal(mismatch.get("gain", -1), 0, "风火各一张不获得同气")
    var split_gain := SameQiRuleScript.analyze([
        _card("2", "wind"), _card("3", "wind"), _card("4", "wind"),
        _card("5", "forest"), _card("6", "forest")], identity)
    _assert_equal(split_gain.get("gain", -1), 3, "3风+2林确定获得3点同气")
    var four_directions := SameQiRuleScript.analyze([
        _card("2", "wind"), _card("3", "forest"),
        _card("4", "fire"), _card("5", "mountain")], identity)
    _assert_equal(four_directions.get("gain", -1), 0, "风林火山各一张获得零同气")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "同气混元与临时属性测试载入内容")
    var mixed = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_5"), "same-qi:hunyuan",
        catalog.card_reshape_rules)
    mixed.set_enhancement("hunyuan")
    var mixed_result := SameQiRuleScript.analyze(
        [_card("2", "wind"), mixed], identity)
    _assert_true(mixed_result.get("qualified", false), "风牌与混元构成同气")
    _assert_equal(mixed_result.get("common_attributes", []), ["wind"], "混元保留正确共同属性")
    _assert_equal(mixed_result.get("gain", -1), 1, "混元只分配到一个最优属性组")
    var mixed_pair_card = _card("5", "wind")
    var mixed_pair := HandEvaluatorScript.evaluate(
        [mixed_pair_card, mixed], null, identity)
    var mixed_power := PowerCalculatorScript.calculate(
        mixed_pair, {}, Callable(), identity)
    _assert_equal(mixed_power["attribute_concentration"], 2, "混元参与各属性候选但最大集中数只取一次")

    var temporary = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "forest_6"), "same-qi:temporary",
        catalog.card_reshape_rules)
    temporary.set_temporary_attribute("wind")
    var temporary_result := SameQiRuleScript.analyze(
        [_card("3", "wind"), temporary], identity)
    _assert_true(temporary_result.get("qualified", false), "临时属性参与同气判断")
    _assert_equal(temporary_result.get("common_attributes", []), ["wind"], "临时属性进入共同属性集合")

    var overlap_cards := [
        _card("4", "wind"), _card("5", "forest"), _card("6", "fire")]
    var overlap_identity := CardIdentityPolicyScript.new()
    overlap_identity.register_provider(
        func(card, _context):
            var additions := {
                overlap_cards[0].id: ["forest"],
                overlap_cards[1].id: ["fire"],
                overlap_cards[2].id: ["wind"],
            }
            return {"additional_effective_attributes": additions.get(card.id, [])},
        "same_qi_pairwise_overlap", 10)
    var overlap_result := SameQiRuleScript.analyze(
        overlap_cards, overlap_identity)
    _assert_true(not overlap_result.get("qualified", true), "两两相交但全体交集为空不构成同气")
    _assert_equal(overlap_result.get("common_attributes", ["unexpected"]), [], "全体交集严格为空")
    var overlap_repeat := SameQiRuleScript.analyze(overlap_cards, overlap_identity)
    _assert_equal(overlap_repeat.get("assignments", {}), overlap_result.get("assignments", {}), "多属性最优分组稳定")
    _assert_equal(overlap_repeat.get("source_fingerprint", ""), overlap_result.get("source_fingerprint", "x"), "相同输入重复查询 fingerprint 一致")
    _assert_equal(overlap_result.get("card_ids", []).size(), 3, "多属性实体牌没有重复计数")

    var zero_wind = _card("7", "wind")
    zero_wind.qi_value = 0
    var zero_result := SameQiRuleScript.analyze(
        [zero_wind, _card("8", "fire")], identity)
    _assert_true(not zero_result.get("qualified", true), "零有效值真气仍参与属性判断")
    _assert_equal(zero_result.get("card_count", 0), 2, "零有效值真气仍计入投入张数")

    var failed_identity := CardIdentityPolicyScript.new()
    failed_identity.register_provider(
        func(_card_value, _context): return {"success": false, "reason": "Fake 身份失败"},
        "same_qi_identity_failure", 10)
    var failed_result := SameQiRuleScript.analyze(
        [_card("9", "wind")], failed_identity)
    _assert_true(not failed_result.get("success", true), "身份查询失败返回结构化失败")
    _assert_true(str(failed_result.get("reason", "")).contains("Fake 身份失败"), "身份失败原因不被静默吞掉")

    var high_cards := [
        _card("A", "fire"), _card("7", "fire"), _card("4", "fire")]
    var high_engine = _engine_with_hand(high_cards)
    var high_same_qi_before: int = int(high_engine.player.same_qi_value)
    var high_history_before: int = high_engine.trigger_queue.history.size()
    var high_preview: Dictionary = high_engine.preview(_ids(high_cards))
    _assert_equal(high_preview["hand"]["id"], "high_card", "高牌额外投入仍只识别高牌")
    _assert_equal(high_preview["hand"]["contributing"].size(), 1, "高牌只有最高牌参与基础贡献")
    _assert_equal(high_preview["same_qi"]["card_count"], 3, "高牌非贡献牌计入同气投入")
    _assert_equal(high_preview["same_qi_gain"], 2, "高牌额外投入计入行动同气收益")
    _assert_equal(high_preview["values"]["attribute_concentration"], 1, "高牌额外投入不进入属性集中 N")
    _assert_equal(high_preview["values"]["direct_power_percent"], 0, "旧同气百分比不再进入功法值")
    _assert_equal(high_engine.player.same_qi_value, high_same_qi_before, "纯预览不修改同气槽")
    _assert_equal(high_engine.trigger_queue.history.size(), high_history_before, "纯预览不写战斗历史")
    var preview_power := int(high_preview["values"]["technique_value"])
    var preview_n := int(high_preview["values"]["attribute_concentration"])
    var recalculated: Dictionary = high_engine.action_preview_service.recalculate_confirmed_power(
        high_engine.player, high_engine.enemy, high_preview, "same-qi-recalculate")
    _assert_true(recalculated.get("success", false), "正式确认功法值重算成功")
    _assert_equal(high_preview["values"]["technique_value"], preview_power, "正式重算功法值稳定")
    _assert_equal(high_preview["values"]["attribute_concentration"], preview_n, "正式重算不改变 N")

    var split_main := [_card("6", "wind"), _card("6", "wind"), _card("6", "wind")]
    var split_coop := [_card("4", "fire"), _card("4", "fire")]
    var split_engine = _same_qi_cooperation_engine(split_main, split_coop, 82601)
    var split_result: Dictionary = split_engine.confirm_play(
        _ids(split_main), _ids(split_coop))
    _assert_true(split_result.get("success", false), "不同属性的两组协同结算成功")
    _assert_equal(split_result["preview"]["values"]["attribute_concentration"], 3, "主组三张独立计算 N=3")
    _assert_equal(split_result["cooperation_preview"]["values"]["attribute_concentration"], 2, "协同组两张独立计算 N=2")
    _assert_equal(split_result["preview"]["same_qi_gain"], 3, "主组与协同组行动级合并只计算一次 G=3")
    _assert_equal(split_engine.player.same_qi_value, 3, "未充满时同气保存在槽内")

    var linked_main := [_card("6", "wind"), _card("6", "wind"), _card("6", "wind")]
    var linked_coop := [_card("4", "wind"), _card("4", "wind")]
    var linked_engine = _same_qi_cooperation_engine(linked_main, linked_coop, 82602)
    var linked_reserve := [
        _card("7", "wind"), _card("8", "wind"),
        _card("9", "wind"), _card("10", "wind")]
    linked_engine.player.hand.append_array(linked_reserve)
    linked_engine.player.same_qi_value = 4
    var linked_result: Dictionary = linked_engine.confirm_play(
        _ids(linked_main), _ids(linked_coop))
    _assert_true(linked_result.get("success", false), "五张同属性协同结算成功")
    _assert_equal(linked_result["preview"]["same_qi"]["gain"], 4, "整次行动冻结五张同属性 G=4")
    _assert_equal(linked_engine.player.same_qi_value, 3, "4+4跨过5后保留3点溢出")
    _assert_equal(linked_result["actions_available"], 1, "首次充满同气获得一次行动")
    var second_result: Dictionary = linked_engine.confirm_play(
        _ids(linked_reserve.slice(0, 3)))
    _assert_true(second_result.get("success", false), "同回合同气连动行动正常打出")
    _assert_equal(linked_engine.player.same_qi_value, 0, "溢出3再获得2后正确消耗5")
    _assert_equal(second_result["actions_available"], 1, "同一完整回合可以连续再次充满并连动")

    var pending_cards := [_card("8", "wind"), _card("3", "fire")]
    var pending_reserve = _card("5", "mountain")
    var pending_reserve_second = _card("7", "forest")
    var pending_engine = _engine_with_hand(
        pending_cards + [pending_reserve, pending_reserve_second], [], 82603)
    pending_engine.player.same_qi_value = 4
    var identity_enabled := [true]
    pending_engine.card_identity_policy.register_provider(
        func(_card_value, _context): return {
            "additional_effective_attributes": ["forest"] \
                if identity_enabled[0] else [],
        },
        "same_qi_frozen_identity", 10)
    pending_engine.repository.techniques["same_qi_wait_probe"] = {
        "id": "same_qi_wait_probe",
        "name": "同气等待恢复探针",
        "pool": "high",
        "effects": [{
            "op": "select_cards",
            "choice_id": "same_qi_wait_once",
            "prompt": "请选择保留手牌",
            "chooser": "actor",
            "minimum": 1,
            "maximum": 1,
            "insufficient_policy": "fail",
            "query": {"side": "actor", "zone": "hand", "order": "zone"},
            "capture": "same_qi_waited",
        }],
    }
    pending_engine.sequence_book.configure({
        "high_card": ["same_qi_wait_probe"],
    })
    var pending_start: Dictionary = pending_engine.confirm_play(_ids(pending_cards))
    _assert_true(pending_start.get("pending_choice", false), "同气行动进入等待功法选择")
    if not pending_start.get("pending_choice", false):
        _assert_true(false, "同气等待探针诊断：%s" % str(pending_start))
        return
    _assert_equal(
        pending_start["preview"]["same_qi"]["common_attributes"],
        ["forest"],
        "等待前冻结行动级身份与分组")
    identity_enabled[0] = false
    var pending_request: Dictionary = pending_start["choice_request"]
    var pending_finish: Dictionary = pending_engine.resolve_effect_choice(
        str(pending_request["request_id"]), [str(pending_reserve.id)])
    _assert_true(pending_finish.get("success", false), "等待选择恢复后行动完成")
    _assert_equal(pending_finish["actions_available"], 1, "恢复只读取冻结 G 并授予一次行动")
    var repeated_finish: Dictionary = pending_engine.resolve_effect_choice(
        str(pending_request["request_id"]), [str(pending_reserve.id)])
    _assert_true(not repeated_finish.get("success", true), "重复 finalizer 请求被拒绝")
    _assert_equal(pending_engine.actions_available, 1, "重复恢复不重复增加同气或行动")
    _assert_equal(pending_engine.player.same_qi_value, 0, "重复恢复不重复改变同气槽")

    var audit_record = linked_engine.action_resolver.make_action_record(
        linked_engine.player,
        linked_engine.enemy,
        linked_result["preview"],
        linked_engine.sequence_book,
        100,
        linked_engine.turn_number)
    audit_record.cooperation_groups = [{
        "group_index": 1,
        "preview": linked_result["cooperation_preview"],
    }]
    var audit_snapshot: Dictionary = audit_record.snapshot()
    _assert_equal(audit_snapshot["schema_version"], 8, "行动记录保存功法执行汇总状态版本")
    _assert_equal(audit_snapshot["same_qi"]["gain"], 4, "行动记录保存行动级最优分组与 G")
    _assert_equal(audit_snapshot["same_qi_gain"], 4, "行动记录保存预计同气收益")
    _assert_equal(audit_snapshot["cooperation_groups"][0]["same_qi_group"]["gain"], 1, "行动记录保存协同组独立身份事实")

    var no_hand_engine = _engine_with_hand([_card("2", "wind")], [], 82605)
    no_hand_engine.player.hand.clear()
    no_hand_engine.player.same_qi_value = 4
    var held_gain: Dictionary = no_hand_engine.effect_ports.gain_same_qi(
        no_hand_engine.player, 3, "无合法手牌探针", "same-qi:no-hand")
    _assert_equal(held_gain.get("granted_actions", -1), 0, "没有合法手牌时不创建额外行动")
    _assert_equal(no_hand_engine.player.same_qi_value, 7, "没有合法手牌时未消耗同气完整保留")
    var idempotent_first: Dictionary = no_hand_engine.effect_ports.gain_same_qi(
        no_hand_engine.player, 2, "幂等探针", "same-qi:idempotent")
    var idempotent_repeat: Dictionary = no_hand_engine.effect_ports.gain_same_qi(
        no_hand_engine.player, 2, "幂等探针", "same-qi:idempotent")
    _assert_true(idempotent_repeat.get("reused", false), "相同行动 token 重复写入复用收据")
    _assert_equal(no_hand_engine.player.same_qi_value, int(idempotent_first["same_qi_after"]), "幂等重放不重复增加同气")
    no_hand_engine.player.hand = [
        _card("3", "wind"), _card("4", "forest")]
    no_hand_engine.player.same_qi_value = 0
    var multi_threshold: Dictionary = no_hand_engine.effect_ports.gain_same_qi(
        no_hand_engine.player, 11, "多阈值探针", "same-qi:multi-threshold")
    _assert_equal(multi_threshold.get("granted_actions", -1), 2, "一次跨过多个阈值逐次获得行动")
    _assert_equal(no_hand_engine.player.same_qi_value, 1, "多阈值结算保留最终溢出")
    var failed_play: Dictionary = no_hand_engine.confirm_play(["missing-card"])
    _assert_true(not failed_play.get("success", true), "失败行动被拒绝")
    _assert_equal(no_hand_engine.player.same_qi_value, 1, "失败或回滚不增加同气")

    var technique_card = _card("J", "wind")
    var technique_engine = _engine_with_hand([technique_card], [], 82604)
    technique_engine.repository.techniques["same_qi_technique_action"] = {
        "id": "same_qi_technique_action",
        "name": "功法额外行动探针",
        "pool": "high",
        "effects": [{
            "op": "gain_extra_action",
            "amount": {"kind": "constant", "value": 1},
        }],
    }
    technique_engine.sequence_book.configure({
        "high_card": ["same_qi_technique_action"],
    })
    var technique_result: Dictionary = technique_engine.confirm_play(
        [technique_card.id])
    _assert_true(technique_result.get("success", false), "功法额外行动正常结算")
    _assert_equal(technique_result["actions_available"], 0, "空手且没有预期抽牌时不建立功法额外行动")

    var capacity_handler := BattleFineGrainedProbeHandler.new()
    var capacity_registry = PassiveRuleHandlerRegistryScript.new()
    _assert_true(capacity_registry.register_handler(capacity_handler), "注册同气容量 Fake Provider")
    var capacity_catalog_result := _battle_passive_test_catalog(
        capacity_registry, [_f5d2_probe_item("same_qi_capacity_probe", {
            "query_values": {"same_qi_capacity_query": 4},
        })], [])
    _assert_true(capacity_catalog_result["success"], "同气容量 Fake 内容通过校验")
    var capacity_engine = _battle_passive_test_engine(
        capacity_catalog_result["catalog"], capacity_registry,
        ["same_qi_capacity_probe"])
    capacity_engine.player.hand = [_card("A", "wind")]
    capacity_engine.player.same_qi_value = 3
    var capacity_gain: Dictionary = capacity_engine.effect_ports.gain_same_qi(
        capacity_engine.player, 1, "容量4探针", "same-qi:capacity-four")
    _assert_equal(capacity_gain.get("same_qi_capacity", -1), 4, "Fake Provider 将有效容量改为4")
    _assert_equal(capacity_gain.get("granted_actions", -1), 1, "容量4时3+1触发一次行动")

func _same_qi_cooperation_engine(main_cards: Array, cooperation_cards: Array, seed_value: int):
    var engine = _engine_with_hand(main_cards + cooperation_cards, [], seed_value)
    engine.repository.techniques["same_qi_cooperation_main"] = {
        "id": "same_qi_cooperation_main",
        "name": "同气协同主组探针",
        "pool": "three",
        "effects": [],
        "cooperation": {
            "hand_id": "pair",
            "max_groups": 1,
            "power_rule": "shared_half",
            "post_commit": {"destination": "own_discard"},
        },
    }
    engine.repository.techniques["same_qi_cooperation_pair"] = {
        "id": "same_qi_cooperation_pair",
        "name": "同气协同组探针",
        "pool": "pair",
        "effects": [],
    }
    engine.sequence_book.configure({
        "three_kind": ["same_qi_cooperation_main"],
        "pair": ["same_qi_cooperation_pair"],
    })
    return engine

func _test_power_calculation() -> void:
    var result := HandEvaluatorScript.evaluate([_card("7"), _card("7", "forest"), _card("4"), _card("3"), _card("A")])
    var values := PowerCalculatorScript.calculate(result, {
        "base_fixed": 3,
        "insight_multiplier": 1,
        "multiplier_bonus": 2,
        "power_fixed": 5,
        "power_amp_percent": 40,
    })
    _assert_equal(values["base_value"], 17, "基础值含固定修正")
    _assert_equal(values["baseline_value"], 17, "牌型基准值等于贡献 C")
    _assert_equal(values["attribute_counts"], {
        "wind": 1, "forest": 1, "fire": 0, "mountain": 0,
    }, "不同属性对子分别进入属性候选计数")
    _assert_equal(values["attribute_concentration"], 1, "不同属性对子 N=1")
    _assert_equal(values["technique_multiplier"], 3, "M 以 N 为基础再加显式倍率修正")
    _assert_equal(values["initial_power"], 51, "P₀=floor(C×M)")
    _assert_equal(values["direct_power_fixed"], 5, "直接固定修正在 P₀ 后保存")
    _assert_equal(values["direct_power_percent"], 40, "直接百分比在 P₀ 后保存")
    _assert_equal(values["pre_momentum_power"], 78, "连势前功法值统一向下取整")
    _assert_equal(values["technique_value"], 78, "无成功功法连势时 P 等于非负连势前值")
    _assert_true(not values.has("fixed_multiplier"), "功法值结果不再输出固定牌型倍率")

    var same_pair := HandEvaluatorScript.evaluate([
        _card("8", "wind"), _card("8", "wind")])
    var same_pair_values := PowerCalculatorScript.calculate(same_pair)
    _assert_equal(same_pair_values["attribute_concentration"], 2, "两张可视为同属性的对子 N=2")
    var full_house := HandEvaluatorScript.evaluate([
        _card("7", "wind"), _card("7", "wind"), _card("7", "wind"),
        _card("3", "forest"), _card("3", "forest")])
    var full_house_values := PowerCalculatorScript.calculate(full_house)
    _assert_equal(full_house_values["attribute_concentration"], 3, "葫芦3风2林 N=3")

    var splash_extra = _card("2", "wind")
    var splash_high := HandEvaluatorScript.evaluate([
        _card("A", "wind"), splash_extra])
    splash_high["numeric_contributing"] = splash_high["contributing"].duplicate()
    splash_high["numeric_contributing"].append(splash_extra)
    var splash_values := PowerCalculatorScript.calculate(splash_high)
    _assert_equal(splash_values["contribution_total"], 14, "明确额外参与后飞溅牌同时进入 C")
    _assert_equal(splash_values["attribute_concentration"], 2, "明确额外参与后飞溅牌同时进入 N")

    var replay_card = _card("5", "fire")
    var replay_hand := HandEvaluatorScript.evaluate([replay_card])
    replay_hand["numeric_contributing"] = [replay_card, replay_card]
    var replay_values := PowerCalculatorScript.calculate(replay_hand)
    _assert_equal(replay_values["contribution_total"], 10, "同一实体的重演可以重复贡献 C")
    _assert_equal(replay_values["attribute_concentration"], 1, "同一实体重演只为 N 提供一张计数")

func _test_damage_resolver_rules_and_facade() -> void:
    var resolver = DamageResolverScript.new()
    var status_catalog = ContentCatalogScript.new()
    _assert_true(status_catalog.load_all(), "伤害服务测试载入状态定义")
    var standalone_status_system = StatusSystemScript.new(status_catalog)
    var actor = BattleSideScript.new("攻击方")
    actor.use_status_system(standalone_status_system)
    var target = BattleSideScript.new("受击方")
    target.life = 100
    target.defense = 7
    var normal: Dictionary = resolver.resolve(actor, target, 10, "technique")
    _assert_equal(normal["defense_lost"], 7, "普通伤害优先扣除全部可用防御")
    _assert_equal(normal["life_lost"], 3, "普通伤害余量才扣除生命")
    _assert_equal(target.defense, 0, "普通伤害实际更新目标防御")
    _assert_equal(target.life, 97, "普通伤害实际更新目标生命")

    target.life = 100
    target.defense = 9
    var true_hit: Dictionary = resolver.resolve(actor, target, 4, "technique", true)
    _assert_equal(true_hit["defense_lost"], 0, "真伤不扣除防御")
    _assert_equal(target.defense, 9, "真伤绕过并保留目标防御")
    _assert_equal(target.life, 96, "真伤直接扣除目标生命")

    target.life = 100
    target.defense = 0
    var momentum_hit: Dictionary = resolver.resolve(actor, target, 8, "technique")
    _assert_equal(momentum_hit["final_amount"], 8, "连势不再修改攻击段伤害")
    _assert_equal(target.life, 92, "普通伤害不读取连势百分比")

    target.life = 5
    var completed_segments := 0
    for _index in range(3):
        if not resolver.target_can_receive(target):
            break
        resolver.resolve(actor, target, 3, "technique")
        completed_segments += 1
    _assert_equal(completed_segments, 2, "多段攻击在目标死亡后停止后续攻击段")
    _assert_equal(target.life, 0, "多段攻击不会将生命扣至负数")

    var first = BattleSideScript.new("甲")
    var second = BattleSideScript.new("乙")
    first.life = 4
    second.life = 5
    resolver.begin_synchronized([first, second])
    resolver.resolve(first, second, 5, "technique")
    _assert_equal(second.life, 5, "同步伤害在缓冲刷新前不提前修改真实生命")
    _assert_true(not resolver.target_can_receive(second), "同步伤害 shadow 能判定目标已被本击击倒")
    _assert_true(resolver.actor_can_continue(second), "同步行动方按本击开始时存活状态完成已锁定伤害")
    resolver.resolve(second, first, 4, "technique")
    var synchronized_flush: Dictionary = resolver.flush_synchronized(
        func(intent: Dictionary) -> Dictionary:
            var actual := ComboDamageResolver.apply_to_target(
                intent["target"], int(intent["amount"]),
                str(intent.get("damage_type", "normal")),
                int(intent.get("poison_defense_intervention", 0)))
            return {
                "success": true,
                "resolution": {"result": actual},
                "stop_actor": int(intent["actor"].life) <= 0,
            })
    _assert_true(synchronized_flush.get("success", false),
        "低层同步伤害结构化刷新成功")
    var synchronized: Array = synchronized_flush.get("resolutions", [])
    _assert_equal(synchronized.size(), 2, "同步伤害刷新全部已锁定意图")
    _assert_equal(first.life, 0, "同步双方致命时第一方正常倒下")
    _assert_equal(second.life, 0, "同步双方致命时第二方正常倒下")

    var engine = _tracked_combat_engine()
    engine.setup(144, false)
    engine.player.momentum_value = 25
    engine.enemy.life = 20
    engine.enemy.defense = 3
    var facade: Dictionary = engine.deal_damage(
        engine.player,
        engine.enemy,
        8,
        "technique")
    var direct_actor = BattleSideScript.new("直接攻击方")
    direct_actor.use_status_system(standalone_status_system)
    var direct_target = BattleSideScript.new("直接受击方")
    direct_actor.momentum_value = 25
    direct_target.life = 20
    direct_target.defense = 3
    var direct: Dictionary = DamageResolverScript.new().resolve(
        direct_actor,
        direct_target,
        8,
        "technique")
    _assert_equal(facade["requested"], direct["requested"], "战斗引擎兼容门面与伤害服务请求值一致")
    _assert_equal(facade["defense_lost"], direct["defense_lost"], "战斗引擎兼容门面与伤害服务防御结算一致")
    _assert_equal(facade["life_lost"], direct["life_lost"], "战斗引擎兼容门面与伤害服务生命结算一致")
    _assert_equal(engine.enemy.life, direct_target.life, "战斗引擎兼容门面与伤害服务最终生命一致")
    _assert_equal(engine.enemy.defense, direct_target.defense, "战斗引擎兼容门面与伤害服务最终防御一致")

func _test_structured_game_log_channels() -> void:
    var game_log = GameLogScript.new()
    var battle_entry: Dictionary = game_log.record_battle(
        "damage",
        "测试攻击段",
        "测试功法",
        "成功",
        "造成 3 点伤害")
    var system_entry: Dictionary = game_log.record_system(
        "warning",
        "battle_command",
        "测试命令被拒绝",
        "命令参数无效",
        {"command": "test"})
    var run_entry: Dictionary = game_log.record_run(
        "node_lifecycle",
        "测试节点完成",
        "历练 +3",
        {"node_id": "0_0"})
    _assert_equal(battle_entry["serial"], 0, "统一日志从稳定序号零开始")
    _assert_equal(system_entry["serial"], 1, "战斗与系统日志共享同一递增序号")
    _assert_equal(run_entry["serial"], 2, "本局日志与其他通道共享同一递增序号")
    _assert_equal(game_log.entries("battle").size(), 1, "统一日志可独立查询战斗通道")
    _assert_equal(game_log.entries("run").size(), 1, "统一日志可独立查询本局通道")
    _assert_equal(game_log.entries("system").size(), 1, "统一日志可独立查询系统通道")
    _assert_equal(
        game_log.entries("battle")[0]["context"]["status"],
        "成功",
        "战斗日志保留结构化结算状态")
    var copied: Array = game_log.entries("system")
    copied[0]["detail"] = "被外部修改"
    _assert_equal(
        game_log.latest("system")["detail"],
        "命令参数无效",
        "修改日志查询副本不会污染日志核心")
    game_log.clear("battle")
    _assert_equal(game_log.entries("battle").size(), 0, "可以单独清理战斗日志通道")
    _assert_equal(game_log.entries("system").size(), 1, "清理战斗日志不会删除系统诊断")
    _assert_equal(game_log.entries("run").size(), 1, "清理战斗日志不会删除本局流程记录")

func _test_action_preview_service_matches_engine_facade() -> void:
    var engine = _tracked_combat_engine()
    engine.setup(2308, false)
    engine.start_player_turn()
    var card_ids: Array = [engine.player.hand[0].id, engine.player.hand[1].id]
    var hand_count_before: int = engine.player.hand.size()
    var sequence_position_before: int = engine.sequence_book.position("pair")
    var direct: Dictionary = engine.action_preview_service.preview(
        engine.player,
        card_ids,
        engine.sequence_book,
        engine.power_modifiers,
        engine.enemy)
    var through_facade: Dictionary = engine.preview(card_ids)
    _assert_equal(direct, through_facade, "独立行动预览服务与战斗门面返回完全一致")
    _assert_equal(engine.player.hand.size(), hand_count_before, "行动预览服务不移动手牌")
    _assert_equal(
        engine.sequence_book.position("pair"),
        sequence_position_before,
        "行动预览服务不推进功法序列")

func _engine_with_hand(cards: Array, draw_cards: Array = [], seed_value: int = 99):
    var engine = _tracked_combat_engine()
    engine.setup(seed_value, false)
    engine.player.hand = cards.duplicate()
    engine.player.draw_pile = draw_cards.duplicate()
    engine.player.discard_pile.clear()
    engine.player.staging.clear()
    engine.actions_available = 1
    return engine

func _ids(cards: Array) -> Array:
    var result: Array = []
    for card in cards:
        result.append(card.id)
    return result

func _test_no_automatic_damage_or_draw() -> void:
    var pair := [_card("5"), _card("5", "forest")]
    var reserve := [_card("A", "fire")]
    var engine = _engine_with_hand(pair + reserve, [_card("2")])
    engine.sequence_book.configure({"pair": []})
    var before_draw_count: int = engine.player.draw_pile.size()
    var result := engine.confirm_play(_ids(pair))
    _assert_true(result["success"], "空序列允许出牌")
    _assert_equal(engine.enemy.life, 100, "出牌与牌型基准值不自动伤害")
    _assert_equal(engine.player.hand.size(), 1, "连击期间不自动补牌")
    _assert_equal(engine.player.draw_pile.size(), before_draw_count, "出牌后牌库未自动抽取")
    _assert_equal(engine.player.discard_pile.size(), 2, "打出牌进入弃牌堆")

func _test_representative_damage_draw_discard() -> void:
    ## 覆盖 damage + draw + discard_random + draw_if_captured_attribute 效果链。
    ##
    ## 此前由清风过隙承载，该功法已随风池重写移出权威活跃名单（提交 d66b4a3）。
    ## draw_if_captured_attribute 仍是注册操作码但已无内容承载，因此改用合成夹具，
    ## 避免这条链变成零运行时覆盖。
    var selected := [_card("9", "mountain")]
    var remaining := [_card("3", "forest"), _card("4", "fire")]
    var draw_cards := [_card("6", "forest"), _card("2", "wind")]
    var engine = _engine_with_hand(selected + remaining, draw_cards, 4242)
    engine.repository.techniques["probe_draw_discard_chain"] = {
        "id": "probe_draw_discard_chain",
        "name": "测试抽弃条件链",
        "pool": "high",
        "effects": [
            {"op": "damage", "amount": {"kind": "power"}},
            {"op": "draw", "count": {"kind": "constant", "value": 1}, "capture": "first_draw"},
            {"op": "discard_random", "count": {"kind": "constant", "value": 1}},
            {
                "op": "draw_if_captured_attribute",
                "capture": "first_draw",
                "attribute": "wind",
                "count": 1,
            },
        ],
    }
    engine.sequence_book.configure({"high_card": ["probe_draw_discard_chain"]})
    var result := engine.confirm_play(_ids(selected))
    _assert_true(result["technique_triggered"], "抽弃条件链功法触发")
    _assert_equal(engine.enemy.life, 91, "效果链首项造成 P 点伤害")
    _assert_equal(engine.player.draw_pile.size(), 0, "首次抽到风后额外抽 1 张")
    _assert_equal(engine.player.hand.size(), 3, "抽 2、随机弃 1、打出 1 后手牌数量")

func _test_multi_damage_and_consecutive_chase() -> void:
    var selected := [_card("6", "wind")]
    var engine = _engine_with_hand(selected)
    engine.repository.techniques["multi_damage_probe"] = {
        "id": "multi_damage_probe",
        "name": "普通多段伤害探针",
        "pool": "high",
        "effects": [{
            "op": "multi_damage",
            "segments": 3,
            "amount": {"kind": "constant", "value": 3},
            "chase_on_consecutive_life_hits_percent": 50,
        }],
    }
    engine.sequence_book.configure({"high_card": ["multi_damage_probe"]})
    var result := engine.confirm_play(_ids(selected))
    _assert_true(result["technique_triggered"], "普通 multi_damage 探针触发")
    _assert_equal(engine.enemy.life, 89, "普通三段伤害与连续生命追击正常结算")

func _test_visible_queue_left_to_right() -> void:
    var engine = _engine_with_hand([])
    var hand_result := HandEvaluatorScript.evaluate([_card("2")])
    var context := {"engine": engine, "actor": engine.player, "target": engine.enemy, "hand_result": hand_result, "power": 1, "captures": {}}
    engine.trigger_queue.enqueue("same", "右侧", "测试", 200, [{"op": "defense", "amount": 1}], context.duplicate(true))
    engine.trigger_queue.enqueue("same", "左侧", "测试", 100, [{"op": "defense", "amount": 2}], context.duplicate(true))
    engine.trigger_queue.process_timing("same", engine.effect_executor)
    _assert_equal(engine.player.defense, 3, "同一时点效果逐项更新最新状态")
    var size: int = engine.trigger_queue.history.size()
    _assert_equal(engine.trigger_queue.history[size - 2]["label"], "左侧", "触发队列先结算左侧")
    _assert_equal(engine.trigger_queue.history[size - 1]["label"], "右侧", "触发队列后结算右侧")

func _test_inner_skill_equipment_and_extra_qi_defense() -> void:
    var cards := [_card("4", "wind"), _card("4", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var unequipped = _engine_with_hand(cards)
    unequipped.sequence_book.configure({"pair": []})
    unequipped.confirm_play(_ids(cards))
    _assert_equal(unequipped.player.defense, 0, "未装备初始内功时额外真气不提供防御")

    var equipped_cards := [_card("4", "wind"), _card("4", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var equipped = _engine_with_hand(equipped_cards)
    equipped.sequence_book.configure({"pair": []})
    equipped.player.configure_inner_skills(["extra_qi_to_defense"], 1)
    equipped.confirm_play(_ids(equipped_cards))
    _assert_equal(equipped.player.defense, 5, "未参与一对的 2 与 3 转化为 5 点防御")
    _assert_equal(equipped.player.equipped_inner_skill_ids.size(), 1, "玩家独立记录已装备内功")
    _assert_equal(equipped.enemy.equipped_inner_skill_ids.size(), 0, "敌方装备状态与玩家独立")
    var over_capacity: Dictionary = equipped.player.configure_inner_skills([
        "extra_qi_to_defense", "extra_qi_to_defense", "extra_qi_to_defense",
        "extra_qi_to_defense", "extra_qi_to_defense", "extra_qi_to_defense",
        "extra_qi_to_defense"], 7)
    _assert_true(not over_capacity["success"], "默认有效容量下七门内功明确失败")
    _assert_equal(equipped.player.equipped_inner_skill_ids.size(), 1, "容量失败不截断或替换原配装")
    _assert_equal(equipped.player.technique_slot_index, 1, "容量失败不移动原功法位置")

func _test_inner_skill_preview_and_enemy_plan() -> void:
    var cards := [_card("7", "wind"), _card("7", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var engine = _engine_with_hand(cards)
    engine.sequence_book.configure({"pair": []})
    engine.player.configure_inner_skills(["extra_qi_to_defense"], 1)
    var preview: Dictionary = engine.preview(_ids(cards))
    _assert_equal(preview["intent"]["inner_skill_defense"], 5, "玩家预览单独显示内功预计防御")
    _assert_equal(preview["intent"]["defense"], 5, "玩家总行动预览计入内功防御")

    engine.enemy.hand = cards.duplicate()
    engine.enemy_sequence_book.configure({"pair": [], "high_card": []})
    engine.enemy.configure_inner_skills(["extra_qi_to_defense"], 1)
    var enemy_preview: Dictionary = engine._preview_for_side(engine.enemy, _ids(cards), engine.enemy_sequence_book)
    var public_plan: Dictionary = engine._public_enemy_plan(enemy_preview["intent"])
    _assert_equal(public_plan["defense"], 5, "敌方行动计划计入已装备内功防御")
    _assert_true(not public_plan.has("inner_skills"), "敌方公开计划不泄露具体内功来源")

func _test_consumable_shared_slots_and_generation_limit() -> void:
    var engine = _tracked_combat_engine()
    engine.setup(77, false)
    GrowthInventoryScript.new(
        engine.content_catalog, false).apply_to_battle_side(engine.player)
    engine.player.configure_consumables([
        "high_card_insight", "zengyuan_pill"])
    _assert_equal(engine.player.consumable_ids.size(), 2, "三类消耗品共用两格基础容量")
    _assert_equal(engine.player.consumable_ids, ["high_card_insight", "zengyuan_pill"], "共享槽只保留前两种代表消耗品")
    _assert_equal(engine.grant_consumable(engine.player, "straight_insight", "测试"), false, "没有空位时不生成消耗品")
    var used := engine.use_player_consumable(0, [])
    _assert_true(used["success"], "无目标心得可以直接使用")
    _assert_equal(engine.player.consumable_use_sequence, 1, "战斗成功使用只递增一次序号")
    _assert_equal(
        engine.player.last_recallable_consumable_id,
        "high_card_insight",
        "战斗心得成功记录最近可溯忆消耗品")
    _assert_equal(engine.player.consumable_ids.size(), 1, "使用后立即释放共享槽位")
    _assert_true(engine.grant_consumable(engine.player, "straight_insight", "测试"), "释放槽位后可以生成消耗品")
    _assert_equal(engine.player.consumable_ids.size(), 2, "重新生成后占满两格")

func _test_unified_run_and_battle_consumable_order_and_records() -> void:
    var definition := {
        "id": "transaction_order_probe",
        "name": "统一事务顺序探针",
        "kind": "pill",
        "targeting": {
            "zone": "none",
            "selection": "deterministic_random",
            "minimum": 0,
            "maximum": 0,
        },
        "effects": [
            {"op": "transaction_order_a"},
            {"op": "transaction_order_b"},
        ],
    }
    var probe := ConsumableOrderProbeHandler.new()
    var registry := ConsumableEffectHandlerRegistryScript.new()
    _assert_true(registry.register_handler(probe), "Run 统一事务顺序探针注册成功")
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "统一消耗品事务测试内容目录可加载")
    var service = ConsumableUseServiceScript.new(
        registry, catalog, ContentValidatorScript.HAND_IDS,
        ContentValidatorScript.POOL_IDS)
    var growth = GrowthInventoryScript.new()
    growth.consumable_ids.append("transaction_order_probe")
    var run_context = RunConsumableUseContextScript.new(
        growth, [], null, catalog, {
            "source_kind": "consumable",
            "source_instance_key": "run-consumable:order-probe",
            "action_token": "run-consumable-use:order-probe",
        })
    var run_result: Dictionary = service.use(
        run_context, 0, [], 9981, definition)
    _assert_true(run_result.get("success", false), "Run 入口通过统一事务使用成功")

    var engine = _tracked_combat_engine()
    engine.setup(9981, false)
    _assert_true(engine.consumable_repository.configure({
        "practice_offer_ids": ["transaction_order_probe"],
        "consumables": [definition],
    }), "Battle 统一事务顺序探针仓库配置成功")
    _assert_true(
        engine.consumable_service._handler_registry.register_handler(probe),
        "Battle 统一事务顺序探针注册成功")
    engine.player.configure_consumables(["transaction_order_probe"])
    var battle_result: Dictionary = engine.use_player_consumable(0, [])
    _assert_true(
        battle_result.get("success", false),
        "Battle 入口通过同一 ConsumableUseService 使用成功")
    _assert_equal(probe.calls, [
        "run:transaction_order_a",
        "run:transaction_order_b",
        "battle:transaction_order_a",
        "battle:transaction_order_b",
    ], "Run 与 Battle 使用完全相同的 Handler 顺序")
    _assert_equal(
        battle_result.get("consumable_use_sequence"), 1,
        "统一成功结果包含递增后的使用序号")
    _assert_equal(
        engine.player.last_recallable_consumable_id,
        "transaction_order_probe",
        "Battle pill 通过公共提交步骤记录最近使用")

func _test_battle_unique_consumable_and_query_purity() -> void:
    var unique_definition := {
        "id": "battle_unique_probe",
        "name": "战斗唯一事务探针",
        "kind": "curio",
        "unique": true,
        "record_last_used": false,
        "targeting": {
            "zone": "none",
            "selection": "deterministic_random",
            "minimum": 0,
            "maximum": 0,
        },
        "effects": [{"op": "transaction_order_a"}],
    }
    var probe := ConsumableOrderProbeHandler.new()
    var run_only_definition := {
        "id": "battle_run_only_probe",
        "name": "战斗外能力探针",
        "kind": "curio",
        "targeting": {
            "zone": "run_deck",
            "selection": "deterministic_random",
            "minimum": 1,
            "maximum": 1,
        },
        "effects": [{"op": "remove_run_cards"}],
    }
    var engine = _tracked_combat_engine()
    engine.setup(9982, false)
    _assert_true(engine.consumable_repository.configure({
        "practice_offer_ids": ["battle_unique_probe"],
        "consumables": [unique_definition, run_only_definition],
    }), "战斗唯一消耗品探针仓库配置成功")
    _assert_true(
        engine.consumable_service._handler_registry.register_handler(probe),
        "战斗唯一消耗品探针 Handler 注册成功")
    engine.player.configure_consumables([
        "battle_unique_probe", "battle_unique_probe", "battle_run_only_probe"])
    var rng_before := int(engine.rng.state)
    var query: Dictionary = engine.consumable_service.query_player(0)
    _assert_true(query.get("can_use", false), "战斗 query_use 返回可用")
    _assert_equal(engine.rng.state, rng_before, "战斗 query_use 不推进 RNG")
    _assert_equal(
        engine.player.consumable_use_sequence, 0,
        "战斗 query_use 不修改使用序号")
    var first: Dictionary = engine.use_player_consumable(0, [])
    _assert_true(first.get("success", false), "战斗唯一消耗品首次使用成功")
    _assert_true(
        engine.player.used_unique_consumable_ids.has("battle_unique_probe"),
        "战斗成功后记录 unique 使用")
    var second: Dictionary = engine.use_player_consumable(0, [])
    _assert_true(not second.get("success", false), "战斗唯一消耗品不能再次使用")
    _assert_equal(
        engine.player.consumable_ids,
        ["battle_unique_probe", "battle_run_only_probe"],
        "重复失败不扣库存")
    _assert_equal(engine.player.consumable_use_sequence, 1, "重复失败不推进使用序号")
    var unsupported: Dictionary = engine.consumable_service.query_player(1)
    _assert_true(
        not unsupported.get("can_use", true),
        "战斗外专属能力在 Battle 查询阶段明确不可用")
    _assert_true(
        str(unsupported.get("reason", "")).contains("不支持"),
        "Battle 查询返回不支持能力的明确原因：%s" % str(
            unsupported.get("reason", "")))

func _test_battle_consumable_multi_effect_rollback() -> void:
    var target = _card("9", "wind")
    target.set_enhancement("momentum")
    var engine = _engine_with_hand([target], [], 7901)
    var configured: bool = bool(engine.consumable_repository.configure({
        "practice_offer_ids": ["battle_transaction_probe"],
        "consumables": [{
            "id": "battle_transaction_probe",
            "name": "战斗事务探针",
            "kind": "pill",
            "targeting": {
                "zone": "run_deck",
                "selection": "player_selected",
                "minimum": 1,
                "maximum": 1,
            },
            "effects": [
                {"op": "battle_working_state_mutation", "amount": 0},
                {"op": "gain_insight", "hand": "high_card", "pools": ["high"]},
                {"op": "apply_enhancement", "enhancement": "qi_boost"},
                {"op": "battle_transaction_fail", "amount": 0},
            ],
        }],
    }))
    _assert_true(configured, "战斗事务探针消耗品仓库配置成功")
    _assert_true(
        engine.consumable_service._handler_registry.register_handler(
            BattleWorkingStateMutationProbeHandler.new()),
        "战斗工作状态修改探针注册成功")
    _assert_true(
        engine.consumable_service._handler_registry.register_handler(
            ConsumableProbeHandler.new(["battle_transaction_fail"], true)),
        "战斗事务失败探针注册成功")
    engine.player.configure_consumables(["battle_transaction_probe"])
    var card_before: Dictionary = target.persistent_reshape_state()
    var progression_before: Dictionary = engine.player.hand_technique_progression.duplicate(true)
    var owned_before: Array[String] = engine.player.owned_technique_ids.duplicate()
    var consumables_before: Array[String] = engine.player.consumable_ids.duplicate()
    var learned_inner_before: Array[String] = (
        engine.player.learned_inner_skill_ids.duplicate())
    var forgotten_before: int = engine.player.forgotten_inner_skill_count
    var use_sequence_before: int = engine.player.consumable_use_sequence
    var last_recallable_before: String = engine.player.last_recallable_consumable_id
    var used_unique_before: Array[String] = (
        engine.player.used_unique_consumable_ids.duplicate())
    var source_markers_before: Dictionary = (
        engine.player.source_marker_store.snapshot())
    var sequence_book_before: Dictionary = engine.sequence_book.snapshot()
    var event_state_before: Dictionary = (
        engine.battle_passive_event_service.capture_transaction_state())
    var trigger_state_before: Dictionary = engine.trigger_queue.capture_runtime_state()
    var rng_state_before: int = int(engine.rng.state)
    var observed_events: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(event_kind, _values, _receipt):
            observed_events.append(str(event_kind)))

    var result := engine.use_player_consumable(0, [target.id])

    _assert_true(not result.get("success", false), "战斗多效果第二阶段后失败时整体失败")
    _assert_true(result.get("rolled_back", false), "战斗多效果失败报告已完成事务回滚")
    _assert_equal(target.persistent_reshape_state(), card_before, "失败恢复目标真气持久重塑状态")
    _assert_equal(
        engine.player.hand_technique_progression,
        progression_before,
        "失败恢复牌型功法成长")
    _assert_equal(engine.player.owned_technique_ids, owned_before, "失败恢复已拥有功法")
    _assert_equal(engine.player.consumable_ids, consumables_before, "失败不消费指定消耗品槽")
    _assert_equal(
        engine.player.learned_inner_skill_ids, learned_inner_before,
        "失败恢复战斗中新获得内功")
    _assert_equal(
        engine.player.forgotten_inner_skill_count, forgotten_before,
        "失败恢复战斗内功遗忘计数")
    _assert_equal(
        engine.player.consumable_use_sequence, use_sequence_before,
        "失败恢复消耗品使用序号")
    _assert_equal(
        engine.player.last_recallable_consumable_id, last_recallable_before,
        "失败恢复最近可溯忆消耗品")
    _assert_equal(
        engine.player.used_unique_consumable_ids, used_unique_before,
        "失败恢复唯一消耗品使用记录")
    _assert_equal(
        engine.player.source_marker_store.snapshot(), source_markers_before,
        "失败恢复本局来源标识")
    _assert_equal(engine.sequence_book.snapshot(), sequence_book_before, "失败恢复 SequenceBook")
    _assert_equal(
        engine.battle_passive_event_service.capture_transaction_state(),
        event_state_before,
        "失败恢复事件 serial、receipt 与 execution history")
    _assert_equal(
        engine.trigger_queue.capture_runtime_state(), trigger_state_before,
        "失败恢复触发历史及结构化战斗日志")
    _assert_true(observed_events.is_empty(), "失败事务不会向监听器发布已回滚事件")
    _assert_equal(engine.rng.state, rng_state_before, "失败恢复战斗消耗品随机状态")

func _test_s2f2f3_practice_shop_packs_items_and_migration() -> void:
    var profile = RuntimeProfileScript.production()
    var catalog = ContentCatalogScript.new(profile)
    _assert_true(catalog.load_all(), "F3 正式内容目录可以装载")
    var practice: Dictionary = catalog.definition("practice_shop")
    _assert_equal(practice.get("version"), 2, "修习商店升级为 v2")
    _assert_equal(practice.get("normal", {}).get("slot_count"), 2, "v2 普通栏为两个槽位")
    _assert_equal(practice.get("packs", {}).get("slot_count"), 2, "v2 补充包栏为两个槽位")
    _assert_equal(practice.get("items", {}).get("slot_count"), 1, "v2 物品栏为一个槽位")
    var categories: Array = practice.get("normal", {}).get("categories", [])
    var weights: Dictionary = {}
    var pill_ids: Array = []
    var insight_ids: Array = []
    var curio_ids: Array = []
    for category in categories:
        weights[str(category.get("id", ""))] = int(category.get("weight", 0))
        match str(category.get("content_kind", "")):
            "pill": pill_ids = category.get("candidate_ids", []).duplicate()
            "insight": insight_ids = category.get("candidate_ids", []).duplicate()
            "curio": curio_ids = category.get("candidate_ids", []).duplicate()
    _assert_equal(weights, {
        "techniques": 35, "pills": 25, "insights": 15,
        "curios": 20, "inner_skills": 5, "awakened_qi": 5,
    }, "普通商品分类权重全部来自商店数据")
    _assert_equal(pill_ids.size(), 23, "普通池白名单包含 23 种正式丹药")
    _assert_equal(insight_ids.size(), 8, "普通池白名单包含 8 种正式心得")
    _assert_equal(curio_ids.size(), 17, "普通池白名单包含 17 种正式奇珍")
    var pack_candidates: Array = practice.get("packs", {}).get("candidates", [])
    _assert_equal(pack_candidates.size(), 9, "九种补充包全部存在")
    var pack_shapes: Dictionary = {}
    for pack in pack_candidates:
        pack_shapes[str(pack.get("id", ""))] = [
            int(pack.get("price", 0)),
            int(pack.get("offer_count", 0)),
            int(pack.get("choose_count", 0)),
        ]
    _assert_equal(pack_shapes.get("pill_pack_basic"), [4, 3, 1], "普通丹药包规格")
    _assert_equal(pack_shapes.get("large_pill_pack"), [6, 5, 1], "大型丹药包规格")
    _assert_equal(pack_shapes.get("deluxe_pill_pack"), [8, 5, 2], "豪华丹药包规格")
    _assert_equal(pack_shapes.get("insight_pack_basic"), [4, 3, 1], "普通心得包规格")
    _assert_equal(pack_shapes.get("large_insight_pack"), [6, 5, 1], "大型心得包规格")
    _assert_equal(pack_shapes.get("deluxe_insight_pack"), [8, 5, 2], "豪华心得包规格")
    _assert_equal(pack_shapes.get("curio_pack_basic"), [4, 2, 1], "普通奇珍包规格")
    _assert_equal(pack_shapes.get("large_curio_pack"), [6, 4, 1], "大型奇珍包规格")
    _assert_equal(pack_shapes.get("deluxe_curio_pack"), [8, 4, 2], "豪华奇珍包规格")
    _assert_equal(practice.get("items", {}).get("candidate_ids", []).size(), 7,
        "物品候选池登记七件正式修习策略物品")
    var items_definition: Dictionary = catalog.definition("items")
    _assert_equal(items_definition.get("items", []).size(), 9,
        "items.json 登记两个设计候选与七件正式物品")
    for item in items_definition.get("items", []):
        _assert_true(
            str(item.get("status", "")) in ["candidate", "design_only", "formal"],
            "物品状态使用正式枚举")

    var service := PracticeServiceScript.new(catalog)
    var growth := GrowthInventoryScript.new(catalog, false)
    growth.experience = 100
    var deluxe_pill: Dictionary = pack_candidates.filter(
        func(value): return str(value.get("id", "")) == "deluxe_pill_pack")[0]
    growth.practice_shop_state = {
        "shop_index": 1, "act": 1, "normal": [],
        "packs": [deluxe_pill], "items": [{}],
        "meditation_count": 0, "next_meditation_cost": 5,
        "pack_open_sequence": 0,
    }
    var state_before_preview := growth.capture_mutation_state()
    var preview: Dictionary = service.open_pack(
        growth, "packs", 0, [], true, 77123, 1)
    _assert_true(preview.get("success", false), "补充包预览成功")
    _assert_equal(preview.get("max_choose_count"), 2, "空余栏位足够时豪华包可选两项")
    _assert_equal(growth.capture_mutation_state(), state_before_preview, "补充包预览不改变真实状态")
    var offered: Array = preview.get("preview", [])
    var confirmed: Dictionary = service.open_pack(
        growth, "packs", 0, [offered[0]], true, 77123, 1,
        str(preview.get("preparation_token", "")))
    _assert_true(confirmed.get("success", false), "补充包确认成功")
    _assert_equal(growth.consumable_ids, [str(offered[0])], "确认只加入玩家选择的内容")
    _assert_equal(growth.practice_shop_state.get("packs", [])[0], {}, "补充包确认后槽位为空")
    _assert_equal(growth.experience, 92, "补充包确认只扣除 8 点历练")

    var stale_growth := GrowthInventoryScript.new(catalog, false)
    stale_growth.experience = 100
    stale_growth.practice_shop_state = {
        "shop_index": 1, "act": 1, "normal": [],
        "packs": [deluxe_pill], "items": [{}], "pack_open_sequence": 0,
    }
    var stale_preview: Dictionary = service.open_pack(
        stale_growth, "packs", 0, [], true, 77123, 1)
    stale_growth.experience += 1
    var stale_before := stale_growth.capture_mutation_state()
    var stale_result := service.open_pack(
        stale_growth, "packs", 0, [stale_preview.get("preview", [])[0]], true,
        77123, 1, str(stale_preview.get("preparation_token", "")))
    _assert_true(not stale_result.get("success", false), "预览后历练变化令确认明确失败")
    _assert_equal(stale_growth.capture_mutation_state(), stale_before, "失效 token 不改变状态或随机序号")

    var one_slot_growth := GrowthInventoryScript.new(catalog, false)
    one_slot_growth.experience = 100
    one_slot_growth.consumable_ids.assign(["zengyuan_pill"])
    one_slot_growth.practice_shop_state = {
        "shop_index": 1, "act": 1, "normal": [],
        "packs": [deluxe_pill], "items": [{}], "pack_open_sequence": 0,
    }
    var one_slot_preview := service.open_pack(
        one_slot_growth, "packs", 0, [], true, 77123, 1)
    _assert_equal(one_slot_preview.get("max_choose_count"), 1, "豪华包在一格空位时动态限制为一项")
    var one_slot_before := one_slot_growth.capture_mutation_state()
    var over_selected := service.open_pack(
        one_slot_growth, "packs", 0,
        one_slot_preview.get("preview", []).slice(0, 2), true, 77123, 1,
        str(one_slot_preview.get("preparation_token", "")))
    _assert_true(not over_selected.get("success", false), "空位不足时不能确认超额选择")
    _assert_equal(one_slot_growth.capture_mutation_state(), one_slot_before, "栏位不足失败不改变状态")

    var full_growth := GrowthInventoryScript.new(catalog, false)
    full_growth.experience = 100
    full_growth.consumable_ids.assign(["zengyuan_pill", "pair_insight"])
    full_growth.practice_shop_state = {
        "shop_index": 1, "act": 1, "normal": [],
        "packs": [deluxe_pill], "items": [{}], "pack_open_sequence": 0,
    }
    var full_preview := service.open_pack(full_growth, "packs", 0, [], true, 77123, 1)
    _assert_equal(full_preview.get("max_choose_count"), 0, "没有空余栏位时补充包不能选择")
    var full_before := full_growth.capture_mutation_state()
    var full_confirm := service.open_pack(
        full_growth, "packs", 0, [full_preview.get("preview", [])[0]], true,
        77123, 1, str(full_preview.get("preparation_token", "")))
    _assert_true(not full_confirm.get("success", false), "没有空位时确认明确失败")
    _assert_equal(full_growth.capture_mutation_state(), full_before, "没有空位失败不改变库存和随机序号")

    var curio_pack: Dictionary = pack_candidates.filter(
        func(value): return str(value.get("id", "")) == "curio_pack_basic")[0]
    var unique_growth := GrowthInventoryScript.new(catalog, false)
    unique_growth.experience = 100
    unique_growth.used_unique_consumable_ids.append(str(curio_pack["candidate_ids"][0]))
    unique_growth.practice_shop_state = {
        "shop_index": 1, "act": 1, "normal": [],
        "packs": [curio_pack], "items": [{}], "pack_open_sequence": 0,
    }
    var unique_preview := service.open_pack(unique_growth, "packs", 0, [], true, 77123, 1)
    _assert_true(
        not unique_preview.get("preview", []).has(str(curio_pack["candidate_ids"][0])),
        "已使用唯一奇珍不会再次进入奇珍包")

    var curio_service := PracticeServiceScript.new(catalog)
    curio_service.configure({
        "version": 2,
        "normal": {"slot_count": 1, "categories": [{
            "id": "curios", "offer_kind": "consumable", "content_kind": "curio",
            "weight": 1, "candidate_ids": [str(curio_pack["candidate_ids"][0])]}]},
        "packs": {"slot_count": 0, "candidates": []},
        "items": {"slot_count": 0, "candidate_ids": []},
    })
    var used_normal_growth := GrowthInventoryScript.new(catalog, false)
    used_normal_growth.used_unique_consumable_ids.append(str(curio_pack["candidate_ids"][0]))
    var used_normal := curio_service.start_new_shop(used_normal_growth, 12, 1, 1)
    _assert_equal(used_normal.get("normal", [])[0], {}, "已使用唯一奇珍不会再次进入普通商品")

    var direct_consumable_growth := GrowthInventoryScript.new(catalog, false)
    direct_consumable_growth.experience = 10
    direct_consumable_growth.practice_shop_state = {
        "normal": [{"id": "zengyuan_pill", "kind": "consumable", "price": 3}],
        "packs": [], "items": [],
    }
    _assert_true(
        service.purchase(direct_consumable_growth, "normal", 0, true).get("success", false),
        "普通商品购买正式支持 consumable")
    _assert_equal(direct_consumable_growth.consumable_ids, ["zengyuan_pill"], "普通消耗品进入共享栏")
    var direct_inner_growth := GrowthInventoryScript.new(catalog, false)
    direct_inner_growth.experience = 10
    direct_inner_growth.practice_shop_state = {
        "normal": [{"id": "extra_qi_to_defense", "kind": "inner_skill", "price": 4}],
        "packs": [], "items": [],
    }
    _assert_true(
        service.purchase(direct_inner_growth, "normal", 0, true).get("success", false),
        "普通商品购买协议支持 inner_skill")
    _assert_equal(direct_inner_growth.learned_inner_skill_ids, ["extra_qi_to_defense"], "内功只加入已习得库")
    var direct_item_growth := GrowthInventoryScript.new(catalog, false)
    direct_item_growth.experience = 10
    direct_item_growth.practice_shop_state = {
        "normal": [], "packs": [],
        "items": [{"id": "overstock_plus_two", "kind": "item", "price": 4}],
    }
    _assert_true(
        service.purchase(direct_item_growth, "items", 0, true).get("success", false),
        "独立物品栏购买协议支持 item")
    _assert_equal(direct_item_growth.item_ids, ["overstock_plus_two"], "物品只进入 item_ids")
    _assert_true(
        direct_item_growth.consumable_ids.is_empty() \
            and direct_item_growth.learned_inner_skill_ids.is_empty(),
        "物品不占消耗品栏或内功栏")
    var purchase_fail_growth := GrowthInventoryScript.new(catalog, false)
    purchase_fail_growth.experience = 0
    purchase_fail_growth.practice_shop_state = {
        "normal": [{"id": "zengyuan_pill", "kind": "consumable", "price": 3}],
        "packs": [], "items": [], "pack_open_sequence": 4,
    }
    var purchase_fail_before := purchase_fail_growth.capture_mutation_state()
    _assert_true(
        not service.purchase(purchase_fail_growth, "normal", 0, true).get("success", false),
        "历练不足时普通购买失败")
    _assert_equal(
        purchase_fail_growth.capture_mutation_state(), purchase_fail_before,
        "购买失败时商店、库存、历练和随机序号全部不变")

    var reset_growth := GrowthInventoryScript.new(catalog, false)
    reset_growth.experience = 100
    service.start_new_shop(reset_growth, 77125, 1, 1)
    _assert_true(service.meditate(reset_growth, 77125, 1, true).get("success", false), "新商店内首次冥想成功")
    service.start_new_shop(reset_growth, 77125, 1, 2)
    _assert_equal(reset_growth.practice_shop_state.get("meditation_count"), 0, "新商店重置冥想次数")
    _assert_equal(reset_growth.practice_shop_state.get("next_meditation_cost"), 5, "新商店冥想费用重置为 5")

    var save_session: RunSession = RunSessionScript.new(
        null, null, null, null, catalog, null, null, null, null, profile)
    _assert_true(save_session.execute({"type": "setup_run", "seed": 77124}).success, "F3 存档测试本局建立")
    save_session.growth.item_ids.append("gift_card")
    var save_data = RunSaveDataScript.new().capture(save_session)
    var saved_dict: Dictionary = save_data.to_dict()
    _assert_true(saved_dict["growth"].has("item_ids"), "新存档写入 item_ids")
    _assert_true(not saved_dict["growth"]["practice_shop_state"].has("coupons"), "新存档不写 coupons")
    var legacy_dict := saved_dict.duplicate(true)
    var legacy_shop: Dictionary = legacy_dict["growth"]["practice_shop_state"]
    legacy_shop["coupons"] = legacy_shop.get("items", []).duplicate(true)
    legacy_shop.erase("items")
    legacy_shop["coupon_slots"] = 1
    var restored_legacy := RunSaveDataScript.new(legacy_dict)
    _assert_true(restored_legacy.to_dict()["growth"]["practice_shop_state"].has("items"), "旧 coupons 槽位迁移为 items")
    var legacy_result := restored_legacy.restore_session(catalog)
    _assert_true(legacy_result.get("success", false), "旧 coupons 存档可以读回")
    _assert_equal(legacy_result["run_session"].growth.item_ids, ["gift_card"], "物品独立存档往返")
    _assert_true(
        legacy_result["run_session"].growth.consumable_ids != legacy_result["run_session"].growth.item_ids,
        "item_ids 与 consumable_ids 保持独立")

    var ui_root := Node.new()
    var overlay = PracticeOverlayScript.new()
    ui_root.add_child(overlay)
    overlay.present({
        "experience": 100,
        "growth": {"consumables": [], "items": []},
        "practice": {
            "normal": [
                {"id": "a", "kind": "technique", "name": "甲", "price": 3, "can_purchase": true},
                {},
                {"id": "b", "kind": "technique", "name": "乙", "price": 3, "can_purchase": true},
                {},
            ],
            "packs": [pack_candidates[0], pack_candidates[1]],
            "items": [{}], "next_meditation_cost": 5,
        },
    })
    _assert_equal(overlay._offers.get_child_count(), 4, "UI 按冻结长度渲染四个普通商品槽")
    _assert_equal(overlay._packs.get_child_count(), 2, "UI 渲染两个补充包槽")
    _assert_equal(overlay._items.get_child_count(), 1, "UI 渲染一个物品槽")
    _assert_true(
        str(overlay._offers.get_child(1).text).contains("空槽") \
            and str(overlay._items.get_child(0).text).contains("空槽"),
        "UI 将已购买普通槽和无正式物品槽明确渲染为空槽")
    ui_root.queue_free()

func _test_zengyuan_pill_enhancement_and_preview() -> void:
    var pair := [_card("7", "wind"), _card("7", "forest")]
    pair[0].set_enhancement("momentum")
    var third = _card("3", "fire")
    var engine = _engine_with_hand(pair + [third])
    engine.player.configure_consumables(["zengyuan_pill"])
    var no_target := engine.use_player_consumable(0, [])
    _assert_equal(no_target["success"], false, "增元丹至少需要一张目标真气")
    var too_many := engine.use_player_consumable(0, _ids(pair + [third]))
    _assert_equal(too_many["success"], false, "增元丹不能选择超过两张真气")
    var result := engine.use_player_consumable(0, _ids(pair))
    _assert_true(result["success"], "增元丹可以强化至多两张真气")
    _assert_equal(pair[0].reshape_enhancement, "qi_boost", "新强化替换同一张真气的旧强化")
    _assert_equal(pair[1].reshape_enhancement, "qi_boost", "第二张目标获得增元强化")
    var preview := engine.preview(_ids(pair))
    _assert_equal(preview["values"]["base_value"], 30, "两张增元七的有效真气值各加八")
    _assert_equal(preview["values"]["baseline_value"], 30, "增元后的贡献 C 直接作为牌型基准值")
    _assert_equal(preview["values"]["technique_value"], 30, "不同属性对子 N=1 后得到新功法值预览")

func _test_simple_reshape_behaviors() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "简单强化测试载入正式目录")
    var card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_8"), "simple:hunyuan", catalog.card_reshape_rules)
    card.set_enhancement("hunyuan")
    _assert_true(card.is_attribute("wind") and card.is_attribute("forest"), "混元可同时满足不同属性条件")
    _assert_true(card.is_attribute("fire") and card.is_attribute("mountain"), "混元覆盖火山属性条件")
    _assert_equal(card.attribute, "wind", "混元不改变基础属性身份")

func _test_battle_consumable_reshape_persists_via_run_deck() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "跨战斗强化测试载入内容目录")
    var run_deck = RunDeckScript.new(catalog)
    run_deck.reset_standard("consumable-reshape")
    var default_growth = GrowthInventoryScript.new(catalog, false)
    var progress = RunProgressSnapshotScript.from_dict({
        "consumable_ids": ["zengyuan_pill"],
        "learned_technique_ids": default_growth.learned_technique_ids,
        "hand_technique_progression": (
            default_growth.hand_technique_progression),
        "run_deck": run_deck.to_snapshot(),
    })
    var first_battle: BattleSession = BattleSessionScript.new(
        _tracked_combat_engine())
    _assert_true(first_battle.setup_battle({"content_seed": 4404}, progress), "带增元丹的本局牌组可以进入战斗")
    first_battle.execute({"type": "start_turn"})
    var target = first_battle.engine.player.hand[0]
    var target_id := str(target.id)
    var reshape_result := first_battle.execute({
        "type": "use_consumable",
        "slot_index": 0,
        "card_ids": [target_id],
    })
    _assert_true(reshape_result.success, "战斗中可以使用消耗品重塑真气")
    _assert_equal(target.reshape_enhancement, "qi_boost", "战斗消耗品施加增元强化")
    var after_progress = first_battle.player_progress_snapshot()
    _assert_true(after_progress.consumable_ids.is_empty(), "战斗中使用消耗品后释放本局槽位")
    var second_battle = BattleSessionScript.new(_tracked_combat_engine())
    var second_loaded: bool = second_battle.setup_battle(
        {"content_seed": 4405}, after_progress)
    _assert_true(
        second_loaded,
        "重塑后的 RunDeck 可以建立下一场战斗：%s" % JSON.stringify(
            second_battle.engine.game_log.entries("system")))
    var restored = null
    for card in second_battle.engine.player.all_zone_cards():
        if card.id == target_id:
            restored = card
            break
    _assert_true(restored != null, "下一场战斗保留被消耗品重塑的真气实例")
    _assert_equal(restored.reshape_enhancement, "qi_boost", "战斗中施加的强化通过 RunDeck 跨战斗保存")
    _assert_true(restored.anomaly_snapshot()["marks"].is_empty(), "跨战斗重塑同步不会附带战斗异状")

func _test_consumable_effect_registry_contract() -> void:
    var registry = ConsumableEffectHandlerRegistryScript.new()
    _assert_equal(
        registry.operation_ids(),
        [
            "apply_enhancement", "apply_imprint", "apply_origin",
            "apply_origin_to_matching_rank", "apply_prepared_group_origin",
            "apply_random_enhancement", "apply_random_imprint",
            "copy_run_card", "duplicate_equipped_inner_skill",
            "gain_equipped_inner_skill_forget_value",
            "gain_experience_capped", "gain_insight",
            "generate_random_base_cards",
            "grant_last_used_consumable", "grant_random_consumables",
            "grant_random_inner_skill",
            "modify_base_hand_limit",
            "remove_run_cards", "remove_run_cards_for_experience",
            "rewrite_technique_progression", "set_experience",
        ],
        "默认注册正式消耗品操作")

    var duplicate_registry = ConsumableEffectHandlerRegistryScript.new(false)
    _assert_true(
        duplicate_registry.register_handler(ConsumableProbeHandler.new(["gain_insight"])),
        "空注册表可以注册首个探针")
    _assert_equal(
        duplicate_registry.register_handler(ConsumableProbeHandler.new(["gain_insight"])),
        false,
        "重复 op 注册被拒绝")
    _assert_true(
        _array_contains_text(duplicate_registry.registration_errors(), "重复注册：gain_insight"),
        "重复注册错误报告实际操作 ID")

    var invalid_registry = ConsumableEffectHandlerRegistryScript.new(false)
    _assert_equal(
        invalid_registry.register_handler(ConsumableProbeHandler.new(["Bad-ID"])),
        false,
        "非法 snake_case 操作 ID 被拒绝")
    _assert_true(
        _array_contains_text(invalid_registry.registration_errors(), "稳定 snake_case"),
        "非法 ID 错误说明稳定命名要求")

    var empty_registry = ConsumableEffectHandlerRegistryScript.new(false)
    _assert_equal(
        empty_registry.register_handler(ConsumableProbeHandler.new([])),
        false,
        "空操作列表被拒绝")

func _test_consumable_effect_validation_scope() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "消耗品校验测试基准内容有效")

    var unknown_op_values := _catalog_definitions(catalog)
    unknown_op_values["consumables"]["consumables"][0]["effects"] = [{"op": "unknown_op"}]
    var unknown_op_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_op_catalog.load_from_definitions(unknown_op_values),
        "未注册 op 使内容加载阶段明确失败")
    _assert_true(
        _array_contains_text(
            unknown_op_catalog.errors,
            "consumables.consumables[0].effects[0].op"),
        "未注册 op 错误报告完整 scope")
    _assert_true(
        _array_contains_text(unknown_op_catalog.errors, "unknown_op"),
        "未注册 op 错误包含操作名")

    var bad_hand_values := _catalog_definitions(catalog)
    bad_hand_values["consumables"]["consumables"][0]["effects"] = [
        {"op": "gain_insight", "hand": "not_a_hand", "pools": ["high"]}]
    var bad_hand_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_hand_catalog.load_from_definitions(bad_hand_values),
        "非法精确牌型引用在加载阶段失败")
    _assert_true(
        _array_contains_text(bad_hand_catalog.errors, "引用未知精确牌型 not_a_hand"),
        "非法牌型错误稳定定位")

    var bad_pool_values := _catalog_definitions(catalog)
    bad_pool_values["consumables"]["consumables"][0]["effects"] = [
        {"op": "gain_insight", "hand": "high_card", "pools": ["not_a_pool"]}]
    var bad_pool_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_pool_catalog.load_from_definitions(bad_pool_values),
        "非法功法池引用在加载阶段失败")
    _assert_true(
        _array_contains_text(bad_pool_catalog.errors, "引用未知功法池 not_a_pool"),
        "非法功法池错误稳定定位")

    var bad_enhancement_values := _catalog_definitions(catalog)
    bad_enhancement_values["consumables"]["consumables"][0]["effects"] = [
        {"op": "apply_enhancement", "enhancement": "not_real"}]
    var bad_enhancement_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_enhancement_catalog.load_from_definitions(bad_enhancement_values),
        "非法强化引用在加载阶段失败")
    _assert_true(
        _array_contains_text(bad_enhancement_catalog.errors, "引用未知强化 not_real"),
        "非法强化错误稳定定位")

    var bad_origin_values := _catalog_definitions(catalog)
    bad_origin_values["consumables"]["consumables"][0]["effects"] = [{
        "op": "apply_origin",
        "origin": "attribute_change",
        "payload": {"attribute": "not_real"},
    }]
    var bad_origin_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_origin_catalog.load_from_definitions(bad_origin_values),
        "转属引用非法基础属性时加载失败")
    _assert_true(
        _array_contains_text(bad_origin_catalog.errors, "引用未知基础属性 not_real"),
        "非法本源 payload 错误稳定定位")

func _test_run_consumable_zengyuan_pill() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77201}).success, "增元丹测试本局建立")
    session.growth.consumable_ids.append("zengyuan_pill")
    var query := session.execute({"type": "query_consumable_use", "slot_index": 0})
    _assert_true(query.success, "增元丹使用查询成功")
    _assert_equal(
        query.payload_value("targeting"),
        {"zone": "run_deck", "selection": "player_selected"},
        "增元丹目标协议为 run_deck/player_selected")
    _assert_equal(query.payload_value("selection"), "player_selected", "增元丹查询返回 selection")
    _assert_equal(query.payload_value("minimum"), 1, "增元丹最少选择一张")
    _assert_equal(query.payload_value("maximum"), 2, "增元丹至多选择两张")
    var targets: Array = query.payload_value("eligible_targets")
    _assert_equal(targets.size(), 52, "增元丹可选目标为完整 RunDeck")
    var first_target: Dictionary = targets[0]
    for field in ["instance_id", "card_id", "rank", "suit", "origin", "enhancement", "imprint", "others", "display_name"]:
        _assert_true(first_target.has(field), "增元丹可选目标包含字段 %s" % field)
    _assert_true(str(first_target["instance_id"]) != "", "可选目标携带稳定实例 ID")
    _assert_true(str(first_target["card_id"]) != "", "可选目标携带牌型 ID")
    _assert_equal(str(first_target["rank"]), "2", "可选目标携带点数")
    _assert_true(str(first_target["suit"]) != "", "可选目标携带属性")
    _assert_true(str(first_target["display_name"]) != "", "可选目标携带显示名称")

    var ids: Array = [first_target["instance_id"], targets[1]["instance_id"]]
    var use := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": ids})
    _assert_true(use.success, "增元丹选择两张真气成功")
    _assert_equal(
        str(session.growth.run_deck.card_data(str(ids[0]))["reshapes"]["enhancement"]),
        "qi_boost",
        "增元写入 RunDeck 第一张")
    _assert_equal(
        str(session.growth.run_deck.card_data(str(ids[1]))["reshapes"]["enhancement"]),
        "qi_boost",
        "增元写入 RunDeck 第二张")
    _assert_equal(session.growth.consumable_ids, [], "增元丹使用后释放槽位")

    var progress = session.progress_snapshot()
    var battle: BattleSession = BattleSessionScript.new(
        _tracked_combat_engine())
    _assert_true(battle.setup_battle({"content_seed": 77201}, progress), "携带增元的本局牌组进入战斗")
    battle.execute({"type": "start_turn"})
    var seen := false
    for card in battle.engine.player.all_zone_cards():
        if card.id != str(ids[0]):
            continue
        seen = true
        _assert_equal(card.reshape_enhancement, "qi_boost", "后续战斗装配能看到强化")
    _assert_true(seen, "被强化真气实例在战斗中出现")

func _test_run_consumable_origin_and_save() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77301}).success, "通用本源消耗品测试本局建立")
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "通用本源消耗品测试载入目录")
    session.growth.consumable_ids.append("high_card_insight")
    var service = ConsumableUseServiceScript.new(
        null, catalog, ContentValidatorScript.HAND_IDS, ContentValidatorScript.POOL_IDS)
    var definition := {
        "id": "high_card_insight",
        "targeting": {
            "zone": "run_deck", "selection": "player_selected",
            "minimum": 1, "maximum": 1},
        "effects": [{
            "op": "apply_origin",
            "origin": "attribute_change",
            "payload": {"attribute": "mountain"},
        }],
    }
    var used: Dictionary = service.use(
        session.growth, 0, ["wind_7"], 77301, definition)
    _assert_true(used.get("success", false), "统一消耗品 Handler 可施加转属本源")
    var changed: Dictionary = session.growth.run_deck.card_data("wind_7")
    _assert_equal(changed["definition_id"], "mountain_7", "消耗品转属更新基础定义")
    _assert_equal(changed["reshapes"]["origin"]["payload"], {"attribute": "mountain"}, "消耗品保存本源参数")
    var save = RunSaveDataScript.new().capture(session)
    var restored_dict: Dictionary = save.restore_session(catalog)
    _assert_true(restored_dict.get("success", false), "本源消耗品结果可以存档恢复")
    var restored: RunSession = restored_dict["run_session"]
    _assert_equal(
        restored.growth.run_deck.card_data("wind_7")["reshapes"]["origin"],
        changed["reshapes"]["origin"],
        "读档保留本源身份和锁定状态")

func _test_run_consumable_invalid_targets() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77401}).success, "非法目标测试本局建立")
    session.growth.consumable_ids.append("zengyuan_pill")
    var deck_ids: Array = session.growth.run_deck.cards_snapshot()
    var first_id := str(deck_ids[0]["instance_id"])
    var second_id := str(deck_ids[1]["instance_id"])

    var not_in_deck := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["ghost_card"]})
    _assert_true(not not_in_deck.success, "不属于 RunDeck 的目标明确失败")
    var duplicate := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [first_id, first_id]})
    _assert_true(not duplicate.success, "重复实例 ID 明确失败")
    var too_few := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(not too_few.success, "少于 minimum 明确失败")
    var too_many := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [first_id, second_id, str(deck_ids[2]["instance_id"])]})
    _assert_true(not too_many.success, "多于 maximum 明确失败")
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "随机目标拒绝手选测试内容目录有效")
    var service = ConsumableUseServiceScript.new(
        null, catalog, ContentValidatorScript.HAND_IDS, ContentValidatorScript.POOL_IDS)
    var random_definition: Dictionary = catalog.get_by_id("consumable", "zengyuan_pill")
    random_definition["targeting"]["selection"] = "deterministic_random"
    var manual_random := service.use(
        session.growth, 0, [first_id], 77401, random_definition)
    _assert_true(
        not manual_random.get("success", false),
        "deterministic_random 传入手动目标明确失败")
    _assert_true(
        str(manual_random.get("reason", "")).contains("不允许手动指定目标"),
        "deterministic_random 手动目标失败原因明确")
    _assert_equal(int(session.growth.consumable_use_sequence), 0, "非法目标失败不递增使用序号")
    _assert_equal(session.growth.consumable_ids, ["zengyuan_pill"], "非法目标失败不删除消耗品")
    for card in session.growth.run_deck.cards_snapshot():
        _assert_equal(str(card["reshapes"]["enhancement"]), "", "非法目标失败不改动牌组")

func _test_run_consumable_transaction_rollback() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77501}).success, "回滚测试本局建立")
    session.growth.experience = 50
    session.growth.consumable_ids.append("high_card_insight")
    session.growth.consumable_use_sequence = 3
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "回滚测试内容目录有效")

    var registry = ConsumableEffectHandlerRegistryScript.new()
    _assert_true(
        registry.register_handler(ConsumableProbeHandler.new(["test_gain"])),
        "成功探针注册")
    _assert_true(
        registry.register_handler(ConsumableProbeHandler.new(["test_fail"], true)),
        "失败探针注册")
    var service = ConsumableUseServiceScript.new(
        registry, catalog, ContentValidatorScript.HAND_IDS, ContentValidatorScript.POOL_IDS)

    var crafted_success := {
        "id": "high_card_insight",
        "targeting": {"zone": "none", "selection": "deterministic_random", "minimum": 0, "maximum": 0},
        "effects": [{"op": "test_gain", "amount": 5}],
    }
    var ok := service.use(session.growth, 0, [], 77501, crafted_success)
    _assert_true(ok.get("success", false), "探针效果成功路径通过事务")
    _assert_equal(session.growth.experience, 55, "探针效果按工作副本应用")
    _assert_equal(session.growth.consumable_ids, [], "成功后删除消耗品")
    _assert_equal(int(session.growth.consumable_use_sequence), 4, "成功后递增序号")

    session.growth.experience = 50
    session.growth.consumable_ids.append("high_card_insight")
    session.growth.last_recallable_consumable_id = "pair_insight"
    var state_before = session.growth.capture_mutation_state()
    var crafted_failing := {
        "id": "high_card_insight",
        "targeting": {"zone": "none", "selection": "deterministic_random", "minimum": 0, "maximum": 0},
        "effects": [
            {"op": "test_gain", "amount": 5},
            {"op": "test_fail", "amount": 7},
        ],
    }
    var failed := service.use(session.growth, 0, [], 77501, crafted_failing)
    _assert_true(not failed.get("success", false), "第一个效果成功、第二个效果失败时事务失败")
    _assert_equal(
        session.growth.capture_mutation_state(),
        state_before,
        "失败后历练、生命、库存、功法、牌组与随机序号全部不变")

func _test_run_consumable_failed_use_keeps_randomness() -> void:
    var session_a: RunSession = RunSessionScript.new()
    _assert_true(session_a.execute({"type": "setup_run", "seed": 77601}).success, "随机保持甲本局建立")
    session_a.growth.consumable_ids.append("zengyuan_pill")
    var target := str(session_a.growth.run_deck.cards_snapshot()[0]["instance_id"])
    var use_a := session_a.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [target]})
    _assert_true(use_a.success, "甲直接成功使用增元丹")
    var result_a := str(session_a.growth.run_deck.card_data(target)["reshapes"]["enhancement"])

    var session_b: RunSession = RunSessionScript.new()
    _assert_true(session_b.execute({"type": "setup_run", "seed": 77601}).success, "随机保持乙本局建立")
    session_b.growth.consumable_ids.append("zengyuan_pill")
    var failed := session_b.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["not_in_deck"]})
    _assert_true(not failed.success, "乙先发生一次失败操作")
    _assert_equal(int(session_b.growth.consumable_use_sequence), 0, "失败不递增序号")
    var use_b := session_b.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [target]})
    _assert_true(use_b.success, "乙随后合法使用成功")
    var result_b := str(session_b.growth.run_deck.card_data(target)["reshapes"]["enhancement"])
    _assert_equal(result_b, result_a, "失败后合法操作结果与没有发生失败操作时一致")

func _test_run_consumable_slot_release_order() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77701}).success, "槽位顺序测试本局建立")
    session.growth.consumable_ids.assign(["zengyuan_pill", "pair_insight", "high_card_insight"])
    var first_id := str(session.growth.run_deck.cards_snapshot()[0]["instance_id"])
    var use_zero := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [first_id]})
    _assert_true(use_zero.success, "使用 0 号槽成功")
    _assert_equal(
        session.growth.consumable_ids,
        ["pair_insight", "high_card_insight"],
        "0 号槽释放后其余槽位顺序保持")
    var use_one := session.execute({
        "type": "use_consumable", "slot_index": 1, "selected_instance_ids": []})
    _assert_true(use_one.success, "使用释放后的新 1 号槽成功")
    _assert_equal(
        session.growth.consumable_ids,
        ["pair_insight"],
        "心得释放后剩余槽位顺序保持")

func _test_s2f2f1_formal_pills_and_transactions() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F2F1 正式丹药内容目录有效")
    var pills: Array = []
    var insights: Array = []
    for definition in catalog.all_of("consumable"):
        match str(definition.get("kind", "")):
            "pill": pills.append(definition)
            "insight": insights.append(definition)
    _assert_equal(pills.size(), 23, "正式内容包含 23 种丹药")
    _assert_equal(insights.size(), 8, "正式内容包含 8 种心得")
    for definition in pills:
        _assert_equal(int(definition.get("price", -1)), 3, "%s 丹药价格为 3" % definition.get("name", ""))
        _assert_true(not str(definition.get("description", "")).is_empty(), "%s 描述非空" % definition.get("name", ""))
        _assert_true(not definition.get("effects", []).is_empty(), "%s 具有正式效果" % definition.get("name", ""))
        _assert_equal(str(definition.get("kind", "")), "pill", "%s 使用 pill 类型" % definition.get("name", ""))

    var target_session: RunSession = RunSessionScript.new()
    _assert_true(target_session.execute({"type": "setup_run", "seed": 880101}).success, "资格查询本局建立")
    target_session.growth.run_deck.apply_card_origin(
        ["wind_3"], "attribute_change", {"attribute": "mountain"})
    target_session.growth.consumable_ids.assign(["shengjie_pill"])
    var up_query := target_session.execute({"type": "query_consumable_use", "slot_index": 0})
    var up_ids := _target_ids(up_query.payload_value("eligible_targets"))
    _assert_true(up_ids.has("wind_K"), "升阶丹显示 K")
    _assert_true(not up_ids.has("wind_A"), "升阶丹不显示 A")
    _assert_true(not up_ids.has("wind_3"), "升阶丹不显示已有本源真气")
    var illegal_up := target_session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["wind_A"],
    })
    _assert_true(not illegal_up.success, "服务端重新拒绝 A 升阶")
    var legal_up := target_session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["wind_K"],
    })
    _assert_true(legal_up.success, "K 可以升阶")
    _assert_equal(target_session.growth.run_deck.card_data("wind_K")["rank_name"], "A", "升阶实测 K→A")

    var down_first: RunSession = RunSessionScript.new()
    var down_second: RunSession = RunSessionScript.new()
    for session in [down_first, down_second]:
        _assert_true(session.execute({"type": "setup_run", "seed": 880102}).success, "降阶确定性本局建立")
        session.growth.consumable_ids.assign(["jiangjie_pill"])
    var down_query := down_first.execute({"type": "query_consumable_use", "slot_index": 0})
    var down_ids := _target_ids(down_query.payload_value("eligible_targets"))
    _assert_true(down_ids.has("wind_A"), "降阶丹显示 A")
    _assert_true(not down_ids.has("wind_2"), "降阶丹不显示 2")
    var down_targets := ["wind_A", "forest_K"]
    var down_result_first := down_first.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": down_targets,
    })
    var down_result_second := down_second.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": down_targets,
    })
    _assert_true(down_result_first.success and down_result_second.success, "两张真气降阶成功")
    _assert_equal(down_first.growth.run_deck.card_data("wind_A")["rank_name"], "K", "降阶实测 A→K")
    var first_enhancements: Array[String] = []
    var second_enhancements: Array[String] = []
    for instance_id in down_targets:
        first_enhancements.append(str(down_first.growth.run_deck.card_data(instance_id)["reshapes"]["enhancement"]))
        second_enhancements.append(str(down_second.growth.run_deck.card_data(instance_id)["reshapes"]["enhancement"]))
    _assert_true(first_enhancements.all(func(value): return value != ""), "降阶后每张牌分别获得随机强化")
    _assert_equal(first_enhancements, second_enhancements, "相同种子降阶随机强化一致")

    var qiling: RunSession = RunSessionScript.new()
    _assert_true(qiling.execute({"type": "setup_run", "seed": 880103}).success, "启灵丹本局建立")
    qiling.growth.consumable_ids.assign(["qiling_pill"])
    var qiling_before: Dictionary = qiling.growth.run_deck.card_data("forest_7")
    var qiling_use := qiling.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["forest_7"],
    })
    _assert_true(qiling_use.success, "启灵丹使用成功")
    var qiling_after: Dictionary = qiling.growth.run_deck.card_data("forest_7")
    _assert_equal(qiling_after["reshapes"]["origin"]["payload"]["attribute"], "forest", "觉醒读取目标当前基础属性")
    for field in ["rank_name", "attribute", "qi_value"]:
        _assert_equal(qiling_after[field], qiling_before[field], "启灵不改变基础字段 %s" % field)

    var attribute_pills := {
        "shanxiang_pill": "mountain",
        "linxiang_pill": "forest",
        "huoxiang_pill": "fire",
        "fengxiang_pill": "wind",
    }
    for pill_id in attribute_pills:
        var attribute_session: RunSession = RunSessionScript.new()
        _assert_true(attribute_session.execute({"type": "setup_run", "seed": 880104}).success, "%s 本局建立" % pill_id)
        attribute_session.growth.consumable_ids.assign([pill_id])
        var before: Dictionary = attribute_session.growth.run_deck.card_data("wind_8")
        var used := attribute_session.execute({
            "type": "use_consumable", "slot_index": 0,
            "selected_instance_ids": ["wind_8"],
        })
        _assert_true(used.success, "%s 使用成功" % pill_id)
        var after: Dictionary = attribute_session.growth.run_deck.card_data("wind_8")
        _assert_equal(after["attribute"], attribute_pills[pill_id], "%s 转属正确" % pill_id)
        _assert_equal(after["rank_name"], before["rank_name"], "%s 不改变牌阶" % pill_id)
        _assert_equal(after["qi_value"], before["qi_value"], "%s 不改变基础真气" % pill_id)

    var collection: RunSession = RunSessionScript.new()
    _assert_true(collection.execute({"type": "setup_run", "seed": 880105}).success, "牌组操作本局建立")
    collection.growth.run_deck.apply_card_origin(
        ["fire_9"], "awakening", {})
    collection.growth.run_deck.apply_card_reshape(
        "fire_9", "enhancement", "momentum")
    collection.growth.run_deck.apply_card_reshape(
        "fire_9", "imprint", "echo")
    var source_before: Dictionary = collection.growth.run_deck.card_data("fire_9")
    collection.growth.consumable_ids.assign(["yanyuan_pill"])
    var copy_use := collection.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["fire_9"],
    })
    _assert_true(copy_use.success, "衍元丹完整复制成功")
    var copy_id := str(copy_use.payload_value("applied")[0]["instance_ids"][0])
    _assert_true(copy_id != "fire_9", "复制真气使用新实例 ID")
    _assert_equal(collection.growth.run_deck.card_data(copy_id)["reshapes"], source_before["reshapes"], "复制继承全部持久重塑")
    _assert_equal(collection.growth.run_deck.card_data("fire_9"), source_before, "复制不改变源牌")
    collection.growth.consumable_ids.assign(["sanyuan_pill"])
    var count_before: int = collection.growth.run_deck.card_count()
    var remove_use := collection.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [copy_id],
    })
    _assert_true(remove_use.success, "散元丹永久移出成功")
    _assert_equal(collection.growth.run_deck.card_count(), count_before - 1, "散元丹减少牌组实例")
    _assert_true(not collection.growth.run_deck.has_card(copy_id), "被散元丹移出的实例不再存在")

    for grant_case in [
        ["wanhua_pill", "pill"],
        ["tongwu_pill", "insight"],
    ]:
        var grant_session: RunSession = RunSessionScript.new()
        _assert_true(grant_session.execute({"type": "setup_run", "seed": 880106}).success, "%s 满栏本局建立" % grant_case[0])
        grant_session.growth.consumable_ids.assign([
            "pair_insight", grant_case[0]])
        var grant_use := grant_session.execute({
            "type": "use_consumable", "slot_index": 1,
            "selected_instance_ids": [],
        })
        _assert_true(grant_use.success, "%s 满栏时利用自身释放栏位" % grant_case[0])
        _assert_equal(grant_session.growth.consumable_ids.size(), 2, "%s 提交后仍不超过有效容量" % grant_case[0])
        var granted_id := str(grant_use.payload_value("applied")[0]["consumable_ids"][0])
        _assert_equal(catalog.get_by_id("consumable", granted_id)["kind"], grant_case[1], "%s 只从对应正式池抽取" % grant_case[0])
        if grant_case[0] == "wanhua_pill":
            _assert_true(granted_id != "wanhua_pill", "万化丹排除自身")

    var recall_empty: RunSession = RunSessionScript.new()
    _assert_true(recall_empty.execute({"type": "setup_run", "seed": 880107}).success, "无溯忆记录本局建立")
    recall_empty.growth.consumable_ids.assign(["suyi_pill"])
    var empty_query := recall_empty.execute({"type": "query_consumable_use", "slot_index": 0})
    _assert_true(not empty_query.payload_value("can_use"), "无最近记录时溯忆丹不可用")
    var empty_use := recall_empty.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [],
    })
    _assert_true(not empty_use.success, "无记录使用溯忆丹失败")
    _assert_equal(recall_empty.growth.consumable_ids, ["suyi_pill"], "失败不消耗溯忆丹")

    var recall: RunSession = RunSessionScript.new()
    _assert_true(recall.execute({"type": "setup_run", "seed": 880108}).success, "溯忆记录本局建立")
    recall.growth.consumable_ids.assign(["zengyuan_pill"])
    _assert_true(recall.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["wind_4"],
    }).success, "先成功使用增元丹")
    _assert_equal(recall.growth.last_recallable_consumable_id, "zengyuan_pill", "成功提交后记录最近丹药")
    recall.growth.consumable_ids.assign(["suyi_pill"])
    _assert_true(recall.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [],
    }).success, "溯忆丹生成最近丹药")
    _assert_equal(recall.growth.consumable_ids, ["zengyuan_pill"], "溯忆丹用自身释放栏位保存生成内容")
    _assert_equal(recall.growth.last_recallable_consumable_id, "zengyuan_pill", "溯忆丹自身不覆盖最近记录")

    var recall_insight: RunSession = RunSessionScript.new()
    _assert_true(recall_insight.execute({"type": "setup_run", "seed": 880112}).success, "心得溯忆本局建立")
    recall_insight.growth.consumable_ids.assign(["pair_insight"])
    _assert_true(recall_insight.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [],
    }).success, "心得成功使用并提交")
    _assert_equal(recall_insight.growth.last_recallable_consumable_id, "pair_insight", "最近记录可以保存心得")
    recall_insight.growth.consumable_ids.assign(["suyi_pill"])
    _assert_true(recall_insight.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [],
    }).success, "溯忆丹可以生成最近心得")
    _assert_equal(recall_insight.growth.consumable_ids, ["pair_insight"], "溯忆生成最近使用心得")

    for experience_case in [[7, 14], [20, 40], [35, 55]]:
        var experience_session: RunSession = RunSessionScript.new()
        _assert_true(experience_session.execute({"type": "setup_run", "seed": 880109}).success, "聚功丹历练样例本局建立")
        experience_session.growth.experience = experience_case[0]
        experience_session.growth.consumable_ids.assign(["jugong_pill"])
        _assert_true(experience_session.execute({
            "type": "use_consumable", "slot_index": 0,
            "selected_instance_ids": [],
        }).success, "聚功丹样例使用成功")
        _assert_equal(experience_session.growth.experience, experience_case[1], "聚功丹 %d→%d" % experience_case)

    var fixture_values := _catalog_definitions(catalog)
    fixture_values["inner_skills"]["version"] = 2
    fixture_values["inner_skills"]["inner_skills"].append_array([
        {
            "id": "forget_fixture_a", "name": "遗忘甲", "status": "candidate",
            "forget_value": 30,
            "behaviors": [{"id": "on_play_effects", "configuration": {
                "effects": [{"op": "defense", "amount": {"kind": "constant", "value": 1}}]} }],
        },
        {
            "id": "forget_fixture_b", "name": "遗忘乙", "status": "candidate",
            "forget_value": 35,
            "behaviors": [{"id": "on_play_effects", "configuration": {
                "effects": [{"op": "defense", "amount": {"kind": "constant", "value": 1}}]} }],
        },
    ])
    var fixture_catalog = ContentCatalogScript.new()
    _assert_true(fixture_catalog.load_from_definitions(fixture_values), "带遗忘所得的内功 fixture 有效")
    var service = ConsumableUseServiceScript.new(
        fixture_catalog.consumable_effect_registry,
        fixture_catalog,
        ContentValidatorScript.HAND_IDS,
        ContentValidatorScript.POOL_IDS)
    var nagong_growth = GrowthInventoryScript.new(fixture_catalog)
    nagong_growth.experience = 5
    nagong_growth.learned_inner_skill_ids.assign(["forget_fixture_a", "forget_fixture_b"])
    nagong_growth.equipped_inner_skill_ids.assign(["forget_fixture_a", "forget_fixture_b"])
    nagong_growth.consumable_ids.assign(["nagong_pill"])
    var equipped_before: Array[String] = nagong_growth.equipped_inner_skill_ids.duplicate()
    var nagong_use: Dictionary = service.use(
        nagong_growth, 0, [], 880110,
        fixture_catalog.get_by_id("consumable", "nagong_pill"))
    _assert_true(nagong_use.get("success", false), "纳功丹使用成功")
    _assert_equal(nagong_growth.experience, 55, "纳功丹遗忘所得求和后 50 封顶")
    _assert_equal(nagong_growth.equipped_inner_skill_ids, equipped_before, "纳功丹不卸下内功")

    var chuangong_growth = GrowthInventoryScript.new(fixture_catalog)
    chuangong_growth.learned_inner_skill_ids.assign(
        fixture_catalog.all_of("inner_skill").map(
            func(definition): return str(definition.get("id", ""))).filter(
                func(inner_skill_id): return inner_skill_id != "forget_fixture_b"))
    chuangong_growth.consumable_ids.assign(["chuangong_pill"])
    var equipped_count_before: int = chuangong_growth.equipped_inner_skill_ids.size()
    var chuangong_use: Dictionary = service.use(
        chuangong_growth, 0, [], 880111,
        fixture_catalog.get_by_id("consumable", "chuangong_pill"))
    _assert_true(chuangong_use.get("success", false), "传功丹获得唯一未习得内功")
    _assert_true(chuangong_growth.learned_inner_skill_ids.has("forget_fixture_b"), "传功丹加入本局内功库")
    _assert_equal(chuangong_growth.equipped_inner_skill_ids.size(), equipped_count_before, "传功丹不自动装备")

func _test_s2f2f2_formal_curios_and_protocols() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F2F2 正式奇珍内容目录有效")
    var curios: Array = []
    for definition in catalog.all_of("consumable"):
        if str(definition.get("kind", "")) == "curio":
            curios.append(definition)
    _assert_equal(curios.size(), 17, "正式内容包含 17 种奇珍")
    for definition in curios:
        _assert_equal(int(definition.get("price", -1)), 4, "%s 奇珍价格为 4" % definition.get("name", ""))
        _assert_equal(bool(definition.get("unique", false)), true, "%s 使用唯一奇珍协议" % definition.get("name", ""))
        _assert_equal(bool(definition.get("record_last_used", true)), false, "%s 不进入溯忆记录" % definition.get("name", ""))

    var generation_cases := [
        {"id": "zhenyuan_huasheng", "count": 3, "ranks": ["J", "Q", "K"], "net": 2},
        {"id": "shuangji_huasheng", "count": 2, "ranks": ["A"], "net": 1},
        {"id": "fanshu_huasheng", "count": 4, "ranks": ["2", "3", "4", "5", "6", "7", "8", "9", "10"], "net": 3},
    ]
    for generation_case in generation_cases:
        var session: RunSession = RunSessionScript.new()
        _assert_true(session.execute({"type": "setup_run", "seed": 99101}).success, "%s 本局建立" % generation_case["id"])
        session.growth.consumable_ids.assign([generation_case["id"]])
        var before_count: int = session.growth.run_deck.card_count()
        var result := session.execute({"type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
        _assert_true(result.success, "%s 使用成功" % generation_case["id"])
        _assert_equal(session.growth.run_deck.card_count(), before_count + int(generation_case["net"]), "%s 牌数净变化正确" % generation_case["id"])
        var generated: Array = result.payload_value("applied")[1]["generated"]
        _assert_equal(generated.size(), generation_case["count"], "%s 生成数量正确" % generation_case["id"])
        for generated_card in generated:
            var values: Dictionary = session.growth.run_deck.card_data(str(generated_card["instance_id"]))
            _assert_true(generation_case["ranks"].has(str(values["rank_name"])), "%s 只从指定牌阶池生成" % generation_case["id"])
            _assert_true(["wind", "forest", "fire", "mountain"].has(str(values["attribute"])), "%s 使用正式属性" % generation_case["id"])
            _assert_true(str(values["reshapes"]["enhancement"]) != "", "%s 每张生成牌各有随机强化" % generation_case["id"])

    var imprint_cases := {
        "xiantian_fu": "innate",
        "huixiang_fu": "echo",
        "wudao_fu": "enlightenment",
        "huadan_fu": "alchemy",
    }
    for curio_id in imprint_cases:
        var session: RunSession = RunSessionScript.new()
        _assert_true(session.execute({"type": "setup_run", "seed": 99102}).success, "%s 本局建立" % curio_id)
        session.growth.consumable_ids.assign([curio_id])
        _assert_true(session.execute({
            "type": "use_consumable", "slot_index": 0,
            "selected_instance_ids": ["wind_5"],
        }).success, "%s 使用成功" % curio_id)
        _assert_equal(session.growth.run_deck.card_data("wind_5")["reshapes"]["imprint"], imprint_cases[curio_id], "%s 印记正确" % curio_id)

    for prepared_id in ["zhuanxiang_lun", "yijie_pan"]:
        var prepared_session: RunSession = RunSessionScript.new()
        _assert_true(prepared_session.execute({"type": "setup_run", "seed": 99103}).success, "%s 预览本局建立" % prepared_id)
        prepared_session.growth.consumable_ids.assign([prepared_id])
        var state_before_queries: Dictionary = (
            prepared_session.growth.capture_mutation_state())
        var query_a := prepared_session.execute({"type": "query_consumable_use", "slot_index": 0})
        var query_b := prepared_session.execute({"type": "query_consumable_use", "slot_index": 0})
        _assert_equal(query_a.payload_value("prepared_preview"), query_b.payload_value("prepared_preview"), "%s 重复查询冻结结果一致" % prepared_id)
        _assert_equal(query_a.payload_value("preparation_token"), query_b.payload_value("preparation_token"), "%s 重复查询 token 一致" % prepared_id)
        _assert_equal(prepared_session.growth.consumable_use_sequence, 0, "%s 查询不递增随机序号" % prepared_id)
        _assert_equal(prepared_session.growth.capture_mutation_state(), state_before_queries, "%s 查询不修改完整本局状态" % prepared_id)
        var token := str(query_a.payload_value("preparation_token"))
        var preview: Dictionary = query_a.payload_value("prepared_preview")
        var use := prepared_session.execute({
            "type": "use_consumable", "slot_index": 0,
            "selected_instance_ids": [],
            "choice_payload": {"preparation_token": token},
        })
        _assert_true(use.success, "%s 使用冻结预览成功" % prepared_id)
        _assert_equal(use.payload_value("prepared_preview"), preview, "%s 正式执行复用展示结果" % prepared_id)
        var prepared_result: Dictionary = preview.get("effects", [])[0].get(
            "result", {})
        for target_preview in prepared_result.get("targets", []):
            _assert_equal(
                prepared_session.growth.run_deck.card_data(
                    str(target_preview.get("instance_id", ""))),
                target_preview.get("after", {}),
                "%s 牌组实际改造与冻结预览一致" % prepared_id)
        if prepared_id == "yijie_pan":
            _assert_equal(prepared_session.growth.base_hand_limit_modifier, -1, "易阶盘基础手牌上限 -1")

    var stale_session: RunSession = RunSessionScript.new()
    _assert_true(stale_session.execute({"type": "setup_run", "seed": 99104}).success, "失效 token 本局建立")
    stale_session.growth.consumable_ids.assign(["zhuanxiang_lun"])
    var stale_query := stale_session.execute({"type": "query_consumable_use", "slot_index": 0})
    var stale_sequence: int = stale_session.growth.consumable_use_sequence
    stale_session.growth.experience += 1
    var stale_state_before_use: Dictionary = stale_session.growth.capture_mutation_state()
    var stale_use := stale_session.execute({
        "type": "use_consumable", "slot_index": 0,
        "choice_payload": {"preparation_token": stale_query.payload_value("preparation_token")},
    })
    _assert_true(not stale_use.success, "状态变化后冻结 token 明确失效")
    _assert_equal(stale_session.growth.consumable_use_sequence, stale_sequence, "失效 token 不递增随机序号")
    _assert_equal(stale_session.growth.consumable_ids, ["zhuanxiang_lun"], "失效 token 不消耗奇珍")
    _assert_equal(stale_session.growth.capture_mutation_state(), stale_state_before_use, "失效 token 不修改当前本局状态")

    var burn: RunSession = RunSessionScript.new()
    _assert_true(burn.execute({"type": "setup_run", "seed": 99105}).success, "焚元祭本局建立")
    burn.growth.consumable_ids.assign(["fenyuan_ji"])
    var burn_before: int = burn.growth.run_deck.card_count()
    var burn_result := burn.execute({"type": "use_consumable", "slot_index": 0})
    _assert_true(burn_result.success, "焚元祭使用成功")
    _assert_equal(burn.growth.run_deck.card_count(), burn_before - 5, "焚元祭最多移出 5 张")
    _assert_equal(burn.growth.experience, 20, "焚元祭每张 4 点且最多 20 点")

    var small_burn: RunSession = RunSessionScript.new()
    _assert_true(small_burn.execute({"type": "setup_run", "seed": 991051}).success, "小牌组焚元祭本局建立")
    _assert_true(small_burn.growth.run_deck.reset_from_card_ids(
        ["wind_2", "forest_3", "fire_4"], "small-burn").is_empty(),
        "小牌组焚元祭测试牌组有效")
    small_burn.growth.consumable_ids.assign(["fenyuan_ji"])
    _assert_true(small_burn.execute({
        "type": "use_consumable", "slot_index": 0,
    }).success, "小牌组焚元祭使用成功")
    _assert_equal(small_burn.growth.run_deck.card_count(), 0, "焚元祭不足 5 张时按实际牌数移出")
    _assert_equal(small_burn.growth.experience, 12, "焚元祭不足 5 张时按实际数量获得历练")

    var mirror: RunSession = RunSessionScript.new()
    _assert_true(mirror.execute({"type": "setup_run", "seed": 99106}).success, "衍元镜本局建立")
    mirror.growth.run_deck.apply_card_reshape("fire_8", "enhancement", "momentum")
    mirror.growth.run_deck.apply_card_reshape("fire_8", "imprint", "echo")
    mirror.growth.consumable_ids.assign(["yanyuan_jing"])
    var mirror_result := mirror.execute({"type": "use_consumable", "slot_index": 0, "selected_instance_ids": ["fire_8"]})
    _assert_true(mirror_result.success, "衍元镜生成两个完整复制")
    var mirror_ids: Array = mirror_result.payload_value("applied")[0]["instance_ids"]
    _assert_equal(mirror_ids.size(), 2, "衍元镜复制数量为 2")
    _assert_true(mirror_ids[0] != mirror_ids[1], "衍元镜副本实例 ID 各不相同")
    for mirror_id in mirror_ids:
        _assert_equal(mirror.growth.run_deck.card_data(str(mirror_id))["reshapes"], mirror.growth.run_deck.card_data("fire_8")["reshapes"], "衍元镜完整继承重塑")

    var perfect: RunSession = RunSessionScript.new()
    _assert_true(perfect.execute({"type": "setup_run", "seed": 99107}).success, "圆满淬炼本局建立")
    perfect.growth.run_deck.apply_card_reshape("mountain_6", "enhancement", "momentum")
    perfect.growth.run_deck.apply_card_reshape("mountain_6", "imprint", "echo")
    perfect.growth.consumable_ids.assign(["yuanman_cuilian"])
    _assert_true(perfect.execute({"type": "use_consumable", "slot_index": 0, "selected_instance_ids": ["mountain_6"]}).success, "圆满淬炼使用成功")
    var perfect_card: Dictionary = perfect.growth.run_deck.card_data("mountain_6")
    _assert_equal(perfect_card["reshapes"]["enhancement"], "momentum", "圆满淬炼不替换已有强化")
    _assert_equal(perfect_card["reshapes"]["imprint"], "echo", "圆满淬炼不替换已有印记")
    _assert_equal(perfect_card["reshapes"]["origin"]["id"], "awakening", "圆满淬炼施加觉醒")

    var resonance: RunSession = RunSessionScript.new()
    _assert_true(resonance.execute({"type": "setup_run", "seed": 99108}).success, "同阶共鸣本局建立")
    resonance.growth.consumable_ids.assign(["tongjie_gongming"])
    var rank_three_before: Array[String] = []
    for values in resonance.growth.run_deck.cards_snapshot():
        if str(values["rank_name"]) == "3":
            rank_three_before.append(str(values["instance_id"]))
    _assert_true(resonance.execute({
        "type": "use_consumable", "slot_index": 0,
        "choice_payload": {"rank": "3"},
    }).success, "同阶共鸣选择 3 成功")
    for instance_id in rank_three_before:
        _assert_equal(resonance.growth.run_deck.card_data(instance_id)["reshapes"]["origin"]["id"], "awakening", "同阶共鸣觉醒全部既有 3")
    _assert_true(resonance.growth.run_deck.card_data("wind_4")["reshapes"]["origin"].is_empty(), "同阶共鸣不影响其他牌阶")

    var guixu: RunSession = RunSessionScript.new()
    _assert_true(guixu.execute({"type": "setup_run", "seed": 99109}).success, "归墟本局建立")
    guixu.growth.consumable_ids.assign(["guixu"])
    var removals: Dictionary = {}
    for hand_id in GrowthInventoryScript.HAND_IDS:
        removals[hand_id] = []
    var guixu_result := guixu.execute({
        "type": "use_consumable", "slot_index": 0,
        "choice_payload": {"removed_technique_ids_by_hand": removals},
    })
    _assert_true(guixu_result.success, "归墟按玩家选择移出超槽功法")
    var expected_modifiers := {"high_card": 1, "pair": 1, "two_pair": 1, "three_kind": 2, "straight": 2, "full_house": 2, "four_kind": 4, "five_kind": 6}
    for hand_id in GrowthInventoryScript.HAND_IDS:
        _assert_equal(guixu.growth.hand_technique_progression[hand_id]["slot_count"], 1, "归墟 %s 槽位最低为 1" % hand_id)
        _assert_equal(guixu.growth.hand_technique_progression[hand_id]["sequence"], ["basic_scatter"], "归墟 %s 保持完整序列" % hand_id)
        _assert_equal(guixu.growth.hand_technique_multiplier_modifiers[hand_id], expected_modifiers[hand_id], "归墟 %s 倍率修正正确" % hand_id)
        for technique_id in removals[hand_id]:
            _assert_true(guixu.growth.learned_technique_ids.has(technique_id), "归墟移出序列但保留功法库")

    guixu.growth.base_hand_limit_modifier = -1
    var battle = BattleSessionScript.new(
        _tracked_combat_engine(null, catalog))
    _assert_true(battle.setup_battle({"content_seed": 99109, "battle": {"use_enemy_ai": false}}, guixu.progress_snapshot()), "奇珍本局规则可装配下一场战斗")
    _assert_equal(battle.engine.player.current_hand_limit(), 7, "下一场战斗读取易阶盘基础手牌上限")
    battle.engine.player.hand = [_card("5", "wind")]
    var guixu_preview: Dictionary = battle.preview([battle.engine.player.hand[0].id])
    _assert_equal(guixu_preview["values"]["baseline_value"], 5, "归墟不改变牌型 baseline_value")
    _assert_equal(guixu_preview["values"]["technique_multiplier"], 2, "归墟只将 +1 加入高牌 technique_multiplier")

    var no_rarity: RunSession = RunSessionScript.new()
    _assert_true(no_rarity.execute({"type": "setup_run", "seed": 99111}).success, "稀有内功空候选本局建立")
    for definition in catalog.all_of("inner_skill"):
        if str(definition.get("rarity", "")) == "rare":
            no_rarity.growth.learned_inner_skill_ids.append(
                str(definition.get("id", "")))
    no_rarity.growth.consumable_ids.assign(["qingshen_qi"])
    _assert_true(not no_rarity.execute({"type": "query_consumable_use", "slot_index": 0}).payload_value("can_use"), "没有稀有内功候选时请神契不可用")

    var fixture_values := _catalog_definitions(catalog)
    fixture_values["inner_skills"]["version"] = 2
    fixture_values["inner_skills"]["inner_skills"].append_array([
        {"id": "rare_curio_fixture", "name": "稀有奇珍测试内功", "status": "candidate", "rarity": "rare", "behaviors": [{"id": "on_play_effects", "configuration": {"effects": [{"op": "defense", "amount": {"kind": "constant", "value": 1}}]}}]},
        {"id": "legendary_curio_fixture", "name": "传奇奇珍测试内功", "status": "candidate", "rarity": "legendary", "behaviors": [{"id": "on_play_effects", "configuration": {"effects": [{"op": "defense", "amount": {"kind": "constant", "value": 1}}]}}]},
    ])
    var fixture_catalog = ContentCatalogScript.new()
    _assert_true(fixture_catalog.load_from_definitions(fixture_values), "奇珍内功 rarity fixture 有效")
    var fixture_service = ConsumableUseServiceScript.new(
        fixture_catalog.consumable_effect_registry, fixture_catalog,
        ContentValidatorScript.HAND_IDS, ContentValidatorScript.POOL_IDS)
    for rarity_case in [["qingshen_qi", "rare_curio_fixture", 0], ["tianshou_zhenjing", "legendary_curio_fixture", 9]]:
        var rarity_growth = GrowthInventoryScript.new(fixture_catalog)
        rarity_growth.experience = 9
        rarity_growth.consumable_ids.assign([rarity_case[0]])
        var learned_before: Array[String] = \
            rarity_growth.learned_inner_skill_ids.duplicate()
        var rarity_use: Dictionary = fixture_service.use(
            rarity_growth, 0, [], 99112,
            fixture_catalog.get_by_id("consumable", rarity_case[0]))
        _assert_true(rarity_use.get("success", false), "%s 从指定 rarity 获得内功" % rarity_case[0])
        var newly_learned: Array = rarity_growth.learned_inner_skill_ids.filter(
            func(inner_skill_id): return not learned_before.has(inner_skill_id))
        var expected_rarity := "rare" if rarity_case[0] == "qingshen_qi" \
            else "legendary"
        _assert_true(
            newly_learned.size() == 1 \
                and str(fixture_catalog.get_by_id(
                    "inner_skill", str(newly_learned[0])).get(
                        "rarity", "")) == expected_rarity,
            "%s 不跨 rarity 抽取" % rarity_case[0])
        _assert_equal(rarity_growth.experience, rarity_case[2], "%s 历练代价正确" % rarity_case[0])

    var lineage_growth = GrowthInventoryScript.new(fixture_catalog)
    lineage_growth.learned_inner_skill_ids.assign(["extra_qi_to_defense", "rare_curio_fixture", "legendary_curio_fixture"])
    lineage_growth.equipped_inner_skill_ids.assign(["extra_qi_to_defense"])
    lineage_growth.consumable_ids.assign(["yimai_zhenchuan"])
    var lineage_use: Dictionary = fixture_service.use(
        lineage_growth, 0, [], 99113,
        fixture_catalog.get_by_id("consumable", "yimai_zhenchuan"))
    _assert_true(lineage_use.get("success", false), "一脉真传使用成功")
    _assert_equal(lineage_growth.learned_inner_skill_ids, ["extra_qi_to_defense", "extra_qi_to_defense"], "一脉真传内功库使用 multiset 双副本")
    _assert_equal(lineage_growth.equipped_inner_skill_ids, ["extra_qi_to_defense", "extra_qi_to_defense"], "一脉真传原件与副本都保持装备")
    _assert_equal(lineage_growth.experience, 0, "一脉真传清理不产生遗忘所得")
    _assert_equal(lineage_growth.forgotten_inner_skill_count, 0, "一脉真传永久清理不计入普通遗忘累计")

    var save = RunSaveDataScript.new().capture(guixu)
    guixu.growth.used_unique_consumable_ids.append("yijie_pan")
    save.capture(guixu)
    var restored: Dictionary = save.restore_session()
    _assert_true(restored.get("success", false), "奇珍本局字段存档恢复成功")
    var restored_growth = restored["run_session"].growth
    _assert_equal(restored_growth.base_hand_limit_modifier, -1, "存档保留基础手牌上限修正")
    _assert_equal(restored_growth.hand_technique_multiplier_modifiers, expected_modifiers, "存档保留功法倍率修正")
    _assert_true(restored_growth.used_unique_consumable_ids.has("guixu") and restored_growth.used_unique_consumable_ids.has("yijie_pan"), "存档保留已用唯一奇珍")
    var legacy_values: Dictionary = save.to_dict()
    legacy_values["growth"].erase("base_hand_limit_modifier")
    legacy_values["growth"].erase("hand_technique_multiplier_modifiers")
    legacy_values["growth"].erase("used_unique_consumable_ids")
    var legacy := RunSaveDataScript.new(legacy_values).restore_session()
    _assert_true(legacy.get("success", false), "旧存档缺少奇珍字段仍可载入")
    _assert_equal(legacy["run_session"].growth.base_hand_limit_modifier, 0, "旧存档手牌上限修正默认 0")

    var unique: RunSession = RunSessionScript.new()
    _assert_true(unique.execute({"type": "setup_run", "seed": 99110}).success, "唯一奇珍本局建立")
    unique.growth.consumable_ids.assign(["xiantian_fu", "xiantian_fu"])
    _assert_true(unique.execute({"type": "use_consumable", "slot_index": 0, "selected_instance_ids": ["wind_2"]}).success, "唯一奇珍首次使用成功")
    var unique_sequence: int = unique.growth.consumable_use_sequence
    _assert_true(not unique.execute({"type": "use_consumable", "slot_index": 0, "selected_instance_ids": ["wind_3"]}).success, "同一种唯一奇珍第二次被拒绝")
    _assert_equal(unique.growth.consumable_use_sequence, unique_sequence, "唯一奇珍重复失败不递增序号")

func _target_ids(targets: Array) -> Array[String]:
    var result: Array[String] = []
    for target in targets:
        if target is Dictionary:
            result.append(str(target.get("instance_id", "")))
    return result

func _test_run_consumable_phase_gate() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77801}).success, "阶段门禁测试本局建立")
    session.growth.consumable_ids.append("high_card_insight")
    var available: Array = session.snapshot().available_node_ids
    _assert_true(
        session.execute({"type": "begin_node", "node_id": str(available[0])}).success,
        "进入节点")
    var in_progress := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(not in_progress.success, "节点执行中不能使用消耗品")
    _assert_true(_complete_current_node_for_test(session).success, "完成节点进入奖励")
    var reward_phase := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(not reward_phase.success, "奖励阶段不能使用消耗品")
    _assert_true(session.execute({"type": "claim_reward", "bundle_id": ""}).success, "领取奖励")
    var ready := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(ready.success, "地图待选阶段可以使用消耗品")

func _test_run_consumable_save_round_trip() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77901}).success, "存档往返测试本局建立")
    session.growth.consumable_ids.assign(["zengyuan_pill", "high_card_insight"])
    var deck_snapshot: Array = session.growth.run_deck.cards_snapshot()
    var reshaped_id := str(deck_snapshot[3]["instance_id"])
    var applied = session.growth.run_deck.apply_card_reshape(
        reshaped_id, "enhancement", "momentum")
    _assert_true(applied.get("success", false), "测试牌组先完成一次重塑")
    var boosted_id := str(deck_snapshot[0]["instance_id"])
    var use := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [boosted_id]})
    _assert_true(use.success, "存档前完成一次增元丹使用")
    _assert_equal(int(session.growth.consumable_use_sequence), 1, "存档前使用序号为 1")

    var save = RunSaveDataScript.new().capture(session)
    var restored_dict: Dictionary = save.restore_session()
    _assert_true(restored_dict.get("success", false), "存档恢复成功")
    var restored: RunSession = restored_dict["run_session"]
    _assert_equal(restored.growth.consumable_ids, ["high_card_insight"], "读档保留消耗品库存")
    _assert_equal(int(restored.growth.consumable_use_sequence), 1, "读档保留 consumable_use_sequence")
    _assert_equal(
        restored.growth.last_recallable_consumable_id,
        "zengyuan_pill",
        "读档保留最近一次可溯忆消耗品记录")
    _assert_equal(
        str(restored.growth.run_deck.card_data(reshaped_id)["reshapes"]["enhancement"]),
        "momentum",
        "读档保留已修改的 RunDeck 强化")
    _assert_equal(
        str(restored.growth.run_deck.card_data(boosted_id)["reshapes"]["enhancement"]),
        "qi_boost",
        "读档保留增元丹强化")
    _assert_equal(
        restored.growth.run_deck.card_count(),
        session.growth.run_deck.card_count(),
        "读档保留 RunDeck 完整牌数")
    var legacy_values: Dictionary = save.to_dict()
    legacy_values["growth"].erase("last_recallable_consumable_id")
    var legacy_restore: Dictionary = RunSaveDataScript.new(
        legacy_values).restore_session()
    _assert_true(
        legacy_restore.get("success", false),
        "旧存档缺少最近使用字段仍可载入")
    _assert_equal(
        legacy_restore["run_session"].growth.last_recallable_consumable_id,
        "",
        "旧存档最近使用字段默认空字符串")

func _test_consumable_no_central_op_branches() -> void:
    var battle_source: String = FileAccess.get_file_as_string(
        "res://core/battle_consumable_service.gd")
    var validator_source: String = FileAccess.get_file_as_string(
        "res://core/content_validator.gd")
    for op in ["gain_insight", "apply_enhancement", "apply_origin"]:
        _assert_true(
            not battle_source.contains(op),
            "战斗兼容适配器不再按 op 写中央分支：%s" % op)
        _assert_true(
            not validator_source.contains(op),
            "内容校验器不再按 op 写中央分支：%s" % op)

func _test_battle_session_commands_snapshots_and_events() -> void:
    var configuration := {
        "content_seed": 2308,
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
        },
    }
    var first: BattleSession = BattleSessionScript.new()
    var second: BattleSession = BattleSessionScript.new()
    _assert_true(first.setup_battle(configuration), "战斗会话可以按配置建立战斗")
    _assert_true(second.setup_battle(configuration), "第二个战斗会话可以按相同配置建立战斗")
    var setup_events: Array = first.drain_events()
    _assert_true(not setup_events.is_empty(), "战斗建立产生可消费事件")
    _assert_equal(first.drain_events().size(), 0, "战斗事件只消费一次")

    _assert_true(first.execute({"type": "start_turn"}).success, "开始回合命令成功")
    _assert_true(second.execute({"type": "start_turn"}).success, "第二会话开始回合命令成功")
    var first_snapshot = first.snapshot()
    var second_snapshot = second.snapshot()
    _assert_equal(first_snapshot.player.hand_count, 8, "战斗快照包含玩家手牌数量")
    _assert_equal(first_snapshot.enemy.hand_count, 8, "战斗快照包含敌方手牌数量")
    _assert_true(first_snapshot.action_states["player"]["can_act"], "战斗快照公开通用玩家行动资格")
    _assert_true(first_snapshot.action_states["enemy"]["can_act"], "战斗快照公开通用敌方行动资格")
    _assert_equal(first_snapshot.player.equipped_inner_skills[0]["id"], "extra_qi_to_defense", "快照提供内功展示定义")
    _assert_equal(first_snapshot.player.consumables[1]["targeting_limits"]["maximum"], 2, "快照提供消耗品展示与目标上限")
    _assert_true(not first_snapshot.battle_log.is_empty(), "战斗快照提供独立战斗日志通道")
    _assert_equal(first_snapshot.battle_log[0]["channel"], "battle", "战斗日志具有统一通道字段")
    _assert_equal(first_snapshot.system_log[0]["channel"], "system", "系统日志具有统一通道字段")
    _assert_equal(
        first_snapshot.player.hand,
        second_snapshot.player.hand,
        "相同配置与种子产生相同只读手牌快照")
    var changed_copy: Dictionary = first_snapshot.to_dict()
    changed_copy["player"]["life"] = 0
    _assert_equal(first.snapshot().player.life, 100, "修改快照副本不会修改战斗核心")
    var battle_log_copy: Array = first_snapshot.battle_log
    battle_log_copy[0]["message"] = "外部篡改"
    _assert_true(first.snapshot().battle_log[0]["message"] != "外部篡改", "日志快照同样保持只读副本边界")

    var preview_snapshot: Dictionary = first.preview([
        first_snapshot.player.hand[0]["id"]])
    _assert_true(preview_snapshot.get("cards", [])[0] is Dictionary, "会话预览只返回卡牌快照而非领域对象")
    _assert_true(preview_snapshot.get("hand", {}).has("contributing_card_ids"), "会话预览用卡牌 ID 表达参与牌")

    var move_result := first.execute({"type": "move_technique_slot", "direction": -1})
    _assert_true(move_result.success, "调整功法位命令通过战斗会话执行")
    _assert_equal(first.snapshot().player.technique_slot_index, 0, "功法位变化进入新快照")
    var hand: Array = first.snapshot().player.hand
    var play_result := first.execute({"type": "play_cards", "card_ids": [hand[0]["id"]]})
    _assert_true(play_result.success, "出牌命令通过战斗会话执行")
    var action_events: Array = first.drain_events()
    _assert_true(not action_events.is_empty(), "出牌结算产生战斗事件流")
    _assert_true(action_events[0].serial >= 0, "战斗事件具有稳定递增序号")

    var rejected := first.execute({"type": "not_a_command"})
    _assert_equal(rejected.success, false, "未知战斗命令被安全拒绝")
    var rejected_events: Array = first.drain_events()
    _assert_equal(rejected_events[-1].type, "command_rejected", "命令失败产生结构化拒绝事件")
    var system_log: Array = first.snapshot().system_log
    _assert_equal(system_log[-1]["severity"], "warning", "命令拒绝进入系统日志 warning 通道")
    _assert_equal(system_log[-1]["context"]["command"], "not_a_command", "系统日志保留被拒绝命令上下文")

func _test_snapshot_boundaries_are_typed() -> void:
    ## 锁住 core → 表现层的类型化读取边界。
    ##
    ## 这些快照类曾经只包一个裸 Dictionary 并暴露 value(key, default)，
    ## 键名写错会静默返回默认值。这里断言字段访问可用、无类型旁路残留，
    ## 且 inner_skill_limit 由领域常量供给而不是表现层各自假设一个数字。
    var session: BattleSession = BattleSessionScript.new(
        _tracked_combat_engine())
    _assert_true(session.setup_battle({"seed": 8801}), "战斗会话建立用于快照边界检查")
    session.execute({"type": "start_turn"})
    var battle := session.snapshot()

    _assert_true(battle is BattleSnapshot, "战斗快照是类型化对象")
    _assert_true(battle.player is BattleSideSnapshot, "参战方快照是类型化对象")
    _assert_true(
        not battle.has_method("value") and not battle.has_method("section"),
        "战斗快照不再保留无类型读取旁路")
    _assert_true(
        not battle.player.has_method("value"),
        "参战方快照不再保留无类型读取旁路")
    var battle_events: Array = session.drain_events()
    _assert_true(not battle_events.is_empty(), "战斗会话产出类型化事件")
    _assert_true(
        battle_events[0] is BattleEvent
        and not battle_events[0].has_method("value"),
        "战斗事件按字段读取且不保留无类型旁路")
    _assert_equal(
        battle.player.inner_skill_limit,
        6,
        "无被动修正时快照公开基础六格容量")
    _assert_equal(battle.player.same_qi_value, 0, "双方快照公开当前同气")
    _assert_equal(battle.player.same_qi_capacity, 5, "双方快照公开有效同气容量")
    _assert_equal(battle.SCHEMA_VERSION, 5, "战斗快照升级为卸力公开字段版本")
    _assert_equal(battle.to_dict()["schema_version"], 5, "战斗快照序列化包含卸力字段版本号")
    _assert_equal(
        battle.log_channel("battle"),
        battle.battle_log,
        "日志通道入口与字段访问返回同一内容")
    _assert_true(
        battle.action_state("player").has("can_act"),
        "行动状态入口按方返回结构")

    var composition_root = GameCompositionRootScript.new()
    _assert_true(composition_root.initialize(), "组合根初始化用于本局快照检查")
    var run_session = composition_root.create_run_session()
    _assert_true(run_session != null, "内容通过校验时组合根产出本局会话")
    run_session.execute({"type": "setup_run", "seed": 8802})
    var run := run_session.snapshot()

    _assert_true(run is RunSnapshot, "本局快照是类型化对象")
    _assert_true(
        not run.has_method("value") and not run.has_method("section"),
        "本局快照不再保留无类型读取旁路")
    _assert_equal(run.seed, 8802, "本局快照按字段公开种子")
    _assert_equal(run.SCHEMA_VERSION, 1, "本局快照使用稳定版本号")
    _assert_true(not run.available_node_ids.is_empty(), "本局快照按字段公开可选节点")

func _test_map_generation_is_deterministic_and_constrained() -> void:
    var generator = MapGeneratorScript.new()
    var first: Dictionary = generator.generate(2308, 1)
    var second: Dictionary = generator.generate(2308, 1)
    _assert_equal(first, second, "相同种子生成完全相同的地图与连线")
    _assert_equal(first["width"], 7, "地图内部网格横向宽度为七列")
    _assert_equal(first["route_rows"], 15, "Boss 前有十五行路线节点")
    _assert_equal(first["start_id"], "map_start", "地图记录唯一旅程起点")
    _assert_true(first["boss_variant"] >= 0 and first["boss_variant"] < 3, "种子确定三选一 Boss 候选序号")
    var row_counts: Dictionary = {}
    for node in first["nodes"]:
        var row: int = int(node["row"])
        row_counts[row] = int(row_counts.get(row, 0)) + 1
        _assert_true(node["type"] != "shop", "地图不生成商店节点")
        if row == 0:
            _assert_equal(node["type"], "combat", "第一行固定普通战斗")
        elif row == 8:
            _assert_equal(node["type"], "treasure", "第九层固定宝箱特殊奖励")
        elif row == 14:
            _assert_equal(node["type"], "rest", "第十五行固定休息")
        elif row == 15:
            _assert_equal(node["type"], "boss", "第十六行固定单一 Boss")
        elif row < 5:
            _assert_true(node["type"] not in ["elite", "rest"], "前五行不随机生成精英或休息")
        if row == 13:
            _assert_true(node["type"] != "rest", "第十四层不随机生成休息")
    _assert_equal(row_counts.get(-1, 0), 1, "地图只有一个位于第1层下方的旅程起点")
    _assert_true(row_counts.get(0, 0) >= 1 and row_counts.get(0, 0) <= 6, "六次路径生成保留一至六个第1层房间")
    for row in range(15):
        _assert_true(row_counts.get(row, 0) <= 6, "每个普通楼层最多六个有效节点")
    _assert_equal(row_counts.get(15, 0), 1, "地图只有一个层末 Boss")
    _assert_equal(
        int(generator.rules["weights"]["event"]) + int(generator.rules["weights"]["event_shop"]),
        27,
        "原生事件与商店替代事件合计百分之二十七")
    var hundred_room_pool: Array = generator._build_room_pool(100)
    _assert_equal(hundred_room_pool.count("combat"), 53, "房间类型池普通战斗占百分之五十三")
    _assert_equal(hundred_room_pool.count("event"), 22, "房间类型池原生事件占百分之二十二")
    _assert_equal(hundred_room_pool.count("event_shop"), 5, "房间类型池商店替代事件占百分之五")
    _assert_equal(hundred_room_pool.count("elite"), 8, "房间类型池精英占百分之八")
    _assert_equal(hundred_room_pool.count("rest"), 12, "房间类型池休息占百分之十二")
    var constraint_grid: Array = generator._create_grid(15, 7)
    generator._connect_grid_nodes(constraint_grid, 5, 3, 2)
    generator._connect_grid_nodes(constraint_grid, 5, 3, 3)
    constraint_grid[6][2]["type"] = "event"
    _assert_true(
        not generator._can_assign_type(constraint_grid, 6, 3, "event"),
        "类型分配器拒绝同一分叉目的地使用相同内部类型")
    constraint_grid[5][3]["type"] = "event_shop"
    _assert_true(
        not generator._can_assign_type(constraint_grid, 6, 3, "event_shop"),
        "商店替代事件继承原商店不可沿路线连续的生成约束")
    var trim_grid: Array = generator._create_grid(15, 7)
    generator._connect_grid_nodes(trim_grid, 0, 1, 2)
    generator._connect_grid_nodes(trim_grid, 0, 3, 2)
    generator._trim_redundant_first_floor_edges(trim_grid)
    _assert_equal(trim_grid[0][3]["out_columns"].size(), 0, "首层重复目的地连线按顺序移除")
    _assert_equal(trim_grid[1][2]["parent_columns"].size(), 2, "移除首层冗余边时保留原作内部父引用")
    for edge in first["edges"]:
        var from_type: String = _map_node_type(first, edge["from"])
        var to_type: String = _map_node_type(first, edge["to"])
        if from_type in ["elite", "rest"]:
            _assert_true(from_type != to_type, "精英与休息不沿路径直接同类相连")

func _test_map_routes_reach_boss_without_crossing() -> void:
    var generator = MapGeneratorScript.new()
    for seed_value in range(512):
        var graph: Dictionary = generator.generate(98173 + seed_value * 7919, seed_value % 3 + 1)
        _assert_map_route_constraints(graph, "地图种子 %d" % seed_value)

func _test_node_dispatcher_is_data_driven_and_deterministic() -> void:
    var dispatcher = NodeDispatcherScript.new()
    var combat_node := {
        "id": "0_2",
        "row": 0,
        "column": 2,
        "type": "combat",
        "generation_type": "combat",
    }
    var context := {"seed": 2308, "act": 1, "boss_variant": 2}
    var first: Dictionary = dispatcher.dispatch(combat_node, context)
    var second: Dictionary = dispatcher.dispatch(combat_node, context)
    _assert_true(first["success"], "普通战斗节点可以被调度")
    _assert_equal(first, second, "同一节点与上下文产生确定性调度结果")
    _assert_equal(first["route"], "battle", "普通战斗路由到战斗呈现层")
    _assert_equal(first["content_id"], "representative_combat", "普通战斗读取数据内容标识")
    _assert_equal(first["battle"]["scenario_path"], "res://data/scripted_battle.json", "战斗场景配置来自节点内容数据")
    var another_act: Dictionary = dispatcher.dispatch(combat_node, {"seed": 2308, "act": 2})
    _assert_true(first["content_seed"] != another_act["content_seed"], "不同层的相同坐标使用不同内容种子")

    var event_result: Dictionary = dispatcher.dispatch(
        {"id": "4_3", "row": 4, "column": 3, "type": "event"}, context)
    _assert_equal(event_result["route"], "placeholder", "未确认事件路由到占位呈现层")
    _assert_equal(event_result["content_status"], "unconfirmed", "未确认事件显式标记设计状态")
    _assert_true(not event_result.has("battle"), "非战斗调度结果不泄漏战斗配置")

    var boss_result: Dictionary = dispatcher.dispatch(
        {"id": "15_3", "row": 15, "column": 3, "type": "boss"}, context)
    _assert_equal(boss_result["boss_variant"], 2, "Boss 调度保留地图生成的候选序号")
    _assert_equal(
        dispatcher.dispatch({"id": "bad", "type": "unknown"}, context)["success"],
        false,
        "未知节点类型安全拒绝而不猜测内容")

func _test_run_state_node_and_practice_gate() -> void:
    var state = RunStateScript.new()
    state.setup(2308)
    _assert_true(state.can_open_practice(), "初次进入地图等待选路时可以修习")
    _assert_true(
        state.available_node_ids().size() >= 1 and state.available_node_ids().size() <= 6,
        "单一旅程起点连接一至六个第1层可选房间")
    var first_node_id: String = state.available_node_ids()[0]
    var begin := state.begin_node(first_node_id)
    _assert_true(begin["success"], "可以进入当前可达节点")
    _assert_true(not state.can_open_practice(), "节点进行中锁定修习入口")
    _assert_equal(state.purchase_consumable("zengyuan_pill", 3)["success"], false, "节点未完成时不能购买修习内容")
    var completion := state.complete_current_node()
    _assert_true(completion["success"], "节点可以完成并返回地图")
    _assert_true(not completion.has("reward"), "兼容状态门面不再从地图导航取得奖励整数")
    _assert_equal(state.experience, 0, "地图导航不再直接修改本局历练")
    _assert_true(state.can_open_practice(), "节点完成到选择下一节点前重新开放修习")
    _assert_true(not state.available_node_ids().is_empty(), "返回地图后只开放相连下一节点")
    _assert_equal(
        state.purchase_consumable("zengyuan_pill", 3)["success"], false,
        "没有经 NodeRewardService 领取奖励时不能消费不存在的历练")

func _test_run_service_boundaries_and_progress_snapshot() -> void:
    var navigation = MapNavigationServiceScript.new()
    navigation.setup(2308)
    _assert_equal(navigation.act, 1, "地图导航服务独立保存当前层数")
    _assert_equal(navigation.phase, "awaiting_node", "地图导航服务独立保存待选阶段")
    var available := navigation.available_node_ids()
    _assert_true(available.size() >= 1 and available.size() <= 6, "地图导航服务独立计算可达节点")
    _assert_true(navigation.begin_node(str(available[0]))["success"], "地图导航服务独立进入节点")
    var completed := navigation.complete_current_node()
    _assert_true(completed["success"], "地图导航服务独立完成节点")
    _assert_equal(navigation.phase, "awaiting_node", "地图导航服务完成普通节点后回到待选阶段")
    _assert_true(not completed.has("reward"), "地图导航服务不再返回基础奖励整数")

    var growth = GrowthInventoryScript.new()
    growth.experience = 3
    _assert_equal(
        growth.purchase_consumable("zengyuan_pill", 3, false)["success"],
        false,
        "成长库存不绕过地图导航的修习时机限制")
    _assert_true(
        growth.purchase_consumable("zengyuan_pill", 3, true)["success"],
        "成长库存独立处理历练和消耗品购买")
    _assert_equal(growth.experience, 0, "成长库存独立扣除历练")
    growth.learned_inner_skill_ids.assign(["extra_qi_to_defense"])
    growth.equipped_inner_skill_ids.assign(["extra_qi_to_defense"])
    growth.technique_slot_index = 1
    var progress = growth.to_progress_snapshot()
    var progress_copy: Dictionary = progress.to_dict()
    progress_copy["consumable_ids"].clear()
    _assert_equal(progress.consumable_ids, ["zengyuan_pill"], "成长快照对外提供深复制")
    var manual_deck = RunDeckScript.new()
    manual_deck.reset_standard("manual")
    var manual_cards := manual_deck.create_battle_cards()
    for card in manual_cards:
        if card.id == "wind_8":
            card.set_enhancement("qi_boost")
    manual_deck.sync_from_battle_cards(manual_cards)
    var manual_progress = RunProgressSnapshotScript.from_dict({
        "consumable_ids": ["zengyuan_pill"],
        "hand_technique_progression": {
            "high_card": {"slot_count": 2, "sequence": ["basic_scatter"]},
        },
        "learned_technique_ids": [],
        "run_deck": manual_deck.to_snapshot(),
    })
    growth.life = 41
    growth.apply_progress_snapshot(manual_progress)
    _assert_equal(growth.consumable_ids, ["zengyuan_pill"], "成长库存可以从进度快照导入消耗品")
    _assert_equal(
        growth.hand_progression("high_card")["slot_count"],
        2,
        "成长库存可以从进度快照导入牌型功法槽位")
    _assert_equal(growth.life, 41, "局部战斗进度不清空未携带的当前生命")
    _assert_equal(growth.run_deck.card_data("wind_8")["reshapes"]["enhancement"], "qi_boost", "成长库存可以从进度快照导入完整本局牌组")
    _assert_equal(
        growth.equipped_inner_skill_ids,
        ["extra_qi_to_defense"],
        "局部战斗进度不清空未携带的已装备内功")
    _assert_equal(
        growth.technique_slot_index,
        1,
        "局部战斗进度不重置未携带的功法结算位")
    _assert_true(
        not manual_progress.to_dict().has("equipped_inner_skill_ids"),
        "局部快照序列化保留字段缺失语义")

func _test_battle_run_progress_working_state_protocol() -> void:
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(catalog.load_all(), "战斗工作状态协议测试载入内容目录")
    var engine = _tracked_combat_engine(null, catalog)
    engine.setup(260817, false)
    var setup_service = BattleSetupServiceScript.new(catalog)
    var run_deck = RunDeckScript.new(catalog)
    run_deck.reset_standard("working-state")
    var initial_growth = GrowthInventoryScript.new(catalog)
    var learned_technique_id := ""
    for definition in catalog.all_of("technique"):
        if not bool(definition.get("built_in", false)):
            learned_technique_id = str(definition.get("id", ""))
            break
    var learned_technique_ids: Array[String] = (
        initial_growth.learned_technique_ids.duplicate())
    if learned_technique_id != "" \
            and not learned_technique_ids.has(learned_technique_id):
        learned_technique_ids.append(learned_technique_id)
    var marker_state := {
        "schema_version": 1,
        "entries": [{
            "source_kind": "inner_skill",
            "source_instance_key": "inner:player:0:extra_qi_to_defense",
            "content_id": "extra_qi_to_defense",
            "marker_id": "working_state_probe",
            "scope": "run",
            "value": 6,
            "public": true,
            "display_name": "协议探针",
            "contributes_to": "max_life",
            "forget_policy": "clear",
        }],
    }
    var values := {
        "consumable_ids": ["zengyuan_pill", "high_card_insight"],
        "item_ids": ["gift_card"],
        "learned_technique_ids": learned_technique_ids,
        "learned_inner_skill_ids": [
            "extra_qi_to_defense", "extra_qi_to_defense"],
        "equipped_inner_skill_ids": ["extra_qi_to_defense"],
        "technique_slot_index": 1,
        "forgotten_inner_skill_count": 4,
        "run_deck": run_deck.to_snapshot(),
        "life": 93,
        "max_life": 137,
        "base_max_life": 131,
        "source_marker_state": marker_state,
        "experience": 17,
        "free_meditation_charge": 0,
        "experience_operation_receipts": {},
        "consumable_capacity": 2,
        "consumable_overflow_count": 0,
        "hand_technique_progression": (
            initial_growth.hand_technique_progression.duplicate(true)),
        "consumable_use_sequence": 8,
        "last_recallable_consumable_id": "zengyuan_pill",
        "base_hand_limit_modifier": 2,
        "hand_technique_multiplier_modifiers": {
            "high_card": {"multiplier_bonus": 3}},
        "used_unique_consumable_ids": ["zhenyuan_huasheng"],
        "passive_counter_state": {"version": 1, "entries": []},
        "run_combat_history_state": RunCombatHistoryScript.new().snapshot(),
    }
    var progress = RunProgressSnapshotScript.from_dict(values)
    _assert_true(
        setup_service.apply_non_deck_progress(
            engine.player, progress).get("success", false),
        "完整 RunProgressSnapshot 装入 BattleSide")
    _assert_true(
        setup_service.apply_player_technique_progression(
            engine.player, engine.sequence_book, progress).get("success", false),
        "完整功法进度装入战斗序列")
    engine.player.replace_deck(
        setup_service.run_deck_from_progress(progress).create_battle_cards(),
        RandomNumberGenerator.new(), false)
    var captured = setup_service.capture_progress(engine.player, run_deck)
    _assert_equal(captured.to_dict(), progress.to_dict(), "战斗可提交字段装入再捕获完整无损")
    var round_trip_growth = GrowthInventoryScript.new(catalog, false)
    round_trip_growth.apply_progress_snapshot(captured)
    var growth_round_trip: Dictionary = round_trip_growth.to_progress_snapshot().to_dict()
    for field in values:
        _assert_equal(
            growth_round_trip[field], progress.to_dict()[field],
            "GrowthInventory 完整往返字段：%s" % field)

    var entry_growth = GrowthInventoryScript.new(catalog, false)
    entry_growth.apply_progress_snapshot(progress)
    var entry_state: Dictionary = entry_growth.to_progress_snapshot().to_dict()
    var battle_use: Dictionary = engine.use_player_consumable(1, [])
    _assert_true(battle_use.get("success", false), "战斗工作状态可使用正式心得消耗品")
    _assert_equal(
        entry_growth.to_progress_snapshot().to_dict(), entry_state,
        "战斗中使用消耗品但未提交 progress 时 GrowthInventory 保持入口状态")
    var used_progress = setup_service.capture_progress(engine.player, run_deck)
    entry_growth.apply_progress_snapshot(used_progress)
    _assert_true(
        not entry_growth.consumable_ids.has("high_card_insight"),
        "正式同步 progress 后提交一次战斗消耗")
    _assert_equal(
        entry_growth.consumable_use_sequence, 9,
        "正式同步 progress 后提交一次使用序号")
    _assert_equal(
        entry_growth.last_recallable_consumable_id,
        "high_card_insight",
        "正式同步 progress 后提交最近可溯忆记录")

    engine.player.consumable_ids.assign(["pair_insight"])
    engine.player.used_unique_consumable_ids.append("shuangji_huasheng")
    engine.player.consumable_use_sequence = 9
    engine.player.last_recallable_consumable_id = "pair_insight"
    engine.player.experience = 23
    engine.player.hand_technique_progression["high_card"]["slot_count"] = 2
    engine.player.learn_technique("working_state_technique")
    engine.player.learned_inner_skill_ids.append("extra_qi_to_defense")
    engine.player.forgotten_inner_skill_count = 5
    engine.player.item_ids.append("astronomer")
    engine.player.base_max_life = 140
    engine.player.max_life = 146
    engine.player.source_marker_store.write(
        "inner_skill", "inner:player:0:extra_qi_to_defense",
        "extra_qi_to_defense", "working_state_probe", "run", "add", 1)
    var changed = setup_service.capture_progress(engine.player, run_deck)
    _assert_equal(changed.consumable_ids, ["pair_insight"], "捕获战斗消耗品变化")
    _assert_equal(changed.consumable_use_sequence, 9, "捕获消耗品使用序号变化")
    _assert_equal(changed.last_recallable_consumable_id, "pair_insight", "捕获最近可溯忆消耗品变化")
    _assert_true(changed.used_unique_consumable_ids.has("shuangji_huasheng"), "捕获唯一使用记录变化")
    _assert_equal(changed.experience, 23, "捕获战斗心得与历练变化")
    _assert_equal(changed.hand_technique_progression["high_card"]["slot_count"], 2, "捕获永久功法槽变化")
    _assert_true(changed.learned_technique_ids.has("working_state_technique"), "捕获战斗获得功法")
    _assert_equal(changed.learned_inner_skill_ids.size(), 3, "捕获战斗获得内功")
    _assert_equal(changed.forgotten_inner_skill_count, 5, "捕获战斗内功遗忘计数")
    _assert_true(changed.item_ids.has("astronomer"), "捕获战斗获得物品")
    _assert_equal(changed.base_max_life, 140, "捕获基础最大生命变化")
    _assert_equal(changed.max_life, 146, "捕获有效最大生命变化")
    _assert_equal(changed.source_marker_state["entries"][0]["value"], 7, "捕获 run 来源标识变化")

    engine.player.defense = 88
    engine.player.momentum_value = 7
    engine.player.same_qi_value = 4
    engine.player.source_marker_store.write(
        "technique", "temporary:battle", "basic_scatter",
        "temporary_marker", "battle", "add", 5)
    var runtime_filtered: Dictionary = setup_service.capture_progress(
        engine.player, run_deck).to_dict()
    for runtime_field in [
            "defense", "momentum_value", "same_qi_value", "hand",
            "draw_pile", "status_state", "battle_counters"]:
        _assert_true(
            not runtime_filtered.has(runtime_field),
            "纯战斗字段不进入 RunProgressSnapshot：%s" % runtime_field)
    _assert_true(
        runtime_filtered["source_marker_state"]["entries"].all(
            func(entry): return str(entry.get("scope", "")) == "run"),
        "battle 范围来源标识不进入 RunProgressSnapshot")

    var deck_before_temporary_state: Dictionary = run_deck.to_snapshot()
    var first_card = engine.player.all_zone_cards()[0]
    first_card.set_anomaly("state", "poison")
    first_card.set_temporary_enhancement("momentum")
    var temporary_card = QiCardScript.new(
        "temporary-probe", "A", 14, 14, "fire", "火", "fire_A")
    temporary_card.temporary_card = true
    engine.player.hand.append(temporary_card)
    var stolen_card = engine.player.all_zone_cards()[1]
    stolen_card.original_owner_id = "enemy"
    setup_service.capture_progress(engine.player, run_deck)
    _assert_equal(
        run_deck.to_snapshot(), deck_before_temporary_state,
        "临时真气、夺取真气、异状和临时重塑不写入 RunDeck")

func _test_node_interaction_platform_contract() -> void:
    var invalid_registry = NodeInteractionHandlerRegistryScript.new()
    _assert_true(
        not invalid_registry.register_handler(NodeInteractionProbeHandler.new("")),
        "节点交互 Registry 拒绝空 kind")
    _assert_true(
        not invalid_registry.register_handler(NodeInteractionProbeHandler.new("Bad-Kind")),
        "节点交互 Registry 拒绝非法 snake_case kind")
    var registry = NodeInteractionHandlerRegistryScript.new()
    var handler = NodeInteractionProbeHandler.new(
        "probe_interaction", [{"op": "heal_life", "amount": 10}])
    _assert_true(registry.register_handler(handler), "测试节点交互 Handler 可注入 Registry")
    var duplicate_registration_registry = NodeInteractionHandlerRegistryScript.new()
    duplicate_registration_registry.register_handler(
        NodeInteractionProbeHandler.new())
    _assert_true(
        not duplicate_registration_registry.register_handler(
            NodeInteractionProbeHandler.new()),
        "节点交互 Registry 拒绝重复 kind")
    _assert_true(
        not registry.require_handler("missing_interaction").get("success", false),
        "节点交互 Registry 对未知 kind 明确失败")

    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "节点交互测试载入内容基线")
    var fixture_values := _catalog_definitions(base_catalog)
    fixture_values["node_content"]["node_types"]["event"] = {
        "route": "interaction",
        "content_id": "probe_event",
        "content_status": "test_fixture",
        "title": "测试事件",
        "description": "测试统一非战斗交互",
        "interaction": {
            "kind": "probe_interaction",
            "configuration": {"mode": "test"},
        },
    }
    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, null, null, registry)
    _assert_true(
        catalog.load_from_definitions(fixture_values, base_catalog.paths),
        "注册 Handler 后 interaction 节点内容通过加载校验：%s" % "；".join(catalog.errors))
    var dispatcher = NodeDispatcherScript.new(fixture_values["node_content"])
    var event_node := {
        "id": "event-1", "type": "event", "generation_type": "event",
        "row": 0, "column": 0,
    }
    var dispatch: Dictionary = dispatcher.dispatch(
        event_node, {"seed": 9917, "act": 2})
    _assert_true(dispatch.get("success", false), "interaction 路由可由节点调度器解析")
    _assert_equal(dispatch.get("route"), "interaction", "节点调度结果公开 interaction route")
    _assert_equal(
        dispatch.get("interaction", {}).get("kind"),
        "probe_interaction",
        "NodeDispatchResult 完整透传 interaction 配置")

    var missing_values := fixture_values.duplicate(true)
    missing_values["node_content"]["node_types"]["event"].erase("interaction")
    _assert_true(
        not ContentCatalogScript.new(
            RuntimeProfileScript.test(), null, null, null, null,
            registry).load_from_definitions(missing_values, base_catalog.paths),
        "interaction route 缺少 interaction 对象时加载失败")
    var unknown_values := fixture_values.duplicate(true)
    unknown_values["node_content"]["node_types"]["event"]["interaction"]["kind"] = "missing_kind"
    _assert_true(
        not ContentCatalogScript.new(
            RuntimeProfileScript.test(), null, null, null, null,
            registry).load_from_definitions(unknown_values, base_catalog.paths),
        "interaction.kind 未注册时加载失败")
    var bad_configuration_values := fixture_values.duplicate(true)
    bad_configuration_values["node_content"]["node_types"]["event"]["interaction"]["configuration"] = {
        "invalid": true,
    }
    _assert_true(
        not ContentCatalogScript.new(
            RuntimeProfileScript.test(), null, null, null, null,
            registry).load_from_definitions(
                bad_configuration_values, base_catalog.paths),
        "Handler configuration 校验失败会阻止内容加载")
    _assert_equal(
        base_catalog.get_by_id("node_type", "combat").get("route"),
        "battle",
        "既有 battle 路由保持不变")
    _assert_equal(
        base_catalog.get_by_id("node_type", "rest").get("route"),
        "placeholder",
        "未迁移的 placeholder 路由保持不变")

    var growth = GrowthInventoryScript.new(catalog)
    growth.life = 50
    var mutation = RunMutationServiceScript.new(
        catalog.run_effect_registry, catalog)
    var service = NodeInteractionServiceScript.new(registry, mutation, catalog)
    var growth_before: Dictionary = growth.capture_mutation_state()
    var prepared: Dictionary = service.prepare(dispatch, growth, {
        "source_kind": "map_node",
        "source_id": "event-1",
        "run_seed": 9917,
    })
    _assert_true(prepared.get("success", false), "节点交互 prepare 成功冻结 DTO")
    var frozen: Dictionary = prepared.get("interaction", {})
    _assert_true(str(frozen.get("interaction_token", "")).begins_with("interaction-"), "交互 token 使用稳定信封前缀")
    var repeated: Dictionary = service.prepare(dispatch, growth, {
        "source_kind": "map_node",
        "source_id": "event-1",
        "run_seed": 9917,
    })
    _assert_equal(repeated.get("interaction"), frozen, "相同状态重复 prepare 返回完全相同 DTO")
    _assert_equal(handler.prepare_calls, 1, "重复 prepare 与 query 都不会再次调用 Handler.prepare")
    _assert_equal(service.query_active(), frozen, "query 只读取已冻结 DTO")
    _assert_equal(growth.capture_mutation_state(), growth_before, "prepare/query 不修改真实成长")
    var edited_query := service.query_active()
    edited_query["choices"][0]["label"] = "污染"
    _assert_equal(service.query_active()["choices"][0]["label"], "接受", "DTO 查询返回深复制")
    _assert_true(JSON.stringify(frozen) != "", "冻结 DTO 可直接 JSON 序列化")

    var token := str(frozen["interaction_token"])
    _assert_true(
        not service.commit("wrong-token", "accept", {"confirmed": true}, growth).get("success", false),
        "错误 interaction token 被拒绝")
    _assert_true(
        not service.commit(token, "missing", {"confirmed": true}, growth).get("success", false),
        "未知 choice 被拒绝")
    _assert_true(
        not service.commit(token, "disabled", {"confirmed": true}, growth).get("success", false),
        "disabled choice 被拒绝")
    _assert_true(
        not service.commit(token, "accept", [], growth).get("success", false),
        "非对象 choice_payload 被拒绝")
    _assert_true(
        service.cancel(token).get("success", false),
        "cancel 只放弃 UI 选择草稿")
    _assert_equal(service.query_active(), frozen, "cancel 后仍查询到同一冻结交互")
    _assert_equal(growth.capture_mutation_state(), growth_before, "cancel 不修改成长")
    _assert_true(
        not service.commit(token, "accept", {}, growth).get("success", false),
        "Handler 在 commit 阶段重新校验 choice_payload")
    _assert_equal(service.query_active(), frozen, "Handler 重新校验失败后 pending 保留")
    _assert_true(
        service.commit(
            token, "accept", {"confirmed": true}, growth
        ).get("success", false),
        "合法节点交互通过共享事务成功提交")
    _assert_equal(growth.life, 60, "成功提交一次应用节点自身效果")
    _assert_true(
        not service.commit(
            token, "accept", {"confirmed": true}, growth
        ).get("success", false),
        "NodeInteractionService 拒绝同一 token 成功提交第二次")
    service.clear()

    var fail_registry = RunEffectHandlerRegistryScript.new()
    _assert_true(
        fail_registry.register_handler(
            RunEffectProbeHandler.new(["fail_node_interaction"], true)),
        "节点交互回滚测试注册失败探针")
    var failing_handler = NodeInteractionProbeHandler.new(
        "failing_interaction", [
            {"op": "gain_experience", "amount": 7},
            {"op": "fail_node_interaction", "amount": 1},
        ])
    var failing_registry = NodeInteractionHandlerRegistryScript.new()
    failing_registry.register_handler(failing_handler)
    var failing_service = NodeInteractionServiceScript.new(
        failing_registry,
        RunMutationServiceScript.new(fail_registry, catalog),
        catalog)
    var failing_dispatch := dispatch.duplicate(true)
    failing_dispatch["interaction"]["kind"] = "failing_interaction"
    var failing_growth = GrowthInventoryScript.new(catalog)
    failing_growth.experience = 3
    var failing_before := failing_growth.capture_mutation_state()
    var failing_prepared := failing_service.prepare(
        failing_dispatch, failing_growth, {
            "source_kind": "map_node", "source_id": "event-1", "run_seed": 9917,
        })
    var failing_token := str(failing_prepared.get("interaction", {}).get(
        "interaction_token", ""))
    _assert_true(
        not failing_service.commit(
            failing_token, "accept", {"confirmed": true}, failing_growth
        ).get("success", false),
        "节点自身多个 effect 中途失败时提交失败")
    _assert_equal(failing_growth.capture_mutation_state(), failing_before, "节点 effect 中途失败时全部成长回滚")
    _assert_equal(
        failing_service.query_active(), failing_prepared.get("interaction"),
        "事务失败后 pending interaction 与 token 保留")

    var duplicate_handler = NodeInteractionProbeHandler.new("duplicate_choice")
    duplicate_handler.duplicate_choices = true
    var duplicate_registry = NodeInteractionHandlerRegistryScript.new()
    duplicate_registry.register_handler(duplicate_handler)
    var duplicate_dispatch := dispatch.duplicate(true)
    duplicate_dispatch["interaction"]["kind"] = "duplicate_choice"
    _assert_true(
        not NodeInteractionServiceScript.new(
            duplicate_registry, mutation, catalog).prepare(
                duplicate_dispatch, growth, {
                    "source_kind": "map_node", "source_id": "event-1", "run_seed": 9917,
                }).get("success", false),
        "prepare 拒绝重复 choice.id")

    var content_probe = RunContentProbeCatalog.new()
    var grant_mutation = RunMutationServiceScript.new(
        RunEffectHandlerRegistryScript.new(), content_probe)
    var grant_growth = GrowthInventoryScript.new(catalog)
    var grant_technique := grant_mutation.apply_effects([{
        "op": "grant_techniques", "technique_ids": ["formal_technique"],
    }], grant_growth)
    _assert_true(grant_technique.get("success", false), "通用功法获得操作成功")
    var technique_state := grant_growth.capture_mutation_state()
    _assert_true(
        not grant_mutation.apply_effects([{
            "op": "grant_techniques", "technique_ids": ["formal_technique"],
        }], grant_growth).get("success", false),
        "已拥有功法再次明确发放被拒绝")
    _assert_equal(grant_growth.capture_mutation_state(), technique_state, "重复功法发放不改变成长")
    _assert_true(grant_mutation.apply_effects([{
        "op": "grant_inner_skills",
        "inner_skill_ids": ["formal_inner_skill", "formal_inner_skill"],
    }], grant_growth).get("success", false), "内功获得允许同 ID 多副本")
    _assert_equal(grant_growth.learned_inner_skill_ids.count("formal_inner_skill"), 2, "两份同 ID 内功进入已获库")
    _assert_true(grant_growth.equipped_inner_skill_ids.is_empty(), "获得内功不会自动装备")
    grant_growth.consumable_ids.assign(["slot_a", "slot_b"])
    var consumables_before := grant_growth.capture_mutation_state()
    _assert_true(
        not grant_mutation.apply_effects([{
            "op": "grant_consumables",
            "consumable_ids": ["formal_consumable", "formal_consumable"],
        }], grant_growth).get("success", false),
        "消耗品整组超过三格容量时失败")
    _assert_equal(grant_growth.capture_mutation_state(), consumables_before, "消耗品容量失败不静默丢弃部分内容")
    grant_growth.consumable_ids.clear()
    _assert_true(grant_mutation.apply_effects([{
        "op": "grant_items", "item_ids": ["formal_item"],
    }], grant_growth).get("success", false), "通用物品获得操作成功")
    var item_state := grant_growth.capture_mutation_state()
    _assert_true(
        not grant_mutation.apply_effects([{
            "op": "grant_items", "item_ids": ["formal_item"],
        }], grant_growth).get("success", false),
        "重复物品发放被拒绝")
    _assert_equal(grant_growth.capture_mutation_state(), item_state, "重复物品不修改库存")
    _assert_true(
        not grant_mutation.apply_effects([{
            "op": "grant_items", "item_ids": ["design_only_item"],
        }], grant_growth).get("success", false),
        "design_only 物品不能通过正式获得操作发放")
    var mixed_before := grant_growth.capture_mutation_state()
    _assert_true(
        not grant_mutation.apply_effects([
            {"op": "grant_consumables", "consumable_ids": ["formal_consumable"]},
            {"op": "grant_items", "item_ids": ["formal_item"]},
        ], grant_growth).get("success", false),
        "多种获得操作中任一失败时整组事务失败")
    _assert_equal(grant_growth.capture_mutation_state(), mixed_before, "混合获得操作失败时全部回滚")

    for invalid_spec in [
        ["grant_techniques", "technique_ids", "technique"],
        ["grant_inner_skills", "inner_skill_ids", "inner_skill"],
        ["grant_consumables", "consumable_ids", "consumable"],
        ["grant_items", "item_ids", "item"],
    ]:
        var invalid_grant_values := _catalog_definitions(base_catalog)
        invalid_grant_values["node_rewards"]["node_rewards"]["event"] = [{
            "op": invalid_spec[0],
            invalid_spec[1]: ["missing_content_id"],
            "kind": invalid_spec[2],
        }]
        _assert_true(
            not ContentCatalogScript.new().load_from_definitions(invalid_grant_values),
            "%s 未知内容 ID 在加载期失败" % invalid_spec[0])

    var navigation = MapNavigationServiceScript.new()
    navigation.seed = 9917
    navigation.act = 2
    navigation.phase = "awaiting_node"
    navigation.graph = {
        "start_id": "start",
        "nodes": [event_node.duplicate(true)],
        "edges": [{"from": "start", "to": "event-1"}],
    }
    var session_growth = GrowthInventoryScript.new(catalog)
    session_growth.life = 50
    var state = RunStateScript.new(navigation, session_growth)
    var reward_service = NodeRewardServiceScript.new(
        fixture_values["node_rewards"], mutation)
    var session_service = NodeInteractionServiceScript.new(
        registry, mutation, catalog)
    var session: RunSession = RunSessionScript.new(
        state, dispatcher, null, null, catalog, null, null, null,
        reward_service, RuntimeProfileScript.test(), null, session_service)
    var begin = session.execute({"type": "begin_node", "node_id": "event-1"})
    _assert_true(begin.success, "RunSession 统一按 interaction route 进入节点")
    var session_interaction: Dictionary = begin.payload_value("interaction", {})
    var session_token := str(session_interaction.get("interaction_token", ""))
    _assert_equal(session.snapshot().phase, "node_in_progress", "prepare 成功后才进入 node_in_progress")
    _assert_true(
        not session.execute({"type": "complete_node"}).success,
        "interaction 未提交前直接 complete_node 被拒绝")
    var session_query = session.execute({"type": "query_node_interaction"})
    _assert_equal(session_query.payload_value("interaction"), session_interaction, "RunSession query 返回同一冻结 DTO")
    _assert_true(session.execute({
        "type": "cancel_node_interaction", "interaction_token": session_token,
    }).success, "RunSession cancel 不退出当前地图节点")
    _assert_equal(session.snapshot().phase, "node_in_progress", "cancel 后仍停留进行中节点")

    var prepare_calls_before_save: int = handler.prepare_calls
    var pending_save = RunSaveDataScript.new().capture(session)
    var pending_values: Dictionary = pending_save.to_dict()
    _assert_equal(
        pending_values["node_state"]["resume_policy"],
        "resume_interaction",
        "pending interaction 存档使用 resume_interaction")
    _assert_equal(
        pending_values["node_state"]["pending_node_interaction"]["interaction"],
        session_interaction,
        "存档保存完整冻结 DTO 与 metadata")
    var restored: Dictionary = pending_save.restore_session(catalog)
    _assert_true(
        restored.get("success", false),
        "pending interaction 可以存档恢复：%s" % str(restored.get("reason", "")))
    _assert_equal(restored.get("resume_policy"), "resume_interaction", "恢复结果公开交互恢复策略")
    if not restored.get("success", false):
        return
    var restored_session: RunSession = restored["run_session"]
    _assert_equal(
        restored_session.execute({"type": "query_node_interaction"}).payload_value("interaction"),
        session_interaction,
        "恢复后 query 与保存前 DTO 完全一致")
    _assert_equal(handler.prepare_calls, prepare_calls_before_save, "恢复 pending interaction 不重新调用 prepare 或抽随机")
    var interaction_save_path := "/tmp/taiwu-s2-f4c-interaction-ui.json"
    for path in [interaction_save_path, interaction_save_path + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    var interaction_composition = GameCompositionRootScript.new()
    _assert_true(interaction_composition.initialize(), "交互恢复 UI 建立组合根")
    interaction_composition.run_save_application_service = RunSaveApplicationServiceScript.new(
        SaveRepositoryScript.new(interaction_save_path),
        interaction_composition.content_catalog,
        Callable(interaction_composition, "create_run_session"))
    var interaction_ui = RunScene.instantiate()
    interaction_ui.configure_composition_root(interaction_composition)
    interaction_ui.configure_restored_run(
        restored_session,
        "resume_interaction",
        {"source": "primary"})
    interaction_ui.initialize_interface()
    _assert_true(interaction_ui.interaction_overlay.visible, "resume_interaction 打开通用单选 UI")
    _assert_equal(
        interaction_ui.interaction_overlay.interaction,
        session_interaction,
        "通用交互 UI 展示原冻结 token、choices 与 metadata")
    _assert_equal(handler.prepare_calls, prepare_calls_before_save, "UI 恢复路由也不重新调用 Handler.prepare")
    interaction_ui.shutdown_interface()
    interaction_ui.free()
    for path in [interaction_save_path, interaction_save_path + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    var committed = restored_session.execute({
        "type": "commit_node_interaction",
        "interaction_token": session_token,
        "choice_id": "accept",
        "choice_payload": {"confirmed": true},
    })
    _assert_true(committed.success, "恢复后的节点交互可以成功提交一次")
    _assert_equal(restored_session.growth.life, 60, "节点自身 effect 在共享成长事务中提交")
    _assert_equal(restored_session.snapshot().phase, "awaiting_reward", "交互成功后建立基础奖励并进入 awaiting_reward")
    _assert_equal(restored_session.snapshot().experience, 0, "奖励领取前不计算功行或写入基础奖励")
    _assert_true(restored_session.snapshot().reward.get("available", false), "节点自身结果成功后才建立 NodeRewardService 奖励包")
    _assert_true(
        not restored_session.execute({
            "type": "commit_node_interaction",
            "interaction_token": session_token,
            "choice_id": "accept",
            "choice_payload": {"confirmed": true},
        }).success,
        "同一 token 成功提交第二次被拒绝")
    _assert_true(
        RunSaveDataScript.new().capture(restored_session).to_dict()["node_state"][
            "pending_node_interaction"].is_empty(),
        "interaction commit 后存档不再包含 pending interaction")
    var legacy_values: Dictionary = pending_values.duplicate(true)
    legacy_values["node_state"].erase("pending_node_interaction")
    legacy_values["node_state"]["resume_policy"] = "restart_node_from_start"
    _assert_true(
        RunSaveDataScript.new(legacy_values).restore_session(catalog).get("success", false),
        "旧存档缺少 pending_node_interaction 仍可加载")

    var map_source := FileAccess.get_file_as_string(
        "res://core/map_navigation_service.gd")
    _assert_true(
        not map_source.contains("_reward_for_type") \
            and not map_source.contains('"combat": 3') \
            and not map_source.contains('"elite": 4') \
            and not map_source.contains('"boss": 5'),
        "MapNavigationService 不再维护或返回 3/4/5 奖励表")
    var composition_root = GameCompositionRootScript.new(
        RuntimeProfileScript.test())
    _assert_true(composition_root.initialize(), "组合根可装配空生产交互 Registry")
    var composed_session: RunSession = composition_root.create_run_session()
    _assert_true(
        composition_root.content_catalog.node_interaction_registry \
            == composition_root.node_interaction_registry \
            and composition_root.node_interaction_service.handler_registry \
            == composition_root.node_interaction_registry \
            and composed_session._node_interaction_service \
            == composition_root.node_interaction_service,
        "ContentValidator、ContentCatalog、RunSession 与交互服务复用组合根 Registry")
    _assert_true(
        composed_session._node_interaction_service.mutation_service \
            == composition_root.run_mutation_service \
            and composed_session._node_reward_service.mutation_service \
            == composition_root.run_mutation_service,
        "节点交互与基础奖励复用组合根的同一成长事务边界")

func _test_run_session_commands_snapshots_events_and_logs() -> void:
    var session: RunSession = RunSessionScript.new()
    var setup := session.execute({"type": "setup_run", "seed": 2308})
    _assert_true(setup.success, "本局会话接受结构化建局命令")
    var initial = session.snapshot()
    _assert_equal(initial.act, 1, "本局快照提供当前层数")
    _assert_equal(initial.phase, "awaiting_node", "本局快照提供当前流程阶段")
    _assert_true(initial.can_open_practice, "本局快照提供修习可用状态")
    _assert_equal(initial.practice.get("offers", []).size(), 9, "修习快照提供八心得与增元丹")
    var snapshot_insight_ids: Array = []
    for offer in initial.practice.get("offers", []):
        if str(offer.get("kind", "")) == "insight":
            snapshot_insight_ids.append(str(offer.get("id", "")))
    snapshot_insight_ids.sort()
    _assert_equal(
        snapshot_insight_ids,
        [
            "five_kind_insight", "four_kind_insight", "full_house_insight",
            "high_card_insight", "pair_insight", "straight_insight",
            "three_kind_insight", "two_pair_insight",
        ],
        "本局修习快照公开全部八种心得")
    var copied_graph: Dictionary = initial.graph
    copied_graph["act"] = 99
    _assert_equal(session.snapshot().graph.get("act"), 1, "修改地图快照不会污染本局核心")

    var first_node_id := str(initial.available_node_ids[0])
    var begin := session.execute({"type": "begin_node", "node_id": first_node_id})
    _assert_true(begin.success, "本局会话统一校验并进入可达节点")
    _assert_true(
        begin.payload_value("dispatch", {}).get("success", false),
        "进入节点命令同时返回数据驱动调度结果")
    _assert_equal(session.snapshot().phase, "node_in_progress", "节点开始后快照进入未完成状态")
    var rejected := session.execute({"type": "open_practice"})
    _assert_equal(rejected.success, false, "节点未完成时本局会话拒绝打开修习")

    var completion := _complete_current_node_for_test(session)
    _assert_true(completion.success, "本局会话完成当前节点")
    _assert_equal(session.snapshot().phase, "awaiting_reward", "节点完成后进入待领取奖励阶段")
    _assert_equal(session.snapshot().experience, 0, "领取前奖励不会提前写入历练")
    var reward_snapshot: Dictionary = session.snapshot().reward
    _assert_true(reward_snapshot.get("available", false), "本局快照公开待领取奖励包")
    _assert_equal(reward_snapshot.get("experience_total"), 3, "奖励快照公开普通战斗三点历练")
    _assert_true(not session.execute({"type": "open_practice"}).success, "奖励领取前修习保持锁定")
    var bundle_id := str(reward_snapshot.get("bundle", {}).get("id", ""))
    var claim := session.execute({"type": "claim_reward", "bundle_id": bundle_id})
    _assert_true(claim.success, "匹配奖励包ID后可以领取节点奖励")
    _assert_equal(session.snapshot().experience, 3, "领取后节点奖励写入本局历练")
    _assert_equal(session.snapshot().phase, "awaiting_node", "领取后才返回地图待选状态")
    _assert_true(not session.execute({"type": "claim_reward", "bundle_id": bundle_id}).success, "同一奖励包不能重复领取")
    _assert_true(session.execute({"type": "open_practice"}).success, "领取奖励返回待选状态后可以打开修习")
    var purchase := session.execute({
        "type": "purchase_consumable",
        "consumable_id": "zengyuan_pill",
        "price": 0,
    })
    _assert_true(purchase.success, "修习购买通过本局命令完成")
    _assert_equal(purchase.payload_value("price"), 3, "修习价格由核心内容定义决定而不信任 UI 参数")
    _assert_equal(session.snapshot().experience, 0, "修习购买后的历练进入只读快照")
    _assert_equal(session.snapshot().growth.get("consumable_ids"), ["zengyuan_pill"], "本局成长快照包含共享消耗品")

    var run_log: Array = session.snapshot().run_log
    var system_log: Array = session.snapshot().system_log
    _assert_true(run_log.size() >= 5, "建局、节点、修习和购买写入统一本局日志通道")
    _assert_true(not system_log.is_empty(), "被拒绝的本局命令写入统一系统日志通道")
    var events: Array = session.drain_events()
    _assert_true(events.size() >= 6, "本局会话公开一次性结构化事件流")
    _assert_equal(events[0].type, "run_setup", "本局事件保留稳定的建局事件类型")
    _assert_true(
        events[0] is RunEvent and not events[0].has_method("value"),
        "本局事件使用稳定信封字段且不保留无类型旁路")
    _assert_true(session.drain_events().is_empty(), "本局事件被消费后不会重复播放")

    var battle_session: BattleSession = BattleSessionScript.new(
        _tracked_combat_engine())
    battle_session.use_game_log(session.game_log)
    _assert_true(battle_session.setup_battle({"content_seed": 2308}), "战斗会话可以复用本局日志实例")
    _assert_true(not session.game_log.entries("run").is_empty(), "建立战斗不会清除既有本局日志")
    _assert_true(not session.game_log.entries("system").is_empty(), "本局与战斗系统诊断进入同一日志序列")

    var boss_state = RunStateScript.new()
    boss_state.setup(8128)
    boss_state.current_node_id = boss_state.graph["boss_id"]
    boss_state.phase = "node_in_progress"
    var boss_session: RunSession = RunSessionScript.new(boss_state)
    _assert_true(_complete_current_node_for_test(boss_session).success, "Boss 节点完成也经过本局会话")
    _assert_equal(boss_session.snapshot().phase, "awaiting_reward", "Boss胜利先进入奖励阶段")
    _assert_equal(boss_session.snapshot().reward["experience_total"], 5, "Boss奖励包为五点历练")
    var boss_bundle_id := str(boss_session.snapshot().reward["bundle"]["id"])
    _assert_true(boss_session.execute({"type": "claim_reward", "bundle_id": boss_bundle_id}).success, "领取Boss奖励后推进流程")
    _assert_equal(boss_session.snapshot().phase, "boss_chest", "领取后本局快照公开 Boss 宝箱阶段")
    _assert_equal(boss_session.snapshot().experience, 6, "Boss基础历练后按当前历练计算功行1")
    _assert_true(boss_session.execute({"type": "complete_boss_chest"}).success, "Boss 宝箱流程通过本局命令完成")
    _assert_equal(boss_session.snapshot().act, 2, "Boss 宝箱命令推进到下一层")
    _assert_equal(boss_session.snapshot().run_log.size(), 3, "Boss奖励建立、领取与宝箱流程均写入本局日志")

func _test_battle_outcome_aggregate_transaction_contract() -> void:
    var prepared := _prepare_battle_outcome_transaction_case()
    var victory: RunSession = prepared["session"]
    var victory_close: BattleCloseProbe = prepared["close_probe"]
    var victory_passive: BattleCompletedMutationProbe = prepared["passive_probe"]
    victory.growth.consumable_ids.assign(["zengyuan_pill"])
    var victory_progress_values := victory.progress_snapshot().to_dict()
    victory_progress_values["life"] = 73
    victory_progress_values["consumable_ids"] = []
    victory_progress_values["consumable_use_sequence"] = 1
    var changed_count := [0]
    var persistence_count := [0]
    victory._run_state.changed.connect(func(): changed_count[0] += 1)
    victory.persistence_boundary_reached.connect(
        func(_command_type): persistence_count[0] += 1)
    var victory_result := victory.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            prepared["dispatch"], "player_victory", "聚合事务胜利", 4),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            victory_progress_values),
    })
    _assert_true(victory_result.success, "战斗胜利通过完整本局聚合事务提交")
    _assert_equal(victory.snapshot().phase, "awaiting_reward", "胜利事务推进到 awaiting_reward")
    _assert_true(victory.snapshot().reward.get("available", false), "胜利事务建立待领取奖励")
    _assert_equal(victory.snapshot().growth.get("life"), 73, "绝对战斗进度只提交一次")
    _assert_equal(victory.growth.consumable_ids, [], "战斗消耗品消耗进入同一提交")
    _assert_equal(victory.growth.consumable_use_sequence, 1, "消耗品使用序号进入同一提交")
    _assert_equal(victory_passive.call_count, 1, "battle_completed 在胜利事务中只触发一次")
    _assert_equal(victory.growth.experience, 7, "battle_completed 成长与 progress 同属一次提交")
    _assert_equal(victory._run_state.committed_passive_event_tokens.size(), 1, "battle_completed token 与被动变化一起提交")
    _assert_equal(
        victory.growth.source_marker_store.value(
            "inner_skill", "inner:probe:0", "battle_completed_probe", "run"),
        3,
        "battle_completed 本局来源标识与聚合事务一起提交")
    _assert_equal(victory_close.close_count, 1, "成功事务只关闭一次 BattleSession")
    _assert_equal(victory._active_battle_session, null, "成功后释放活动 BattleSession 引用")
    _assert_equal(changed_count[0], 1, "胜利聚合提交只发送一次 changed")
    _assert_equal(persistence_count[0], 1, "胜利聚合提交只形成一次持久化边界")
    var event_count_before_repeat: int = victory._event_queue.size()
    var log_state_before_repeat: Dictionary = victory.game_log.capture_runtime_state()
    var repeated := victory.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            prepared["dispatch"], "player_victory", "重复提交", 4),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            victory_progress_values),
    })
    _assert_true(not repeated.success, "同一成功结果重复提交按阶段不匹配拒绝")
    _assert_equal(victory_passive.call_count, 1, "重复结果不重复触发 battle_completed")
    _assert_equal(victory._event_queue.size(), event_count_before_repeat, "重复结果不追加 RunEvent")
    _assert_equal(victory.game_log.capture_runtime_state(), log_state_before_repeat, "重复结果不追加日志")

    for failure_stage in [
            "progress_applied", "battle_completed", "node_advanced",
            "reward_created", "terminal_created", "terminal_applied"]:
        var failure_case := _prepare_battle_outcome_transaction_case(
            failure_stage, true)
        var failed_session: RunSession = failure_case["session"]
        var failed_close: BattleCloseProbe = failure_case["close_probe"]
        var failed_passive: BattleCompletedMutationProbe = failure_case["passive_probe"]
        failed_session.growth.consumable_ids.assign(["zengyuan_pill"])
        var growth_before: Dictionary = failed_session.growth.capture_mutation_state()
        var map_before: Dictionary = failed_session.navigation.capture_transaction_state()
        var run_state_before: Dictionary = failed_session._run_state.capture_transaction_state()
        _assert_true(
            not run_state_before.has("node_passive_source_snapshot")
            and not run_state_before.has("node_passive_source_node_id"),
            "%s 聚合事务不捕获节点级来源派生状态" % failure_stage)
        var log_before: Dictionary = failed_session.game_log.capture_runtime_state()
        var events_before: Array = failed_session._event_queue.duplicate()
        var event_serial_before: int = failed_session._event_serial
        var persistent_serial_before: int = failed_session._persistent_change_serial
        var retained_battle = failed_session._active_battle_session
        var failure_changed := [0]
        var failure_persistence := [0]
        failed_session._run_state.changed.connect(func(): failure_changed[0] += 1)
        failed_session.persistence_boundary_reached.connect(
            func(_command_type): failure_persistence[0] += 1)
        var failure_progress_values := failed_session.progress_snapshot().to_dict()
        failure_progress_values["life"] = 19
        failure_progress_values["consumable_ids"] = []
        var failure_state := (
            "player_defeat" if failure_stage in [
                "terminal_created", "terminal_applied"]
            else "player_victory")
        var failed := failed_session.execute({
            "type": "resolve_battle_result",
            "battle_result": _battle_final_result_for_test(
                failure_case["dispatch"], failure_state,
                "聚合事务失败注入", 6),
            "progress_snapshot": RunProgressSnapshotScript.from_dict(
                failure_progress_values),
        })
        _assert_true(not failed.success, "%s 注入失败拒绝正式提交" % failure_stage)
        _assert_true(failed.payload_value("rolled_back", false), "%s 统一报告完成回滚" % failure_stage)
        _assert_equal(failed_session.growth.capture_mutation_state(), growth_before, "%s 恢复完整成长与被动计数" % failure_stage)
        _assert_equal(failed_session.navigation.capture_transaction_state(), map_before, "%s 恢复地图阶段与完成节点" % failure_stage)
        _assert_equal(failed_session._run_state.capture_transaction_state(), run_state_before, "%s 恢复终局与被动 token" % failure_stage)
        _assert_equal(failed_session.game_log.capture_runtime_state(), log_before, "%s 恢复日志与日志序号" % failure_stage)
        _assert_equal(failed_session._event_queue, events_before, "%s 恢复 RunEvent 队列" % failure_stage)
        _assert_equal(failed_session._event_serial, event_serial_before, "%s 恢复 RunEvent 序号" % failure_stage)
        _assert_equal(failed_session._persistent_change_serial, persistent_serial_before, "%s 不推进持久变化序号" % failure_stage)
        _assert_equal(failed_session._active_battle_session, retained_battle, "%s 保留原 BattleSession 供重试" % failure_stage)
        _assert_equal(failed_close.close_count, 0, "%s 失败不关闭 BattleSession" % failure_stage)
        _assert_equal(failure_changed[0], 0, "%s 回滚不发送 changed" % failure_stage)
        _assert_equal(failure_persistence[0], 0, "%s 失败不形成持久化边界" % failure_stage)
        _assert_equal(failed_session._pending_reward, null, "%s 不保留新奖励" % failure_stage)
        if failure_stage == "progress_applied":
            _assert_equal(failed_passive.call_count, 0, "progress 后失败不触发 battle_completed")
        else:
            _assert_equal(failed_passive.call_count, 1, "%s 前 battle_completed 只执行一次" % failure_stage)

    var defeat_case := _prepare_battle_outcome_transaction_case()
    var defeat_session: RunSession = defeat_case["session"]
    var defeat_close: BattleCloseProbe = defeat_case["close_probe"]
    var defeat_changed := [0]
    var defeat_persistence := [0]
    defeat_session._run_state.changed.connect(func(): defeat_changed[0] += 1)
    defeat_session.persistence_boundary_reached.connect(
        func(_command_type): defeat_persistence[0] += 1)
    var defeat_progress_values := defeat_session.progress_snapshot().to_dict()
    defeat_progress_values["life"] = 0
    var defeat_result := defeat_session.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            defeat_case["dispatch"], "player_defeat", "聚合事务战败", 5),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            defeat_progress_values),
    })
    _assert_true(defeat_result.success, "战败通过同一聚合事务进入终局")
    _assert_equal(defeat_session.snapshot().phase, "run_terminated", "战败事务进入 run_terminated")
    _assert_equal(defeat_session.snapshot().terminal_result.get("kind"), "defeat", "战败事务建立正确 terminal_result")
    _assert_equal(defeat_session.snapshot().growth.get("life"), 0, "战败仍提交现有绝对 progress")
    _assert_equal(defeat_close.close_count, 1, "战败成功后关闭一次 BattleSession")
    _assert_equal(defeat_changed[0], 1, "战败只发送一次 changed")
    _assert_equal(defeat_persistence[0], 1, "战败只形成一次持久化边界")

func _prepare_battle_outcome_transaction_case(
        failure_stage: String = "",
        mutate_counter: bool = false) -> Dictionary:
    var session: RunSession = RunSessionScript.new()
    session.execute({"type": "setup_run", "seed": 94600})
    var node_id := str(session.snapshot().available_node_ids[0])
    var begun := session.execute({"type": "begin_node", "node_id": node_id})
    var close_probe := BattleCloseProbe.new()
    var passive_probe := BattleCompletedMutationProbe.new(mutate_counter)
    session._active_battle_session = close_probe
    session._run_passive_event_service = passive_probe
    if failure_stage != "":
        session._battle_outcome_commit_service = (
            BattleOutcomeFailureProbe.new(failure_stage))
    return {
        "session": session,
        "dispatch": begun.payload_value("dispatch", {}),
        "close_probe": close_probe,
        "passive_probe": passive_probe,
    }

func _test_run_terminal_result_contract_and_closure() -> void:
    _assert_equal(
        BattleFinalResultDTOScript.from_dict({
            "schema_version": 1,
            "battle_state": "active",
        }),
        null,
        "active 战斗不能建立正式 BattleFinalResultDTO")

    var stale_session: RunSession = RunSessionScript.new()
    _assert_true(stale_session.execute({
        "type": "setup_run", "seed": 94001,
    }).success, "过期战斗结果测试建立本局")
    var stale_node := str(stale_session.snapshot().available_node_ids[0])
    var stale_begin := stale_session.execute({
        "type": "begin_node", "node_id": stale_node,
    })
    var stale_dispatch: Dictionary = stale_begin.payload_value("dispatch", {})
    var stale_result = _battle_final_result_for_test(
        stale_dispatch, "player_victory", "测试胜利", 2)
    stale_result.content_seed += 1
    _assert_true(not stale_session.execute({
        "type": "resolve_battle_result",
        "battle_result": stale_result,
        "progress_snapshot": stale_session.progress_snapshot(),
    }).success, "过期 content_seed 的战斗结果被拒绝")
    _assert_equal(stale_session.snapshot().phase, "node_in_progress", "过期结果不推进节点")
    _assert_true(not stale_session.execute({
        "type": "resolve_battle_result",
        "battle_result": null,
        "progress_snapshot": stale_session.progress_snapshot(),
    }).success, "active/空战斗结果被统一命令拒绝")
    var victory: RunSession = RunSessionScript.new()
    _assert_true(victory.execute({
        "type": "setup_run", "seed": 94002,
    }).success, "胜利结果测试建立本局")
    var victory_node := str(victory.snapshot().available_node_ids[0])
    var victory_begin := victory.execute({
        "type": "begin_node", "node_id": victory_node,
    })
    var victory_dispatch: Dictionary = victory_begin.payload_value("dispatch", {})
    var victory_progress_values := victory.progress_snapshot().to_dict()
    victory_progress_values["life"] = 83
    var victory_command := victory.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            victory_dispatch, "player_victory", "玩家胜利", 4),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            victory_progress_values),
    })
    _assert_true(victory_command.success, "玩家胜利结果通过统一命令结算")
    _assert_equal(victory.snapshot().phase, "awaiting_reward", "玩家胜利同步进度后进入 awaiting_reward")
    _assert_equal(victory.snapshot().growth.get("life"), 83, "胜利同步绝对战斗生命")
    _assert_true(victory.snapshot().completed_node_ids.has(victory_node), "胜利节点标记完成")
    _assert_true(victory.snapshot().reward.get("available", false), "胜利建立 NodeRewardService 奖励")

    var defeat: RunSession = RunSessionScript.new()
    _assert_true(defeat.execute({
        "type": "setup_run", "seed": 94003,
    }).success, "战败结果测试建立本局")
    var defeat_node := str(defeat.snapshot().available_node_ids[0])
    var defeat_begin := defeat.execute({
        "type": "begin_node", "node_id": defeat_node,
    })
    var defeat_dispatch: Dictionary = defeat_begin.payload_value("dispatch", {})
    var defeat_progress_values := defeat.progress_snapshot().to_dict()
    defeat_progress_values["life"] = 0
    var defeat_result = _battle_final_result_for_test(
        defeat_dispatch, "player_defeat", "玩家生命归零", 5)
    var defeated := defeat.execute({
        "type": "resolve_battle_result",
        "battle_result": defeat_result,
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            defeat_progress_values),
    })
    _assert_true(defeated.success, "战败结果成功进入本局终局")
    _assert_equal(defeat.snapshot().phase, "run_terminated", "战败进入 run_terminated")
    _assert_equal(defeat.snapshot().terminal_result.get("kind"), "defeat", "战败终局 kind 稳定")
    _assert_equal(defeat.snapshot().growth.get("life"), 0, "战败绝对进度保留生命归零")
    _assert_true(not defeat.snapshot().completed_node_ids.has(defeat_node), "失败节点不进入 completed_node_ids")
    _assert_true(not defeat.snapshot().reward.get("available", false), "战败不建立节点奖励")
    _assert_equal(defeat.snapshot().experience, 0, "战败不增加基础历练或结算功行")
    _assert_equal(defeat.snapshot().act, 1, "战败不推进层数")
    _assert_true(not defeat.execute({"type": "begin_node", "node_id": defeat_node}).success, "终局后节点选择锁定")
    _assert_true(not defeat.execute({"type": "claim_reward", "bundle_id": ""}).success, "终局后奖励领取锁定")
    _assert_true(not defeat.execute({"type": "open_practice"}).success, "终局后修习锁定")
    _assert_true(not defeat.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": [],
        "technique_slot_index": 0,
    }).success, "终局后构筑修改锁定")
    var terminal_log_count := _count_run_log_category(defeat, "run_defeated")
    _assert_true(not defeat.execute({
        "type": "resolve_battle_result",
        "battle_result": defeat_result,
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            defeat_progress_values),
    }).success, "同一战斗结果重复提交被拒绝")
    _assert_equal(
        _count_run_log_category(defeat, "run_defeated"),
        terminal_log_count,
        "重复战斗结果不重复写终局日志")

    var unresolved: RunSession = RunSessionScript.new()
    unresolved.execute({"type": "setup_run", "seed": 94004})
    var unresolved_node := str(unresolved.snapshot().available_node_ids[0])
    var unresolved_begin := unresolved.execute({
        "type": "begin_node", "node_id": unresolved_node,
    })
    var unresolved_progress_values := unresolved.progress_snapshot().to_dict()
    unresolved_progress_values["life"] = 1
    unresolved_progress_values["experience"] = 77
    var unresolved_result := unresolved.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            unresolved_begin.payload_value("dispatch", {}),
            "unresolved_draw", "双方同时倒下", 6),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            unresolved_progress_values),
    })
    _assert_true(unresolved_result.success, "同归于尽结果可以正式终止本局")
    _assert_equal(unresolved.snapshot().terminal_result.get("kind"), "unresolved_rule", "同归于尽保持规则未确认而非战败")
    _assert_equal(unresolved.snapshot().experience, 0, "规则未确认不应用本场部分进度")
    _assert_true(unresolved.snapshot().terminal_result.get("detail", "").contains("尚未确认"), "规则未确认保留明确说明")

    var scenario: RunSession = RunSessionScript.new()
    scenario.execute({"type": "setup_run", "seed": 94005})
    var scenario_node := str(scenario.snapshot().available_node_ids[0])
    var scenario_begin := scenario.execute({
        "type": "begin_node", "node_id": scenario_node,
    })
    var scenario_progress_values := scenario.progress_snapshot().to_dict()
    scenario_progress_values["life"] = 1
    scenario_progress_values["experience"] = 99
    var scenario_result := scenario.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            scenario_begin.payload_value("dispatch", {}),
            "scenario_error", "测试场景脚本在第 4 步失败", 3),
        "progress_snapshot": RunProgressSnapshotScript.from_dict(
            scenario_progress_values),
    })
    _assert_true(scenario_result.success, "场景错误进入技术终止")
    _assert_equal(scenario.snapshot().terminal_result.get("kind"), "scenario_error", "场景错误不映射为普通战败")
    _assert_equal(scenario.snapshot().experience, 0, "场景错误不应用部分战斗进度")
    _assert_equal(scenario.snapshot().growth.get("life"), 100, "场景错误保留战前生命")
    _assert_equal(scenario.snapshot().terminal_result.get("detail"), "测试场景脚本在第 4 步失败", "场景错误保留具体 detail")

    victory._node_interaction_service._pending = {"test_pending": true}
    var abandoned := victory.execute({"type": "abandon_run"})
    _assert_true(abandoned.success, "awaiting_reward 阶段允许主动放弃")
    _assert_equal(victory.snapshot().terminal_result.get("kind"), "abandoned", "主动放弃建立 abandoned 终局")
    _assert_true(not victory.snapshot().reward.get("available", false), "放弃清除未领取奖励")
    _assert_true(victory._node_interaction_service.capture_pending().is_empty(), "放弃清除 pending interaction")
    var abandon_logs := _count_run_log_category(victory, "run_abandoned")
    _assert_true(not victory.execute({"type": "abandon_run"}).success, "重复放弃被拒绝")
    _assert_equal(_count_run_log_category(victory, "run_abandoned"), abandon_logs, "重复放弃不重复写日志")

    var remote_run: RunSession = RunSessionScript.new()
    remote_run.execute({"type": "setup_run", "seed": 94006})
    var remote_node := str(remote_run.snapshot().available_node_ids[0])
    var remote_begin := remote_run.execute({
        "type": "begin_node", "node_id": remote_node,
    })
    var remote_dispatch: Dictionary = remote_begin.payload_value("dispatch", {})
    var remote_provider = MockAiProviderScript.new(false)
    var remote_battle: BattleSession = remote_run.create_battle_session()
    remote_battle.use_ai_provider(remote_provider)
    remote_dispatch["battle"]["use_remote_ai"] = true
    remote_dispatch["battle"]["use_enemy_ai"] = true
    _assert_true(remote_battle.setup_battle(
        remote_dispatch, remote_run.progress_snapshot()), "放弃测试建立远程 AI 战斗")
    _assert_true(remote_battle.execute({"type": "start_turn"}).success, "放弃测试打开远程 AI 行动窗口")
    _assert_true(not remote_provider.pending.is_empty(), "放弃前远程 Provider 存在待处理请求")
    _assert_true(remote_run.execute({"type": "abandon_run"}).success, "等待远程 AI 时可以放弃本局")
    _assert_true(remote_provider.pending.is_empty(), "放弃通过 BattleSession 公开关闭方法取消远程请求")
    remote_provider.free()

    var defeat_save = RunSaveDataScript.new().capture(defeat)
    _assert_equal(defeat_save.to_dict()["node_state"]["resume_policy"], "show_terminal", "终局存档使用 show_terminal")
    var defeat_restored: Dictionary = defeat_save.restore_session()
    _assert_true(defeat_restored.get("success", false), "战败终局存档可以恢复")
    _assert_equal(defeat_restored.get("resume_policy"), "show_terminal", "终局读档返回 show_terminal")
    _assert_equal(
        defeat_restored["run_session"].snapshot().terminal_result,
        defeat.snapshot().terminal_result,
        "终局存档往返保持完整结果")

    var final_state = RunStateScript.new()
    final_state.setup(94007)
    final_state.navigation.act = 3
    final_state.navigation.graph = final_state.navigation.map_generator.generate(
        final_state.navigation.seed, 3)
    final_state.current_node_id = str(final_state.graph["boss_id"])
    final_state.phase = "node_in_progress"
    var final_run: RunSession = RunSessionScript.new(final_state)
    var final_dispatch := final_run._current_node_dispatch()
    _assert_true(final_run.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            final_dispatch, "player_victory", "第三层 Boss 胜利", 9),
        "progress_snapshot": final_run.progress_snapshot(),
    }).success, "第三层 Boss 胜利先建立奖励")
    var final_bundle := str(final_run.snapshot().reward["bundle"]["id"])
    _assert_true(final_run.execute({
        "type": "claim_reward", "bundle_id": final_bundle,
    }).success, "第三层 Boss 完整奖励可以领取")
    _assert_equal(final_run.snapshot().phase, "run_complete", "第三层 Boss 奖励后保持原 run_complete 流程")
    _assert_equal(final_run.snapshot().terminal_result.get("kind"), "victory", "完整奖励与功行后才建立 victory 终局")
    var legacy_terminal_save: Dictionary = (
        RunSaveDataScript.new().capture(final_run).to_dict())
    legacy_terminal_save["node_state"].erase("terminal_result")
    legacy_terminal_save["node_state"]["resume_policy"] = "resume_boundary"
    var legacy_terminal_restore := RunSaveDataScript.new(
        legacy_terminal_save).restore_session()
    _assert_true(not legacy_terminal_restore.get("success", false), "缺少 terminal_result 的旧终局存档明确拒绝")

    var overlay = RunTerminalOverlayScript.new()
    root.add_child(overlay)
    for kind in RunTerminalResultDTOScript.KINDS:
        var battle_state: String = {
            "victory": "player_victory",
            "defeat": "player_defeat",
            "abandoned": "",
            "unresolved_rule": "unresolved_draw",
            "scenario_error": "scenario_error",
        }[kind]
        overlay.present({
            "schema_version": 1,
            "kind": kind,
            "source": "ui_test",
            "detail": "UI detail %s" % kind,
            "battle_state": battle_state,
            "act": 2,
            "node_id": "node-ui",
            "node_type": "combat",
            "turn_number": 3,
        }, {"act": 2, "current_node_id": "node-ui", "experience": 17})
        _assert_equal(overlay.presented_kind, kind, "终局 UI 展示 %s kind" % kind)
        _assert_equal(overlay.detail_label.text, "UI detail %s" % kind, "终局 UI 展示 %s 具体说明" % kind)
        _assert_true(overlay.progress_label.text.contains("17"), "终局 UI 展示 %s 当前历练" % kind)
    overlay.queue_free()

func _battle_final_result_for_test(
        dispatch: Dictionary,
        battle_state: String,
        detail: String,
        turn_number: int):
    return BattleFinalResultDTOScript.from_dict({
        "schema_version": 1,
        "battle_state": battle_state,
        "detail": detail,
        "node_id": str(dispatch.get("node_id", "")),
        "act": int(dispatch.get("act", 1)),
        "node_type": str(dispatch.get("node_type", "")),
        "content_id": str(dispatch.get("content_id", "")),
        "content_seed": int(dispatch.get("content_seed", 0)),
        "turn_number": turn_number,
    })

func _complete_current_node_for_test(session: RunSession) -> CommandResult:
    var dispatch: Dictionary = session._current_node_dispatch()
    if str(dispatch.get("route", "")) != "battle":
        return session.execute({"type": "complete_node"})
    return session.execute({
        "type": "resolve_battle_result",
        "battle_result": _battle_final_result_for_test(
            dispatch, "player_victory", "测试节点胜利", 1),
        "progress_snapshot": session.progress_snapshot(),
    })

func _count_run_log_category(session: RunSession, category: String) -> int:
    var count := 0
    for entry in session.snapshot().run_log:
        if str(entry.get("category", "")) == category:
            count += 1
    return count

func _test_inner_skill_loadout_and_forgetting() -> void:
    var production_catalog = ContentCatalogScript.new()
    _assert_true(production_catalog.load_all(), "内功配装测试载入正式内容目录")
    var fixture_values := _catalog_definitions(production_catalog)
    fixture_values["inner_skills"]["version"] = 2
    fixture_values["inner_skills"]["inner_skills"].append_array([
        {
            "id": "loadout_fixture_a",
            "name": "配装测试甲",
            "status": "formal",
            "forget_value": 7,
            "behaviors": [{
                "id": "on_play_effects",
                "configuration": {"effects": [{
                    "op": "defense",
                    "amount": {"kind": "constant", "value": 1},
                }]},
            }],
        },
        {
            "id": "loadout_fixture_b",
            "name": "配装测试乙",
            "status": "formal",
            "forget_value": 11,
            "behaviors": [{
                "id": "on_play_effects",
                "configuration": {"effects": [{
                    "op": "defense",
                    "amount": {"kind": "constant", "value": 1},
                }]},
            }],
        },
    ])
    var fixture_catalog = ContentCatalogScript.new()
    _assert_true(
        fixture_catalog.load_from_definitions(fixture_values),
        "正式内功配置遗忘所得后通过内容校验")

    var missing_values := fixture_values.duplicate(true)
    missing_values["inner_skills"]["inner_skills"].append({
        "id": "formal_missing_forget_value",
        "name": "缺失遗忘所得",
        "status": "formal",
        "behaviors": [{
            "id": "on_play_effects",
            "configuration": {"effects": [{
                "op": "defense",
                "amount": {"kind": "constant", "value": 1},
            }]},
        }],
    })
    var missing_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_catalog.load_from_definitions(missing_values),
        "正式内功缺少 forget_value 时启动校验拒绝")
    _assert_true(
        "\n".join(missing_catalog.errors).contains("正式内功必须配置"),
        "正式内功缺少遗忘所得的诊断明确")
    var negative_values := fixture_values.duplicate(true)
    negative_values["inner_skills"]["inner_skills"][1]["forget_value"] = -1
    _assert_true(
        not ContentCatalogScript.new().load_from_definitions(negative_values),
        "内功 forget_value 不能为负数")

    var session: RunSession = RunSessionScript.new(
        null, null, null, null, fixture_catalog)
    _assert_true(
        session.execute({"type": "setup_run", "seed": 30301}).success,
        "内功配装测试建立本局")
    session.growth.experience = 5
    session.growth.learned_inner_skill_ids.assign([
        "loadout_fixture_a",
        "loadout_fixture_a",
        "loadout_fixture_b",
        "extra_qi_to_defense",
    ])
    session.growth.equipped_inner_skill_ids.assign([
        "loadout_fixture_a",
        "loadout_fixture_a",
    ])
    session.growth.technique_slot_index = 1

    var queried := session.execute({"type": "get_inner_skill_loadout"})
    _assert_true(queried.success, "内功配装查询命令成功")
    var loadout: Dictionary = queried.payload_value("loadout")
    _assert_equal(loadout.get("schema_version"), 1, "内功配装 DTO schema_version 为 1")
    _assert_equal(loadout.get("inner_skill_limit"), 6, "内功配装 DTO 公开六格上限")
    _assert_true(loadout.get("editable", false), "地图待选状态 DTO 可编辑")
    var learned_a: Dictionary = {}
    var learned_candidate: Dictionary = {}
    for learned_entry in loadout.get("learned", []):
        if str(learned_entry.get("id", "")) == "loadout_fixture_a":
            learned_a = learned_entry
        if str(learned_entry.get("id", "")) == "extra_qi_to_defense":
            learned_candidate = learned_entry
    _assert_equal(learned_a.get("total_count"), 2, "DTO 汇总相同 ID 的两个已获副本")
    _assert_equal(learned_a.get("equipped_count"), 2, "DTO 汇总相同 ID 的两个装备副本")
    _assert_equal(learned_a.get("unequipped_count"), 0, "DTO 正确计算未装备副本数")
    _assert_equal(learned_a.get("base_forget_value"), 7, "DTO 公开基础遗忘所得")
    _assert_true(not learned_candidate.get("can_forget", true), "缺少遗忘所得的候选不可普通遗忘")
    _assert_equal(learned_candidate.get("base_forget_value"), null, "候选缺失所得不静默解释为 0")
    _assert_equal(loadout["equipped"][0]["occurrence_index"], 1, "首个同 ID 装备副本序号为 1")
    _assert_equal(loadout["equipped"][1]["occurrence_index"], 2, "第二个同 ID 装备副本序号为 2")
    _assert_equal(loadout["equipped"][0]["combat_source_order"], 0, "功法位前的内功战斗顺序正确")
    _assert_equal(loadout["equipped"][1]["combat_source_order"], 2, "功法位后的内功战斗顺序正确")

    var set_duplicates := session.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": [
            "loadout_fixture_b", "loadout_fixture_a", "loadout_fixture_a"],
        "technique_slot_index": 2,
    })
    _assert_true(set_duplicates.success, "两个相同 ID 副本可以同时装备")
    _assert_equal(
        session.growth.equipped_inner_skill_ids,
        ["loadout_fixture_b", "loadout_fixture_a", "loadout_fixture_a"],
        "完整配装按提交顺序保存")
    _assert_equal(set_duplicates.payload_value("technique_slot_index"), 2, "配装返回新的功法位置")
    _assert_true(
        set_duplicates.payload_value("before", {}).has("schema_version")
        and set_duplicates.payload_value("after", {}).has("schema_version"),
        "完整配装返回结构化 before 与 after")

    var battle = session.create_battle_session()
    _assert_true(
        battle.setup_battle(
            {"content_seed": 30301, "battle": {"use_enemy_ai": false}},
            session.progress_snapshot()),
        "永久内功配装可以建立下一场战斗")
    _assert_equal(
        battle.engine.player.equipped_inner_skill_ids,
        ["loadout_fixture_b", "loadout_fixture_a", "loadout_fixture_a"],
        "下一场战斗严格按永久配装顺序装配同 ID 副本")
    _assert_equal(battle.engine.player.technique_slot_index, 2, "下一场战斗按永久功法位置装配")
    var persistent_before_battle_sync: Array[String] = (
        session.growth.equipped_inner_skill_ids.duplicate())
    var forgotten_before_battle_sync: int = (
        session.growth.forgotten_inner_skill_count)
    session.sync_progress_snapshot(battle.player_progress_snapshot())
    _assert_equal(
        session.growth.learned_inner_skill_ids,
        [
            "loadout_fixture_a", "loadout_fixture_a",
            "loadout_fixture_b", "extra_qi_to_defense"],
        "战斗快照同步不清空本局已获内功库")
    _assert_equal(
        session.growth.equipped_inner_skill_ids,
        persistent_before_battle_sync,
        "战斗快照同步不清空或写回永久内功顺序")
    _assert_equal(
        session.growth.forgotten_inner_skill_count,
        forgotten_before_battle_sync,
        "战斗局部快照不清空普通遗忘累计")

    var stable_state: Dictionary = session.growth.capture_mutation_state()
    for invalid_case in [
        {
            "label": "装备数量超过已获数量被拒绝",
            "ids": ["loadout_fixture_a", "loadout_fixture_a", "loadout_fixture_a"],
            "slot": 0,
        },
        {
            "label": "未知内功 ID 被拒绝",
            "ids": ["unknown_inner_skill"],
            "slot": 0,
        },
        {
            "label": "空内功 ID 被拒绝",
            "ids": [""],
            "slot": 0,
        },
        {
            "label": "非法 technique_slot_index 被拒绝",
            "ids": ["loadout_fixture_a"],
            "slot": 2,
        },
        {
            "label": "超过六门内功被拒绝且不截断",
            "ids": [
                "loadout_fixture_a", "loadout_fixture_a", "loadout_fixture_a",
                "loadout_fixture_a", "loadout_fixture_a", "loadout_fixture_a",
                "loadout_fixture_a"],
            "slot": 0,
        },
    ]:
        var rejected := session.execute({
            "type": "set_inner_skill_loadout",
            "equipped_inner_skill_ids": invalid_case["ids"],
            "technique_slot_index": invalid_case["slot"],
        })
        _assert_true(not rejected.success, invalid_case["label"])
        _assert_equal(
            session.growth.capture_mutation_state(),
            stable_state,
            "%s且不会部分修改旧状态" % invalid_case["label"])

    var repository = InnerSkillRepositoryScript.new()
    repository.configure(fixture_values["inner_skills"])
    var policy_service = InnerSkillLoadoutServiceScript.new(
        session.growth, repository, InnerSkillForgetValueProbe.new(3))
    _assert_equal(
        policy_service.query_forget_value("loadout_fixture_a").get("forget_value"),
        7,
        "旧遗忘策略注入不再绕过统一被动整数查询链")

    _assert_true(session.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": ["loadout_fixture_a"],
        "technique_slot_index": 0,
    }).success, "遗忘前卸下一份同 ID 副本")
    var forget := session.execute({
        "type": "forget_inner_skill",
        "inner_skill_id": "loadout_fixture_a",
    })
    _assert_true(forget.success, "普通遗忘一个未装备内功副本")
    _assert_equal(forget.payload_value("forget_value"), 7, "普通遗忘按默认策略结算 forget_value")
    _assert_equal(forget.payload_value("experience_before"), 5, "普通遗忘返回历练前值")
    _assert_equal(session.growth.experience, 12, "普通遗忘所得加入历练")
    _assert_equal(forget.payload_value("remaining_count"), 1, "普通遗忘只移除一个匹配副本")
    _assert_equal(session.growth.learned_inner_skill_ids.count("loadout_fixture_a"), 1, "其他同 ID 副本保持不变")
    _assert_equal(session.growth.equipped_inner_skill_ids, ["loadout_fixture_a"], "普通遗忘不改变装备顺序")
    _assert_equal(session.growth.forgotten_inner_skill_count, 1, "普通遗忘累计增加一次")
    _assert_equal(
        session.growth.create_mutation_copy().forgotten_inner_skill_count,
        1,
        "普通遗忘累计进入 GrowthInventory mutation copy")
    var failed_forget_state: Dictionary = session.growth.capture_mutation_state()
    _assert_true(not session.execute({
        "type": "forget_inner_skill",
        "inner_skill_id": "loadout_fixture_a",
    }).success, "同 ID 所有剩余副本均装备时不能遗忘")
    _assert_equal(session.growth.capture_mutation_state(), failed_forget_state, "失败遗忘保持全部成长状态不变")
    var missing_forget := session.execute({
        "type": "forget_inner_skill",
        "inner_skill_id": "extra_qi_to_defense",
    })
    _assert_true(not missing_forget.success, "缺少 forget_value 的 candidate 不能普通遗忘")
    _assert_true(missing_forget.reason.contains("尚未配置遗忘所得"), "候选遗忘拒绝原因明确")
    _assert_equal(session.growth.forgotten_inner_skill_count, 1, "查询与失败不增加普通遗忘累计")

    var save = RunSaveDataScript.new().capture(session)
    var restored: Dictionary = save.restore_session(fixture_catalog)
    _assert_true(restored.get("success", false), "内功配装和遗忘累计可存档恢复")
    var restored_growth = restored["run_session"].growth
    _assert_equal(restored_growth.equipped_inner_skill_ids, ["loadout_fixture_a"], "存档保留内功装备顺序")
    _assert_equal(restored_growth.technique_slot_index, 0, "存档保留功法插入位置")
    _assert_equal(restored_growth.forgotten_inner_skill_count, 1, "存档保留普通遗忘累计")
    var legacy_values: Dictionary = save.to_dict()
    legacy_values["growth"].erase("forgotten_inner_skill_count")
    var legacy_restored := RunSaveDataScript.new(legacy_values).restore_session(
        fixture_catalog)
    _assert_true(legacy_restored.get("success", false), "旧存档缺少普通遗忘累计仍可恢复")
    _assert_equal(
        legacy_restored["run_session"].growth.forgotten_inner_skill_count,
        0,
        "旧存档缺少 forgotten_inner_skill_count 时默认为 0")
    var invalid_save_values: Dictionary = save.to_dict()
    invalid_save_values["growth"]["forgotten_inner_skill_count"] = -1
    _assert_true(
        not RunSaveDataScript.new(invalid_save_values).validate(fixture_catalog).is_empty(),
        "存档拒绝负数 forgotten_inner_skill_count")

    var gate_session: RunSession = RunSessionScript.new(
        null, null, null, null, fixture_catalog)
    _assert_true(gate_session.execute({"type": "setup_run", "seed": 30302}).success, "构筑门禁测试建立本局")
    gate_session.growth.learned_inner_skill_ids.assign(["loadout_fixture_a"])
    _assert_true(gate_session.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": ["loadout_fixture_a"],
        "technique_slot_index": 1,
    }).success, "地图待选状态可以修改内功配装")
    _assert_true(not gate_session.execute({
        "type": "set_hand_technique_loadout",
        "hand_id": "high_card",
        "technique_ids": [],
    }).success, "地图待选状态拒绝保存空功法序列")
    var first_node_id := str(gate_session.snapshot().available_node_ids[0])
    _assert_true(gate_session.execute({
        "type": "begin_node", "node_id": first_node_id,
    }).success, "构筑门禁测试进入节点")
    _assert_true(not gate_session.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": [],
        "technique_slot_index": 0,
    }).success, "节点中及战斗中不能修改永久内功配装")
    _assert_true(not gate_session.execute({
        "type": "set_hand_technique_loadout",
        "hand_id": "high_card",
        "technique_ids": [],
    }).success, "set_hand_technique_loadout 使用相同构筑门禁")
    var node_query := gate_session.execute({"type": "get_inner_skill_loadout"})
    _assert_true(node_query.success, "节点中仍可查询内功配装")
    _assert_true(not node_query.payload_value("loadout").get("editable", true), "节点中 DTO 标记不可编辑")
    _assert_true(str(node_query.payload_value("loadout").get("blocked_reason", "")) != "", "不可编辑 DTO 提供门禁原因")
    _assert_true(gate_session.execute({"type": "get_hand_technique_loadout", "hand_id": "high_card"}).success, "功法序列查询不受修改门禁影响")
    _assert_true(_complete_current_node_for_test(gate_session).success, "构筑门禁测试进入待领奖励阶段")
    _assert_true(not gate_session.execute({
        "type": "set_inner_skill_loadout",
        "equipped_inner_skill_ids": [],
        "technique_slot_index": 0,
    }).success, "奖励未领取时不能修改永久配装")
    gate_session.navigation.phase = "boss_chest"
    gate_session._pending_reward = null
    _assert_true(not gate_session.execute({
        "type": "forget_inner_skill",
        "inner_skill_id": "loadout_fixture_a",
    }).success, "Boss 宝箱阶段不能普通遗忘内功")
    _assert_true(gate_session.execute({"type": "get_inner_skill_loadout"}).success, "Boss 宝箱阶段仍可查询配装")


func _test_experience_interest_node_settlement() -> void:
    var combat := _interest_test_session("combat", 0)
    var combat_bundle := _claim_interest_test_node(combat)
    _assert_equal(combat.growth.experience, 3, "当前历练0的普通战斗最终为3，功行生息为0")
    _assert_equal(combat_bundle.payload_value("experience_interest", {}).get("amount"), 0, "普通战斗功行生息0")

    var rest := _interest_test_session("rest", 7)
    var rest_bundle := _claim_interest_test_node(rest)
    _assert_equal(rest.growth.experience, 8, "当前历练7的休息节点功行生息1")
    _assert_equal(rest_bundle.payload_value("experience_interest", {}).get("amount"), 1, "休息节点功行生息1")

    var event := _interest_test_session("event", 10)
    var event_bundle := _claim_interest_test_node(event)
    _assert_equal(event.growth.experience, 12, "当前历练10的事件节点功行生息2")
    _assert_equal(event_bundle.payload_value("experience_interest", {}).get("amount"), 2, "事件节点功行生息2")

    var treasure := _interest_test_session("treasure", 7)
    var treasure_bundle := _claim_interest_test_node(treasure)
    _assert_equal(treasure.growth.experience, 8, "宝箱节点也触发一次功行生息")
    _assert_equal(treasure_bundle.payload_value("experience_interest", {}).get("amount"), 1, "宝箱节点功行生息1")

    var boss := _interest_test_session("boss", 25)
    var boss_bundle := _claim_interest_test_node(boss)
    _assert_equal(boss.growth.experience, 35, "Boss基础奖励后当前历练30，功行生息5")
    _assert_equal(boss_bundle.payload_value("experience_interest", {}).get("amount"), 5, "Boss功行生息达到单次上限5")

    var before_duplicate: int = combat.growth.experience
    _assert_true(
        not combat.execute({"type": "claim_reward", "bundle_id": ""}).success,
        "同一节点重复领取被拒绝")
    _assert_equal(combat.growth.experience, before_duplicate, "重复领取不重复增加历练或功行")

    var hidden_chest := RunSessionScript.new()
    _assert_true(
        hidden_chest.execute({"type": "setup_run", "seed": 20606}).success,
        "Boss隐藏宝箱功行测试可以建立本局")
    hidden_chest.growth.experience = 10
    hidden_chest.navigation.phase = "boss_chest"
    var chest_result := hidden_chest.execute({"type": "complete_boss_chest"})
    _assert_true(chest_result.success, "Boss隐藏宝箱完成并触发功行")
    _assert_equal(hidden_chest.growth.experience, 12, "Boss隐藏宝箱当前历练10时功行生息2")
    _assert_equal(chest_result.payload_value("experience_interest", {}).get("amount"), 2, "Boss隐藏宝箱功行生息2")
    _assert_true(
        not hidden_chest.execute({"type": "complete_boss_chest"}).success,
        "同一Boss隐藏宝箱重复提交被拒绝")
    _assert_equal(hidden_chest.growth.experience, 12, "重复提交Boss隐藏宝箱不重复触发功行")

    var state := RunStateScript.new()
    state.setup(20607)
    state.growth.experience = 7
    state.graph = {"nodes": [{"id": "compat-rest", "type": "rest"}], "edges": []}
    state.current_node_id = "compat-rest"
    state.phase = "node_in_progress"
    var compatibility_result := state.complete_current_node()
    _assert_true(compatibility_result.get("success", false), "RunState兼容门面复用节点功行规则")
    _assert_equal(state.experience, 8, "RunState兼容门面对休息节点计算功行1")

    var save_data = RunSaveDataScript.new().capture(rest)
    var restored: Dictionary = save_data.restore_session()
    _assert_true(restored.get("success", false), "包含功行生息后的节点状态可以存档读档")
    _assert_equal(restored["run_session"].growth.experience, 8, "存档读档保留功行生息后的历练")

func _interest_test_session(node_type: String, starting_experience: int) -> RunSession:
    var session: RunSession = RunSessionScript.new()
    session.execute({"type": "setup_run", "seed": 20600 + starting_experience})
    session.navigation.graph = {
        "nodes": [{"id": "interest-node", "type": node_type}],
        "edges": [],
        "boss_variant": 0,
    }
    session.navigation.current_node_id = "interest-node"
    session.navigation.phase = "node_in_progress"
    session.growth.experience = starting_experience
    return session

func _claim_interest_test_node(session: RunSession) -> CommandResult:
    _assert_true(
        _complete_current_node_for_test(session).success,
        "功行测试节点建立奖励包")
    var bundle_id := str(session.snapshot().reward.get("bundle", {}).get("id", ""))
    var result := session.execute({"type": "claim_reward", "bundle_id": bundle_id})
    _assert_true(result.success, "功行测试节点奖励领取成功")
    return result

func _test_boss_chest_flow() -> void:
    var state = RunStateScript.new()
    state.setup(8128)
    state.current_node_id = state.graph["boss_id"]
    state.phase = "node_in_progress"
    var boss_result := state.complete_current_node()
    _assert_true(boss_result["success"], "第一层 Boss 节点可以完成")
    _assert_equal(state.phase, "boss_chest", "第一层 Boss 后进入不可见的第十七层 Boss 宝箱")
    _assert_true(not state.can_open_practice(), "Boss 宝箱流程中修习入口锁定")
    var chest_result := state.complete_boss_chest()
    _assert_true(chest_result["success"], "Boss 宝箱可以完成")
    _assert_equal(state.act, 2, "完成第一层 Boss 宝箱后进入第二层")
    _assert_equal(state.phase, "awaiting_node", "新层地图进入待选节点状态")
    _assert_true(state.can_open_practice(), "进入新层地图后修习入口开放")

    state.act = 3
    state.graph = state.map_generator.generate(state.seed, state.act)
    state.current_node_id = state.graph["boss_id"]
    state.phase = "node_in_progress"
    state.complete_current_node()
    _assert_equal(state.phase, "run_complete", "第三层 Boss 后直接完成本局且没有 Boss 宝箱")

func _test_layered_life_progression_and_battle_persistence() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(
        session.execute({"type": "setup_run", "seed": 70401}).success,
        "生命成长测试可以建立本局")
    _assert_equal(session.growth.life, 100, "本局开局玩家当前生命为100")
    _assert_equal(session.growth.max_life, 100, "本局开局玩家生命上限为100")
    _assert_equal(session.snapshot().growth.get("life"), 100, "本局快照公开当前生命")
    _assert_equal(session.snapshot().growth.get("max_life"), 100, "本局快照公开生命上限")

    var first_battle: BattleSession = session.create_battle_session()
    _assert_true(
        first_battle.setup_battle(
            {"content_seed": 70402, "battle": {"use_enemy_ai": false}},
            session.progress_snapshot()),
        "第一场战斗从本局成长快照建立")
    _assert_equal(first_battle.engine.player.life, 100, "第一场战斗以本局当前生命开始")
    first_battle.engine.deal_damage(
        first_battle.engine.enemy,
        first_battle.engine.player,
        60,
        "technique")
    _assert_equal(first_battle.engine.player.life, 40, "战斗中受到60点伤害后剩余40生命")
    session.sync_progress_snapshot(first_battle.player_progress_snapshot())
    _assert_equal(session.growth.life, 40, "战后当前生命回写本局且不自动回满")
    _assert_equal(session.growth.max_life, 100, "战后生命上限保持第一层100")

    var second_battle: BattleSession = session.create_battle_session()
    _assert_true(
        second_battle.setup_battle(
            {"content_seed": 70403, "battle": {"use_enemy_ai": false}},
            session.progress_snapshot()),
        "残血本局可以建立下一场战斗")
    _assert_equal(second_battle.engine.player.life, 40, "下一场战斗以本局40点当前生命开始")
    _assert_equal(second_battle.engine.player.max_life, 100, "下一场战斗保留第一层100点上限")

    session.navigation.phase = "boss_chest"
    var first_chest := session.execute({"type": "complete_boss_chest"})
    _assert_true(first_chest.success, "第一层 Boss 宝箱完成后推进第二层")
    _assert_equal(session.navigation.act, 2, "第一层 Boss 宝箱后进入第二层")
    _assert_equal(session.growth.life, 90, "权威例子40/100跨层后成为90/150")
    _assert_equal(session.growth.max_life, 150, "第一层跨层后生命上限增至150")

    session.growth.life = 80
    session.navigation.phase = "boss_chest"
    var second_chest := session.execute({"type": "complete_boss_chest"})
    _assert_true(second_chest.success, "第二层 Boss 宝箱完成后推进第三层")
    _assert_equal(session.navigation.act, 3, "第二层 Boss 宝箱后进入第三层")
    _assert_equal(session.growth.life, 155, "第二层80/150跨层后当前生命增加75至155")
    _assert_equal(session.growth.max_life, 225, "第二层跨层后生命上限增至225")

    var full_session: RunSession = RunSessionScript.new()
    _assert_true(
        full_session.execute({"type": "setup_run", "seed": 70404}).success,
        "满血跨层测试可以建立独立本局")
    full_session.navigation.phase = "boss_chest"
    _assert_true(
        full_session.execute({"type": "complete_boss_chest"}).success,
        "满血时可以完成第一层 Boss 宝箱")
    _assert_equal(full_session.growth.life, 150, "满血跨层当前生命不超过新上限")
    _assert_equal(full_session.growth.max_life, 150, "满血跨层上限正确增长到150")

    var final_session: RunSession = RunSessionScript.new()
    _assert_true(
        final_session.execute({"type": "setup_run", "seed": 70405}).success,
        "第三层通关测试可以建立独立本局")
    final_session.growth.max_life = 225
    final_session.growth.base_max_life = 225
    final_session.growth.life = 77
    final_session.navigation.act = 3
    final_session.navigation.graph = final_session.navigation.map_generator.generate(
        final_session.navigation.seed, 3)
    final_session.navigation.current_node_id = final_session.navigation.graph["boss_id"]
    final_session.navigation.phase = "node_in_progress"
    _assert_true(
        _complete_current_node_for_test(final_session).success,
        "第三层 Boss 胜利建立最终奖励")
    var final_bundle_id := str(final_session.snapshot().reward["bundle"]["id"])
    _assert_true(
        final_session.execute({
            "type": "claim_reward",
            "bundle_id": final_bundle_id,
        }).success,
        "第三层 Boss 奖励领取成功")
    _assert_equal(final_session.navigation.phase, "run_complete", "第三层 Boss 后直接完成本局")
    _assert_equal(final_session.growth.life, 77, "第三层通关不改变当前生命")
    _assert_equal(final_session.growth.max_life, 225, "第三层通关不执行下一层生命成长")

    var reset_probe = BattleSideScript.new("重置探针")
    var reset_rng := RandomNumberGenerator.new()
    reset_probe.max_life = 150
    reset_probe.life = 40
    reset_probe.reset([], reset_rng, false, false)
    _assert_equal(reset_probe.life, 40, "显式关闭生命重置时 BattleSide 保留当前生命")
    reset_probe.reset([], reset_rng, false)
    _assert_equal(reset_probe.life, 150, "默认重置仍为敌人侧和既有调用恢复满生命")

func _test_run_state_battle_growth_persistence() -> void:
    var state = RunStateScript.new()
    state.setup(420)
    state.consumable_ids.append("zengyuan_pill")
    state.hand_technique_progression["high_card"] = {
        "slot_count": 2,
        "sequence": ["basic_scatter"],
    }
    var run_cards: Array = state.run_deck.create_battle_cards()
    for card in run_cards:
        if card.id == "wind_8":
            card.set_enhancement("qi_boost")
    state.run_deck.sync_from_battle_cards(run_cards)
    var engine = _tracked_combat_engine()
    engine.setup(420, false)
    state.apply_to_battle_side(engine.player)
    var modified = null
    for card in engine.player.draw_pile:
        if card.id == "wind_8":
            modified = card
            break
    _assert_true(modified != null, "本局牌组改造能应用到下一场战斗")
    _assert_equal(modified.reshape_enhancement, "qi_boost", "跨战斗保留真气强化")
    _assert_equal(
        engine.player.hand_technique_progression.get("high_card", {}).get("slot_count", 0),
        2,
        "跨战斗保留高牌功法槽位")
    _assert_equal(engine.sequence_book.find_slots({
        "hand_id": "high_card"}).size(), 1,
        "旧RunState入口也只按实际sequence实例化功法")
    _assert_equal(engine.player.consumable_ids, ["zengyuan_pill"], "跨战斗保留共享消耗品")
    modified.set_enhancement("momentum")
    engine.player.consume_at(0)
    state.sync_from_battle_side(engine.player)
    _assert_equal(state.run_deck.card_data("wind_8")["reshapes"]["enhancement"], "momentum", "战斗中的强化替换同步回本局 RunDeck")
    _assert_equal(state.consumable_ids.size(), 0, "战斗中使用消耗品后同步释放本局槽位")

func _test_run_save_life_round_trip_legacy_defaults_and_validation() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(
        session.execute({"type": "setup_run", "seed": 20501}).success,
        "生命存档测试可以建立本局")
    session.navigation.act = 2
    session.navigation.graph = session.navigation.map_generator.generate(
        session.navigation.seed, 2)
    session.growth.life = 90
    session.growth.max_life = 150
    session.growth.base_max_life = 150
    var save_data = RunSaveDataScript.new().capture(session)
    var saved: Dictionary = save_data.to_dict()
    _assert_equal(saved["growth"]["life"], 90, "存档 growth 段保存当前生命")
    _assert_equal(saved["growth"]["max_life"], 150, "存档 growth 段保存生命上限")
    var restored: Dictionary = save_data.restore_session()
    _assert_true(restored.get("success", false), "第2层90/150生命存档可以恢复")
    _assert_equal(restored["run_session"].growth.life, 90, "读档不把当前生命回满")
    _assert_equal(restored["run_session"].growth.max_life, 150, "读档不把生命上限退回100")

    var legacy: Dictionary = saved.duplicate(true)
    legacy["growth"].erase("life")
    legacy["growth"].erase("max_life")
    legacy["growth"].erase("base_max_life")
    legacy["growth"].erase("source_marker_state")
    var legacy_restored: Dictionary = RunSaveDataScript.new(legacy).restore_session()
    _assert_true(legacy_restored.get("success", false), "缺少生命字段的旧版v1存档仍可读取")
    _assert_equal(legacy_restored["run_session"].growth.life, 150, "第2层旧存档补齐为满血150")
    _assert_equal(legacy_restored["run_session"].growth.max_life, 150, "第2层旧存档按权威表补齐150上限")

    var over_max: Dictionary = saved.duplicate(true)
    over_max["growth"]["life"] = 151
    _assert_true(
        _array_contains_text(
            RunSaveDataScript.new(over_max).validate(),
            "growth.life 不能大于 growth.max_life"),
        "当前生命高于上限时校验报出具名错误")
    var invalid_life: Dictionary = saved.duplicate(true)
    invalid_life["growth"]["life"] = -1
    _assert_true(
        _array_contains_text(
            RunSaveDataScript.new(invalid_life).validate(),
            "growth.life 必须是正整数"),
        "负数当前生命被具名拒绝")
    var fractional: Dictionary = saved.duplicate(true)
    fractional["growth"]["life"] = 90.5
    _assert_true(
        _array_contains_text(
            RunSaveDataScript.new(fractional).validate(),
            "growth.life 必须是正整数"),
        "非整数当前生命被具名拒绝")

func _test_run_build_query_dto_and_empty_formal_pools() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(
        session.execute({"type": "setup_run", "seed": 30301}).success,
        "构筑 DTO 测试建立标准本局")
    session.growth.consumable_ids.assign(["xiantian_fu"])
    session.growth.item_ids.assign(["gift_card", "gift_card"])
    var first_result := session.execute({"type": "get_run_build"})
    _assert_true(first_result.success, "任何地图待选状态可以查询完整构筑")
    var first: Dictionary = first_result.payload_value("build", {})
    _assert_equal(first.get("schema_version"), 1, "构筑 DTO 使用 schema_version 1")
    _assert_equal(first.get("cards", []).size(), 52, "构筑 DTO 返回完整标准真气实例")
    _assert_true(
        not _contains_object_value(first),
        "构筑命令边界不返回 GrowthInventory、RunDeck 或其他真实对象")
    _assert_equal(first.get("hand_loadouts", []).size(), 8, "基础功法配装返回八种精确牌型")
    for loadout in first.get("hand_loadouts", []):
        _assert_true(
            loadout.get("sequence", []).map(func(value): return value.get("id")) == ["basic_scatter"]
            and loadout.get("available_techniques", []).any(func(value): return value.get("id") == "basic_guard"),
            "%s 显示默认散招和可选守招" % loadout.get("hand_id", ""))
    var four: Dictionary = first["hand_loadouts"][6]
    var five: Dictionary = first["hand_loadouts"][7]
    four["sequence"].append({"id": "local_probe"})
    _assert_equal(five["sequence"].size(), 1, "四条与五条 DTO 序列不是同一数组")
    _assert_equal(first.get("consumables", []).size(), 2, "共享消耗品 DTO 始终保留两个基础槽位")
    _assert_equal(first["consumables"][0].get("slot_index"), 0, "非空消耗品保留 slot_index 0")
    _assert_equal(first["consumables"][1].get("status"), "empty", "未占用槽位明确返回空槽")
    _assert_equal(first.get("items", [])[0].get("count"), 2, "相同物品按独立持有区汇总数量")
    _assert_true(
        first.get("items", []).all(func(item):
            return str(item.get("id", "")) != "xiantian_fu"),
        "奇珍不会进入物品页 DTO")
    first["cards"][0]["display_name"] = "本地篡改"
    first["consumables"][0]["name"] = "本地篡改"
    var second: Dictionary = session.execute(
        {"type": "get_run_build"}).payload_value("build", {})
    _assert_true(
        second["cards"][0].get("display_name") != "本地篡改"
        and second["consumables"][0].get("name") != "本地篡改",
        "修改返回 DTO 不会反向修改领域对象或下一次查询")

func _test_run_build_consumable_target_selection_and_cancel() -> void:
    var session: RunSession = RunSessionScript.new()
    session.execute({"type": "setup_run", "seed": 30302})
    session.growth.consumable_ids.assign(["zengyuan_pill"])
    var query_result := session.execute({
        "type": "query_consumable_use", "slot_index": 0})
    var query: Dictionary = query_result.payload.duplicate(true)
    _assert_equal(query.get("selection"), "player_selected", "选择型消耗品由 query 声明 player_selected")
    _assert_equal(query.get("minimum"), 1, "选择型消耗品返回最少目标数")
    _assert_equal(query.get("maximum"), 2, "选择型消耗品返回最多目标数")
    var build = RunBuildDTOScript.new().configure(
        session.execute({"type": "get_run_build"}).payload_value("build", {}))
    var dialog = RunCardSelectionDialogScene.instantiate()
    root.add_child(dialog)
    var submitted := {"count": 0, "ids": []}
    dialog.use_requested.connect(func(_slot: int, ids: Array, _payload: Dictionary):
        submitted["count"] = int(submitted["count"]) + 1
        submitted["ids"] = ids.duplicate())
    dialog.present_query(0, query, build)
    _assert_true(not dialog.can_confirm(), "未达到 minimum 时确认按钮禁用")
    _assert_true(not dialog.toggle_target("not-eligible", true), "DTO 外真气不能被选择")
    var targets: Array = query.get("eligible_targets", [])
    var first_id := str(targets[0].get("instance_id", ""))
    var second_id := str(targets[1].get("instance_id", ""))
    var third_id := str(targets[2].get("instance_id", ""))
    _assert_true(dialog.toggle_target(first_id, true), "合法真气可按 instance_id 选择")
    _assert_true(dialog.can_confirm(), "达到 minimum 后允许确认")
    _assert_true(dialog.toggle_target(second_id, true), "可选择到 maximum")
    _assert_true(not dialog.toggle_target(third_id, true), "超过 maximum 的选择被 UI 拒绝")
    dialog.cancel()
    _assert_equal(submitted["count"], 0, "取消选择不发送 use_consumable 意图")
    _assert_equal(build.consumables[0].get("id"), "zengyuan_pill", "取消不会在 UI 本地删除消耗品")
    dialog.present_query(0, query, build)
    dialog.toggle_target(first_id, true)
    _assert_true(dialog.confirm(), "合法 player_selected 选择可以确认")
    _assert_equal(submitted["ids"], [first_id], "确认只提交 eligible_targets 中的稳定实例 ID")
    var failed := session.execute({
        "type": "use_consumable",
        "slot_index": 0,
        "selected_instance_ids": ["not-eligible"],
        "choice_payload": {},
    })
    _assert_true(not failed.success, "核心拒绝非法目标")
    _assert_equal(
        session.execute({"type": "get_run_build"}).payload_value(
            "build", {}).get("consumables", [])[0].get("id"),
        "zengyuan_pill",
        "命令失败后库存未被乐观修改")
    dialog.queue_free()

func _test_run_build_prepared_preview_and_enum_protocol() -> void:
    var session: RunSession = RunSessionScript.new()
    session.execute({"type": "setup_run", "seed": 30303})
    session.growth.consumable_ids.assign(["zhuanxiang_lun"])
    var first: Dictionary = session.execute({
        "type": "query_consumable_use", "slot_index": 0}).payload
    var second: Dictionary = session.execute({
        "type": "query_consumable_use", "slot_index": 0}).payload
    _assert_true(not str(first.get("preparation_token", "")).is_empty(), "冻结预览返回非空 preparation_token")
    _assert_equal(first.get("prepared_preview"), second.get("prepared_preview"), "重复打开冻结预览保持相同目标和变化")
    _assert_equal(first.get("preparation_token"), second.get("preparation_token"), "重复打开冻结预览保持相同 token")
    var build = RunBuildDTOScript.new().configure(
        session.execute({"type": "get_run_build"}).payload_value("build", {}))
    var dialog = RunCardSelectionDialogScene.instantiate()
    root.add_child(dialog)
    var submitted := {"payload": {}}
    dialog.use_requested.connect(func(_slot: int, _ids: Array, payload: Dictionary):
        submitted["payload"] = payload.duplicate(true))
    dialog.present_query(0, first, build)
    _assert_true(dialog.can_confirm(), "冻结确定性预览无需手选目标即可确认")
    dialog.confirm()
    _assert_equal(
        submitted["payload"].get("preparation_token"),
        first.get("preparation_token"),
        "确认冻结预览时原样回传 preparation_token")

    session.growth.consumable_ids.assign(["tongjie_gongming"])
    var enum_query: Dictionary = session.execute({
        "type": "query_consumable_use", "slot_index": 0}).payload
    _assert_equal(enum_query.get("choice_schema", {}).get("type"), "enum", "同阶共鸣通过通用 enum schema 查询")
    _assert_true(not enum_query.get("choice_options", []).is_empty(), "enum 候选由核心动态返回")
    dialog.present_query(0, enum_query, build)
    var option := str(enum_query.get("choice_options", [])[0].get("value", ""))
    _assert_true(dialog.select_enum(option), "enum 控件只接受 choice_options 中的值")
    _assert_equal(dialog.choice_payload().get("rank"), option, "enum 按 schema.field 生成 choice_payload")
    _assert_true(not dialog.select_enum("UI-hard-coded-rank"), "enum 不接受 DTO 外硬编码牌阶")
    dialog.queue_free()

func _test_run_build_technique_removals_and_independent_drafts() -> void:
    var build := _run_build_ui_fixture(true, true)
    var dialog = RunCardSelectionDialogScene.instantiate()
    root.add_child(dialog)
    var removal_query := {
        "can_use": true,
        "name": "协议探针",
        "description": "按组移出功法",
        "selection": "deterministic_random",
        "minimum": 0,
        "maximum": 0,
        "eligible_targets": [],
        "choice_schema": {
            "type": "technique_sequence_removals",
            "field": "removed_technique_ids_by_hand",
            "groups": [
                {"hand_id": "high_card", "required_count": 0, "options": []},
                {"hand_id": "pair", "required_count": 1, "options": ["pair_a", "pair_b"]},
            ],
        },
        "choice_options": [],
        "prepared_preview": {},
        "preparation_token": "",
    }
    dialog.present_query(0, removal_query, build)
    _assert_true(not dialog.can_confirm(), "功法移出组未满足 required_count 时不能确认")
    _assert_true(dialog.set_removal_selection("pair", ["pair_a"]), "功法移出提交稳定功法 ID")
    _assert_true(dialog.can_confirm(), "所有组恰好满足 required_count 后允许确认")
    _assert_equal(
        dialog.choice_payload().get(
            "removed_technique_ids_by_hand", {}).get("high_card"),
        [],
        "required_count 为 0 的组提交空数组")
    _assert_true(
        not dialog.set_removal_selection("pair", ["pair_a", "pair_b"]),
        "单组不能选择超过 required_count")
    dialog.queue_free()

    var panel = RunTechniqueLoadoutPanelScene.instantiate()
    root.add_child(panel)
    panel.present(build)
    var five_before: Array = panel.draft_sequence("five_kind")
    _assert_true(panel.add_technique("four_kind", "bomb_shared"), "四条草稿可加入炸弹池候选")
    _assert_equal(panel.draft_sequence("five_kind"), five_before, "修改四条草稿不影响五条草稿")
    _assert_true(panel.add_technique("pair", "pair_b"), "功法草稿只能加入 DTO 候选")
    _assert_true(not panel.add_technique("pair", "missing"), "DTO 外功法不能加入草稿")
    var saved := {"hand_id": "", "ids": []}
    panel.save_requested.connect(func(hand_id: String, ids: Array):
        saved["hand_id"] = hand_id
        saved["ids"] = ids.duplicate())
    _assert_true(panel.request_save("pair"), "保存功法页发送一次完整序列命令意图")
    _assert_equal(saved["hand_id"], "pair", "功法保存保留精确牌型 ID")
    _assert_equal(saved["ids"], ["pair_a", "pair_b"], "功法保存发送完整稳定 ID 数组")
    panel.queue_free()

func _test_s2f6a_repeated_technique_slot_index_operations() -> void:
    var build := _run_build_ui_fixture(true, false)
    var loadout = build.hand_loadout("pair")
    loadout.slot_count = 3
    loadout.sequence = [
        {"id": "basic_scatter", "name": "散招"},
        {"id": "basic_guard", "name": "守招"},
        {"id": "basic_scatter", "name": "散招"},
    ]
    loadout.available_techniques = []
    var panel = RunTechniqueLoadoutPanelScene.instantiate()
    root.add_child(panel)
    panel.present(build)
    _assert_true(panel.remove_technique_at("pair", 2), "重复基础功法可按第三槽下标删除")
    _assert_equal(panel.draft_sequence("pair"), ["basic_scatter", "basic_guard"],
        "删除第三槽不会误删第一个同 ID 功法")
    var underfilled_saved := {"ids": []}
    panel.save_requested.connect(func(_hand_id: String, ids: Array):
        underfilled_saved["ids"] = ids.duplicate())
    _assert_true(panel.request_save("pair"), "容量3时装备2门可以提交保存")
    _assert_equal(underfilled_saved["ids"], ["basic_scatter", "basic_guard"],
        "未填满配装保存只提交实际功法，不写入占位")
    panel.discard_drafts()
    _assert_true(panel.move_technique_at("pair", 2, -1), "重复基础功法可按槽位下标移动")
    _assert_equal(panel.draft_sequence("pair"),
        ["basic_scatter", "basic_scatter", "basic_guard"],
        "移动第三槽不会查找并移动第一个同 ID 功法")
    panel.queue_free()

func _test_run_build_inner_skill_draft_and_forgetting() -> void:
    var build := _run_build_ui_fixture(true, true)
    var panel = RunInnerSkillLoadoutPanelScene.instantiate()
    root.add_child(panel)
    panel.present(build)
    _assert_true(panel.add_copy("inner_a"), "同 ID 第二份内功可以单独装备")
    _assert_equal(panel.draft_equipped_ids(), ["inner_a", "inner_a"], "内功草稿保留同 ID 多副本")
    _assert_true(panel.add_copy("inner_b"), "不同内功可以继续加入配装")
    _assert_true(panel.move_copy(2, -1), "内功副本可以调整顺序")
    _assert_true(panel.set_technique_position(2), "功法位置可设为 0～装备数量之间的分隔槽")
    var saved := {"ids": [], "position": -1}
    panel.save_requested.connect(func(ids: Array, position: int):
        saved["ids"] = ids.duplicate()
        saved["position"] = position)
    _assert_true(panel.request_save(), "内功保存发送完整配装")
    _assert_equal(saved["ids"], ["inner_a", "inner_b", "inner_a"], "内功保存保留副本与排序")
    _assert_equal(saved["position"], 2, "内功顺序和 technique_slot_index 一起提交")
    var forgotten := {"id": ""}
    panel.forget_requested.connect(func(inner_skill_id: String):
        forgotten["id"] = inner_skill_id)
    _assert_true(panel.request_forget("inner_a"), "can_forget 且 forget_value 有效时显示确认")
    panel._forget_confirmation.confirmed.emit()
    _assert_equal(forgotten["id"], "inner_a", "普通遗忘只发送一份指定内功 ID")
    _assert_true(not panel.request_forget("inner_b"), "缺少 forget_value 的候选内功禁用普通遗忘")
    panel.queue_free()

func _test_run_build_read_only_layout_and_ui_domain_boundary() -> void:
    var build := _run_build_ui_fixture(false, false)
    var overlay = RunBuildOverlayScene.instantiate()
    root.add_child(overlay)
    overlay.present(build)
    _assert_true(overlay.visible, "只读阶段仍可打开构筑页面")
    _assert_equal(overlay.tabs.get_tab_count(), 5, "构筑 Overlay 提供五个分页")
    for child in overlay.tabs.get_children():
        _assert_true(child is ScrollContainer, "%s 分页内容位于可滚动容器" % child.name)
    _assert_true(
        not overlay.technique_panel.add_technique("pair", "pair_b"),
        "只读阶段功法草稿修改禁用")
    _assert_true(
        not overlay.inner_skill_panel.add_copy("inner_a"),
        "只读阶段内功装备修改禁用")
    overlay.present_consumable_query(0, {
        "can_use": false,
        "reason": "当前阶段只读",
        "name": "只读探针",
        "description": "",
        "selection": "player_selected",
        "minimum": 1,
        "maximum": 1,
        "eligible_targets": [{"instance_id": "card:1", "display_name": "风·2"}],
        "choice_schema": {},
        "choice_options": [],
        "prepared_preview": {},
        "preparation_token": "",
    })
    _assert_true(
        not overlay.selection_dialog.can_confirm(),
        "只读 query 的 can_use=false 禁用消耗品正式确认")
    _assert_true(
        overlay.tabs.custom_minimum_size.y <= 680,
        "1440×900 基准窗口为页头、分页与底部留出可见空间")
    var forbidden := [
        "run_session.growth",
        "run_session.navigation",
        "composition_root.content_catalog",
        "GrowthInventory.new(",
        "ContentCatalog.new(",
        ".run_deck.",
    ]
    var ui_paths := [
        "res://ui/run_main.gd",
        "res://ui/components/run_build_overlay.gd",
        "res://ui/components/run_deck_panel.gd",
        "res://ui/components/run_consumable_panel.gd",
        "res://ui/components/run_card_selection_dialog.gd",
        "res://ui/components/run_technique_loadout_panel.gd",
        "res://ui/components/run_inner_skill_loadout_panel.gd",
        "res://ui/components/run_item_inventory_panel.gd",
    ]
    for path in ui_paths:
        var source := FileAccess.get_file_as_string(path)
        for token in forbidden:
            _assert_true(
                not source.contains(token),
                "%s 不直接访问领域对象：%s" % [path, token])
    overlay.queue_free()

func _test_map_practice_and_battle_scene_integration() -> void:
    var save_path := "/tmp/taiwu-s2-f4c-map-ui.json"
    for path in [save_path, save_path + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    var ui_root = GameCompositionRootScript.new()
    _assert_true(ui_root.initialize(), "地图 UI 自动存档测试建立组合根")
    ui_root.run_save_application_service = RunSaveApplicationServiceScript.new(
        SaveRepositoryScript.new(save_path),
        ui_root.content_catalog,
        Callable(ui_root, "create_run_session"))
    var run_ui = RunScene.instantiate()
    run_ui.configure_composition_root(ui_root)
    run_ui.configure_new_run({
        "seed": 2308,
        "starter_build_id": "standard_52",
    })
    run_ui.initialize_interface()
    root.add_child(run_ui)
    _assert_true(run_ui.practice_button != null, "地图场景建立右下角修习按钮")
    _assert_true(run_ui.build_button != null, "地图场景建立独立于修习的构筑按钮")
    _assert_equal(run_ui.life_label.text, "生命 100/100", "地图顶栏显示当前生命与上限")
    _assert_true(run_ui.map_scroll != null, "地图使用纵向滚动容器")
    _assert_true(
        run_ui.map_view._node_position(-1, 3).y > run_ui.map_view._node_position(0, 3).y,
        "单一旅程起点显示在第1层房间下方")
    _assert_equal(
        run_ui.map_view._node_description({"type": "start", "row": -1}),
        "旅程起点 · 选择上方第 1 层房间开始路线",
        "旅程起点悬停说明不显示为第0行")
    run_ui.map_view.size = Vector2(1100, 1700)
    _assert_true(
        run_ui.map_view._node_position(0, 6).x <= run_ui.map_view.size.x - 180.0,
        "地图右侧为修习按钮保留节点安全区")
    _assert_true(not run_ui.practice_button.disabled, "初始待选节点状态修习按钮可用")
    run_ui._open_run_build()
    _assert_true(run_ui.run_build_overlay.visible, "地图待选阶段可打开构筑 Overlay")
    _assert_equal(run_ui.run_build_overlay.tabs.get_tab_count(), 5, "地图构筑入口加载五个分页")
    _assert_true(
        not run_ui.run_build_overlay.technique_panel._empty_state.visible,
        "基础功法始终作为正式候选显示")
    _assert_true(
        run_ui.run_build_overlay.inner_skill_panel._empty_state.visible,
        "未获得正式内功时 UI 显示空状态而不伪装候选内容")
    run_ui._close_run_build()
    run_ui._open_practice()
    _assert_true(run_ui.practice_overlay.visible, "点击修习按钮打开卡片式修习页面")
    run_ui._close_practice()
    var first_node_id: String = str(run_ui.run_session.snapshot().available_node_ids[0])
    run_ui._on_node_selected(first_node_id)
    if not run_ui.current_battle.is_node_ready():
        run_ui.current_battle.battle_session.setup_battle(
            run_ui.current_battle.battle_configuration,
            run_ui.run_session.progress_snapshot())
    _assert_equal(run_ui.run_session.snapshot().phase, "node_in_progress", "地图选择战斗节点后进入未完成状态")
    _assert_true(run_ui.battle_layer.visible and run_ui.current_battle != null, "战斗节点接入现有战斗场景")
    _assert_equal(
        run_ui.current_battle.battle_configuration["content_id"],
        "representative_combat",
        "地图 UI 使用调度结果创建战斗而不自行选择内容")
    _assert_equal(
        run_ui.current_battle.battle_configuration.get("node_id", "missing"),
        first_node_id,
        "地图 UI 将当前节点 ID 传入战斗配置")
    _assert_true(
        int(run_ui.current_battle.battle_configuration["content_seed"]) > 0,
        "地图 UI 将节点稳定内容种子传入战斗场景")
    _assert_true(run_ui.practice_button.disabled, "战斗节点进行中修习按钮锁定")
    _assert_true(not run_ui.build_button.disabled, "战斗节点进行中仍允许只读查看构筑")
    run_ui._open_run_build()
    _assert_true(
        run_ui.run_build_overlay.visible
        and not run_ui.run_build_overlay._build.editable,
        "节点进行中构筑页保持可见并使用 DTO 只读门禁")
    run_ui._close_run_build()
    run_ui.current_battle.battle_session.engine.battle_state = "player_victory"
    run_ui.current_battle.battle_session.engine.battle_state_detail = "测试胜利"
    var ui_final_result = run_ui.current_battle.final_result()
    _assert_equal(
        run_ui.current_battle.battle_session._battle_binding.get(
            "node_id", "missing"),
        first_node_id,
        "BattleSession 保存地图节点绑定")
    _assert_equal(
        ui_final_result.node_id,
        first_node_id,
        "战斗 UI 的正式结果保留当前节点绑定")
    run_ui._on_battle_finished("player_victory")
    _assert_equal(
        run_ui.run_session.snapshot().phase,
        "awaiting_reward",
        "战斗胜利后进入可见奖励阶段：%s" % run_ui.toast_label.text)
    _assert_equal(run_ui.run_session.snapshot().experience, 0, "领取前战斗奖励不会提前到账")
    _assert_true(run_ui.reward_overlay.visible, "战斗胜利后显示奖励结算页面")
    _assert_true(run_ui.practice_button.disabled, "奖励领取期间修习保持锁定")
    run_ui._claim_reward()
    _assert_equal(run_ui.run_session.snapshot().phase, "awaiting_node", "领取奖励后返回地图待选状态")
    _assert_equal(run_ui.run_session.snapshot().experience, 3, "领取后战斗奖励显示为当前历练")
    _assert_true(not run_ui.reward_overlay.visible, "领取后关闭奖励结算页面")
    _assert_true(
        run_ui.run_session.snapshot().run_log.size() >= 3,
        "地图、战斗节点完成与本局流程共用结构化日志")
    _assert_true(not run_ui.battle_layer.visible, "战斗胜利后关闭战斗层而不自动打开修习")
    _assert_true(not run_ui.practice_overlay.visible, "战斗胜利不会强制弹出修习页面")
    run_ui.queue_free()
    for path in [save_path, save_path + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func _test_battle_scene_prefers_injected_session_and_keeps_standalone_fallback() -> void:
    var injected_scene = BattleScene.instantiate()
    _assert_true(
        injected_scene.battle_session == null,
        "战斗场景实例化时不提前创建并加载默认会话")
    var shared_root = GameCompositionRootScript.new()
    _assert_true(shared_root.initialize(), "UI 注入测试建立共享组合根")
    var shared_run = shared_root.create_run_session()
    var injected_session = shared_run.create_battle_session()
    injected_scene.configure_battle_session(injected_session)
    root.add_child(injected_scene)
    _assert_true(
        injected_scene.battle_session == injected_session,
        "正式流程在 ready 前注入并保留共享战斗会话")
    _assert_true(
        injected_scene.battle_session.engine.content_catalog == shared_root.content_catalog,
        "正式流程复用组合根内容目录而不建立第二份目录")
    injected_scene.queue_free()

    var standalone_scene = BattleScene.instantiate()
    standalone_scene._ensure_battle_session()
    _assert_true(
        standalone_scene.battle_session != null,
        "独立启动战斗场景时建立默认会话")
    _assert_true(
        standalone_scene.battle_session.engine.content_ready,
        "独立战斗场景的默认会话完成内容加载：%s" % ", ".join(
            standalone_scene.battle_session.engine.content_catalog.errors))
    standalone_scene.queue_free()

func _test_front_menu_and_starter_build_flow() -> void:
    var save_path := "/tmp/taiwu-s2-f4c-front-ui.json"
    for path in [save_path, save_path + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    var front_root = GameCompositionRootScript.new()
    _assert_true(front_root.initialize(), "首页自动存档测试建立组合根")
    front_root.run_save_application_service = RunSaveApplicationServiceScript.new(
        SaveRepositoryScript.new(save_path),
        front_root.content_catalog,
        Callable(front_root, "create_run_session"))
    var front = FrontScene.instantiate()
    front.composition_root = front_root
    front.initialize_interface()
    root.add_child(front)
    _assert_true(front.menu_page.visible, "项目入口默认显示主菜单")
    _assert_true(front.continue_button.disabled, "没有存档时继续游戏入口明确不可用")
    _assert_true(front.starter_repository.available_builds().size() == 1, "主菜单读取唯一标准初始构筑")
    front._on_new_game()
    _assert_true(front.build_page.visible, "新游戏进入初始构筑页面")
    _assert_equal(front.selected_starter_build_id, "standard_52", "初始构筑页面默认选中标准52张牌组")
    _assert_true(not front.begin_run_button.disabled, "存在可用初始构筑时允许开始行旅")
    front._start_new_run()
    _assert_true(front.active_run != null, "确认初始构筑后创建本局地图场景")
    _assert_equal(
        front.active_run.run_session.snapshot().starter_build_id,
        "standard_52",
        "初始构筑ID进入本局快照：run=%s" % [
            str(front.active_run.starter_build_id),
            ])
    _assert_equal(
        front.active_run.run_session.snapshot().phase,
        "awaiting_node",
        "确认构筑后本局从地图待选状态开始")
    _assert_true(FileAccess.file_exists(save_path), "新本局稳定 setup_run 边界写入首份自动存档")
    front.queue_free()
    for path in [save_path, save_path + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func _assert_map_route_constraints(graph: Dictionary, label: String) -> void:
    var nodes_by_id: Dictionary = {}
    var incoming: Dictionary = {}
    var outgoing: Dictionary = {}
    var row_counts: Dictionary = {}
    var floor_entries: Array = []
    for node in graph["nodes"]:
        var node_id: String = str(node["id"])
        nodes_by_id[node_id] = node
        incoming[node_id] = []
        outgoing[node_id] = []
        var row: int = int(node["row"])
        row_counts[row] = int(row_counts.get(row, 0)) + 1
        if row == 0:
            floor_entries.append(node_id)
    var start_id := str(graph.get("start_id", ""))
    _assert_true(nodes_by_id.has(start_id), "%s：图中存在单一旅程起点" % label)
    _assert_equal(int(nodes_by_id[start_id]["row"]), -1, "%s：旅程起点位于第1层下方" % label)
    _assert_true(floor_entries.size() >= 1 and floor_entries.size() <= 6, "%s：第1层房间数量为一至六个" % label)
    for row in range(15):
        _assert_true(row_counts.get(row, 0) <= 6, "%s：第%d层最多六个节点" % [label, row + 1])

    var first_floor_destinations: Dictionary = {}
    for edge in graph["edges"]:
        incoming[str(edge["to"])].append(str(edge["from"]))
        outgoing[str(edge["from"])].append(str(edge["to"]))
        if int(edge["from_row"]) == 0:
            _assert_true(
                not first_floor_destinations.has(str(edge["to"])),
                "%s：首层不同节点不共享同一个第二层目的地" % label)
            first_floor_destinations[str(edge["to"])] = true
        var from_type: String = str(nodes_by_id[str(edge["from"])].get("generation_type", nodes_by_id[str(edge["from"])]["type"]))
        var to_type: String = str(nodes_by_id[str(edge["to"])].get("generation_type", nodes_by_id[str(edge["to"])]["type"]))
        if from_type in ["event_shop", "elite", "rest"]:
            _assert_true(from_type != to_type, "%s：精英与休息不沿路线连续" % label)

    _assert_equal(outgoing[start_id].size(), floor_entries.size(), "%s：单一起点连接全部第1层房间" % label)
    _assert_true(_map_can_reach(graph, start_id, graph["boss_id"]), "%s：旅程起点可以到达 Boss" % label)
    for entry_id in floor_entries:
        _assert_true(_map_can_reach(graph, entry_id, graph["boss_id"]), "%s：每个第1层房间都可到达 Boss" % label)

    for node_id in nodes_by_id:
        var node: Dictionary = nodes_by_id[node_id]
        var row: int = int(node["row"])
        var in_count: int = incoming[node_id].size()
        var out_count: int = outgoing[node_id].size()
        if row == -1:
            _assert_true(in_count == 0 and out_count >= 1 and out_count <= 6, "%s：单一起点只连接第1层房间" % label)
        elif row == 0:
            _assert_true(in_count == 1 and out_count >= 1 and out_count <= 3, "%s：第1层房间由单一起点进入" % label)
        elif row < 14:
            _assert_true(in_count >= 1 and in_count <= 3 and out_count >= 1 and out_count <= 3, "%s：中间节点入边与出边均为一至三条" % label)
        elif row == 14:
            _assert_true(in_count >= 1 and in_count <= 3 and out_count == 1, "%s：第十五层节点连接单一 Boss" % label)
        else:
            _assert_equal(out_count, 0, "%s：Boss 没有地图出边" % label)

    for left_index in range(graph["edges"].size()):
        var left: Dictionary = graph["edges"][left_index]
        if int(left["to_row"]) > 14:
            continue
        for right_index in range(left_index + 1, graph["edges"].size()):
            var right: Dictionary = graph["edges"][right_index]
            if int(left["from_row"]) != int(right["from_row"]):
                continue
            var crossing := (
                int(left["from_column"]) < int(right["from_column"])
                and int(left["to_column"]) > int(right["to_column"])) or (
                int(left["from_column"]) > int(right["from_column"])
                and int(left["to_column"]) < int(right["to_column"]))
            _assert_true(not crossing, "%s：相邻楼层连线不交叉" % label)

func _map_node_type(graph: Dictionary, node_id: String) -> String:
    for node in graph["nodes"]:
        if node["id"] == node_id:
            return str(node["type"])
    return ""

func _map_can_reach(graph: Dictionary, start_id: String, target_id: String) -> bool:
    var pending: Array = [start_id]
    var visited: Dictionary = {}
    while not pending.is_empty():
        var current: String = pending.pop_front()
        if current == target_id:
            return true
        if visited.has(current):
            continue
        visited[current] = true
        for edge in graph["edges"]:
            if edge["from"] == current:
                pending.append(str(edge["to"]))
    return false

func _hand_ids(cards: Array) -> Array:
    var ids: Array = []
    for card in cards:
        ids.append(card.id)
    return ids

func _test_scripted_enemy_is_deterministic_and_locked() -> void:
    var first = _tracked_combat_engine()
    var second = _tracked_combat_engine()
    _assert_true(first.setup_scripted_battle(2308), "第一个脚本场景载入")
    _assert_true(second.setup_scripted_battle(2308), "第二个脚本场景载入")
    first.start_player_turn()
    second.start_player_turn()
    _assert_equal(_hand_ids(first.enemy.hand), _hand_ids(second.enemy.hand), "相同种子敌方起手一致")
    _assert_equal(first.locked_enemy_card_ids, ["enemy:fire_2", "enemy:forest_4"], "第一回合敌方按 JSON 定义 ID 锁定唯一战斗实例")
    _assert_equal(first.locked_enemy_card_ids, second.locked_enemy_card_ids, "敌方锁定不依赖玩家选牌")

func _test_enemy_ai_plan_is_deterministic_and_hidden() -> void:
    var first = _tracked_combat_engine()
    var second = _tracked_combat_engine()
    _assert_true(first.setup_scripted_battle(2308, "res://data/scripted_battle.json", true), "第一个调试 AI 场景载入")
    _assert_true(second.setup_scripted_battle(2308, "res://data/scripted_battle.json", true), "第二个调试 AI 场景载入")
    first.start_player_turn()
    second.start_player_turn()
    _assert_equal(first.locked_enemy_card_ids, second.locked_enemy_card_ids, "相同种子与局面产生相同 AI 选牌")
    _assert_equal(first.enemy_plan, second.enemy_plan, "相同种子与局面产生相同公开计划")
    _assert_true(first.enemy_plan.has("damage"), "公开计划包含预计伤害")
    _assert_true(first.enemy_plan.has("defense"), "公开计划包含预计防御")
    _assert_true(first.enemy_plan.has("combo"), "公开计划包含连击提示")
    _assert_equal(first.enemy_plan["damage"], 6, "首击公开计划正确汇总三段预计伤害")
    _assert_equal(first.enemy_plan["defense"], 0, "首击公开计划正确显示零防御")
    _assert_true(not first.enemy_plan.has("hand"), "公开计划不包含具体牌型")
    _assert_true(not first.enemy_plan.has("cards"), "公开计划不包含具体真气")
    _assert_true(not first.enemy_plan.has("technique"), "公开计划不包含具体功法")

func _test_enemy_ai_uses_same_qi_gauge() -> void:
    var engine = _tracked_combat_engine()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    engine.player.hand = [_card("2", "wind"), _card("3", "forest"), _card("4", "mountain")]
    engine.player.draw_pile.clear()
    _assert_true(engine.enemy_plan.has("same_qi_gain"), "AI 首击计划包含预计同气收益")
    var result := engine.confirm_play(_ids(engine.player.hand.slice(0, 2)))
    _assert_true(result["success"], "玩家混属性出牌后同步行动成功")
    _assert_true(engine.enemy.same_qi_value >= 0, "敌方实际结算同气槽")

func _test_both_sides_use_synchronized_combo() -> void:
    var engine = _tracked_combat_engine()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    engine.player.hand = [_card("2", "wind"), _card("3", "forest"), _card("4", "mountain")]
    engine.player.draw_pile.clear()
    engine.confirm_play([engine.player.hand[0].id])
    _assert_equal(engine.actions_available, 0, "单张行动 G=0 不会自动获得连击")
    _assert_equal(engine.enemy_actions_available, 0, "敌方同样只按同气槽阈值获得连击")

func _test_ai_battle_reaches_terminal_state() -> void:
    var engine = _tracked_combat_engine()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    var steps := 0
    var all_actions_succeeded := true
    while engine.battle_state == "active" and steps < 200:
        if engine.actions_available > 0 and not engine.player.hand.is_empty():
            var result: Dictionary = engine.confirm_play([engine.player.hand[0].id])
            all_actions_succeeded = all_actions_succeeded and result.get("success", false)
        else:
            engine.end_player_turn()
            if engine.battle_state == "active":
                engine.start_player_turn()
        steps += 1
    _assert_true(all_actions_succeeded, "完整调试 AI 战斗中玩家动作均能结算")
    _assert_true(engine.battle_state != "active", "完整调试 AI 战斗在安全步数内结束")
    _assert_true(engine.battle_state != "scenario_error", "完整调试 AI 战斗不发生场景错误")

func _install_sync_guard(engine) -> void:
    engine.repository.techniques["sync_guard"] = {
        "id": "sync_guard",
        "name": "同步护身测试",
        "pool": "high",
        "effects": [
            {"op": "defense", "amount": {"kind": "power"}},
            {"op": "damage", "amount": {"kind": "power"}},
        ],
    }
    engine.sequence_book.configure({"high_card": ["sync_guard"]})
    engine.enemy_sequence_book.configure({"high_card": ["sync_guard"]})

func _content_entry_index(values: Array, content_id: String) -> int:
    for index in range(values.size()):
        if values[index] is Dictionary \
                and str(values[index].get("id", "")) == content_id:
            return index
    return -1

func _scripted_engine_with_player_high(rank: String = "5"):
    var engine = _tracked_combat_engine()
    engine.setup_scripted_battle(2308)
    engine.start_player_turn()
    engine.player.hand = [_card(rank, "mountain"), _card("3", "forest")]
    engine.player.draw_pile.clear()
    return engine

func _test_synchronized_defense_before_damage() -> void:
    var engine = _scripted_engine_with_player_high("5")
    _install_sync_guard(engine)
    var result := engine.confirm_play([engine.player.hand[0].id])
    _assert_true(result["success"], "同步出牌成功")
    _assert_equal(result["enemy_preview"]["hand"]["id"], "high_card", "敌方揭示后识别牌型")
    _assert_equal(engine.player.life, 100, "敌方伤害先被我方本击建立的防御吸收")
    _assert_equal(engine.player.defense, 1, "我方五点防御承受敌方四点伤害")
    _assert_equal(engine.enemy.life, 99, "敌方先建立四点防御后只损失一点生命")
    _assert_equal(engine.enemy.defense, 0, "敌方本击防御被我方伤害耗尽")
    _assert_equal(engine.sequence_book.position("high_card"), 0, "单门我方序列循环回第一门")
    _assert_equal(engine.enemy_sequence_book.position("high_card"), 0, "敌我序列分别推进")

func _install_lethal_strike(engine) -> void:
    engine.repository.techniques["sync_lethal"] = {
        "id": "sync_lethal",
        "name": "同步致命测试",
        "pool": "high",
        "effects": [{"op": "damage", "amount": {"kind": "power"}}],
    }
    engine.sequence_book.configure({"high_card": ["sync_lethal"]})
    engine.enemy_sequence_book.configure({"high_card": ["sync_lethal"]})

func _test_synchronized_lethal_and_battle_results() -> void:
    var unresolved = _scripted_engine_with_player_high("5")
    _install_lethal_strike(unresolved)
    unresolved.player.life = 4
    unresolved.enemy.life = 5
    var unresolved_result := unresolved.confirm_play([unresolved.player.hand[0].id])
    _assert_true(unresolved_result["success"], "双方致命同步行动成功")
    _assert_equal(unresolved.player.life, 0, "敌方即使同击被击倒仍完成已锁定伤害")
    _assert_equal(unresolved.enemy.life, 0, "我方同步伤害击倒敌方")
    _assert_equal(unresolved.battle_state, "unresolved_draw", "同归于尽不擅自判定胜负")

    var victory = _scripted_engine_with_player_high("9")
    _install_lethal_strike(victory)
    victory.enemy.life = 3
    victory.confirm_play([victory.player.hand[0].id])
    _assert_equal(victory.battle_state, "player_victory", "敌方生命归零判定胜利")

    var exhausted = _scripted_engine_with_player_high("2")
    _install_lethal_strike(exhausted)
    exhausted.player.hand = [exhausted.player.hand[0]]
    exhausted.player.draw_pile.clear()
    exhausted.confirm_play([exhausted.player.hand[0].id])
    _assert_equal(exhausted.battle_state, "player_defeat", "无手牌无牌库且敌人存活判负")
