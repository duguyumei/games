class_name AiProvider
extends Node

signal request_completed(request_id, result)

func provider_id() -> String:
    return "base"

func submit(_request_id: String, _payload: Dictionary) -> bool:
    return false

func cancel(_request_id: String) -> bool:
    return false
