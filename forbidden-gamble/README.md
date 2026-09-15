# 禁地牌局（Godot 武侠卡牌战斗）

独立的 Godot 4.7 工程（项目目录 `forbidden-gamble`）。规则与设计的权威来源是 `../game-design-docs/`（现行三份：《战斗系统底层_v1》全局规则、《真气语法_v3》真气层·麻将本体、《敌方系统_v2》对手卡；历史文档在 `_archive_2026-09-11/`）；本 README 只负责怎么跑、怎么测、现在做到哪，不重复规则细节。

## 当前进度

- 已完成（最新）：**真气语法 v3 麻将本体（2026-09-15/16，v3.1–v3.4，run_checks 全绿）**——`core/mahjong/` 薄核（tile/wall/river/shiki/fighter/technique/match/ai）＋钩子/DTO 内容协议＋功法一类一文件（`core/mahjong/techniques/`）＋贪心权重敌人 AI；交互重构（打出主按钮、功法按钮按需浮现、多付法选项、自动理牌、截牌窗可截才弹、气河分敌我）；`previews/m13_ui_autoplay` UI 自动驾驶回归。
- 已完成：**v2.2 旧战斗并行保留**（`core/battle/`：流动制＋对手卡敌方系统）；演武场工作台（scenes/dojo：择敌〔对手卡卡牌＋详情页〕＋功法/心法卡槽＋真气配置）；图鉴（scenes/codex）；意图/护境覆盖/力体/伤害三分类/透明边界等全局规则（《战斗系统底层_v1》§12）。
- 主线流程（2026-09-12 定）：title → 演武场 → 战斗。搜打撤层（远征会话/版图/据点/备战/局外仓库）已下架，回滚锚点＝git 首个基线提交。
- 待做：全部数值占位待演武场校准（《真气语法_v3》§10 证伪预测）；搜集层未立项；心法/状态等后置系统见现行文档开放项。

## 运行

用 Godot 4.7 打开本目录并运行，主场景 `scenes/title/title.tscn`（主菜单）。主菜单「演武场」→ `scenes/dojo/dojo.tscn`（择敌＋自由构筑工作台：开战走 v2.2 `scenes/battle/battle.tscn`，「麻将演武（v3）」走 `scenes/mahjong_battle/mahjong_battle.tscn`）；「图鉴」→ `scenes/codex/codex.tscn`。正文字体 Noto Sans SC、标题字体 MaShanZheng（`assets/fonts/`，均 OFL 协议）。

## 目录结构

```
scenes/           五屏（场景根脚本只做编排）
  title/          主菜单
  dojo/           演武场（战斗工作台：择敌＋卡槽构筑）
  mahjong_battle/ 真气语法 v3 麻将战斗（现行）
  battle/         v2.2 旧战斗（并行保留）
  codex/          图鉴
core/             规则与数据（纯逻辑）
  mahjong/        v3 麻将内核：tile/wall/river/shiki/fighter/technique/match/ai ＋ techniques/（功法一类一文件）
  battle/         v2.2 战斗内核：combat_state/turn_manager/technique_resolver/effect_pipeline/status_runtime/enemy_brain/…
  data/           数据定义层（data_repo：七份 JSON 统一加载＋schema 校验）
  dojo_config.gd  演武场→战斗交接（静态类）
  scene_routes.gd 场景路径唯一出处
  sfx.gd          音效池
ui/               UI 组件（battle_palette 暗墨 / board_palette 纸墨亮；theme/main_theme.tres 纸墨基线）
data/             游戏数据 JSON（techniques/xinfa/enemies/items/statuses/player/sandbox_encounter）
tests/            GUT 单元/模型测试（tests/mahjong/ 为 v3；余为 v2.2 侧＋数据 schema）
previews/         行为预览与视觉截图工具（自校验，退出码即结论；m12 麻将仿真、m13 UI 自动驾驶）
tools/            run_checks.sh 一键验证
```

UI ↔ 模型契约：v2.2 战斗维持拉模式（`drain_messages`＋唯一重画入口）；v3 走请求/应答 DTO（玩家决策以应答键回灌引擎，协议见 `core/mahjong/hooks.gd` 头注）。

## 玩法速览（细节以现行文档为准）

- **麻将演武 v3（现行，《真气语法_v3》）**：真气牌＝万/筒/条×1–9×4 共 108 全活共墙；每方丹田 13（静息不变量：手牌＋3×明式＝13）；每拍自动摸 3、打出至上限——架势（弃牌入气河、开截牌窗）或功法（耗式占行动、效果在途至下次能行动拍、延迟＝式数）；守功法＝行动期间（摸牌后出牌前）免费吃罡气；碰/杠截牌（无吃）＝截 1 弃 1；超发回气拍；气河干涸整洗回气海。
- **v2.2 旧战斗（并行保留，归档《真气语法_v2》＋《敌方系统_v2》）**：流动制行动权、数值卡＋刻/顺三输入、架势弃 1–4、截即打、疲劳兜底、对手卡敌方（行为链梯＋冷却两刻度＋对手卡详情明码）。

## 架构速览

