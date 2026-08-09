# 本局内容效果扩展指南

- 状态：S2-F1A 平台契约
- 适用范围：战斗外、会改变本局成长库存的内容效果
- 不适用范围：战斗功法效果、地图推进、UI 流程和功行计算

## 1. Java 开发者对照

| Godot 类 | Java 语境中的对应概念 | 职责 |
|---|---|---|
| `RunEffectHandler` | Interface / SPI | 声明稳定操作 ID，校验专属参数，在事务工作副本上执行一个小能力 |
| `RunEffectHandlerRegistry` | Strategy 注册中心 | 维护 `op -> Handler` 的唯一映射，拒绝非法或重复 ID，完成运行时分派 |
| `RunEffectContext` | Application Context / Command Context | 向 Handler 提供工作副本和只读语义元数据，不暴露 `RunSession` |
| `RunMutationService` | Application Service + Transaction Boundary | 先校验整组效果，再复制完整成长状态，顺序执行，全部成功后一次提交 |
| `ContentValidator` | 启动期 Bean/配置校验 | 内容加载时通过同一注册表验证操作是否存在及参数是否合法 |
| JSON 内容文件 | 运行时配置 | 选择已注册能力并提供参数，不承担程序控制流 |

战斗内的 `EffectHandlerRegistry` 与本局的 `RunEffectHandlerRegistry` 采用相似模式，
但上下文和生命周期不同。两者保持独立，避免本局库存能力反向依赖战斗引擎。

## 2. 调用与事务边界

```text
RunSession
  -> NodeRewardService
    -> RunMutationService
      -> RunEffectHandlerRegistry
        -> RunEffectHandler
      -> GrowthInventory 工作副本
```

`NodeRewardService` 只创建奖励包并把整包交给一次事务。它不识别 `gain_experience`、
`heal_life` 或任何内容 ID。操作分派只发生在注册表中。

事务流程如下：

1. 按数据顺序校验全部效果和操作 ID。
2. 从 `GrowthInventory.capture_mutation_state()` 捕获完整本局状态。
3. 通过 `create_mutation_copy()` 建立独立 `GrowthInventory` 和独立 `RunDeck`。
4. Handler 依次修改工作副本。
5. 任一 Handler 失败时丢弃副本，真实库存不发生变化。
6. 全部成功后通过 `replace_mutation_state()` 一次替换真实库存。

事务状态覆盖历练、生命、消耗品、功法、内功及装备顺序、功法结算位置、八种牌型的
槽位与序列、完整 `RunDeck`、修习购买记录和修习商店状态。返回的
`state_before/state_after` 只包含日志和 UI 需要的数量摘要，不复制完整牌组。

## 3. 当前正式操作

### `gain_experience`

```json
{
  "op": "gain_experience",
  "amount": 3,
  "source": "battle_victory"
}
```

`amount` 是非负整数，只增加历练。消费历练不能用负数复用该操作。功行仍由节点编排在
奖励事务成功提交之后结算，不属于 Handler。

### `heal_life`

固定回复：

```json
{"op": "heal_life", "amount": 20}
```

按最大生命百分比回复：

```json
{"op": "heal_life", "max_life_percent": 30}
```

两个参数必须且只能提供一个。百分比回复向下取整，实际生命不超过最大生命。当前操作只作为
平台契约探针存在，尚未接入正式休息或其他节点内容。

## 4. 新增第三种简单操作

以 `grant_consumable` 为假设名称，准确步骤是：

1. 在 `core/run_effects/` 新建一个小型 Handler，继承 `RunEffectHandler`。
2. `operation_ids()` 返回稳定 snake_case ID，例如 `grant_consumable`。
3. 在 `validate_effect()` 中只校验该操作自己的参数和内容引用。
4. 在 `apply()` 中只修改 `context.growth` 工作副本，并返回结构化 `applied` 结果。
5. 在 `RunEffectHandlerRegistry._init()` 注册该 Handler；不要修改 `RunMutationService`、
   `NodeRewardService` 或 `RunSession` 的操作分支。
6. 在相应 JSON 中使用新 `op`，并补充内容加载失败、成功执行和事务回滚测试。
7. 如果该字段需要保存，确认它已包含在 `GrowthInventory` 的事务状态和现有存档边界中。

测试专用 Handler 可以通过 `register_handler()` 注入独立注册表，不需要改生产注册表。

## 5. 什么时候只写 JSON

满足以下条件时只写 JSON：

- 所需 `op` 已注册；
- 参数形状已经由 Handler 定义；
- 效果只需要现有上下文能力；
- 内容不需要新的选择协议或 UI 交互。

例如新增另一个“获得 4 点历练”的节点奖励，只需配置 `gain_experience`，不应新增 Handler。

以下情况必须新增 Handler：

- 出现新的本局状态变化语义；
- 现有 Handler 的参数含义无法准确表达规则；
- 新能力需要新的专属校验和结构化结果。

若规则需要玩家选择卡牌、暂停并恢复节点流程，应先建立专门的选择协议或领域服务，而不是
把 UI 回调塞进 Handler。

## 6. 为什么不建立万能 DSL

注册式小 Handler 让每种能力拥有明确输入、校验、测试和依赖边界。把条件、循环、查询、
选择、流程跳转都扩张成通用 DSL，会重新制造一个缺少类型检查、调试工具和事务语义的脚本
语言，并让 JSON 承担程序代码职责。

本项目只在出现已知、重复的内容需求时增加窄能力。简单内容复用已注册操作；新的规则语义
新增小 Handler；复杂领域流程建立独立服务。三者不混写。
