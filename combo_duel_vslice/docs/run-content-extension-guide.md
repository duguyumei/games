# 本局内容效果扩展指南

- 状态：S2-F4A 非战斗节点统一交互与通用奖励能力
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
| `NodeInteractionHandler` | 非战斗节点 SPI | 纯准备冻结选项，并把一次选择翻译为明确 `effects` 与展示结果 |
| `NodeInteractionHandlerRegistry` | kind 注册中心 | 维护 `interaction_kind -> Handler` 唯一映射，支持测试注入 |
| `NodeInteractionContext` | 只读交互上下文 | 提供来源、稳定种子、冻结配置、成长快照、内容查询端口与独立 RNG |
| `NodeInteractionDTO` | Frozen Envelope | 在领域、UI 和存档之间传递可 JSON 序列化的冻结选择 |
| `NodeInteractionService` | 生命周期服务 | 编排 `prepare/query/commit/cancel`，提交时复用成长事务 |

战斗内的 `EffectHandlerRegistry` 与本局的 `RunEffectHandlerRegistry` 采用相似模式，
但上下文和生命周期不同。两者保持独立，避免本局库存能力反向依赖战斗引擎。
消耗品效果注册表是第三套独立平台：正式本局入口与战斗纵切兼容入口共用同一注册表，
通过两个窄 Context 适配目标区域（RunDeck 实例 vs 当前手牌 QiCard）。

战斗被动若要影响敌方候选画像，不把内容 ID 或状态 ID 写进 AI 中央模块，而是在既有
`PassiveRuleHandler` 上声明 `ai_action_value_query`、`ai_card_play_value_query` 或
`ai_card_retention_value_query`。Handler 返回 `estimated_value`、`progress_value`、
`control_value`、`trigger_signatures`、`progress_entries` 中需要的字段；运行时保留稳定
`source_breakdown`。三类查询只读，禁止移动真气、推进 RNG 或修改本局／战斗计数器；缺少
Handler 时统一返回零贡献。这里评估的只是在当前战斗内的一步即时与未来价值，不纳入跨战斗
经济、成长，也不实现 MCTS 或完整状态克隆。

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

非战斗节点自身结果使用同一事务边界：

```text
RunSession
  -> NodeInteractionService
    -> NodeInteractionHandlerRegistry -> NodeInteractionHandler
    -> RunMutationService -> GrowthInventory 工作副本
  -> NodeRewardService（节点自身结果成功后才创建基础奖励）
```

`MapNavigationService` 只维护阶段与路线，不再保存或返回 combat／elite／boss 的
`3／4／5` 奖励整数；基础节点奖励的唯一数据源是 `node_rewards.json`，唯一应用入口是
`NodeRewardService + RunMutationService`。

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

### 通用本局内容获得

以下操作都只接受已经决定好的稳定 ID，不负责随机抽取：

```json
{"op": "grant_techniques", "technique_ids": ["technique_a"]}
{"op": "grant_inner_skills", "inner_skill_ids": ["inner_a", "inner_a"]}
{"op": "grant_consumables", "consumable_ids": ["pill_a"]}
{"op": "grant_items", "item_ids": ["item_a"]}
```

- 功法是集合：只允许 `formal_complete`，已经拥有或同一效果内重复发放会失败。
- 内功是 multiset：只允许 `formal`，同 ID 多副本合法，只加入已获库而不自动装备。
- 心得、丹药、奇珍共用三格消耗品栏：整组加入后超容量会让整个效果失败。
- 物品当前唯一持有：只允许 `formal`，重复、`candidate` 或 `design_only` 发放会失败。

内容加载期先校验引用和正式状态，运行时再校验当前库存；多个操作中的任一个失败时，
`RunMutationService` 丢弃整个工作副本。

## 3.1 非战斗节点 Handler 协议

稳定接口为：

```gdscript
interaction_kind() -> String
validate_configuration(configuration: Dictionary, validation) -> void
prepare(context) -> Dictionary
commit(context, prepared_interaction, choice_id, choice_payload) -> Dictionary
```

