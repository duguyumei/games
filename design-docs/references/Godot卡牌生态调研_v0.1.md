# Godot 卡牌生态调研（v0.1）

> 2026-10-26 立档。两轮调研合并：①「做卡牌游戏 Godot 有什么现成件」生态全景；②「已发售 Godot 卡牌游戏实际用了啥」发售实证。方法＝网络检索＋仓库内 addon 源码逐文件审读＋公开源码仓库结构实证。起因：用户点破「写码前调研令未覆盖仓内已有 addon（chun92 未审即自建）」，补课立此档。

## 一、生态全景（2026-10 实查，五类）

| 类别 | 件 | Godot | 许可证 | 成熟度 | 判定 |
|---|---|---|---|---|---|
| 整框架 | db0 Card Game Framework | **3.x**（4 移植＝未合并社区 PR，Issue #178 自 2022 挂起） | **AGPL-3.0**（传染，闭源商用堵死；仅 Steam 集成附录非商业授权） | 1.4k★，最负盛名 | 用不上（版本＋许可证双拦路）；其效果脚本引擎（纯文本字典定卡牌规则＋触发器＋运行时重算）是全生态最强规则引擎设计，思路可抄 |
| 整框架 | Slay-The-Robot（本项目基底） | 4.x | MIT | 新开源、活跃 | 已在脚下：Action 管道/Interceptor/Validator 规则引擎＋肉鸽全流程＋确定性 RNG＋存档 |
| 容器件 | chun92 card-framework | 4.6+ | MIT | v1.4.0（Reddit 161 赞） | 仓内已装；详档见 §二 |
| 容器件 | Card3D | 4.x | — | — | 3D 卡，我方 2D 出局 |
| 编辑器工作流 | pudgypoultry card-game-skeleton | 4.x（4.5，2026-02 更新） | MIT | 婴儿期（2★/23 commits） | 概念最贴内容量产：Dock 管卡牌 JSON 库＋自定义属性（Text/Numeric/Enum）＋按文件夹自动关联美术与场景＋逐卡生成 .tscn＋可视化牌组构筑器；候选试装 |
| VFX 资产 | Godot Card FX（Binbun）/ Prism Card FX / godotshaders.com card 标签 | 4.x | 价/证未确证（itch 页超时） | 商用资产 | 卡面视差/全息/闪箔/稀有度光效——美术后期料 |
| 教程参考 | YouTube 卡牌系列（Card Template 单集 11 万观看）/ guladam deck_builder_tutorial | 4.x | — | 教程 | 参考实现 |
| 已死 | BraindeadBZH Godot Card Engine | 3.x | — | 仓库 404 | 出局 |

**结论：Godot 4 卡牌生态很薄**——真正成熟可用就两条线（StR 框架线＋chun92 容器线），本项目两条都占。Godot 3 存量≠行业现状：新项目几乎全 4.x，3.x 只是老家伙没搬家（db0）或已死（BraindeadBZH）。

## 二、chun92 card-framework 档案（仓内件）

- **是什么**：GitHub `chun92/card-framework`，作者 Hyunjoon Park，MIT，v1.4.0，同时发布于 Godot 官方资产库 #3616。卡牌容器（CFHand 扇形手牌／CFile 牌堆）＋贴图卡模板（CFCard＝整卡 PNG 正反面）＋JSON 卡厂＋自带拖拽（CFDraggableObject 四态状态机：IDLE→HOVERING→HOLDING→MOVING，逐帧跟鼠标）＋撤销历史。
- **来源考证**：非 Godot 原生（引擎不带卡牌件）；非 StR 上游自带（查实上游 addons/ 仅 label_font_auto_sizer、smooth_scroll_container、sound_manager 三件）；本地落盘 2026-10-24 22:00＝立档当日，AGENTS.md 同日记为基底配套件；git 一直 untracked 从未提交。具体下载动作无留痕（用户未拉过则系首日建仓会话按基底方案所装）。
- **四轴判定**（2026-10-26 源码逐文件审读）：
  1. **卡牌模板**：贴图卡 vs 我方数据装配卡面（分区/缩号/硬裁/三态）——类型不合，且撞卡牌工厂制，必须自建；其「一厂管一尺寸」思路与 QiCardStyle 同构。
  2. **手牌系统**：CFHand＝Curve 控扇形＋旋转包围盒落点分区＋拖拽重排，Godot 4 唯一成熟扇形容器；现需求（固定扇＋拖出弃置）15 行排版＋原生拖放已覆盖，若后期要悬停抬卡/重排/回弹手感可接它——代价＝弃引擎原生拖放协议，与少码优先制②冲突，需例外裁定。
  3. **牌堆管理**：我方 v0.5 无卡组·涌出制，牌堆概念已删——架构性无对象，非其有缺点。
  4. **战场布局**：addon 无此件（容器仅 Pile/Hand 两种），宣传四大优势水分最大一条；我方固定七槽行＝两行原生 HBox 完成，几何被 UI实施 §8 冻结稿锁死。

## 三、名词备查

- **Godot 3 vs 4**：2023-03 换代重写（GDScript 语法大改/渲染器重写/API 大改名），3→4 移植≈半重写，故老框架易停滞。
- **AGPL vs MIT**：AGPL＝传染性开源（用它整个游戏必须 AGPL 开源发布，闭源商用基本堵死）；MIT＝随便用保留版权声明即可。选件先看许可证。

