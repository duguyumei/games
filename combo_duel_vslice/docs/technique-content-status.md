# 功法内容接入状态

本文件只记录工程接入证据，不新增或修改功法设计。规则唯一权威源是
`godot/docs/design-current/README.md` v0.30 及其功法框架、[高牌正式功法目录](../../godot/docs/design-current/martial-arts/24-gongfa-high-card-pool.md)、[扩展正式索引](../../godot/docs/design-current/martial-arts/28-gongfa-expanded-formal-pool-index.md)、[山系正式功法目录](../../godot/docs/design-current/martial-arts/29-gongfa-mountain-candidate-pool.md)、[风系正式功法目录](../../godot/docs/design-current/martial-arts/33-gongfa-wind-pool.md)与[火系正式功法目录](../../godot/docs/design-current/martial-arts/34-gongfa-fire-pool.md)。

## TargetQuery 筛选与校验框架优化（2026-08-16，已完成）

本批只优化公共目标查询框架，没有新增、录入或改写功法效果；正式资源数量仍为 211，
25 门特殊候选的接入状态没有变化。四个牌区的查询／移动规则以及普通、临时、虚无真气的
生命周期均未调整。

已完成：28 个实际 TargetQuery filters 字段已由身份／属性、牌阶／有效真气、异状／重塑、
运行权限／capture 排除四个处理器模块登记。每个模块同时负责本组字段名称、参数校验和
`matches`／集合后处理；`TargetQueryFieldRegistry` 统一拒绝非法或重复注册。
`EffectSpecValidator` 和 `EffectTargetQuery` 不再保存字段白名单或逐字段运行分支，旧
`TargetQueryFieldCatalog` 已删除。未注册字段在内容加载时失败，直接运行入口也会拒绝。

语义保持：有效属性与基础属性继续分离；临时牌阶和有效真气值继续读取当前运行事实；异状、
永久／临时重塑、临时真气、虚无明确弃置权限和异状施加权限继续走原窄端口。两类 capture
排除字段现在由注册处理器直接匹配，不再由牌区处理器改写字段。牌区顺序、随机并列、limit
以及 `BattleChoiceRequest` 的目标不足策略没有变化。本批没有修改任何正式功法资源、牌区
操作或真气状态生命周期。

验证结果：新增注册完整性、重复／非法注册、动态字段、未知内容字段、校验与运行一致性、
属性／基础属性、临时牌阶与有效真气、异状与重塑、临时／虚无真气、明确弃置权限、capture
排除、稳定并列和随机确定性测试；`content-contracts` 1073 条、风系专项 349 条、林系成长
专项 213 条、功法运行专项 314 条断言通过；quick 7/7 通过，其中项目加载覆盖 637 项。最终
quick 日志位于 `/tmp/taiwu-target-query-quick-final-20260816-01`。所有 Godot 调用使用不同的
`/tmp` 日志；测试与门禁除已知 macOS CA 证书警告外没有脚本加载、文件缺失、解析或运行错误。

## ValueSpec 框架优化（2026-08-16，已完成）

本批只优化公共数值规格框架，没有新增、录入或改写功法效果；正式资源数量仍为 211，
25 门特殊候选的接入状态没有变化。

已完成：`ValueSpecRegistry` 不再只是中央 kind 名单，66 个现有 kind 已由算术／递归、
捕获聚合、战斗状态和来源标识四个处理器模块登记。每个模块同时负责本组 kind 注册、字段
校验和数值解析；注册表统一拒绝非法或重复注册。`EffectSpecValidator.validate_amount_spec`
只委托注册表，`EffectValueResolver` 只保留入口、条件求值和公共上下文辅助，不再维护完整
kind 分支。未注册 kind 在内容加载时失败，直接运行也会显式诊断。

语义保持：递归 `add`、`subtract`、`multiply`、`max`、`conditional`，除零保护，
`floor`／`ceil` 与功法值分数取整，事件及集合 capture，稳定槽位来源标识和装备来源标识
聚合均未改变。本批没有调整任何正式功法资源或效果公式。

验证结果：新增注册完整性、重复／非法注册、未知 kind、递归表达式、capture、来源标识、
正负边界取整和除零保护测试；`content-contracts` 1020 条断言、功法运行直跑 314 条、
分组 139 条通过；quick 7/7 通过，其中项目加载覆盖 633 项。最终 quick 日志位于
`/tmp/taiwu-value-quick-final2-20260816-1786812338`。所有 Godot 调用使用不同的 `/tmp`
日志，除已知 macOS CA 证书警告外没有脚本加载、文件缺失、解析、运行或退出期资源错误。

