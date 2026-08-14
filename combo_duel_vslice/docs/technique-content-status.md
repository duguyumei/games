# 功法内容接入状态

本文件只记录工程接入证据，不新增或修改功法设计。规则唯一权威源是
`godot/docs/design-current/README.md` v0.30 及其功法框架、[高牌正式功法目录](../../godot/docs/design-current/martial-arts/24-gongfa-high-card-pool.md)。

## 当前正式目录（2026-08-14）

正式目录共79门：基础通用功法`basic_scatter`、`basic_guard`，首批25门高牌功法，以及本批新增52门蛊毒、成长和跨系统桥接功法。新增分布为高牌11、对子18、三条10、顺子7、炸弹6；完整稳定ID与池归属见[扩展正式功法索引](../../godot/docs/design-current/martial-arts/28-gongfa-expanded-formal-pool-index.md)。52门均为独立`.tres`、`formal_complete`、`built_in=false`、普通装配上限1，并进入对应正式修习候选。

本批实现分类为A 2门、B 41门、C 9门。A直接组合既有即时能力；B使用通用毒伤、快照、聚合值、捕获集合、原子层数、牌区操作和可恢复选择；C使用通用入堆完成、毒触发完成、下一回合、正常补牌后、防御保留后、完整回合结束和协同时点。中央战斗流程、AI与UI均不按这52门功法ID分支。

蛊毒底层已区分`normal`、`true`与`poison`，毒伤默认绕过普通防御、普通增减伤和反震，并公开实际生命损失；双方手牌／牌库毒量与毒牌张数实时派生。成长与桥接底层已支持G/Q/R、集合sum/max、原子转移／转换／平均分配、玩家选择余数、临时牌、清理前移动快照、同步毒完成事件、来源安全响应和协同限制。

专项行为入口为`tests/test_poison_techniques.gd`、`tests/test_growth_techniques.gd`与`tests/test_bridge_techniques.gd`。它们逐门识别新增ID，并覆盖独立毒伤、同步毒爆、五叶／宿根入堆清理、落英余数选择、春风下一回合、护根防御保留、蛊焰追身、连枝协同、涸泽顶5与等待选择恢复。2026-08-14最终门禁结果：内容校验扫描99个文件、79个`.tres`、0错误、0警告；设计一致性为权威79、数据79、待接入0、错误0；quick为7组全过，full为21组全过。专项断言分别为蛊毒178、成长170、桥接112。

## 统计口径

基础通用实体 `basic_scatter`（散招）与 `basic_guard`（守招）均为 `formal_complete`、`built_in=true`、基础装配上限 99，并用八种 `eligible_hand_ids` 声明通用资格；其余77门非内建正式功法进入对应修习候选。

`data/production_sequences.json` 的八种精确牌型均为 `["basic_scatter"]`。两门基础功法不进入修习商店、奖励、心得随机候选或 `learned_technique_ids`；构筑 DTO 仍始终把它们作为合格候选公开。旧 47 门流派／纵切资源统计均属历史记录，不再描述当前正式目录。
`DesignConsistencyValidator` 的 0 错误也只证明名称、共用牌型池与废弃状态一致。

以下 S2-01/S2-02 旧矩阵仅保留为历史审计，不描述当前正式目录：

| 接入状态 | 数量 | 判定边界 |
|---|---:|---|
| 正式语义完整 | 8 | 权威主分支、目标不足边界与预览／实际结算均有确定性行为测试 |
| 部分接入 | 32 | 资源与所需通用处理器已存在，但没有逐门覆盖全部权威分支／时点的行为测试，暂不据此宣称语义完整 |
| 回归夹具 | 7 | 早期纵切用于回归协议；不是 S2 正式白名单候选，其中两门另有已确认语义偏差 |
| 禁用或延期资源 | 0 | 当前 47 个资源内没有；五条心得等禁用内容不属于这 47 门功法实体 |

当前正式口径以开头的79门实体为准；下列47门只解释更早的历史测试与迁移证据，不计入当前正式玩家内容。

## 47 门覆盖矩阵

### 已证明正式语义完整（8）

- 高牌：`borrow_fire_guard_heart`（借火护心）、`stagnant_gu_conceal_breath`（郁蛊敛息）
- 一对：`double_gu_exchange_breath`（双蛊换息）
- 两对：`balance_sleeves_listen_wind`（衡袖听风）
- 三条：`three_ring_ensemble`（三环并奏）
- 葫芦：`three_ring_chaos_qi`（三环乱气）
- 顺子：`five_steps_echo`（五步余音）
- 四条：`seize_qi_return_nest`（夺气归巢）

