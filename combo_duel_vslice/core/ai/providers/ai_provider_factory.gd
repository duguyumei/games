class_name AiProviderFactory
extends RefCounted

const SettingsScript = preload("res://core/ai/providers/ai_provider_settings.gd")
const ChatProviderScript = preload("res://core/ai/providers/chat_completions_ai_provider.gd")

static func default_deepseek_config(model: String = SettingsScript.DEFAULT_MODEL) -> Dictionary:
    return SettingsScript.new({"model": model}).snapshot(false)

static func create(config: Dictionary = {}):
    var resolved := config.duplicate(true)
    if str(resolved.get("kind", "remote")) == "mock":
        var mock_provider_script = load(
            "res://core/ai/providers/mock_ai_provider.gd")
        return mock_provider_script.new(bool(resolved.get("auto_complete", true)))
    if str(resolved.get("api_key", "")) == "":
        resolved["api_key"] = OS.get_environment("DEEPSEEK_API_KEY")
    return ChatProviderScript.new(resolved)
