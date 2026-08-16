class_name StatusBehaviorContext
extends RefCounted

## 一次状态行为分发的类型化上下文。
##
## 不同触发只填写自己拥有的字段；处理器必须只读取其声明支持的触发字段。

var trigger: String = ""
var status_id: String = ""
var category: String = ""
var definition: Dictionary = {}
var behavior: Dictionary = {}
var actor = null
var holder = null
var card = null
var event = null
var flow_kind: String = ""
var count: int = 0
var resolution: Dictionary = {}
var attacker = null
var source_kind: String = ""
var defense_lost: int = 0
var life_lost: int = 0
var card_anomaly_service = null
var effect_ports = null
var source_card_instance_id: String = ""
var source_trigger: String = ""
var action_token: String = ""
var replay_depth: int = 0
var trigger_sequence: int = 0
var rng: RandomNumberGenerator = null

func configure(values: Dictionary):
    trigger = str(values.get("trigger", ""))
    status_id = str(values.get("status_id", ""))
    category = str(values.get("category", ""))
    definition = values.get("definition", {}).duplicate(true)
    behavior = values.get("behavior", {}).duplicate(true)
    actor = values.get("actor")
    holder = values.get("holder")
    card = values.get("card")
    event = values.get("event")
    flow_kind = str(values.get("flow_kind", ""))
    count = int(values.get("count", 0))
    resolution = values.get("resolution", {})
    attacker = values.get("attacker")
    source_kind = str(values.get("source_kind", ""))
    defense_lost = int(values.get("defense_lost", 0))
    life_lost = int(values.get("life_lost", 0))
    card_anomaly_service = values.get("card_anomaly_service")
    effect_ports = values.get("effect_ports")
    source_card_instance_id = str(values.get("source_card_instance_id", ""))
    source_trigger = str(values.get("source_trigger", ""))
    action_token = str(values.get("action_token", ""))
    replay_depth = int(values.get("replay_depth", 0))
    trigger_sequence = int(values.get("trigger_sequence", 0))
    rng = values.get("rng")
    return self
