class_name AiSettingsService
extends RefCounted

## 远程 AI 配置的加载、规范化与公开投影边界。
##
## 这里管理本机 Provider、会话和存储设置，不发送网络请求，也不把密钥放入
## 公开快照；请求执行与审计脱敏由各自组件负责。

const ProviderSettingsScript = preload("res://core/ai/providers/ai_provider_settings.gd")

const DEFAULT_PATH := "user://ai/ai_settings.cfg"
const DEFAULT_CONVERSATION_DIRECTORY := "user://ai/conversations"
const DEFAULT_DECISION_TRACE_DIRECTORY := "user://ai/traces"

var config_path: String = DEFAULT_PATH
var last_error: String = ""
var _loaded: bool = false
var _enabled: bool = false
var _provider: Dictionary = {}
var _conversation: Dictionary = {}
var _storage: Dictionary = {}

func _init(path: String = DEFAULT_PATH) -> void:
    config_path = path
    _reset_defaults()

func load_or_create() -> bool:
    if not FileAccess.file_exists(config_path):
        if not _write_default_file():
            return false
    return reload()

func reload() -> bool:
    _reset_defaults()
    var config := ConfigFile.new()
    var error := config.load(config_path)
    if error != OK:
        last_error = "AI 配置文件无法读取：%s（错误 %d）" % [config_path, error]
        return false
    _enabled = bool(config.get_value("remote_ai", "enabled", false))
    for key in _provider.keys():
        _provider[key] = config.get_value("provider", key, _provider[key])
    for key in _conversation.keys():
        _conversation[key] = config.get_value("conversation", key, _conversation[key])
    for key in _storage.keys():
        _storage[key] = config.get_value("storage", key, _storage[key])
    var normalized = ProviderSettingsScript.new(_provider)
    if not normalized.is_valid():
        last_error = "AI Provider 配置无效"
        return false
    _provider = normalized.snapshot(true)
    _conversation["compression_interval_rounds"] = maxi(
        1, int(_conversation.get("compression_interval_rounds", 5)))
    _conversation["max_retries"] = maxi(
        0, int(_conversation.get("max_retries", 1)))
    _conversation["intent_visibility"] = (
        "full"
        if str(_conversation.get("intent_visibility", "full")) == "full"
        else "ready_only")
    _storage["conversation_directory"] = str(
        _storage.get("conversation_directory", DEFAULT_CONVERSATION_DIRECTORY))
    _storage["decision_trace_directory"] = str(
        _storage.get("decision_trace_directory", DEFAULT_DECISION_TRACE_DIRECTORY))
    _loaded = true
    last_error = ""
    return true

func is_loaded() -> bool:
    return _loaded

func runtime_profile(include_secret: bool = true) -> Dictionary:
    var provider := _provider.duplicate(true)
    if not include_secret:
        provider.erase("api_key")
        provider.erase("extra_headers")
    return {
        "enabled": _enabled,
        "provider": provider,
        "conversation": _conversation.duplicate(true),
        "storage": _storage.duplicate(true),
    }

func public_snapshot() -> Dictionary:
    var provider: Dictionary = runtime_profile(false)["provider"]
    provider["has_api_key"] = str(_provider.get("api_key", "")) != ""
    return {
        "loaded": _loaded,
        "enabled": _enabled,
        "config_path": config_path,
        "provider": provider,
        "conversation": _conversation.duplicate(true),
        "storage": _storage.duplicate(true),
        "last_error": last_error,
    }

func _reset_defaults() -> void:
    var provider_defaults = ProviderSettingsScript.new()
    _enabled = false
    _provider = provider_defaults.snapshot(true)
    _conversation = {
        "compression_enabled": true,
        "compression_interval_rounds": 5,
        "max_retries": 1,
        "intent_visibility": "full",
    }
    _storage = {
        "autosave_conversation": true,
        "conversation_directory": DEFAULT_CONVERSATION_DIRECTORY,
        "autosave_decision_trace": true,
        "decision_trace_directory": DEFAULT_DECISION_TRACE_DIRECTORY,
    }
    _loaded = false
    last_error = ""

func _write_default_file() -> bool:
    if not _ensure_parent_directory(config_path):
        return false
    var config := ConfigFile.new()
    config.set_value("remote_ai", "enabled", false)
    for key in _provider:
        if key in ["extra_body", "extra_headers", "has_api_key"]:
            continue
        config.set_value("provider", key, _provider[key])
    for key in _conversation:
        config.set_value("conversation", key, _conversation[key])
    for key in _storage:
        config.set_value("storage", key, _storage[key])
    var error := config.save(config_path)
    if error != OK:
        last_error = "AI 默认配置文件无法创建：%s（错误 %d）" % [config_path, error]
        return false
    return true

func _ensure_parent_directory(path: String) -> bool:
    var parent := path.get_base_dir()
    if parent == "":
        return true
    var error := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(parent))
    if error not in [OK, ERR_ALREADY_EXISTS]:
        last_error = "AI 配置目录无法创建：%s（错误 %d）" % [parent, error]
        return false
    return true
