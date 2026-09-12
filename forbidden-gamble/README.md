# 禁地牌局（Godot 武侠搜打撤卡牌）

独立的 Godot 4.7 工程（项目目录 `forbidden-gamble`）。规则与设计的权威来源是 `../game-design-docs/`（入口：《00_文档索引与使用规范》）；本 README 只负责怎么跑、怎么测、现在做到哪，不重复规则细节。

## 当前进度

- 已完成（最新）：**战斗优先工作台化（2026-09-10/11，D-065）**——演武场升级为自由构筑工作台（scenes/dojo：择敌＋功法六槽/内功五槽卡槽点选＋装备＋真气牌组编辑，DojoConfig 交接、战斗内核零改动）；图鉴落地（scenes/codex：真气/装备/功法/内功四分页卡牌网格）；UI 纸墨主题基线（ui/theme/main_theme.tres）、手牌栏 7 孔（修隐形手牌 P0）、甲护徽章。产品目标重定位：**构筑类武侠卡牌战斗为唯一核心**，探索层重构方向讨论中（见设计文档《18》D-065），实施暂缓。
- 已完成：战斗规则引擎（牌型/功法/兵器/回合结构/敌方意图/动作管线）；地块大陆探索层与 UI（M1~M5）；局外流程（M6：主菜单 → 据点 → 出发，撤离背包入库）；战斗场景 UI（M7 全部 + M8 战斗顶栏）；**架构升级（2026-09-06，C-020/C-021）**——场景根脚本拆解为组件、模型分层、会话/仓库分家、目录按层重组、数据层统一（DataRepo）；**心法与搭配系统（2026-09-09，D-060/D-061/C-031）**——小丑牌式被动规则修改器（XinfaRuntime 挂管线，敌我同规则）、5 平权槽、效果词表（时机×条件×动作）、technique_prepare 新点位、功法 16 门（补顺子）、心法 15 门、敌人心法（D-055）、meta 档 v5（已学清单+构筑配置）、据点「参悟」（研读秘籍）与「搭配·构筑」面板、备战页心法区、战斗心法胶囊。
- 待做：物资使用效果与休整（含"逃跑道具"设计，C-017 遗留）、战斗内取用物资时机；平局结算口径待定案（现按败北）；真气状态跨战斗持续（设计清单，交接载荷位已留）；C-030 战斗浮层连续性（D-058 待实现）。
- 全局状态与最新变更见《00》"当前开发状态"与《18_设计决策日志》。

## 运行

用 Godot 4.7 打开本目录并运行，主场景 `scenes/title/title.tscn`（主菜单 → 据点 → 牌阵探索 board.tscn；战斗场景 battle.tscn 由牌阵进入，也可单独运行）。主菜单「演武场」→ `scenes/dojo/dojo.tscn`（择敌＋自由构筑→开战，战斗内容开发工作台）；据点「图鉴」→ `scenes/codex/codex.tscn`（可构筑信息总览）。正文字体 Noto Sans SC、标题字体 MaShanZheng（`assets/fonts/`，均 OFL 协议）。

## 目录结构（按层归位，C-020）

```
scenes/          四屏（场景根脚本只做编排）
  battle/        战斗层（battle.gd/tscn）
  board/         探索层（board.gd/tscn）
  stronghold/    备战层·据点
  title/         主菜单
core/            规则与数据（纯逻辑）
  battle/        战斗内核：combat_state/turn_manager/technique_resolver/effect_pipeline/status_runtime/…
  expedition/    探索模型：board_state（规则门面）+ map_generator/presenters/board_codec + expedition_session（会话与交接）
  meta/          局外仓库（meta_archive）
  data/          数据定义层（data_repo：六份 JSON 统一加载+schema 校验）
  sfx.gd         音效池
ui/              UI 组件（两套主题各自收敛：board_palette 纸墨亮 / battle_palette 暗墨）
data/            游戏数据 JSON
tests/           GUT 单元/模型测试（含数据 schema）
previews/        行为预览与视觉截图工具（自校验，退出码即结论）
tools/           run_checks.sh 一键验证
```