## ConditionSpec 与事件 filters 框架优化（2026-08-16，已完成）

本批只处理公共条件框架，没有新增、录入或实现特殊功法，正式资源数量仍为 211，25 门特殊
候选的接入状态没有变化。

已完成：`ConditionSpecRegistry` 成为 42 个实际条件字段的登记、结构校验和运行判断唯一事实
源；修复 `group_snapshot_flag_value`、`group_has_no_common_attribute`、
`group_all_active_permanent_reshape` 及全量扫描发现的字段名单漂移；`all`、`any`、`not`
继续递归校验和递归运行。`EffectSpecValidator` 不再保存条件字段名单或逐字段结构分支，
`EffectValueResolver` 不再保存条件运行 switch；功法仓库的启动条件也使用同一注册表。

已完成：`ContentValidator` 现在校验功法自身 `condition`，同时继续校验每个 `effect.when`；
事件 filters 的 57 个字段在同一事件定义表中登记类型、取值、比较与捕获引用解析，
`StatusSystem` 不再单独维护三个 `*_from_capture` 转换分支。未知条件和未知事件筛选字段在
内容加载时失败，运行时也不会静默满足。

验证结果：新增未知字段、错误结构、递归条件、功法自身 condition、事件 filters 校验／运行
与捕获引用解析测试；`content-contracts` 935 条断言、功法运行直跑 314 条断言通过；quick
7/7 通过，其中项目加载检查覆盖 629 项。所有 Godot 调用使用不同的 `/tmp` 日志，除已知
macOS CA 证书警告外没有脚本加载、文件缺失、解析错误或脚本运行错误。

## 特殊功法运行底层改造（2026-08-15，公共底层已完成）

本节只记录当前工作区已经通过门禁的公共能力，不代表 25 门特殊候选已经成为正式资源。冻结规则先写入功法框架、行动结算、伤害防御、真气状态与地图生命权威文档；本批没有新增特殊功法 `.tres`，正式资源数量继续为 211。

已完成：稳定战斗槽位与确定性临时槽位；即时／推进后／行动末／回合末调用调度；唯一调用 token 与根行动 token；调用目标条件和启动权限在槽位移动前预检；统一 `TechniqueResolutionService` 提供功法启动、P₀ 后直接修正、Handler 默认阶段、连势结算和调用 continuation，`ActionResolver` 只保留卡牌行动与同步层调度，不维护第二套功法值或阶段白名单；自动条件通过统一 `ConditionSpec`、`ValueSpec`、`TargetQuery` 与 `BattleEventCatalog` 运行和校验；已提交事件通过统一事件桥转发动态响应，不再在 commit 后重复手动响应。

已完成：唯一临时移出事务承接虚无打出、虚无明确弃置、主动消散与同步移动；防御减少统一携带 `cause`，直接削防、支付、衰减、清空与重置不触发反震，`blockable=false` 只跳过格挡且仍结算伤害增减、防御吸收和反震；来源标识使用统一地址解析器，battle／run／`share_origin` 与独立临时副本边界已接入；生命上限贡献由统一服务在本局库存和战斗方复用；毒伤逐段冻结修正并在成功提交后按稳定 receipt 幂等消费。

已完成：旧效果操作码 `add_momentum`、`set_momentum`、`consume_momentum`、`add_same_qi`、`clear_same_qi_for_defense`、`set_reflection_percent`、`set_reflection_until_turn_end` 与 `remove_all_defense` 已从效果注册表和正式资源中迁移；保留 `dissipate_captured`、`atomic_exchange_captured`、`synchronous_discard_queries`、`insert_technique_slots` 与 `invoke_sequence_technique`，因为它们表达原子批次、同步冻结或嵌套结算时序，不是重复底层包装。底层兼容方法名仍可存在于窄端口或角色对象上，但内容不能再把它们当效果操作码使用。

投影与持久化：公开来源标识、稳定功法槽位和毒伤修正来源已经进入战斗快照、AI 公开状态和历史过滤；私有标识不会进入 AI 历史；功法序列 UI 显示当前／下一槽位公开标识，本局配装 UI 显示 run 标识；存档保存 `base_max_life` 与来源标识状态，旧 `max_life` 存档迁移为基础上限。当前没有已知的 UI／AI 公共字段漏接边界。