`prepare` 是纯准备过程，只能从 `context.rng` 取得由 `content_seed` 派生的确定性随机值，
并把 UI 与恢复所需结果冻结进 DTO。`commit` 必须重新校验选项，返回：

```gdscript
{
    "success": true,
    "effects": [{"op": "heal_life", "max_life_percent": 30}],
    "result": {"choice_id": "rest", "description": "..."},
}
```

Handler 不得持有 `RunSession`、地图服务或 UI，不得修改真实成长、推进地图、建立基础奖励
或计算功行。条件、循环和概率使用具体 Handler 的普通代码，不写进 JSON，也不建立事件 DSL。

生命周期为：

1. `prepare(dispatch, growth, source_context)` 校验 route、生成稳定 token、调用一次 Handler 并冻结 DTO。
2. `query_active()` 只返回 DTO 深复制，不重跑 prepare、不推进随机源。
3. `commit(token, choice_id, payload, growth)` 校验 token 和 enabled 选项，重新调用 Handler 校验，
   再把完整 effects 交给一次 `RunMutationService.apply_effects`。
4. `cancel(token)` 只放弃 UI 草稿；冻结交互、节点阶段与成长均保持不变。
5. 成功提交后同一 token 不能重放；`RunSession` 随后完成节点、创建基础奖励并清除 pending。

token 稳定字段依次为 `run_seed`、`act`、`source_kind`、`source_id`、`content_id`、
`content_seed`、`interaction_kind`。地图节点使用 `source_kind=map_node`；以后 Boss 隐藏宝箱
使用 `source_kind=boss_chest`，无需另建交互协议。

进行中 interaction 的存档位于 `node_state.pending_node_interaction`，包含 token、来源、节点、
kind、种子、configuration 与完整冻结 DTO；`resume_policy=resume_interaction`。恢复直接装入冻结
信封，不调用 prepare。旧存档缺少该可选字段时仍按 `restart_node_from_start` 兼容。

当前生产 `event/rest/treasure` 仍是 placeholder，Registry 允许为空。后续每类正式内容只新增
小型 Handler 并逐个迁移 route；本阶段没有提前实现 Rest/Event/Treasure Handler。

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
效果使该牌型功法槽位容量 +1，并从正式白名单（`formal_complete` 且属于指定池）中
确定性抽取尚未进入该牌型序列的功法加入本局功法库，不自动装备；没有合格功法时仍成功增加槽位，不跨池抽取。
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
不改变属性集中数、`baseline_value=C` 或 `power_fixed`。唯一内容只在整次事务成功提交时记录，
查询、预览和失败均不写入。

## 6.8 内功配装与普通遗忘

永久内功配装通过 `InnerSkillLoadoutService` 一次性提交完整的
`equipped_inner_skill_ids` 和 `technique_slot_index`。服务按 ID 统计已获与请求数量，允许同 ID
多副本，但任何 ID 的装备数不能超过内功库中的副本数；基础容量为 6，当前有效容量由统一
`InnerSkillCapacityPolicy` 纯查询得到。非法提交在修改前完整拒绝，战斗侧也不再截断或 clamp。
永久功法序列与内功配装共用地图待选门禁，
进行中的节点、战斗、待领奖励和 Boss 宝箱流程均不可修改，查询始终可用。

普通遗忘每次只删除一个未装备副本。基础所得来自 `forget_value`，展示与提交都经由
`PassiveIntPolicyResolver` 的 `inner_skill_forget_value_query` 依次归并当前有效值，中央流程
不识别内功或物品 ID。正式内功必须配置非负整数 `forget_value`；候选或仅设计内容缺少该字段时
可以载入，但普通遗忘会明确拒绝，不按 0 处理。成功的普通遗忘同时增加历练和
`forgotten_inner_skill_count`；奇珍清理、替换、自动消失及其他永久移除不增加该计数。

`forgotten_inner_skill_count` 属于 `GrowthInventory` 的完整 mutation state、
`RunProgressSnapshot`、v1 存档 `growth` 段与本局成长快照。玩家战斗工作状态会绝对装入并回传该字段；
旧存档缺省时恢复为 0。

