# 本局内容效果扩展指南

- 状态：S2-F2A 消耗品统一执行平台
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
| `CardReshapeBehaviorHandler` | Strategy / SPI | 校验并执行一个真气重塑行为，不持有战斗引擎 |
| `CardReshapeBehaviorRegistry` | Strategy 注册中心 | 维护稳定行为 ID，校验触发时点并支持测试注入 |
| `CardReshapeBehaviorContext` | Narrow Domain Context | 只提供当前真气、数值累加器和必要查询 |
| `CardReshapeRuleService` | Domain Rule Service | 按 `card_states.json` 查找行为并编排数值、属性和生命周期规则 |
| `ConsumableEffectHandler` | SPI | 声明稳定操作 ID，校验专属参数，在事务工作副本上执行一个小能力 |
| `ConsumableEffectHandlerRegistry` | Strategy 注册中心 | 维护 `op -> Handler` 唯一映射，拒绝非法或重复 ID |
| `ConsumableUseContext` | Narrow Port | 向 Handler 提供已解析目标、确定性随机源与查询端口 |
| `ConsumableUseService` | Application Service | 解析目标、维护原子事务边界并派生确定性随机种子 |
| `ConsumableValidationContext` | 启动期校验上下文 | 向 Handler 暴露校验器窄表面与消耗品专属词表 |

战斗内的 `EffectHandlerRegistry` 与本局的 `RunEffectHandlerRegistry` 采用相似模式，
但上下文和生命周期不同。两者保持独立，避免本局库存能力反向依赖战斗引擎。
消耗品效果注册表是第三套独立平台：正式本局入口与战斗纵切兼容入口共用同一注册表，
通过两个窄 Context 适配目标区域（RunDeck 实例 vs 当前手牌 QiCard）。

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

真气重塑行为使用独立的 `CardReshapeBehaviorRegistry`。内容校验和真实战斗都通过同一注册表
解析 `card_states.json` 的 `behaviors`；上下文不会暴露 `CombatEngine`、`BattleSession` 或
`RunSession`。注册表拒绝空 ID、非法 snake_case ID、重复注册和未知触发时点，处理器负责自己的
参数校验与执行。

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

## 5.1 新增一个重塑行为 Handler

先判断现有 Handler 是否已经能表达需求：

1. 若只是已有数值累加、属性别名、有效真气变换或已有生命周期动作，新增一条 JSON
   `behaviors` 绑定并填写该 Handler 的参数。
2. 若出现新的规则语义，新增一个小型 `CardReshapeBehaviorHandler`，声明稳定的
   snake_case `behavior_id()` 和有限的 `triggers()`，在 `validate_behavior()` 中校验专属参数，
   在 `execute()` 中只操作 `CardReshapeBehaviorContext`。
3. 在 `CardReshapeBehaviorRegistry` 注册 Handler，并补内容加载、参数失败、预览／结算贯通和
   持久重塑回归测试。不要向 `PowerCalculator`、`ActionResolver` 或 `CombatEngine` 增加内容 ID 分支。

行为时点目前只包括 `card_contribution`、`technique_multiplier`、`power_amp`、
`attribute_check`、`effective_qi`、`anomaly_apply` 和 `reshape_applied`。需要条件、循环、
查询或流程跳转时，建立新的窄协议，不把它们扩张成 JSON DSL。

## 5.2 只改 JSON 与必须新增 Handler 的边界

只要行为 ID 已注册、参数形状已定义、现有上下文能力足够，新增内容 ID 可以只修改
`card_states.json`。例如两个不同品相都可以绑定同一个数值 Handler，只通过 `amount` 或
`factor` 产生不同结果。

以下情况必须新增 Handler：现有触发时点无法表达；参数含义会改变；需要新的战斗端口、随机源、
选择协议或本局奖励账本。新增 Handler 后仍由注册表统一校验和分发，不在中央流程按名称分支。

当前仍未完成的重塑／相关行为包括：玻璃牌战后损毁、钢铁牌留手防御、黄金牌和幸运牌的历练效果、
金印／赤印／蓝印／紫印、负片内功，以及任何新的战斗奖励账本。已有定义或槽位不代表这些行为
已经语义完整；它们须在后续任务补齐对应时点和确定性测试。

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

## 6.1 新增一种消耗品效果操作

心得、丹药、奇珍共用 `GrowthInventory.consumable_ids` 的三个槽位。正式构筑修改
以完整 RunDeck 中的稳定真气实例为目标，入口是 `RunSession` 的战斗外命令
`query_consumable_use` / `use_consumable`；战斗内 `BattleConsumableService` 只作为
纵切兼容适配器，效果执行委托同一注册表，不再按操作码写中央分支。

新增操作步骤：

1. 在 `core/consumables/` 新建一个小型 Handler，继承 `ConsumableEffectHandler`。
2. `operation_ids()` 返回稳定 snake_case ID；`validate_effect()` 只校验自己的
   参数和内容引用；`apply()` 只通过 `ConsumableUseContext` 窄端口修改工作副本，
   并返回包含 `op` 与 `details` 的结构化 `applied`。
3. 在 `ConsumableEffectHandlerRegistry._init()` 注册；不要修改
   `ConsumableUseService`、`RunSession` 或 `BattleConsumableService` 的分支。
4. 内容文件使用新 `op`，并补齐内容加载、正式使用、失败回滚、随机确定性和
   存档往返测试。