验证结果：即时调用顺序 `乙→丁→丙→甲`、`after_caller_advance` 顺序 `乙→丁→甲→丙` 均由匿名 probe 通过；拒绝调用不会移动槽位，等待选择恢复不会重掷或重复插入；专项直跑 wind 349、poison 171、mountain 432、content-contracts 906，project-load 加载 629 项；设计一致性为权威 211／运行时 211／待接入 0／错误 0；quick 7/7、full 24/24 通过，full 输出中可计数断言合计 138495 条，功法运行直跑 314 条、分组 139 条；`verify_test_runner.sh` 的 missing-script 与 missing-resource 故障探针均成功检出失败。全部 Godot 调用使用不同的 `/tmp` 日志，除已知 macOS CA 证书警告外没有脚本缺失、文件缺失、解析错误或脚本运行错误。

尚未接入：25 门特殊候选仍只存在于候选池权威文档，没有稳定正式 ID、独立 `.tres`、正式池资格、图标或逐门行为测试；在逐门内容接入完成前，不得加入心得、奖励、修习商店、敌人装配或生产序列。

## 当前正式目录（2026-08-15）

正式目录共211门：基础通用功法`basic_scatter`、`basic_guard`与209门普通功法。五个普通正式池分布为高牌55、对子48、三条34、顺子34、炸弹38；完整稳定ID与池归属见[扩展正式功法索引](../../godot/docs/design-current/martial-arts/28-gongfa-expanded-formal-pool-index.md)。全部209门非内建内容均为独立`.tres`、`formal_complete`、`built_in=false`、普通装配上限1，并进入对应正式修习候选。

本批实现分类为A 2门、B 41门、C 9门。A直接组合既有即时能力；B使用通用毒伤、快照、聚合值、捕获集合、原子层数、牌区操作和可恢复选择；C使用通用入堆完成、毒触发完成、下一回合、正常补牌后、防御保留后、完整回合结束和协同时点。中央战斗流程、AI与UI均不按这52门功法ID分支。

49门山系实现分类为A 10门、B 8门、C 31门。A复用即时数值与条件，B复用选择、捕获、批量牌区和临时重塑，C复用限时反震来源、反震真伤修改、格挡、邀战、结构化响应、协同、同气原子收口、防御保留和跨回合记录。`BattleSideSnapshot`、ActionPreview、AI公开状态、UI与历史事件均投影当前反震来源、格挡来源和邀战X/Q；中央流程不按49门山功法ID分支。

51门风系实现分类为A 3门、B 31门、C 17门；本批7门调整林系为B 6门、C 1门。A组合既有即时效果，B复用查询、捕获、牌区移动、临时牌与临时重塑，C使用提交后阶段、响应、格挡、回响、同步移动或跨持有者归还。寄脉、虚无、临时牌阶、占脉查询、冻结排除、原子交换、同步弃置和战后归还均为通用能力；中央流程与敌人AI不按风林功法ID分支。

本批40门火系实现分类为A 0门、B 15门、C 25门。B类复用多段伤害、牌型分支、捕获集合、燃尽施加／移除／转移、牌区查询与批量移动；C类使用连势快照前原子消费、来源安全连势回执、一次性保留保护、同气结构化写入与额外行动来源、功法回响、伤害／格挡／抽牌响应、跨回合延迟、原子跨阵营转移及战后归还。`BattleActionRecord`与战斗快照保存连势消费、连势改变来源、同气写入结果和额外行动来源；中央流程与AI不按火系功法ID分支。

整体功法审计后的优化不增加正式数量：`straight_forest_change_form`支持1至2张临时牌阶目标；`high_wind_break_page`令燃尽顶牌进入敌方手牌、非燃尽合法顶牌明确弃置，可自然触发`straight_fire_hidden_kindling`；`three_mountain_challenge_gate`使用邀战达标分支获得冻结C点连势；`pair_fire_guard_momentum`只简化公开说明。邀战底层现冻结达标／未达标分支并发布结构化`challenge_resolved`事件；内容校验拒绝未登记或重复的功法语义标签。

