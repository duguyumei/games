class_name CardReshapeBehaviorContext
extends RefCounted

## 重塑行为处理器的窄上下文。
## 处理器只通过这里读取/修改当前计算，不持有战斗或本局会话。

var card
var value: int = 0
var attribute_id: String = ""
var holder
var payload: Dictionary = {}
var result: Dictionary = {}
var effect_ports
var rng: RandomNumberGenerator
var trigger: String = ""
var calculation_context: Dictionary = {}
var anomaly_category: String = ""
var anomaly_id: String = ""
var zone_name: String = ""

func configure(values: Dictionary) -> CardReshapeBehaviorContext:
    card = values.get("card")
    value = int(values.get("value", 0))
    attribute_id = str(values.get("attribute_id", ""))
    holder = values.get("holder")
    payload = values.get("payload", {}).duplicate(true)
    result = values.get("result", {}).duplicate(true)
    effect_ports = values.get("effect_ports")
    rng = values.get("rng")
    trigger = str(values.get("trigger", ""))
    calculation_context = values.get("calculation_context", {}).duplicate(true)
    anomaly_category = str(values.get("anomaly_category", ""))
    anomaly_id = str(values.get("anomaly_id", ""))
    zone_name = str(values.get("zone_name", ""))
    return self

func matches_origin_attribute(behavior: Dictionary) -> bool:
    var expected := str(behavior.get("origin_attribute", ""))
    if expected == "":
        return true
    var origin = card.reshape_origin if card != null else {}
    if not origin is Dictionary:
        return false
    return str(origin.get("payload", {}).get("attribute", "")) == expected
