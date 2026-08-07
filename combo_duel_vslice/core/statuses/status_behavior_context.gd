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
var status_system = null
var effect_ports = null

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
    status_system = values.get("status_system")
    effect_ports = values.get("effect_ports")
    return self