蛊毒底层已区分`normal`、`true`与`poison`，毒伤默认绕过普通防御、普通增减伤和反震，并公开实际生命损失；双方手牌／牌库毒量与毒牌张数实时派生。成长与桥接底层已支持G/Q/R、集合sum/max、原子转移／转换／平均分配、玩家选择余数、临时牌、清理前移动快照、同步毒完成事件、来源安全响应和协同限制。风林批次进一步支持实际手牌数／占脉数量分离、虚无离场去重、临时牌阶身份与快照、对子／三条冻结组成集合、定向检索、展示重排、提交后效果、实时手牌格挡后续效果、非递归回响和临时转移牌战后归还。

专项行为入口为`tests/test_poison_techniques.gd`、`tests/test_growth_techniques.gd`、`tests/test_bridge_techniques.gd`、`tests/test_mountain_techniques.gd`、`tests/test_wind_techniques.gd`与`tests/test_fire_techniques.gd`。前三者覆盖独立毒伤、同步毒爆、五叶／宿根入堆清理、落英余数选择、春风下一回合、护根防御保留、蛊焰追身、连枝协同、涸泽顶5与等待选择恢复；山系专项逐门识别49个ID，并覆盖冻结C、反震恢复、反震真伤、格挡、邀战、灰垒、返璞、同气收口、协同来源窗口、精确牌型与快照清理；风系专项逐门识别51个ID，并覆盖寄脉、虚无、临时牌阶、四门林系生成牌、定向检索、原子交换、同步弃置、实时格挡、四散回响、葫芦组成集合、提交后回手与战后归还；火系专项识别全部49个火系ID，并覆盖连势消费与回滚、护势、同气额外行动排序、燃尽生命周期、对子／葫芦边界、嫁薪原子转移、暗薪抽牌响应、K=4/5与回响禁止递归。

2026-08-15最终门禁：设计一致性为权威211／运行时211／待接入0／错误0；独立quick为7组全通过，full为24组全通过，full 输出中可计数断言合计138495条；火系专项264条、风系专项349条、成长专项213条、山系专项432条、蛊毒专项171条、桥接专项112条断言通过。Godot日志均显式写入独立`/tmp`路径，未出现脚本缺失、文件缺失、解析错误或脚本运行错误。

## 统计口径

基础通用实体 `basic_scatter`（散招）与 `basic_guard`（守招）均为 `formal_complete`、`built_in=true`、基础装配上限 99，并用八种 `eligible_hand_ids` 声明通用资格；其余209门非内建正式功法进入对应修习候选。

`data/production_sequences.json` 的八种精确牌型均为 `["basic_scatter"]`。两门基础功法不进入修习商店、奖励、心得随机候选或 `learned_technique_ids`；构筑 DTO 仍始终把它们作为合格候选公开。旧 47 门流派／纵切资源统计均属历史记录，不再描述当前正式目录。
`DesignConsistencyValidator` 的 0 错误也只证明名称、共用牌型池与废弃状态一致。

以下 S2-01/S2-02 旧矩阵仅保留为历史审计，不描述当前正式目录：

| 接入状态 | 数量 | 判定边界 |
|---|---:|---|
| 正式语义完整 | 8 | 权威主分支、目标不足边界与预览／实际结算均有确定性行为测试 |
| 部分接入 | 32 | 资源与所需通用处理器已存在，但没有逐门覆盖全部权威分支／时点的行为测试，暂不据此宣称语义完整 |
| 回归夹具 | 7 | 早期纵切用于回归协议；不是 S2 正式白名单候选，其中两门另有已确认语义偏差 |
| 禁用或延期资源 | 0 | 当前 47 个资源内没有；五条心得等禁用内容不属于这 47 门功法实体 |

当前正式口径以开头的211门实体为准；下列47门只解释更早的历史测试与迁移证据，不计入当前正式玩家内容。

## 47 门覆盖矩阵

### 已证明正式语义完整（8）

- 高牌：`borrow_fire_guard_heart`（借火护心）、`stagnant_gu_conceal_breath`（郁蛊敛息）
- 一对：`double_gu_exchange_breath`（双蛊换息）
- 两对：`balance_sleeves_listen_wind`（衡袖听风）
- 三条：`three_ring_ensemble`（三环并奏）
- 葫芦：`three_ring_chaos_qi`（三环乱气）
- 顺子：`five_steps_echo`（五步余音）
- 四条：`seize_qi_return_nest`（夺气归巢）

本段是旧接入证据。当前 `production_sequences.json` 的八种序列仍只装配 `basic_scatter`；正式目录以文件开头的211门为准。

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
