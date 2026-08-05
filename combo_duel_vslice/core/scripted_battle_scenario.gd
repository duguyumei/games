class_name ScriptedBattleScenario
extends RefCounted

const DEFAULT_PATH := "res://data/scripted_battle.json"

var definition: Dictionary = {}

func load_from_file(path: String = DEFAULT_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("脚本化战斗场景无法解析：%s" % path)
        return false
    return configure(parsed)

func configure(value: Dictionary) -> bool:
    definition = value.duplicate(true)
    return not definition.is_empty()

func scenario_name() -> String:
    return str(definition.get("name", "脚本化试炼"))

func player_definition() -> Dictionary:
    return definition.get("player", {})

func enemy_definition() -> Dictionary:
    return definition.get("enemy", {})

func enemy_sequences() -> Dictionary:
    return enemy_definition().get("sequences", {})

func enemy_ai_policy() -> Dictionary:
    return enemy_definition().get("ai", {})

func enemy_action_ids(round_number: int, action_index: int) -> Array:
    var rounds: Array = definition.get("rounds", [])
    var round_offset := round_number - 1
    if round_offset < 0 or round_offset >= rounds.size():
        return []
    var actions: Array = rounds[round_offset].get("actions", [])
    if action_index < 0 or action_index >= actions.size():
        return []
    return actions[action_index].duplicate()

func arrange_enemy_deck(cards: Array) -> Array:
    var wanted_ids: Array = []
    wanted_ids.append_array(enemy_definition().get("opening_hand", []))
    wanted_ids.append_array(enemy_definition().get("draw_order", []))
    var by_id: Dictionary = {}
    for card in cards:
        by_id[card.definition_id] = card
    var wanted_cards: Array = []
    var used: Dictionary = {}
    for card_id_value in wanted_ids:
        var card_id := str(card_id_value)
        if used.has(card_id) or not by_id.has(card_id):
            continue
        used[card_id] = true
        wanted_cards.append(by_id[card_id])
    var arranged: Array = []
    for card in cards:
        if not used.has(card.definition_id):
            arranged.append(card)
    for index in range(wanted_cards.size() - 1, -1, -1):
        arranged.append(wanted_cards[index])
    return arranged
