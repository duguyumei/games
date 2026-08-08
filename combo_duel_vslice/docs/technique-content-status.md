# 功法内容接入状态

本文件只记录工程接入证据，不新增或修改功法设计。规则唯一权威源是
`godot/docs/design-current/README.md` v0.30 及其功法框架、三个功法池正文。

## 统计口径

`data/techniques/*.tres` 当前有 47 个可执行实体；这个数字只说明资源能够通过统一定义、效果
注册和内容校验加载，不能证明公式、条件、目标、时点和失败边界均与权威正文一致。
`DesignConsistencyValidator` 的 0 错误也只证明名称、共用牌型池与废弃状态一致。

S2-01/S2-02 以基线 `b5ebf84` 逐项核对资源、处理器和行为测试后，证据分类为：

| 接入状态 | 数量 | 判定边界 |
|---|---:|---|
| 正式语义完整 | 8 | 权威主分支、目标不足边界与预览／实际结算均有确定性行为测试 |
| 部分接入 | 32 | 资源与所需通用处理器已存在，但没有逐门覆盖全部权威分支／时点的行为测试，暂不据此宣称语义完整 |
| 回归夹具 | 7 | 早期纵切用于回归协议；不是 S2 正式白名单候选，其中两门另有已确认语义偏差 |
| 禁用或延期资源 | 0 | 当前 47 个资源内没有；五条心得等禁用内容不属于这 47 门功法实体 |

因此，当前口径是“47 个可执行实体、8 门已由证据证明正式语义完整、39 门尚不能计入正式
玩家内容统计”。后续只有补齐逐门权威分支与确定性行为测试后，才能把条目从部分／夹具迁移为
正式语义完整；不能依据资源加载成功或结构一致性统计自动迁移。

## 47 门覆盖矩阵

### 已证明正式语义完整（8）

- 高牌：`borrow_fire_guard_heart`（借火护心）、`stagnant_gu_conceal_breath`（郁蛊敛息）
- 一对：`double_gu_exchange_breath`（双蛊换息）
- 两对：`balance_sleeves_listen_wind`（衡袖听风）
- 三条：`three_ring_ensemble`（三环并奏）
- 葫芦：`three_ring_chaos_qi`（三环乱气）
- 顺子：`five_steps_echo`（五步余音）
- 四条：`seize_qi_return_nest`（夺气归巢）

`data/production_sequences.json` 只引用上述八门。五条在当前未改造牌组中不可能出现，保留为
受校验允许的显式空数组；其余七个精确牌型的 production 序列均必须非空。`techniques.json` 的
`integration_statuses` 为每个资源声明 `formal_complete`、`partial_integration` 或
`regression_fixture`；production 内容校验会拒绝任何非 `formal_complete` 引用，并在错误中报告
功法 ID 与当前档位。

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
`production_sequences.json` 与 `production_enemy_entry.json` 当前均为空序列。它们不得被 S2 白名单、
正式开局、正式敌人或玩家可见内容统计引用，除非以后按权威语义重新验收。

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

- 五条已完成运行时识别，固定倍率 `×12`，映射到四条／五条共用池并使用独立序列；五条心得仍禁用。
- 所有效果继续通过 `EffectHandlerRegistry` 的稳定操作码、定义校验、预览和正式结算入口运行；
  随机行为使用可注入随机源，处理器只通过窄战斗端口修改状态。
- 32 门风资源从“部分接入”迁移时，应以单门或同能力小批次补齐权威公式、牌型分支、目标不足、
  牌区时点和确定性测试；若撞到新通用语义，先建设对应能力，不在中央流程加内容 ID 分支。
- `data/vertical_slice_sequences.json` 和 `data/scripted_battle.json` 是确定性调试装配，不是正式开局、
  S2 白名单或玩家构筑。正式装配必须只引用已经标为正式语义完整的条目。