层间交接走显式协议（ExpeditionSession）：出发 `start_run` / 开战 `prepare_battle + take_battle_context` / 战报 `report_battle_result + consume_battle_result`（读完自动清）/ 撤离结算 `settle_and_end_run`（入库走 MetaArchive）。UI ↔ 模型维持拉模式：`drain_messages` + 唯一重画入口。

## 玩法速览（细节以文档为准）

- **战斗**（规则见《23》《27》）：**行动权模型（D-063）**——行动权是唯一时序令牌，无大回合无收势；原子行动（发动功法/调息/暂让/用道具）结束即转让。真气牌（风/林/火/山，属性参与心法条件计数）组牌型（高牌~顺子，无同花）发动功法，兵器按系增幅；**调息**＝主动换手（弃全部手牌＋纳 6 口，气持有即保留）；**暂让**＝过牌＋顺纳 1 口；僵局连续 12 次无功法动作→平局视同败北；行动权移交/夺取/护境变更全部是管线动作（可取消=连动/免疫、可改写=改道，D-064）；敌方意图在开战与敌方每次行动后锁定（可以是"调息"）；毒发随本人调息发作；所有效果走动作管线（一切皆动作）。**心法**＝小丑牌式被动规则修改器：5 平权槽，战斗开始自动挂载，竖排胶囊悬浮可见效果文本；搭配靠词条涌现（出招真气属性×装备心法系别×牌型）。
- **探索**（规则见《05》《09》）：预置地块大陆，走到即探索；每地块摊成 3 列明牌网格（C-028：全部亮牌、点击即互动、拿走留洞）；战胜后敌人原地变遗体压牌堆顶，[搜刮]（付开启费，与箱子同规则）或 [无视]挪进散落区，走开也自由（C-019）；容器统一（开启费＋逐张翻牌＋拿取免费，可翻一半续翻）；地点卡解锁特殊地点（捷径/藏宝阁/上锁房/撤离点）；背包 12 格同名叠放。
- **压力与终态**（见《09》）：行动力起始 40，具体定价在 `data/location_qingfeng.json`（原型假设，试玩调整中）；警戒度分级（12/24/36）升级洗入敌人牌、无强制拦截；行动力归 0 且不在撤离点＝力竭被擒。
- **贯通与存档**：气血跨战斗贯通，"临时"效果须 scope 标注；被动存档（无手动存档 UI），死亡/力竭/撤离为终态不续玩，战斗中强退回战前检查点（PvE 合法 SL）；全局单种子驱动，整局可重放。
- **局外**：撤离背包入据点仓库（`user://meta_save.json` v5，跨局累计）；死亡/力竭/中途放弃物资全丢。据点：「参悟」研读秘籍习得功法/心法（参悟即蚀，+历练）；「搭配·构筑」调整心法 5 槽与功法 4 位（生效规则即时汇总）；顶栏显示银两/历练/仓库总价值（meta v6 账面资产；折银与商店后置）；制作/购买/升级为占位；图鉴已落地（四分页卡牌网格，全数据驱动）。

## 架构速览（详见《16》《18》C-020）