## 6.9 内功与物品被动行为

内功和物品内容均使用 version 2 的 `behaviors`：

```json
{
  "behaviors": [{
    "id": "on_play_effects",
    "configuration": {"effects": [{"op": "defense_from_noncontributing_qi"}]}
  }]
}
```

能够由现有战斗 `EffectSpec` 表达的简单出牌效果使用 `on_play_effects`；需要新参数、专有查询或
新规则正文时新增职责单一的 `PassiveRuleHandler`。Handler 只声明 behavior、hook、配置校验和
处理逻辑，不扫描库存、不读 JSON，也不识别内容 ID。中央 `ActionPreviewService` 与
`ActionResolver` 只消费 Runtime 生成的计划和 invocation。

调用链为 `SourceResolver → ActivationPolicy → ExecutionPlan → Invocation → Handler`。内功只从
已装备槽位逐副本建源，物品从唯一持有区建源；两者共用 Runtime 与 Registry，但不合并库存。
容量查询以拟提交完整配装重新解析一次来源，不做递归固定点；压制只影响新计划；重复 invocation
连续执行且不会再次运行计划查询。

## 6.10 本局纯查询与已提交事件

价格、遗忘所得、冥想费用、补充包展示数／选择数使用
`PassiveIntQueryRequest → PassiveIntPolicyResolver → ExecutionPlan → Invocation → Handler →
PassiveIntQueryResult`。Handler 直接返回新的确定整数 `value`；不得为这些能力建立
add／multiply／set／script 表达式 DSL。领域服务再校验价格、费用、数量和遗忘所得均为非负整数。
商店槽位始终保存基础值，快照只在深复制 DTO 上附加有效值与来源明细。

成功行为通过 `RunPassiveEventService` 发送 `practice_opened`、
`practice_purchase_committed`、`practice_pack_opened`、`meditation_committed`、
`inner_skill_forgotten`、`battle_completed` 或 `node_completed`。Handler 的领域修改只能通过上下文的
`RunPassiveEffectPorts` 调用已登记的 `RunMutationService` 效果；有状态 Handler 另按 6.11 使用限域
计数器端口，不能持有 RunSession、修习服务或导航服务。事件在成长工作副本上执行；任一 Invocation
失败时回滚整个副本，成功后才记录稳定事务令牌。节点来源快照只保存 source kind、内容 ID、实例键、
behavior 索引和顺序，读档不会重放已提交事件。

## 6.11 被动持久整数计数器

有状态 Handler 必须实现 `counter_definitions(configuration)`，并只声明整数计数器。内容 behavior
同时提供稳定 `state_key`：

```json
{
  "id": "some_growth_behavior",
  "state_key": "stable_growth",
  "configuration": {}
}
```

```gdscript
func counter_definitions(_configuration: Dictionary) -> Array:
    return [{
        "counter_id": "battle_progress",
        "default_value": 0,
        "minimum": 0,
        "maximum": 2,
        "retention_policy": "while_owned",
    }]
```

Registry 与内容 Validator 会校验稳定 snake_case、整数上下界、默认值范围、保留策略、同一状态
命名空间的重复 counter ID，以及有状态 behavior 是否声明 `state_key`。无状态 behavior 不要求补写
`state_key`。计数器的持久身份固定为
`source_kind + content_id + state_key + counter_id`；不得使用槽位、`source_order`、数组下标或
`source_instance_key` 中的 slot index。

纯查询从 `context.counter_read_port` 调用 `read(counter_id)` 或
`has_non_default_value(counter_id)`；已提交事件从 `context.counter_mutation_port` 调用
`write`、`increment` 或 `reset`。这里使用 `read/write` 而不是覆盖 Godot `Object.get/set`，语义仍是
类型化的 get/set。端口自动限域到当前 Invocation；未声明 ID、非整数和低于 minimum 的写入失败，
声明 maximum 时超出值明确封顶。Handler 不得跨来源拼装 key；确有跨来源需求时新增专用领域端口。

