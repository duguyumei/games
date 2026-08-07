class_name ChatCompletionsAiProvider
extends "res://core/ai/providers/ai_provider.gd"

const SettingsScript = preload("res://core/ai/providers/ai_provider_settings.gd")
const PromptEncoderScript = preload("res://core/ai/ai_prompt_encoder.gd")

var settings = SettingsScript.new()
var prompt_encoder := PromptEncoderScript.new()
var pending: Dictionary = {}
var submitted_requests: Array = []
var _messages_by_battle: Dictionary = {}
var _epoch_by_battle: Dictionary = {}

func _init(config: Dictionary = {}) -> void:
    settings.configure(config)

func provider_id() -> String:
    return settings.provider_id

func configure(config) -> void:
    if config is Object and config.has_method("snapshot"):
        settings.configure(config.snapshot(true))
    elif config is Dictionary:
        settings.configure(config)

func build_request_payload(payload: Dictionary) -> Dictionary:
    var battle_id := str(payload.get("battle_id", "default"))
    var epoch := int(payload.get("provider_epoch", 0))
    _ensure_session(battle_id, epoch)
    _messages_by_battle[battle_id].append(
        prompt_encoder.decision_message(payload))
    var messages: Array = _messages_by_battle[battle_id].duplicate(true)
    return prompt_encoder.build_chat_body(
        messages,
        settings.model,
        settings.thinking_enabled,
        settings.reasoning_effort,
        settings.max_tokens,
        settings.extra_body)

func submit(request_id: String, payload: Dictionary) -> bool:
    if request_id == "" or pending.has(request_id) or not settings.is_valid():
        return false
    if settings.api_key == "":
        return false
    _ensure_in_tree()
    var request_node := HTTPRequest.new()
    request_node.timeout = float(settings.timeout_msec) / 1000.0
    add_child(request_node)
    request_node.request_completed.connect(_on_request_completed.bind(request_id, request_node))
    var headers: PackedStringArray = [
        "Content-Type: application/json",
        "Authorization: Bearer %s" % settings.api_key,
    ]
    for key in settings.extra_headers:
        if str(key).to_lower() in ["authorization", "api-key", "x-api-key"]:
            continue
        headers.append("%s: %s" % [str(key), str(settings.extra_headers[key])])
    var battle_id := str(payload.get("battle_id", "default"))
    var epoch := int(payload.get("provider_epoch", 0))
    _ensure_session(battle_id, epoch)
    var message_count_before: int = _messages_by_battle[battle_id].size()
    var request_payload := build_request_payload(payload)
    pending[request_id] = {
        "node": request_node,
        "payload": payload.duplicate(true),
        "request_payload": request_payload.duplicate(true),
        "battle_id": battle_id,
        "message_count_before": message_count_before,
    }
    submitted_requests.append({
        "request_id": request_id,
        "payload": payload.duplicate(true),
        "request_payload": request_payload.duplicate(true),
    })
    var error := request_node.request(
        settings.endpoint_url(),
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(request_payload))
    if error != OK:
        _rollback_messages(pending[request_id])
        _clear_pending(request_id, request_node)
        return false
    return true

func cancel(request_id: String) -> bool:
    if not pending.has(request_id):
        return false
    var request_node = pending[request_id].get("node")
    if request_node != null:
        request_node.cancel_request()
    _rollback_messages(pending[request_id])
    _clear_pending(request_id, request_node)
    return true

func _on_request_completed(
        result: int,
        response_code: int,
        _headers: PackedStringArray,
        body: PackedByteArray,
        request_id: String,
        request_node: HTTPRequest) -> void:
    if not pending.has(request_id):
        return
    var request_data: Dictionary = pending[request_id]
    var battle_id := str(request_data.get("battle_id", "default"))
    var raw_text := body.get_string_from_utf8()
    _clear_pending(request_id, request_node)
    var provider_result := parse_provider_response(
        result, response_code, raw_text)
    if not provider_result.get("success", false):
        _rollback_messages(request_data)
        request_completed.emit(request_id, provider_result)
        return
    var content := str(provider_result.get("body", ""))
    if not _messages_by_battle.has(battle_id):
        _messages_by_battle[battle_id] = [prompt_encoder.system_message()]
    _messages_by_battle[battle_id].append({"role": "assistant", "content": content})
    request_completed.emit(request_id, provider_result)

func parse_provider_response(
        result: int,
        response_code: int,
        raw_text: String) -> Dictionary:
    var parsed = JSON.parse_string(raw_text)
    if result != HTTPRequest.RESULT_SUCCESS:
        return {
            "success": false,
            "error_code": "HTTP_TRANSPORT_ERROR",
            "message": "HTTP 请求失败（result=%d）" % result,
            "response_code": response_code,
        }
    if response_code < 200 or response_code >= 300:
        return {
            "success": false,
            "error_code": "HTTP_STATUS_%d" % response_code,
            "message": str(parsed.get("error", {}).get(
                "message", "远程服务返回 HTTP %d" % response_code)) \
                if parsed is Dictionary \
                else "远程服务返回 HTTP %d" % response_code,
            "response_code": response_code,
            "body": parsed,
        }
    if not parsed is Dictionary:
        return {
            "success": false,
            "error_code": "INVALID_PROVIDER_JSON",
            "message": "远程服务返回的不是 JSON 对象",
            "response_code": response_code,
        }
    var choices: Array = parsed.get("choices", [])
    if choices.is_empty():
        return {
            "success": false,
            "error_code": "EMPTY_CHOICES",
            "message": "远程服务没有返回 choices",
            "response_code": response_code,
            "usage": parsed.get("usage", {}).duplicate(true),
        }
    return {
        "success": true,
        "body": str(choices[0].get("message", {}).get("content", "")),
        "provider_response": parsed.duplicate(true),
        "usage": parsed.get("usage", {}).duplicate(true),
        "response_code": response_code,
    }

func _clear_pending(request_id: String, request_node) -> void:
    pending.erase(request_id)
    if request_node != null and is_instance_valid(request_node):
        request_node.queue_free()

func _ensure_in_tree() -> void:
    if is_inside_tree():
        return
    var main_loop = Engine.get_main_loop()
    if main_loop is SceneTree and main_loop.root != null:
        main_loop.root.add_child(self)

func _ensure_session(battle_id: String, epoch: int) -> void:
    if not _messages_by_battle.has(battle_id) \
            or int(_epoch_by_battle.get(battle_id, -1)) != epoch:
        _messages_by_battle[battle_id] = [prompt_encoder.system_message()]
        _epoch_by_battle[battle_id] = epoch

func _rollback_messages(request_data: Dictionary) -> void:
    var battle_id := str(request_data.get("battle_id", "default"))
    if not _messages_by_battle.has(battle_id):
        return
    var count_before := int(request_data.get(
        "message_count_before", _messages_by_battle[battle_id].size()))
    _messages_by_battle[battle_id].resize(maxi(1, count_before))