本段是旧接入证据。当前 `production_sequences.json` 的八种序列仍只装配 `basic_scatter`；正式目录以文件开头的79门为准。

### 风运转资源：部分接入（32）

这 32 门已逐门拥有 `TechniqueDefinition` 和可加载的效果链，静态定义与风池正文的主要公式、
条件和目标相符；当前测试只覆盖平台能力及部分代表路径，尚未逐门覆盖所有牌型分支、牌区不足、
选择、延迟时点和失败边界。因此整批保守标为部分接入，不能直接进入 S2 正式白名单。

| 共用池 | 数量 | 资源 ID |
|---|---:|---|
| 高牌 | 10 | `sweeping_wind_sleeve`、`full_sleeve_wind`、`wind_transforms_force`、`layered_leaves_return_tide`、`long_wind_full_sleeve`、`double_wind_continue_form`、`listen_wind_stack_top`、`wind_born_echo`、`poison_wind_seek_meridian`、`discard_gu_exchange_breath` |
| 一对／两对 | 6 | `twin_wind_exchange`、`measure_breath_twins`、`twin_swallows_press_sleeve`、`twin_leaves_build_momentum`、`exchange_nest_into_enemy`、`enemy_discard_returns_nest` |
| 三条／葫芦 | 6 | `three_ring_breathing`、`triple_layer_return_armor`、`returning_wind_continue_form`、`three_breath_turbulence`、`gather_wind_faces`、`three_cards_listen_tide` |
| 四条／五条 | 7 | `wind_deck_return_tide`、`exchange_sea_intake_qi`、`four_poles_control_top`、`poison_nest_seek_meridian`、`full_sleeve_bind_enemy`、`all_sounds_listen_wind`、`four_symbols_harmony` |
| 顺子 | 3 | `snake_path_order_meridian`、`wind_path_control_top`、`returning_loop_long_breath` |

### S2-01/S2-02 迁移证据

以下六门由“部分接入”迁移为“正式语义完整”。每门都由
`tests/test_runner.gd::_test_formal_production_technique_behaviors` 覆盖主分支、资源／目标不足边界和
预览伤害与实际结算一致性；这些是迁移证据，不能用资源可加载替代。

| 功法 ID | 精确牌型入口 | 主分支与不足边界 |
|---|---|---|
| `double_gu_exchange_breath` | 一对 | 伤害后转移带毒手牌；无带毒牌和敌方手牌时安全收敛 |
| `balance_sleeves_listen_wind` | 两对 | 防御、伤害与随机弃敌方两牌并行；敌方空手时弃牌安全收敛 |
| `three_ring_ensemble` | 三条 | 基础伤害；没有可选协同一对时只提交主牌型 |
| `three_ring_chaos_qi` | 葫芦 | 即时伤害与回合结束异状；敌方手牌、牌库皆空时延迟效果安全收敛 |
| `five_steps_echo` | 顺子 | 基础伤害；没有可选协同高牌时只提交主顺子 |
| `seize_qi_return_nest` | 四条 | 伤害与10层夺风；敌方无牌时四条不错误建立五条专属延迟效果 |

`four_poles_control_top` 本轮没有迁移：权威语义要求随机处理**我方**牌库，而当前通用
`apply_random_card_anomaly` 操作固定处理目标方牌区。该能力尚不能在数据中指定阵营；在新建通用
目标阵营参数并补齐测试前，它保持 `partial_integration`，不进入 production 白名单。

### 早期纵切回归夹具（7）

- `lethal_gu_needle`
- `suspended_gu`
- `double_gu_bind`
- `three_corpses_gu`
- `fire_sparks`
- `five_yang_chase`
- `discard_fuel_open_furnace`

这些资源只出现在 `vertical_slice_sequences.json` 或 `scripted_battle.json` 等调试装配中；
当前玩家 `production_sequences.json` 均为散招；`production_enemy_entry.json` 仍可显式为空。历史资源不得被正式开局、正式敌人或玩家可见内容统计引用。

## 九门重点深审

