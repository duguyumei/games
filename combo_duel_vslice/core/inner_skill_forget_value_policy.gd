class_name InnerSkillForgetValuePolicy
extends RefCounted

## 普通内功遗忘所得的窄策略边界。
##
## 当前只读取定义中的基础值；未来本局道具、事件或内功成长可以通过注入同一
## `resolve(definition, growth)` 接口修改有效值，而不需要让配装服务识别内容 ID。

func resolve(definition: Dictionary, _growth) -> int:
    return int(definition["forget_value"])