- **规则核心纯逻辑不含 UI**：`core/battle/`（CombatState/TurnManager/TechniqueResolver/EffectPipeline/StatusRuntime）、`core/expedition/`（BoardState 规则门面 + 生成/展示/编解码三模块）、`core/expedition/expedition_session.gd`（会话与层间交接）、`core/meta/meta_archive.gd`（局外仓库）。
- **EffectPipeline 动作管线**：PRE 拦截 → RESOLVE 默认结算 → POST 触发入队（队列化＋链长上限）；状态、心法、装备都是平等的数据钩子。数据表达不了的规则在核心里加类型，不向数据塞脚本。
- **数据定义层 DataRepo**（autoload）：六份 JSON 唯一加载入口（缓存 + schema 校验 + `reload()` 失效）；跨文件引用（敌人→功法、地点→敌人/物品、功法→状态）在加载期校验，坏数据 `push_error` 带上下文。数据文件：`data/techniques.json` 功法、`enemies.json` 敌人（tier 四档/loot_chest）、`items.json` 物品、`statuses.json` 状态、`player.json` 玩家定义、`sandbox_encounter.json` 演武场遭遇、`location_qingfeng.json` 地点（ap 表/警戒/掉落/地点卡）。
- 演武场/图鉴（D-065）：`scenes/dojo`（择敌＋自由构筑，静态类 core/dojo_config.gd 交接，battle.gd 分支优先加载）、`scenes/codex`（只读图鉴，复用功法卡/丹珠组件＋内功卡/装备卡模板）；新组件（card_picker/qi_count_cell/xinfa_card/item_card/technique_empty_slot）都在 ui/ 下有 .tscn。主题基线 `ui/theme/main_theme.tres`（纸墨按钮/面板，先挂标题/据点）。
- **场景根只做编排**（单文件 ~400-650 行）：battle.gd（装配流/刷新/弹窗开关）、board.gd（刷新/连线/动作分发）；演出归 `ui/battle_fx.gd`（含功法专属演出注册表——万剑归宗式特效将来挂这里）、敌方链归 `ui/battle_sequencer.gd`（令牌防重入）、弹窗框架 `ui/popup_host.gd`（锚定/点外关闭/ESC/互斥，两场景通用）、抽屉 `ui/board_drawer.gd`、镜头 `ui/board_camera.gd`、结算浮层 `ui/battle_end_overlay.gd` / `ui/board_outcome_overlay.gd`。
- **战斗顶栏（M8）**：遭遇名＋回合·行动方（演出时唯一"轮到谁"指示）＋最新战报行（四色事件着色，展开罩层同套配色）＋[背包][战报][⚙设置]——设置弹窗含演出速度三档（快0.6/标准1.0/慢1.6）与弃战（远征＝阵亡口径物资全丢、沙盒＝回主菜单）；背包为只读随身物资窗；ESC 先收弹窗再开关战报。
- **战斗操作流（功法优先装配流）**：点功法卡（一次）＝装配——已选真气带入镶孔、还缺则智能补齐、补不齐提示并保持装配态；满足即待确认 → 中央按钮两组互换：未装配=[暂让][收势]、装配/待确认=[确认][取消]；演出期间整行隐藏。
- 装饰层一律忽略鼠标（点击只落在可交互元素上）。音效为脚本合成占位（`assets/sfx/*.wav`），后续整体替换。

## 当前明确不实现

同花；冻结、封存等真气状态；通用消耗区、反击架势（大回合/收势已随 D-063 行动权模型废止）；潜行、正式美术、联网。尚未接入：物资使用效果与休整（items.json 的 use 字段）、真气运转六区与真气毒（设计已定，见《16》《06》）。

## 战斗日志

运行时把玩家操作与系统记录写入日志文件，启动时在控制台打印路径：

```
~/Library/Application Support/Godot/app_userdata/禁地牌局/logs/combat_<时间戳>.log
```

排查问题时把这个文件发出来即可。（旧项目"江湖险地：战斗沙盒"的存档已自动迁移。）

## 测试与一键验证

规则测试使用 GUT 框架（内置 `addons/gut`，测试在 `tests/`，当前 310 项全绿）：

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

全套验证（import 缓存 → GUT → 七场景冒烟计错 → 七个行为预览）一条命令：

```bash
bash tools/run_checks.sh          # 全套
bash tools/run_checks.sh quick    # 跳过 import（未新增 class_name/资源时）
```

覆盖：行动权模型（调息吐故纳新/暂让顺纳/僵局保险/移交取消与改道/夺取与免疫/调息后强制移交/敌方调息策略/度量计数）、六种牌型判定、功法合法性（含手牌子集搜索）、效果结算与传输修正、心法词条（各时机/条件/动作类型、once 记账、系别计数、敌我同规则）、研读与构筑（清单/白卷/上限/往返/旧档迁移）、账面资产（历练三路入账/银两往返/旧档兼容）、敌人 AI 行动、牌阵规则（大陆连通/地点卡/容器/警戒/力竭/撤离/种子确定性与整局重放）、被动存档、据点 meta 存档、层间交接协议（战报读完即清等）、数据 schema（真数据全绿 + 坏例必被抓）。新增功法只需改 `data/techniques.json`、新增心法只需改 `data/xinfa.json`，schema 校验自动覆盖。

Godot 项目不依赖外部 Node 依赖或构建配置。
