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

func configure(values: Dictionary) -> CardReshapeBehaviorContext:
    card = values.get("card")
    value = int(values.get("value", 0))
    attribute_id = str(values.get("attribute_id", ""))
    holder = values.get("holder")
    payload = values.get("payload", {}).duplicate(true)
    result = values.get("result", {}).duplicate(true)
    return self