- **规则核心纯逻辑不含 UI**：`core/mahjong/`（v3 现行——全整数结算、RandomNumberGenerator 全程种子、对局可重放；内容协议＝钩子＋DTO，功法/心法/词条只准走协议不准直摸流程，见 `core/mahjong/hooks.gd` 头注）；`core/battle/`（v2.2 保留——CombatState/TurnManager/TechniqueResolver/EffectPipeline/StatusRuntime/EnemyBrain）。
- **EffectPipeline 动作管线（v2.2）**：PRE 拦截 → RESOLVE 默认结算 → POST 触发入队（队列化＋链长上限）；状态、心法都是平等的数据钩子。数据表达不了的规则在核心里加类型，不向数据塞脚本。
- **数据定义层 DataRepo（autoload）**：七份 JSON 唯一加载入口（缓存＋schema 校验＋`reload()` 失效）；跨文件引用（敌人→功法）加载期校验，坏数据 `push_error` 带上下文。数据文件：`data/techniques.json` 功法、`xinfa.json` 心法、`enemies.json` 敌人、`items.json` 物品、`statuses.json` 状态、`player.json` 玩家定义、`sandbox_encounter.json` 演武场遭遇。
- **演武场/图鉴**：`scenes/dojo`（择敌＝对手卡卡牌＋点击详情页、功法/心法卡槽点选、真气配置，静态类 core/dojo_config.gd 交接）；`scenes/codex`（只读图鉴）；共用卡牌组件（technique_card/xinfa_card/qi_orb/card_picker 等）在 ui/ 下。
- **演出与弹窗（v2.2 侧）**：演出归 `ui/battle_fx.gd`、敌方链归 `ui/battle_sequencer.gd`（令牌防重入）、弹窗框架 `ui/popup_host.gd`（锚定/点外关闭/ESC/互斥）、结算浮层 `ui/battle_end_overlay.gd`；v3 侧规则与演出同层（《真气语法_v3》§12 裁定），交互与演出驱动集中在 `scenes/mahjong_battle/mahjong_battle.gd`。
- 装饰层一律忽略鼠标（点击只落在可交互元素上）。音效为脚本合成占位（`assets/sfx/*.wav`），后续整体替换。

## 当前明确不实现

僵局兜底（2026-09-15 拍板明示不做）；字牌（红中类：万能牌/状态牌/特殊属性三候选未拍板）；本命牌组/丹田改造/气海布阵（挂起）；搜集层未立项；正式美术、联网。

## 战斗日志

运行时把玩家操作与系统记录写入日志文件，启动时在控制台打印路径：

```
~/Library/Application Support/Godot/app_userdata/禁地牌局/logs/combat_<时间戳>.log
```

排查问题时把这个文件发出来即可。（旧项目"江湖险地：战斗沙盒"的存档已自动迁移。）

## 测试与一键验证

规则测试使用 GUT 框架（内置 `addons/gut`，测试在 `tests/`，当前全绿。**真气语法 v3.4 统一循环＋在途功法＋守功法窗口已实装**（`core/mahjong/`：108 均匀共墙（全活，死牌山已退役）、三门万/筒/条、静息不变量＝手牌＋3×明式＝13 一本账、每拍摸牌开始打出结束（摸 3 起）、回气拍（摸后 ≤上限整拍跳过）、功法＝打出（占行动、每拍一门、耗式入河不回填）、**在途功法（效果在发射者下次能够行动的那一刻自动发动，延迟＝式数；冷却/蓄力拍数退役）**、守功法＝行动期间免费即时（罡气；摸牌后出牌前）、截牌拍＝截＋弃 1、气河循环、六式基本招、断势、**暗杠（手里四张自晒）**、贪心权重敌人 AI；交互＝打出主按钮＋功法按钮按需浮现＋多付法选项＋自动理牌＋截牌窗可截才弹＋牌河分敌我；入口＝演武场"麻将演武（v3）"按钮；功法一类一文件＋钩子/DTO 内容协议见 `core/mahjong/hooks.gd` 头注）。v2.2 战斗（`core/battle/`：流动制＋判定制＋敌方剧本）原样保留：

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

全套验证（import 缓存 → GUT → 五场景冒烟计错 → 九个行为预览）一条命令：

```bash
bash tools/run_checks.sh          # 全套
bash tools/run_checks.sh quick    # 跳过 import（未新增 class_name/资源时用）
```

覆盖：**麻将 v3**（墙/河/式/引擎/AI 四套件 46 测＋`previews/m12_mahjong_sim.gd` AI 对 AI 五种子全流程仿真：自然终局/静息不变量/牌守恒 108/内容活性）、行动权判定制（首拍优先/非前手/破绽跳拍与消耗/双破绽/被袭击反转/度量计数）、敌方剧本执行（循环推进/蓄势断招跳槽/意图标签/力量成长）、功法词条（压制→破绽/冷却/蓄力生命周期与破盾销毁）、先机行动（夺取/护境拦截/优先级）、六种牌型判定、真气量计算、功法合法性与效果结算（含手牌子集搜索/连风双段独立吃盾）、心法词条（各时机/条件/动作类型、once 记账、系别计数）、效果管线（点位/钩子/优先级）、种子确定性与整局重放、战斗日志、被袭击演出链、演武场卡槽配置、数据 schema（真数据全绿 + 坏例必被抓）。v2.2 侧新增功法只需改 `data/techniques.json`、新增心法只需改 `data/xinfa.json`、新增敌人只需改 `data/enemies.json`，schema 校验自动覆盖；**v3 侧新增功法＝`core/mahjong/techniques/` 一个文件＋库一行**。

Godot 项目不依赖外部 Node 依赖或构建配置。
