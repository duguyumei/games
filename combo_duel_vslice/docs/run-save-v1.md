# 本局存档 v1

`RunSaveApplicationService` 是 UI 和应用层唯一需要调用的边界：

- `execute({"type": "save_run", "run_session": session})`
- `execute({"type": "load_run"})`，成功时返回新的 `run_session`
- `execute({"type": "has_run_save"})`

v1 保存种子、初始构筑稳定 ID、层数、完整生成地图、当前/已完成节点、待领取奖励、待提交节点交互、终局结果、历练、当前生命与生命上限、消耗品、八种牌型的功法槽位与序列、当前修习商店、功法 ID、持有/装备内功 ID、功法结算槽位、修习购买和完整 `RunDeck`/`QiCardInstanceData` 持久状态。显示名称不进入身份字段。

`growth` 段字段为 `experience`、`life`、`max_life`、`consumable_ids`、`hand_technique_progression`、`practice_shop_state`、`learned_technique_ids`、`learned_inner_skill_ids`、`equipped_inner_skill_ids`、`technique_slot_index`、`practice_purchase_ids`、`consumable_use_sequence` 与 `run_deck`。`hand_technique_progression` 分别保存八种具体牌型的 `slot_count` 与 `sequence`；每种牌型必须满足`slot_count>=1`且`1<=sequence.size()<=slot_count`，序列中不保存空值，差额表示合法空余功法槽。`practice_shop_state` 保存当前普通商品、补充包、物品空位以及商店序号和冥想次数。当前实现仍可能使用 `coupon` 作为兼容字段名，商品协议迁移后统一改为 `item`；这不改变存档中物品的全局生效语义。`life`、`max_life` 两者存在时必须是正整数，且当前生命不得大于上限；损坏值不会被静默修正。`consumable_use_sequence` 存在时必须是非负整数，它决定消耗品随机效果的确定性种子，旧存档缺省为 0。

存档只允许以下节点边界：`awaiting_node`、`node_in_progress`、`awaiting_reward`、`boss_chest`、`run_complete`、`run_terminated`。`node_state` 可选保存 `pending_node_interaction` 与 `terminal_result`；这些是 v1 的向后兼容可选字段，不提高 schema 版本。

`node_in_progress` 只表示已经进入节点。普通进行中节点返回 `restart_node_from_start`；存在冻结 `pending_node_interaction` 时返回 `resume_interaction`。存档不包含手牌、牌堆顺序、战斗异状、行动队列、待出牌、远程 AI 会话或节点级被动来源列表。战斗中退出后按同一 node ID、content seed 与内容候选新建 BattleSession，并从节点开头重启；这里保存的是此前稳定边界的本局生命，不保存本场战斗中间态。`run_complete` 与 `run_terminated` 使用 `show_terminal`，直接恢复原 `terminal_result`。

磁盘格式是带 `schema_version`、`content_version`、payload SHA-256 的 envelope。写入先落同目录临时文件并回读校验，再替换主文件；替换前将上一份可解析主文件原子更新到 `.bak`。主文件 JSON 或校验和损坏时读取备份并尝试恢复主文件；未知未来 schema 会拒绝读取，不会静默回退旧备份。

## 自动存档稳定边界

`RunSession.execute()` 在命令开始时记录持久变更序号。命令完整结束、结果成功且序号发生变化时，只发送一次 `persistence_boundary_reached(command_type)`；查询命令、失败命令和普通 UI 开关不发送。`RunAutosaveCoordinator` 绑定该信号并调用 `save_run`，所以一次命令内部即使多次触发 `RunState.changed`，也只在最终稳定状态写一次。

战斗场景不接触存档仓储。抽牌、选牌、出牌、回合推进、AI 请求和候选枚举都不会触发本局自动存档；`resolve_battle_result` 只有在完整进入 `awaiting_reward` 或终局后才发送稳定边界。自动存档失败保留上一份有效文件，显示持久错误与手动重试入口；下一条持久命令仍会再次尝试。

## 恢复装配与 UI 路由

`GameCompositionRoot` 持有共享 `RunSaveApplicationService`。`RunSaveData` 只重建 `RunState` 与稳定边界字段，应用服务再通过组合根的 `create_run_session(run_state_override)` 注入同一套 `ContentCatalog`、Registry、`RunMutationService`、`BattleSessionFactory`、`RuntimeProfile`、`NodeInteractionService` 与 `AISettingsService`。恢复不调用 `setup_run`，不重新生成地图、修习商品、奖励或冻结交互，也不调用 Handler.prepare。schema v1 旧存档若仍包含 `node_passive_source_snapshot` 或 `node_passive_source_node_id`，完成既有格式／内容校验后忽略，不恢复为运行时状态；下一次保存不再写出这两个字段。

被动来源采用事件级一致性：事件开始时从当前 growth 捕获一次来源并固定 `ExecutionPlan`，
事件间重新解析最新永久来源。`battle_completed` 使用战斗进度合入后的来源；普通
`node_completed` 使用奖励应用前的来源；Boss 宝箱使用宝箱结算变更前的来源。

四种策略的正式页面路由如下：

| resume_policy | 页面 |
|---|---|
| `resume_boundary` | `awaiting_node` 显示地图；`awaiting_reward` 显示原奖励；`boss_chest` 显示 Boss 宝箱 |
| `restart_node_from_start` | 按已保存节点 dispatch 新建战斗或节点页 |
| `resume_interaction` | query 原冻结 DTO，显示通用单选交互页 |
| `show_terminal` | 直接显示原终局结果，不重复结算或记录终局日志 |

首页先以 `has_run_save` 决定“继续游戏”可用性，再以 `load_run` 恢复。`source == "backup"` 会显示非阻断恢复提示；损坏、未知版本和领域校验失败均保留原文件并阻断进入游戏。已有存档时开始新行旅必须先确认，确认后的首次 `setup_run` 自动存档才覆盖旧记录。

## 五批战斗事务底层改造最终验收（2026-08-17）

五批改造的最终回归确认 v1 存档仍只保存已提交本局状态，不保存战斗现场。状态所有权保持三层：
`RunSession/GrowthInventory` 是已提交状态，`BattleSide` 是当前战斗工作副本，
`BattleSession`、`CombatEngine` 及牌区／异状／响应服务是纯战斗 Runtime。战斗退出会丢弃
`BattleSide`，按同一 node ID、content ID 与 content seed 从入口检查点重建；只有成功的
`RunAggregateTransaction` 才把 `RunProgressSnapshot` 合入 growth 并触发一次稳定存档边界。

被动来源不再按节点长期保存。旧 schema v1 中若存在 `node_passive_source_snapshot` 或
`node_passive_source_node_id`，读取时完成原有格式和领域校验后忽略，恢复运行态不使用它们；下一次
保存自然移除字段。事件开始时捕获一次当前来源并固定 `ExecutionPlan`：`battle_completed` 在
战斗进度合入后捕获，普通 `node_completed` 在奖励应用前捕获，Boss 宝箱在自身结算变更前捕获；
事件之间重新解析最新永久来源。

最终 quick 7/7、full 32/32，设计一致性为 228/228/0/0（活跃／接入／待接入／错误）。
本节是最终验收记录，不改变此前各批次的历史验证说明。
