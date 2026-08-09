class_name TechniqueSequenceBook
extends RefCounted

const DATA_PATH := "res://data/vertical_slice_sequences.json"

var sequences: Dictionary = {}
var positions: Dictionary = {}

func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("功法序列数据无法解析：%s" % path)
        return false
    configure(parsed)
    return true

func configure(values: Dictionary) -> void:
    sequences.clear()
    for hand_id in values:
        if str(hand_id) == "version":
            continue
        if values[hand_id] is Array:
            sequences[str(hand_id)] = values[hand_id].duplicate(true)
    reset()

func configure_hand_progression(values: Dictionary) -> void:
    var next: Dictionary = {}
    for hand_id in sequences:
        var progression: Dictionary = values.get(hand_id, {})
        var sequence = progression.get("sequence", []) if progression is Dictionary else []
        next[hand_id] = sequence.duplicate(true) if sequence is Array else []
    for hand_id in values:
        if not next.has(str(hand_id)):
            var progression: Dictionary = values[hand_id]
            var sequence = progression.get("sequence", []) if progression is Dictionary else []
            next[str(hand_id)] = sequence.duplicate(true) if sequence is Array else []
    sequences = next
    reset()

func reset() -> void:
    positions.clear()
    for hand_id in sequences:
        positions[hand_id] = 0

func current_id(hand_id: String) -> String:
    var sequence: Array = sequences.get(hand_id, [])
    if sequence.is_empty():
        return ""
    var position: int = int(positions.get(hand_id, 0)) % sequence.size()
    return str(sequence[position])

func next_id(hand_id: String) -> String:
    var sequence: Array = sequences.get(hand_id, [])
    if sequence.is_empty():
        return ""
    var position: int = (int(positions.get(hand_id, 0)) + 1) % sequence.size()
    return str(sequence[position])

func advance(hand_id: String) -> void:
    var sequence: Array = sequences.get(hand_id, [])
    if sequence.is_empty():
        return
    positions[hand_id] = (int(positions.get(hand_id, 0)) + 1) % sequence.size()

func position(hand_id: String) -> int:
    return int(positions.get(hand_id, 0))