计数器属于 `GrowthInventory.capture_mutation_state()` 的完整事务。后续 Invocation 读取同一事务中
前一 Invocation 的最新值，ExecutionPlan 不重建；Handler、后续 Invocation、RunMutationService
或基础领域事务失败时，计数器与其他成长字段一起回滚。重复 `transaction_token` 不会再次执行或
增长。压制来源不建立 Invocation，但压制不会删除已有值。

`retention_policy = "run"` 保留到新本局 reset；`while_owned` 在最后一个已获副本永久失去后由
集中所有权清理移除。内功持有读取 `learned_inner_skill_ids`，物品持有读取 `item_ids`；卸下、重排、
压制及只遗忘同 ID 的一份副本都不清除。同 ID 多副本共享内容级状态，因此两个副本分别触发时可以
连续增长两次。需要逐副本状态时必须先引入持久实例 ID，不能借用装备槽位。

存档字段为版本化的 `passive_counter_state`，只保存稳定排序的 key 与非默认整数值；未知来源、
内容、state key、counter ID、重复键或越界值均拒绝载入，不保存 Handler、Callable、配置或完整
定义。`RunProgressSnapshot` 用 `has_passive_counter_state` 区分缺失与空集合：带字段时绝对替换，
缺失时保持现值。战斗装配把该状态绝对导入玩家 `BattleSide` 的独立副本；战斗 Handler 不直接
修改 `GrowthInventory`。玩家胜利或战败的战后局部快照绝对回传副本状态，重复同步同一快照不会
再次增长；未决平局或场景错误不进入本局回写流程，敌方空 Store 也不会覆盖玩家状态。本平台没有
向正式内容 JSON 增加任何内功或物品。

## 6.12 战斗生命周期绑定与临时计数器

生命周期 Handler 在代码中同时声明支持的 hook 与全局 order；例如：

```gdscript
func supported_hooks() -> Array[String]:
    return ["after_normal_draw"] as Array[String]

func battle_timing_bindings(_configuration: Dictionary) -> Array:
    return [{"hook": "after_normal_draw", "order": 700}]
```

允许的 hook 与 `BattleTimingSystem` 十个常量一一对应。Registry 会拒绝未知 hook、未进入
`supported_hooks()` 的 binding、非整数 order 和同一 Handler 重复 hook/order。Bridge 以
`passives.<hook>.<order>` 注册；执行顺序为 BattleTimingSystem order，再按内功装备／物品稳定来源
顺序、behavior 顺序与 Invocation `execution_index`。`on_play_effects` 仍只服务 action preview/resolve，
不伪造生命周期绑定。双方同 Hook 都有有效绑定时，当前正式装配以
`unconfirmed_cross_side_passive_order` 阻断，直到 S4.0 冻结跨阵营顺序。

临时整数由 `battle_counter_definitions(configuration)` 声明，字段为 `counter_id`、
`default_value`、`minimum`、可选 `maximum` 和 `reset_scope`。`battle` 保留整场，`turn` 在对应 actor
的 `turn_start` Handler 前重置，`action_window` 在参与当前窗口的 actor 的
`action_window_start` Handler 前重置。临时键为
`owner_id + source_instance_key + state_key + counter_id`；这与 F5C 持久键刻意不同，使当前战斗的
同 ID 多副本各自计数，但绝不写入存档。生命周期 Context 提供
`persistent_counter_*_port` 与 `battle_counter_*_port`；action preview 只有两个 read port。任一时点的
Invocation 失败会把当前 actor 的两类计数恢复到该时点开始前并进入 `scenario_error`，不会继续较晚
order；`battle_end` Handler 完成后才清临时 Store。

## 6.13 战斗细粒度事件与持续整数查询

生命周期边界与实际事实必须分开选用。阶段开始／结束使用 6.12 的十个
`BattleTimingSystem` Hook；只有玩法修改已经成功提交时，才使用
`BattleEventCatalog.COMMITTED_EVENTS` 登记的正式事件。内容不能通过任意字符串绕过该目录。
`BattlePassiveCommittedEventService` 为事件建立由 battle instance、事件种类、行动／区域／伤害
序号、owner 与卡牌实例 ID 组成的稳定 token；重复提交直接复用 receipt。事件获得两类 mutation
port，失败只回滚计数器并转场景错误，不反向搬牌或恢复生命。

