class_name AiConversationSnapshot
extends RefCounted

## 远程 AI 对话的只读持久化快照。
##
## 这里只冻结对话上下文、交换记录和压缩游标，不负责请求编排、重试或
## 密钥脱敏；前者属于 AiBattleConversation，后者属于 AiConversationStore。

const SCHEMA_VERSION := 1

var battle_id: String = ""
var context_snapshot: Dictionary = {}
var settings: Dictionary = {}
var public_events: Array = []
var exchanges: Array = []
var work_summary: Dictionary = {}
var last_compacted_round: int = 0
var last_sent_public_sequence: int = -1
var provider_epoch: int = 0
var context_sent_in_epoch: bool = false

static func from_dict(values: Dictionary) -> AiConversationSnapshot:
    var result := AiConversationSnapshot.new()
    result.battle_id = str(values.get("battle_id", ""))
    result.context_snapshot = values.get("context_snapshot", {}).duplicate(true)
    result.settings = values.get("settings", {}).duplicate(true)
    result.public_events = values.get("public_events", []).duplicate(true)
    result.exchanges = values.get("exchanges", []).duplicate(true)
    result.work_summary = values.get("work_summary", {}).duplicate(true)
    result.last_compacted_round = int(values.get("last_compacted_round", 0))
    result.last_sent_public_sequence = int(values.get(
        "last_sent_public_sequence", -1))
    result.provider_epoch = int(values.get("provider_epoch", 0))
    result.context_sent_in_epoch = bool(values.get("context_sent_in_epoch", false))
    return result

func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "battle_id": battle_id,
        "context_snapshot": context_snapshot.duplicate(true),
        "settings": settings.duplicate(true),
        "public_events": public_events.duplicate(true),
        "exchanges": exchanges.duplicate(true),
        "work_summary": work_summary.duplicate(true),
        "last_compacted_round": last_compacted_round,
        "last_sent_public_sequence": last_sent_public_sequence,
        "provider_epoch": provider_epoch,
        "context_sent_in_epoch": context_sent_in_epoch,
    }