| 资源 | 权威位置与完整语义 | 当前数据与处理器能力 | 当前行为测试证据 | 状态 |
|---|---|---|---|---|
| `lethal_gu_needle` | `21-gongfa-poison-pool.md:14`：`max(1,floor(P/2))` 伤害；随机给敌手一张合格手牌附烈毒；纯风高牌且实际附毒才加 1 蛊印；无目标时只保留伤害 | `damage` + 随机手牌异状 + 捕获非空／纯风条件层数，数据可表达正文 | `_test_data_driven_lethal_gu_needle` 只覆盖纯风且存在目标；无目标和非纯风边界未独立覆盖 | 回归夹具 |
| `suspended_gu` | `21-gongfa-poison-pool.md:15`：获得 `P` 防御；敌方 1 蛊印，纯风高牌改为 2 | `defense` + 两个数据条件层数效果可以表达 | 没有以该资源为目标的确定性行为测试 | 回归夹具 |
| `double_gu_bind` | `21-gongfa-poison-pool.md:24`：`max(1,floor(P/2))` 防御；一对 1 蛊印、两对 2 蛊印 | `power_fraction(minimum=1)` + `hand_map` 层数可以表达 | `_test_representative_defense_and_layers` 与行动解析测试只明确覆盖一对；两对分支未独立覆盖 | 回归夹具 |
| `three_corpses_gu` | `21-gongfa-poison-pool.md:32`：`max(1,floor(P/3))` 防御；三条 3、葫芦 4 蛊印；纯风再 +1 | `power_fraction(minimum=1)` + `hand_map` + 纯风条件层数可以表达 | 没有以该资源为目标的确定性行为测试 | 回归夹具 |
| `fire_sparks` | `23-gongfa-fire-pool.md:14`：三段 `max(1,floor(P/4))`，每段后 +1 连势；纯阳时第三段改真伤 | `multi_damage` 只能表达等额普通攻击段及逐段加连势；资源缺少纯阳第三段真伤，当前也缺指定攻击段真伤所需的完整纯阳行动上下文 | 现有测试仅间接加载／使用资源，没有覆盖纯阳分支 | 回归夹具；在补齐 S5 通用能力前禁止进入正式白名单 |
| `five_yang_chase` | `23-gongfa-fire-pool.md:58`：五段 `max(1,floor(P/7))`；每段 +1 连势；连续两段均实际扣生命时，后一段追加 50% 追击，追击不参与连续判断且再 +1 连势 | `multi_damage` 已有逐段实际生命损失判断、50% 追击与独立追击连势参数 | `_test_representative_multi_attack` 覆盖五段、四次连续追击和连势总数；仍作为早期纵切装配而非正式玩家内容 | 回归夹具 |
| `discard_fuel_open_furnace` | `23-gongfa-fire-pool.md:53`：本次出牌先进入弃牌堆，再弃全部剩余手牌；按非火 2／火 4 加连势，随后抽 `max(2,N)` 并获一次连击；无直接伤害 | 数值、捕获、抽牌和连击均可表达；但当前 `zones` 效果在 `commit_staging_for` 之前执行，真实顺序是先弃剩余手牌、后提交本次出牌，缺少通用的出牌提交后时点 | `_test_representative_special_technique` 只断言最终牌区和数值，没有证明权威先后顺序 | 回归夹具；新增通用行动后置时点前禁止进入正式白名单 |
| `stagnant_gu_conceal_breath` | `21-gongfa-poison-pool.md:16`：获得 `P` 防御；随机附郁毒；纯林高牌且手牌无合法目标时从牌库顶向下找第一张；没有合法目标时防御仍结算 | 防御、窄牌区查询、可注入随机源、捕获与异状处理器完整表达 | `_test_stagnant_gu_conceal_breath_pipeline` 覆盖手牌目标、纯林牌库候补、第一张停止、全无目标及预览／实际防御 | 正式语义完整 |
| `borrow_fire_guard_heart` | `23-gongfa-fire-pool.md:15` 及公共借力规则：`floor(P/2)` 伤害；按结算时防御获得 1／2 层；敌方攻击段有实际防御或生命损失才逐层消费并按总损失普通反击 | 伤害、结算时防御条件、角色状态处理器和窄反击端口完整表达 | `_test_borrow_fire_guard_heart_pipeline`、`_test_borrowed_force_attack_segments` 覆盖预览／实际、1／2 层、防御／生命／混合损失、零损失、多段及反击击杀中止 | 正式语义完整 |

## 平台能力与后续迁移规则

- 五条已完成运行时识别，固定倍率 `×12`，映射到四条／五条共用池并使用独立序列；五条心得属于当前八种正式心得之一。
- 所有效果继续通过 `EffectHandlerRegistry` 的稳定操作码、定义校验、预览和正式结算入口运行；
  随机行为使用可注入随机源，处理器只通过窄战斗端口修改状态。
- 32 门风资源从“部分接入”迁移时，应以单门或同能力小批次补齐权威公式、牌型分支、目标不足、
  牌区时点和确定性测试；若撞到新通用语义，先建设对应能力，不在中央流程加内容 ID 分支。
- `data/vertical_slice_sequences.json` 和 `data/scripted_battle.json` 是确定性调试装配，不是正式开局、
  S2 白名单或玩家构筑。正式装配必须只引用已经标为正式语义完整的条目。
