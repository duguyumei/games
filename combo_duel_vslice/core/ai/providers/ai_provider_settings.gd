class_name AiProviderSettings
extends RefCounted

const DEFAULT_PROVIDER_ID := "deepseek"
const DEFAULT_BASE_URL := "https://api.deepseek.com"
const DEFAULT_PATH := "/chat/completions"
const DEFAULT_MODEL := "deepseek-v4-flash"
const PRO_MODEL := "deepseek-v4-pro"
const PROTECTED_BODY_KEYS := [
    "model",
    "messages",
    "stream",
    "thinking",
    "reasoning_effort",
    "max_tokens",
]
const SECRET_BODY_KEYS := [
    "api_key",
    "authorization",
    "api-key",
    "x-api-key",
]

var provider_id: String = DEFAULT_PROVIDER_ID
var api_style: String = "openai_chat_completions"
var base_url: String = DEFAULT_BASE_URL
var path: String = DEFAULT_PATH
var api_key: String = ""
var model: String = DEFAULT_MODEL
var thinking_enabled: bool = true
var reasoning_effort: String = "medium"
var timeout_msec: int = 30000
var max_tokens: int = 256
var extra_body: Dictionary = {}
var extra_headers: Dictionary = {}

func _init(values: Dictionary = {}) -> void:
    configure(values)

func configure(values: Dictionary):
    provider_id = str(values.get("provider_id", provider_id))
    api_style = str(values.get("api_style", api_style))
    base_url = str(values.get("base_url", base_url)).rstrip("/")
    path = str(values.get("path", path))
    api_key = str(values.get("api_key", api_key))
    model = str(values.get("model", model))
    thinking_enabled = bool(values.get("thinking_enabled", thinking_enabled))
    if values.has("thinking") and values["thinking"] is Dictionary:
        thinking_enabled = str(values["thinking"].get("type", "enabled")) == "enabled"
    reasoning_effort = str(values.get("reasoning_effort", reasoning_effort))
    timeout_msec = maxi(1000, int(values.get("timeout_msec", timeout_msec)))
    max_tokens = maxi(32, int(values.get("max_tokens", max_tokens)))
    extra_body = _sanitize_extra_body(values.get("extra_body", extra_body))
    extra_headers = values.get("extra_headers", extra_headers).duplicate(true)
    if model == PRO_MODEL and not values.has("reasoning_effort"):
        reasoning_effort = "high"
    return self

func endpoint_url() -> String:
    return "%s/%s" % [base_url, path.trim_prefix("/")]

func is_valid() -> bool:
    return provider_id != "" and api_style == "openai_chat_completions" \
        and base_url.begins_with("http") and path != "" and model != ""

func public_snapshot() -> Dictionary:
    return {
        "provider_id": provider_id,
        "api_style": api_style,
        "base_url": base_url,
        "path": path,
        "model": model,
        "thinking_enabled": thinking_enabled,
        "reasoning_effort": reasoning_effort,
        "timeout_msec": timeout_msec,
        "max_tokens": max_tokens,
        "extra_body": extra_body.duplicate(true),
        "has_api_key": api_key != "",
    }

func snapshot(include_secret: bool = false) -> Dictionary:
    var result := public_snapshot()
    if include_secret:
        result["api_key"] = api_key
        result["extra_headers"] = extra_headers.duplicate(true)
    return result

func _sanitize_extra_body(value) -> Dictionary:
    var result: Dictionary = {}
    if not value is Dictionary:
        return result
    for key in value:
        var normalized := str(key).to_lower()
        if normalized in PROTECTED_BODY_KEYS or normalized in SECRET_BODY_KEYS:
            continue
        result[str(key)] = _sanitize_secret_values(value[key])
    return result.duplicate(true)

func _sanitize_secret_values(value):
    if value is Dictionary:
        var sanitized: Dictionary = {}
        for key in value:
            if str(key).to_lower() in SECRET_BODY_KEYS:
                continue
            sanitized[str(key)] = _sanitize_secret_values(value[key])
        return sanitized
    if value is Array:
        var sanitized: Array = []
        for item in value:
            sanitized.append(_sanitize_secret_values(item))
        return sanitized
    return value