持续整数读取使用 `BattleRuleQueryService`，底层仍是既有 `PassiveIntPolicyResolver`，不得复制整数引擎。正式 Hook 只由 `BattleIntQueryCatalog.HOOKS`维护，查询服务和 Registry 的旧常量是同一目录的兼容别名。普通来源中立内容优先使用 `battle_int_query_modifier`，以数据规则声明 `add`／`multiply`／`minimum`／`maximum`／`set`、整数 operand 和可选精确过滤；Handler不得识别内容ID或修改状态。每个 Invocation 读取上一个有效整数并返回新的确定 `value`；上下文只注入 read port。被压制来源不进入计划，额外 Invocation 在来源位置连续执行且不重新规划。

`BattleSide.base_hand_limit()` 只计算 `max(1, hand_limit + base_hand_limit_modifier)`；`current_hand_limit()`／`effective_hand_limit_result()` 再执行 `hand_limit_query`，供正常补牌、抽至上限、效果值、战斗快照、UI 与 AI 共用。明确写“基础手牌上限”的内容必须调用前者。查询失败不能按基础值继续补牌。

功法值 Handler 只能修改四阶段输入，`PowerCalculator` 继续独占 `baseline_value`、`initial_power`、`pre_momentum_power` 与 `technique_value` 公式。预览可重复查询；正式行动在重塑冻结后重跑四项查询，将 `base_value/effective_value/source_breakdown/fingerprint` 写入 `passive_power_queries`，并随每个主组／协同组自己的 action token 冻结。等待选择恢复只读冻结结果。普通伤害、防御获得和防御保留率在实际写入前按最新状态查询一次；自然防御衰减另在同一纯计划中依次查询最大损失与最低剩余，成功后才经统一防御减少端口提交。真实伤害不进入普通伤害查询。

本接口不提供内功复制或任意战斗状态写端口。S2-F5D2 没有修改正式白名单，也没有使任何候选内功或物品正式化。

## 6.14 牌型、卡牌身份与战斗权限查询

牌型识别统一由 `HandRecognitionOptions` 与 `HandRecognitionPolicy` 提供选项。默认值固定为五张顺子、最大相邻间隔 1、A 可在低端或高端且不可首尾循环；`HandEvaluator.evaluate`、`evaluate_best` 与 `evaluate_best_candidates` 消费同一 Options，正式预览、敌方候选和整手重触都先执行 `hand_evaluation_options_query`。查询只返回选项，不移动牌、不推进 RNG，也不改写战斗状态。

卡牌有效身份由 `CardIdentityFacts`／`CardIdentityPolicy` 汇总 `is_true_qi`、`effective_attributes`、`rank_tags` 与 `card_kinds`，基础事实继续复用 `QiCard` 的归元、临时属性和重塑身份。来源按 Runtime 的稳定执行计划合并；同一标量身份出现冲突会明确失败。牌型、功法条件、功法值卡牌事实、效果值、目标查询和 AI／UI 预览均消费该事实，不改写卡牌原始字段。被压制来源不进入执行计划，解除压制后自然重新参与。

操作否决统一进入 `BattlePermissionService`。当前已接入 `card_play_permission_query` 与 `explicit_discard_permission_query`；`technique_activation_permission_query`、`cooperation_permission_query` 已登记为后续端口。有效来源按稳定顺序执行，只有明确 `allowed = false` 的有效结果拒绝操作，但 Handler 失败或返回形状无效会失败关闭，不能按允许继续。既有状态系统打出否决和 `CardReshapeBattleRuntime` 明确弃牌否决只是统一服务的适配来源，因此无漏、磐石继续沿用原规则，中央流程不识别内容 ID。

