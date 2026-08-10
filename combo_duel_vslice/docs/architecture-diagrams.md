# 项目架构图解（新手向）

> 面向不熟悉 Godot 的开发者。用你熟悉的 Java 概念对照理解：**类 → Godot 脚本（class_name）**，
> **包 → 目录**，**Service → core/ 下的服务类**，**Entity/DTO → 快照与 DTO 脚本**，
> **依赖注入容器 → GameCompositionRoot**，**单元测试 → tests/**。
> 工程入口在 `combo_duel_vslice/`，纯规则逻辑在 `core/`，界面在 `ui/`。
>
> 给 Java 开发者的四个关键定位：`GameCompositionRoot` 是装配入口（composition
> root，不是业务单例）；`RunSession` 是应用层门面，外部通过命令调用本局用例；
> 各类 `HandlerRegistry` 类似 SPI/策略注册中心；`data/*.json` 只是内容定义和参数，
> 不是业务流程代码，状态推进仍由 `RunSession` 与领域服务完成。

---

## 1. 层次架构图（Layered Architecture）

对应 Java 三层架构（Controller / Service / DAO）。本项目是五层，箭头方向即依赖方向
（下层不依赖上层）：

```mermaid
flowchart TB
    subgraph UI["表现层 ui/（类似 Java Controller + View）"]
        FRONT["front_main.gd 主菜单/初始构筑"]
        RUN["run_main.gd 地图/修习"]
        BATTLE["main.gd 战斗界面"]
        COMP["组件: battle_hand_zone / battle_actor_status\nbattle_loadout_view / technique_sequence_view\nreward_overlay / practice_overlay / ..."]
        FRONT --> RUN
        RUN --> BATTLE
        RUN --> COMP
        BATTLE --> COMP
    end

    subgraph APP["应用层 core/（类似 Java Service/门面）"]
        ROOT["GameCompositionRoot 组合根（类似 DI 容器）"]
        RUNS["RunSession 本局门面"]
        BATTLES["BattleSession 战斗门面"]
        ROOT --> RUNS
        RUNS --> BATTLES
    end

    subgraph DOMAIN["领域层 core/（游戏规则本体，纯逻辑无 UI）"]
        ENGINE["CombatEngine + 服务族\n(回合/行动/伤害/状态/效果/敌人AI)"]
        RUNSTATE["RunState → MapNavigationService\nGrowthInventory / NodeDispatcher"]
        BATTLES --> ENGINE
        RUNS --> RUNSTATE
    end

    subgraph CONTENT["内容层 data/ + core/content_catalog.gd（类似 DAO + 配置）"]
        CATALOG["ContentCatalog 按 CONTENT_ORDER 加载 JSON（当前 15 项）\nContentValidator 统一校验"]
        JSON["data/*.json\n牌/功法/内功/消耗品/地图规则/节点奖励..."]
        CATALOG --> JSON
    end

    subgraph INFRA["基础设施（文件/随机数/日志/AI 配置）"]
        LOG["StructuredGameLog 统一日志"]
        AI["ai_settings_service / ai_conversation_store"]
        SAVE["save_repository / 存档迁移"]
    end

    UI -- "只读快照 + 命令" --> APP
    APP --> DOMAIN
    APP --> CONTENT
    INFRA --> APP
    INFRA --> CONTENT
```

阅读提示：UI 不直接改领域对象内部字段；UI 只拿**深复制快照**（`BattleSnapshot`/
`RunSnapshot`）做展示，改状态必须发**命令**给会话门面，这是本项目的核心边界。

---

## 2. 目录结构图（Component / 文件组织）

```mermaid
flowchart TB
    PROJ["combo_duel_vslice/ (Godot 工程)"]
    PROJ --> CORE["core/ 规则与应用逻辑（约 100 个脚本）"]
    PROJ --> UI["ui/ 表现层"]
    PROJ --> DATA["data/ 内容数据"]
    PROJ --> CFG["config/ 配置样例"]
    PROJ --> ASSETS["assets/ 卡牌美术/音频/字体"]
    PROJ --> TESTS["tests/ 自动化测试"]
    PROJ --> TOOLS["tools/ 内容管线工具"]

    CORE --> C1["根目录: 会话门面/服务族\nRunSession BattleSession CombatEngine\nGameCompositionRoot ..."]
    CORE --> C2["ai/ 远程大模型敌方 AI\n(窗口协调器/Provider/脱敏会话)"]
    CORE --> C3["effects/ 功法效果处理器(7 类能力)"]
    CORE --> C4["statuses/ 状态行为处理器"]
    CORE --> C5["card_reshapes/ 卡牌重塑行为"]
    CORE --> C6["run_effects/ 本局成长效果"]
    CORE --> C7["rewards/ 奖励类型"]
    CORE --> C8["localization/ 本地化"]

    UI --> U1["front_main 主菜单"]
    UI --> U2["run_main 地图/修习"]
    UI --> U3["main 战斗界面"]
    UI --> U4["components/ 复用控件(牌区/状态栏/卡面/覆盖层)"]

    TESTS --> T1["test_*.gd 顶层测试入口"]
    TESTS --> T2["groups/ 分组测试"]
    TESTS --> T3["support/ 测试工具"]
```

---

## 3. 类图（Class Diagram）—— 核心类与关系

### 3.1 装配关系（组合根 / Composition Root）

```mermaid
classDiagram
    class GameCompositionRoot {
        +content_catalog
        +game_log
        +runtime_profile
        +initialize() bool
        +create_run_session() RunSession
    }
    class ContentCatalog {
        +load_all() bool
        +definition(name) Dictionary
        +errors
    }
    class RunSession {
        +execute(command) CommandResult
        +snapshot() RunSnapshot
        +create_battle_session() BattleSession
    }
    class MapNavigationService {
        +phase
        +begin_node() / complete_node() / claim_reward()
    }
    class GrowthInventory {
        +run_deck / experience / consumables
    }
    class RunState
    class BattleSessionFactory
    class NodeDispatcher
    class NodeRewardService
    class StarterBuildRepository
    class StarterBuildAssembler
    class PracticeService

    GameCompositionRoot --> ContentCatalog : 创建并加载
    GameCompositionRoot --> RunSession : 工厂方法
    GameCompositionRoot --> BattleSessionFactory
    GameCompositionRoot --> StarterBuildRepository
    GameCompositionRoot --> StarterBuildAssembler
    GameCompositionRoot --> NodeRewardService
    RunSession --> MapNavigationService
    RunSession --> GrowthInventory
    RunSession --> NodeDispatcher
    RunSession --> PracticeService
    RunSession --> BattleSessionFactory : 创建战斗
    RunState --> MapNavigationService
    RunState --> GrowthInventory
    StarterBuildAssembler --> ContentCatalog : 读构筑定义
```

### 3.2 战斗核心类（域模型关系）

```mermaid
classDiagram
    class BattleSession {
        +setup_battle(config)
        +execute(command) CommandResult
        +preview(card_ids) Dictionary
        +snapshot() BattleSnapshot
        +poll_ai_timeout()
    }
    class CombatEngine {
        兼容门面/服务组合根
    }
    class BattleSetupService
    class BattleRoundService
    class BattleActionService
    class BattleConsumableService
    class BattleOutcomeService
    class EnemyActionPlanningService
    class ActionPreviewService
    class DamageResolver
    class StatusSystem
    class CardZoneService
    class BattleEffectPorts
    class ActionResolver
    class TriggerQueue
    class BattleTimingSystem
    class ActorTurnState
    class BattleFlowCoordinator

    BattleSession --> CombatEngine
    CombatEngine --> BattleSetupService
    CombatEngine --> BattleRoundService
    CombatEngine --> BattleActionService
    CombatEngine --> BattleConsumableService
    CombatEngine --> BattleOutcomeService
    CombatEngine --> EnemyActionPlanningService
    CombatEngine --> ActionPreviewService
    CombatEngine --> DamageResolver
    CombatEngine --> StatusSystem
    CombatEngine --> CardZoneService
    BattleActionService --> ActionResolver
    BattleActionService --> BattleFlowCoordinator
    ActionResolver --> BattleEffectPorts
    BattleEffectPorts --> DamageResolver
    BattleEffectPorts --> StatusSystem
    BattleEffectPorts --> TriggerQueue
    BattleRoundService --> BattleTimingSystem
    BattleActionService --> ActorTurnState
```

### 3.3 DTO / 快照边界（UI 与规则的“信封”）

```mermaid
classDiagram
    class BattleSnapshot {
        只读深复制，给 UI 展示
    }
    class RunSnapshot {
        只读深复制，给地图/修习 UI
    }
    class RunProgressSnapshot {
        战斗与本局之间的成长传输
    }
    class BattleEvent
    class RunEvent
    class CommandResult
    class BattleCommandDto
    class BattleActionProposal
    class BattleActionRecord
    class ActionPreviewDto
    class HandResultDto
    class RewardBundle
    class QiCardInstanceData

    BattleSession --> BattleSnapshot
    BattleSession --> BattleEvent
    RunSession --> RunSnapshot
    RunSession --> RunEvent
    BattleSession ..> RunProgressSnapshot : 入战导入/战后导出
    RunSession ..> RunProgressSnapshot
    UI --> BattleSnapshot : 只读
    UI --> RunSnapshot : 只读
    UI --> CommandResult : 命令回执
```

---

## 4. 状态图（State Diagram）

### 4.1 本局流程状态机（RunState / MapNavigationService）

```mermaid
stateDiagram-v2
    [*] --> awaiting_node : 建局(setup_run)
    awaiting_node --> node_in_progress : 进入节点(begin_node)
    node_in_progress --> awaiting_reward : 节点完成(complete_node)
    awaiting_reward --> awaiting_node : 领取普通/精英奖励
    awaiting_reward --> boss_chest : 第1、2层领取 Boss 奖励
    boss_chest --> awaiting_node : 完成 Boss 宝箱并进入下一层
    awaiting_reward --> run_complete : 第3层领取 Boss 奖励
    run_complete --> [*]
```

### 4.2 战斗核心状态机（回合与行动窗口）

```mermaid
stateDiagram-v2
    state "BattleSession (战斗会话)" as BS
    BS : setup_battle → 建立双方
    BS --> RoundStart : start_round
    RoundStart --> ActionWindow : 补牌/时点结算
    state ActionWindow {
        [*] --> PlayerIntent : 玩家选牌/预览
        PlayerIntent --> AwaitEnemy : 锁定意图
        AwaitEnemy --> Resolve : 双方同步/单方出招
        Resolve --> Combo : 同属性连击？
        Combo --> AwaitEnemy : 双方连击继续
        Combo --> Resolve : 单方连击自动
        Resolve --> [*] : 牌型组结束
    }
    ActionWindow --> RoundEnd : end_round(延迟结算)
    RoundEnd --> RoundStart : 下一回合
    ActionWindow --> Victory : 敌方生命 0
    ActionWindow --> Defeat : 我方生命 0 或牌库手牌全空
    Victory --> [*]
    Defeat --> [*]
    RoundStart --> BothDown : 同击双亡(规则待确认)
    BothDown --> [*]
```

### 4.3 远程 AI 行动窗口状态机（ActionWindowAiCoordinator）

```mermaid
stateDiagram-v2
    [*] --> idle : 窗口关闭
    idle --> thinking : 打开行动窗口(异步请求)
    thinking --> ready : 收到合法回答并本地复核通过
    thinking --> fallback_ready : 超时(30s)/非法回答重试失败
    thinking --> failed : 请求失败
    ready --> idle : 候选锁定，进入结算
    fallback_ready --> idle : 本地 Utility AI 接管
    idle --> no_enemy_action : 本轮无敌方行动机会
    no_enemy_action --> [*]
    failed --> [*]
```

---

## 5. 时序图（Sequence Diagram）—— 玩家打一张牌会发生什么

这是游戏开发最常用的“一次操作怎么走完全流程”的图：

```mermaid
sequenceDiagram
    participant UI as main.gd (战斗界面)
    participant BS as BattleSession
    participant CE as CombatEngine
    participant APS as ActionPreviewService
    participant BAS as BattleActionService
    participant AR as ActionResolver / EffectHandlers
    participant DR as DamageResolver
    participant SS as StatusSystem
    participant SNAP as BattleSnapshot

    UI->>UI: 点击 1~5 张手牌
    UI->>BS: preview(card_ids)
    BS->>APS: 校验+牌型+功法值+内功
    APS-->>UI: 预览 DTO(可确认提示)
    UI->>BS: execute(play_action)
    BS->>CE: 提交玩家提案
    CE->>BAS: 开行动事务(等待敌方意图)
    CE->>BAS: 敌我意图齐备 → 同步/单方结算
    BAS->>AR: 结算牌型组(三阶段触发)
    AR->>AR: 效果处理器按操作码分派
    AR->>DR: 计算伤害/防御/真伤/连势
    DR-->>AR: 伤害结果
    AR->>SS: 状态/异状/延迟记录
    AR->>SS: 牌区移动(待出→弃牌/回收)
    BAS-->>CE: 行动事务完成，推进序列
    CE-->>BS: state_changed
    BS-->>UI: snapshot() 深复制
    UI->>UI: 刷新手牌/数值/日志面板
```

---

## 6. 游戏总流程（用例/流程图）

```mermaid
flowchart LR
    A[主菜单 front_main] --> B[初始构筑页]
    B --> C[建局 RunSession + 固定种子生成地图]
    C --> D[地图选择节点 map_view]
    D --> E[节点派发 node_dispatcher]
    E --> F[战斗 main.gd<br>BattleSession]
    E --> G[占位路由/占位页<br>event / rest / treasure 尚未正式实现]
    F --> H[胜利 → 奖励包 reward_overlay]
    F --> I[失败后的本局终止推进尚未正式接入]
    H --> J[领取奖励 → 历练 + 修习开放]
    J --> D
    J --> K[第1、2层 Boss 宝箱占位流程 → 下一层]
    J --> M[第3层 Boss 奖励完成 → run_complete]
    D --> L[修习 practice_overlay<br>买功法/消耗品/冥想]
    L --> D
```

---

## 7. 数据流图（Data Flow）—— 数据从哪来到哪去

```mermaid
flowchart LR
    JSON["data/*.json<br>文件集合由 CONTENT_ORDER 定义"] --> CAT["ContentCatalog<br>加载+索引+深复制"]
    CAT --> VAL["ContentValidator<br>统一校验(拒绝坏内容)"]
    VAL --> REPO["领域仓库<br>technique/inner_skill/consumable/starter_build"]
    REPO --> RUNS["RunSession"]
    CAT --> ROOT["GameCompositionRoot"]
    ROOT --> RUNS
    RUNS --> BSF["BattleSessionFactory"]
    BSF --> BS["BattleSession"]
    RUNS --> GROWTH["GrowthInventory + RunDeck"]
    GROWTH --> BSETUP["BattleSetupService<br>装配战斗牌组"]
    BSETUP --> BS
    BS --> SNAP["BattleSnapshot"]
    BS --> PROG["RunProgressSnapshot<br>战后成长回写"]
    PROG --> GROWTH
    SNAP --> UI["UI 展示"]
```

---

## 8. 一张表：Java 概念 ↔ Godot 本项目对照

| Java | 本项目对应 | 例子 |
|---|---|---|
| 类 | `class_name` 脚本 | `battle_session.gd` |
| 包 | 目录 | `core/`、`ui/`、`tests/` |
| Controller | `ui/` 场景脚本 | `main.gd`、`run_main.gd` |
| Service 层 | `core/` 服务类 | `BattleRoundService`、`NodeRewardService` |
| 实体 Entity | 领域对象 | `BattleSide`、`QiCard`、`TechniqueInstance` |
| DTO / VO | 快照与 DTO 脚本 | `BattleSnapshot`、`CommandResult` |
| Repository / DAO | 内容目录+仓库 | `ContentCatalog`、`TechniqueRepository` |
| 依赖注入容器 | 组合根 | `GameCompositionRoot` |
| 配置文件 | `data/*.json` | `base_deck.json`、`map_rules.json` |
| 状态机 | 显式 phase 字段 | `MapNavigationService.phase` |
| 策略/处理器模式 | 效果处理器注册表 | `EffectHandlerRegistry` |
| 单测 | `tests/` | `test_runner.gd` 13 万+ 断言 |
| 事件监听 | `signal` | `state_changed`、`battle_finished` |

---

## 9. 新手建议的阅读顺序

1. `combo_duel_vslice/README.md` — 游戏怎么玩、边界怎么分
2. 本文 1（分层）→ 2（目录）→ 3.1（装配）
3. `core/game_composition_root.gd` — 看“万物从哪里造出来”
4. 本文 4.1 状态机，对照 `core/map_navigation_service.gd`
5. 本文 5 时序图，对照 `core/battle_session.gd` 的 `execute()`
6. `tests/` 里跑 `./scripts/run_tests.sh quick` 看行为契约
