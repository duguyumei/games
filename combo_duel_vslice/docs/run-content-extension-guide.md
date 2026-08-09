# 本局内容效果扩展指南

- 状态：S2-F1B 平台契约
- 适用范围：战斗外、会改变本局成长库存的内容效果
- 不适用范围：战斗功法效果、地图推进、UI 流程和功行计算

## 1. Java 开发者对照

| Godot 类 | Java 语境中的对应概念 | 职责 |
|---|---|---|
| `RunEffectHandler` | Interface / SPI | 声明稳定操作 ID，校验专属参数，在事务工作副本上执行一个小能力 |
| `RunEffectHandlerRegistry` | Strategy 注册中心 | 维护 `op -> Handler` 的唯一映射，拒绝非法或重复 ID，完成运行时分派 |
| `RunEffectContext` | Application Context / Command Context | 向 Handler 提供工作副本和只读语义元数据，不暴露 `RunSession` |
| `RunMutationService` | Application Service + Transaction Boundary | 先校验整组效果，再复制完整成长状态，顺序执行，全部成功后一次提交 |
| `RunDeck` | Aggregate / Repository 内部存储 | 保存真气实例、顺序和实例 ID 序列，通过窄接口完成底层替换与最终实例校验 |
| `CardWorkshopService` | Domain Service | 校验明确实例并编排牌组改造，不建立第二套事务 |
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

牌组改造 Handler 从 `context.growth.run_deck` 取得事务工作副本，只负责参数校验、调用
`CardWorkshopService` 和整理 `applied` 结果。工坊通过 `RunDeck` 窄接口修改实例；Handler
与工坊都不会接触真实 `GrowthInventory`。

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

## 4. 本局真气工坊操作

这些操作只接受内容生成器或选择流程已经解析完成的稳定 ID，不接受 `selected_card`、条件
查询、随机池或动态占位符。

### `add_run_cards`

```json
{"op": "add_run_cards", "definition_ids": ["wind_2", "fire_A"]}
```

按数组顺序追加基础定义，每张牌都通过同一 `CardInstanceIdFactory` 获得新实例 ID。

### `remove_run_cards`

```json
{"op": "remove_run_cards", "instance_ids": ["wind_2", "run:000001:fire_A"]}
```

目标必须全部存在且不能重复。可以移除到任意牌数，不存在牌组大小下限。

### `copy_run_card`

```json
{"op": "copy_run_card", "source_instance_id": "wind_7", "count": 2}
```

复制来源的印刷定义和全部持久重塑，新实例追加到牌组末尾；战斗异状和临时状态不进入副本。

### `transform_run_card`

```json
{
  "op": "transform_run_card",
  "instance_id": "wind_7",
  "definition_id": "fire_A",
  "preserve_reshapes": true
}
```

保持实例 ID 和牌组位置，替换为明确的新基础定义。`preserve_reshapes` 缺省为 `true`，设为
`false` 时清空全部持久重塑。工坊不推断下一牌阶或目标属性。

### `copy_run_card_state`

```json
{
  "op": "copy_run_card_state",
  "source_instance_id": "wind_7",
  "target_instance_ids": ["forest_3"]
}
```

目标保持各自实例 ID 和牌组位置，印刷定义与持久重塑替换为来源状态。来源不能同时作为目标。

### `apply_run_card_reshape`

```json
{
  "op": "apply_run_card_reshape",
  "instance_ids": ["wind_7"],
  "category": "enhancement",
  "reshape_id": "bonus"
}
```

`category` 支持 `enhancement`、`finish`、`imprint` 和 `other`。前三类是单值槽，写入新值时
替换旧值；`other` 按稳定 ID 保存，并可携带 `payload` 对象。定义和 `allowed_carriers` 来自
统一 `card_states.json` 索引，负片等不允许真气承载的定义会被内容加载和运行时最终校验拒绝。

## 5. 内容生成与执行的边界

事件、休息、宝箱、丹药或奇珍负责决定“改哪一张牌”和“改成什么”。玩家选择或确定性随机
模块把结果解析为具体 `instance_id`、`instance_ids` 或 `definition_id` 后，才提交上述操作。
运行 Handler 只接受明确 ID，因此事务可以在执行前校验目标，不需要理解 UI 生命周期，也不
会把随机性或查询语言混入领域服务。

## 6. 新增一种简单库存操作

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

新增一种牌组改造能力时：

1. 先判断它能否组合现有六种工坊方法；能够组合时只新增内容或选择编排。
2. 新的底层实例变换先加入 `RunDeck` 窄接口，候选数据通过
   `QiCardInstanceData.validate()` 后才替换真实条目。
3. 跨多个实例的领域语义放入 `CardWorkshopService`，不要让外部读取或修改 `_cards`。
4. 在对应能力组 Handler 中声明新 `op`、校验专属载荷并转换结构化结果。
5. 注册 Handler 后补齐内容加载、运行执行、事务回滚和存档往返测试；中央事务、会话和节点
   奖励服务不增加分支。

## 7. 什么时候只写 JSON

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

## 8. 为什么不建立万能 DSL

注册式小 Handler 让每种能力拥有明确输入、校验、测试和依赖边界。把条件、循环、查询、
选择、流程跳转都扩张成通用 DSL，会重新制造一个缺少类型检查、调试工具和事务语义的脚本
语言，并让 JSON 承担程序代码职责。

本项目只在出现已知、重复的内容需求时增加窄能力。简单内容复用已注册操作；新的规则语义
新增小 Handler；复杂领域流程建立独立服务。三者不混写。
