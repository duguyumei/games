class_name AiCandidate
extends RefCounted

const VERSION := 3

var candidate_id: String = ""
var groups: Array = []
var summary: Dictionary = {}
var tags: Array[String] = []
var action_proposal = null
## 仅本地轨迹使用，不进入 public_snapshot()。
var diagnostic_candidate_id: String = ""

func configure(values: Dictionary, proposal = null):
    candidate_id = str(values.get("candidate_id", values.get("id", "")))
    groups = values.get("groups", []).duplicate(true)
    summary = values.get("summary", {}).duplicate(true)
    tags.clear()
    for tag in values.get("tags", []):
        tags.append(str(tag))
    action_proposal = proposal
    diagnostic_candidate_id = str(values.get("diagnostic_candidate_id", ""))
    return self

func is_valid() -> bool:
    return candidate_id != "" and not groups.is_empty()

func public_snapshot() -> Dictionary:
    return {
        "schema_version": VERSION,
        "candidate_id": candidate_id,
        "groups": groups.duplicate(true),
        "summary": summary.duplicate(true),
        "tags": tags.duplicate(),
    }