普通打出只查询打出权限，进入弃牌堆时不查询明确弃牌权限；手动选择、随机弃牌、全部弃牌和 `reason = "explicit_discard"` 的移动则共用明确弃牌链。等待选择恢复使用已冻结候选，不重复发送权限查询。所有查询仍复用唯一 `PassiveRuleRuntime`、压制服务和 Invocation 顺序，本任务没有新增正式内容或白名单。

功法启动与协同不要复用出牌布尔值推断。当前功法非空且自身条件满足后，由 `can_activate_technique()` 查询；预览把 `checked/allowed/reason/source_breakdown` 写入 `ActionPreviewDto.technique_activation`，明确拒绝时仍保留功法定义但裁掉其伤害、防御和协同入口。正式确认在重塑及四阶段值冻结后重新查询，把结果写入 `BattleActionRecord`；解析、等待恢复、`action_confirmed/action_resolved`、连势和序列只读冻结结果。协同在候选建立和正式确认分别调用 `can_establish_cooperation()`，正式失败整单回滚。主组、协同建立、协同组自身启动是三个独立结果。玩家、本地 Utility AI 与远程候选只消费同一个预览，不复制权限规则。

## 6.15 战斗被动标准效果

内功或物品需要执行已有战斗效果时，声明 `battle_effects` behavior，不在专属 Handler 中重新
包装领域写入：

```json
{
  "id": "battle_effects",
  "configuration": {
    "hook": "action_resolved",
    "effects": [{"op": "draw", "side": "owner", "count": 1}]
  }
}
```

`hook` 只能是 `action_resolve`、十个正式生命周期 Hook 或
`BattleEventCatalog.COMMITTED_EVENTS`；生命周期还必须声明整数 `order`。普通 effects 与功法
共用 `EffectSpecValidator`、`EffectHandlerRegistry`、ValueSpec、ConditionSpec、TargetQuery、
`EffectExecutor`、`BattleEffectPorts` 和领域服务。`owner`、`actor`、`target`、`opponent` 是统一
作用域；随机效果只使用战斗 RNG，明确弃牌仍经过权限链，异状仍经过合法性判断。

来源、来源实例、触发方式和事件／行动 token 由 Runtime 注入，内容不得自行填写。已提交事件
公开字段放入统一 `event` capture，可由 `event_field` 等公共规格读取。`action_preview` 只为
`action_resolve` 配置生成只读 intent；查询 Hook、AI 枚举和预览都不获得写端口或计数器 mutation
port。需要等待玩家选择的效果放在 `action_resolve`，复用共享 continuation；生命周期和已提交
事件链不得留下无人接管的 pending choice。单次 Invocation 链仍最多执行 64 条效果命令，首个
Handler 失败即停止后续效果，稳定 Invocation receipt 防止同一已提交事件重放。

旧 `BattlePassiveEffectPorts` 已删除。只有必须在 Handler 内动态循环、必须原子提交、必须读取
上一条真实写入结果再决定下一步，或当前确实没有公共 EffectSpec 语义时，才讨论新增窄领域能力；
来源是内功／物品或触发时点不同都不是理由。本节只描述平台，没有新增正式内容或白名单。

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

## 9. AI 公开语义与被动计数可见性

新功法、内功、物品和消耗品必须提供稳定 `id`、玩家可读 `name` 和 `description`。AI v3 只从这些公开字段及可选 `semantic_tags`／`public_behavior_summary` 投影本场相关语义；不得向模型暴露 Handler 名、脚本路径或完整内部配置。辅助标签只帮助理解，正式战斗仍以本地规则核为准。

被动计数是否公开必须由统一 visibility 元数据声明，不能在 AI 模块按内容 ID 判断。公开计数会投影来源、显示名、计数名、当前值、阈值、剩余值和 active；私有计数只允许出现在敌人自身私有观察或本地轨迹，不进入玩家公开侧。新增内容若没有公开元数据，应按最小披露原则处理并补契约测试。

候选权重属于统一 AI 策略，不是内容效果。调整前必须比较 F6B 结构化诊断、`run_ai_trace_report.gd` 的批量保留／方向／误差数据和试玩记录；不得只根据最终胜率改动权重，也不得在内容定义里嵌入任意评分 DSL。