5. 需要随机时，从 `context.rng` 顺序抽取：种子由 run seed、
   `consumable_use_sequence`、消耗品 ID 与效果序号派生，失败不递增序号，因此
   不会消费下一次成功操作的随机结果。
6. 需要新的目标区域或选择协议时扩展 `ConsumableUseService` 的目标解析，不要
   让 Handler 理解 UI 或战斗引擎。

测试专用 Handler 可以通过 `register_handler()` 注入独立注册表。

## 6.2 消耗品事务与随机序号

一次消耗品使用是完整原子事务：校验槽位、定义与目标 → 建立
`GrowthInventory` 工作副本 → 顺序执行全部效果 → 全部成功后按 `slot_index`
删除消耗品并递增 `consumable_use_sequence` → 一次性提交。任一步失败都不提交，
`experience`、`life/max_life`、`consumable_ids`、功法槽位与序列、内功、
`run_deck`、`permanently_removed_card_ids`、`practice_shop_state` 与
`consumable_use_sequence` 全部保持不变；Handler 不需要写补偿或回滚代码。

`consumable_use_sequence` 属于 `GrowthInventory` 的 mutation state、
`RunProgressSnapshot` 与 v1 存档的 `growth` 段。存档读档后继续使用，随机结果
与未读档路径一致。查询可用目标不消费随机数。

## 6.3 当前消耗品操作

### `gain_insight`

```json
{"op": "gain_insight", "hand": "high_card", "pools": ["high"]}
```

`hand` 必须是八种精确牌型之一，`pools` 必须是非空且属于该牌型成员资格的功法池。
效果使该牌型功法槽位 +1，并从正式白名单（`formal_complete` 且属于指定池）中
确定性抽取尚未进入该牌型序列的功法；没有合格功法时仍成功增加槽位，不跨池抽取。
五条与四条可以共用功法候选池，但槽位与序列相互独立。

### `apply_enhancement`

```json
{"op": "apply_enhancement", "enhancement": "bonus"}
```

对已解析的全部目标真气施加指定强化，替换旧强化。内容加载阶段校验强化引用及其
真气承载资格。

### `apply_random_finish`

```json
{"op": "apply_random_finish", "finishes": ["foil", "holographic", "polychrome"]}
```

对每个已解析目标依次从 `finishes` 确定性抽取品相并替换旧品相。品相引用及其
真气承载资格在内容加载阶段校验。

## 6.4 目标区域与选择方式

`targeting.zone` 是目标区域：心得为 `none`（无目标，传空数组），丹药与奇珍为
`run_deck`（正式目标统一为完整 RunDeck 的稳定 `instance_id`，不再使用战斗
手牌）。`targeting.selection` 缺省为 `player_selected`，第一阶段还支持
`deterministic_random`，由 `ConsumableUseService` 解析后向 Handler 传入明确
实例 ID。目标必须属于当前本局 RunDeck、不得重复，并严格满足
`minimum/maximum`。

## 6.5 结构化选择与冻结预览

战斗外命令继续兼容 `selected_instance_ids`，并可额外提交 `choice_payload`。
内容通过窄 `choice_schema` 声明枚举选择或按牌型移出超槽功法；查询返回动态
`choice_options`，正式执行仍会按当前事务状态重新校验，不把 UI 选择直接视为可信输入。

需要先展示随机目标与转化结果的内容声明 `requires_preparation=true`。查询使用由
本局种子、`consumable_use_sequence`、内容 ID 和效果序号派生的新 RNG 计算
`prepared_preview`，不会修改成长库存或推进随机序号；同时返回覆盖完整事务状态与冻结结果的
`preparation_token`。正式执行必须在 `choice_payload.preparation_token` 中回传该值，
并复用相同目标和效果载荷。任一相关状态变化都会令 token 失效，执行明确失败且不重抽。

`deterministic_random` 的候选先按实例 ID 排序。`count_mode=maximum` 表示选取当前上限
允许的全部随机目标；`maximum_source=base_hand_limit` 表示上限读取本局当前基础手牌上限。
`choice_filtered` 则按结构化枚举值选择全部匹配目标，不接受另一组手动实例 ID。

## 6.6 奇珍通用能力族

奇珍继续使用 `ConsumableEffectHandlerRegistry`，当前能力包括印记施加、随机基础真气生成、
整组冻结本源改造、按稀有度获得内功、已装备内功复制清理、按实际移出真气结算历练、
基础手牌上限修正、牌型槽位与功法倍率修正。基础真气候选读取 `base_deck`，强化、印记与
内功候选读取统一内容目录；中央服务不按奇珍 ID 分派。

`GrowthInventory` 以数组重复项表达内功多副本。已获和已装备内功都使用 multiset 语义，
存档校验按每个 ID 的数量检查“装备数量不超过已获数量”，战斗装配后重复 ID 会按装备顺序
各自生效。

## 6.7 本局规则字段

以下字段属于成长库存的完整事务状态、`RunProgressSnapshot` 与 v1 存档 `growth` 段：

- `base_hand_limit_modifier`：与基础 8 相加，最终基础手牌上限最低为 1；
- `hand_technique_multiplier_modifiers`：按八种精确牌型保存，只加入 `multiplier_bonus`；
- `used_unique_consumable_ids`：记录已成功使用的唯一消耗品 ID。

旧存档缺省时分别按 `0`、空对象和空数组恢复。战斗装配把前两项写入 `BattleSide`；倍率修正
不改变固定牌型倍率、`baseline_value` 或 `power_fixed`。唯一内容只在整次事务成功提交时记录，
查询、预览和失败均不写入。

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