## 四、已发售实证（2026-10 查证）

| 游戏 | 引擎/技术 | 身份 | 关键事实 |
|---|---|---|---|
| 杀戮尖塔 2（Mega Crit） | **Godot 4.5.1＋C#(Mono)**，疑定制引擎分支 | 头部商业作，2026-03 抢鲜体验 | 2023 Unity Runtime Fee 丑闻后弃 Unity 全重写（先做 Dancing Duelists 试验项目验货）；现为 Godot 白金赞助商；无卡牌框架；社区 ILSpy 解包 C# 程序集逆向出全套数据（spire-codex 数据库/sts2-modding-mcp） |
| Worlds Upon The Wind（max99x） | **Godot 4.7（仓库 README 自述；awesome-godot 标 3，以仓库为准）**，GDScript＋疑 Rust gdext | **一人开发，Steam 99% 好评**，2026-07 发售，**全源码公有领域（CC0）** | 2026-02 首次下载 Godot，5 个月至发售 |
| Sengodai | Godot | 独立卡组构筑 | Steam＋Google Play 双端 |

勘误：Shogun Showdown 曾误记为 Godot，查实 **Unity**（Fearless 论坛改引擎条目）——断言前先搜证的再证。

**WUTW 仓库开膛**（github.com/max99x/wutw-public，制作流程活样本）：

- 卡牌定义＝`res://cards/` 每卡一个 **Godot Resource**（非 JSON 非纯代码）；遗物/技能/角色/事件同样 Resource 子类；卡牌能力挂独立脚本——「数据资源＋效果脚本」，与杀戮尖塔本尊及本项目 StR 基底同构；
- 卡牌系统完全自建（内部名 Glyphs），**未用任何现成卡牌框架**；
- addons 全周边件：godotsteam（Steam 集成）／godot_resource_groups／godot-console；外加自写三编辑器插件（wutw_editor 内容量产／wutw_exporter 导出／wutw_i18n_export 本地化）＋`_dev_tools/` 造卡/事件/遭遇；
- 美术管线：零美术师——全用公有领域浮世绘木版画，`art_src/` 独立目录；
- 发布管线：bash＋python 导出脚本、steam_upload.sh、demo/playtest 独立 vdf、Steam Deck 输入配置。

## 五、真实制作流程（实证归纳五条）

1. **卡牌核心全部自建**——无一家用现成框架；卡牌系统（数据定义＋效果引擎＋交互）即游戏本体，框架帮不上核心；
2. **借件全是周边**：Steam 集成/调试台/资源分组等引擎不管的事；
3. **内容量产＝数据资源化＋自制编辑器工具**（WUTW wutw_editor 与 card-game-skeleton 殊途同归）；
4. **美术与文本分层**：美术贴图层＋程序渲染文本；整卡贴图不可取（改数值＝重出图）；
5. **发布自动化**：导出/上传脚本、EA 迭代为后期标配。

## 六、对本项目的启示与备件库

- **路线印证**：StR 规则引擎基底＋QiCardStyle 工厂＋数据表美术位＝与已发售作品同构，不返工。
- **备件库**（按阶段启用）：
  - 接 Steam 阶段：**godotsteam**（上架必用）＋导出脚本自动化（照 WUTW export/steam_upload 模式）；
  - 运行调试：**godot-console**；
  - 内容量产阶段（武器/词条/术法上量）：**card-game-skeleton 试装评估**（Dock 录入＋数据↔美术自动关联）或照其思路自制；
  - 手牌手感升级（悬停抬卡/重排）：**chun92 CFHand** 备选，动前须裁「引擎协议例外」；
  - 美术后期：Godot Card FX 等卡面光效资产（价/证未确证，用时再核）。
- **美术源启发**：公有领域素材路线零美术师可行（Kenney/Quaternius 优先站已在 AGENTS.md；浮世绘案的武侠对应＝公有领域木版年画/连环画，可作候选）。
- **流程教训**：写码前调研令覆盖**仓内已有件**——自建前先审手上装着的（chun92 案）；主流认知会过时（Shogun Showdown 误记案），断言先搜证。

## 出处

- db0 框架：github.com/db0/godot-card-game-framework ｜ Godot4 移植 Issue #178 ｜ asset-library #757
- chun92：github.com/chun92/card-framework ｜ asset-library #3616 ｜ zhihu.com/p/2069386955297645061
- card-game-skeleton：github.com/pudgypoultry/card-game-skeleton ｜ asset-library #4802
- Card3D：asset-library #3031 ｜ VFX：binbun3d.itch.io/godot-card-fx ｜ godotshaders.com/shader-tag/card
- STS2：pcgamer.com（弃 Unity 报道）｜ godotengine.org/showcase/slay-the-spire-2 ｜ r/godot「can be decompiled」｜ github.com/jiegec/STS2FirstMod ｜ github.com/ptrlrd/spire-codex ｜ github.com/elliotttate/sts2-modding-mcp
- WUTW：github.com/max99x/wutw-public ｜ r/godot 99% 好评帖 ｜ gamingonlinux.com（源码发布）｜ 80.lv（美术管线访谈）
- Sengodai：facebook.com/groups/godotengine（发售帖）
- 总目录：store.steampowered.com/curator/41324400（Is it made with Godot）
