# STS2 浮窗与弹窗调研（v0.1）

> 2026-10-27 立档。用户令：浮窗＋弹窗两交互整体照搬杀戮尖塔2——「他用 Godot 哪个功能我们就用哪个功能；他用什么美术我们就用什么美术」。
> 提取方式：pck 未加密，GDRE Tools v2.7.4 `--recover --include` 定向还原源格式＋`--list-files` 全表；C# 逻辑＝ilspycmd 反编译 `sts2.dll`（sts2-decompiled/，pck 内 .cs 皆为 1 字节空壳）。本机游戏＝CrossOver/Windows 版。
> 引擎基底：Godot 4.8.dev 定制版（我方 4.7.1，API 同族）。**仅内部开发参照；其美术/字体不得随产品分发。**

## 1. 浮窗（HoverTips）架构——读自 `NHoverTipSet.cs`（842 行）＋`NCreature.cs`

- **静态注册表**：`Dictionary<Control, NHoverTipSet> _activeHoverTips` 按**源控件**键控（与我方 QiTooltip `_by_host` 同构）；`CreateAndShow(hitbox, tips, alignment)`／`Remove(owner)`。
- **节点结构**：`hover_tip_set.tscn`＝纯 Control（mouse_filter IGNORE）挂两容器：**VFlowContainer 文字 tip 堆叠**（多条关键词 tip 竖排）＋`NHoverTipCardContainer`（整卡预览）。
- **定位/跟随**：文字容器摆在**源控件右侧 +10px**（`node.GlobalPosition + (Size.X+10, 0)×Scale`）；`SetFollowOwner()` 后 **_Process 每帧** `GlobalPosition = owner.GlobalPosition − _followOffset + _extraOffset`（锚源跟拍，非跟鼠标）；另有 `CorrectVerticalOverflow/CorrectHorizontalOverflow` 上下左右翻边。
- **显隐**：`MouseEntered/MouseExited` 直连——**无悬停延迟**；出牌中（`Hand.InCardPlay`）抑制；**战斗状态变化即重刷**（实时连锁同族）。
- **debuff 变体**：`hover_tip_debuff.tres` 材质另挂（红染）。

## 2. 单条 tip 视觉——`hover_tip.tscn`（逐节点抄录）

- 根：`MarginContainer`（mouse_filter=2；右/下负 margin −8 供影子出血）。
- **Shadow**：`NinePatchRect(hover_tip.png)` modulate 黑 25%、region 偏移 (−8,−8)——底影层。
- **Bg**：`NinePatchRect(hover_tip.png)` 320×96，**patch_margin 左55／上43／右91／下32**（不对称＝卡身带右侧尖尾），axis_stretch=1。
- TextContainer margins：**左22／上16／右45／下28**。
- Title：Label 22px，**金色 #EFC851**，黑影 (3,2) 25%；右侧 Icon 槽。
- Description：RichTextLabel 22px，**奶油 #FFF5E2**，黑影 (3,2)，**line_separation −2**，bbcode＋fit_content，最小宽 300。

## 3. 弹窗系统——读自 `NModalContainer.cs`（CommonUi）

- **不用 AcceptDialog/Window**：`Control 容器 + ColorRect Backstop`（压暗背板）。
- `Add(modal, show_backstop=true)`：弹窗作**普通子节点**加入；**单弹窗互斥**（已有弹窗直接拒绝新弹窗）。
- Backstop：**alpha 补间到 0.85（0.3 秒）**；期间容器 `MouseFilter=Stop` 全局吃输入；关闭＝补间归零后隐藏＋`Ignore`。
- `Clear()`：释放全部弹窗子节点（背板除外）。
- 面板皮肤：**通用对话九宫格 `dialogue_nine_patch.png`（114×82）＋事件对白尾巴 `dialogue_tail.png`（36×40）**；专用弹窗（药水等）各自 bespoke 整图。另有 `tiny_nine_patch.png`（48×48 小件）。

## 4. 引擎功能对应表（他用什么我们用什么）

| STS2 用法 | Godot 功能 | 我方对应 |
|---|---|---|
| 浮窗背景 | NinePatchRect（双层：影＋体） | QiTooltip 改双层 NinePatch |
| 多 tip 堆叠 | VFlowContainer | 新增 |
| 源控件跟拍 | _Process 每帧 GlobalPosition | 现有 janitor 同层扩展 |
| 文字 | RichTextLabel(bbcode, fit_content, 行距−2) | 换 RichTextLabel＋投影 |
| 弹窗 | Control＋ColorRect 背板补间＋MouseFilter 门 | QiDialog 弃 AcceptDialog 改制 |
| 显隐补间 | Tween（0.3s alpha） | Tween 同款 |

## 5. 照搬方案——**2026-10-27 已实施**（偏离清单附后）

1. 资产入仓：`hover_tip.png / dialogue_nine_patch.png / dialogue_tail.png / tiny_nine_patch.png` 拷入 `assets/sts2-ref/`（内部参照标记）。
2. **QiTooltip 重写**：hover_tip_set 制（按源键控＋VFlow 多行堆叠＋右侧+10 定位＋每帧跟拍＋翻边纠正）；皮肤＝双层 NinePatch（55/43/91/32）＋金标题/奶油正文（字号 22、行距 −2、投影 3,2）；**去悬停延迟**（SHOW_DELAY→0）；保留自愈巡检（我方补丁，STS2 没这坑因它不自毁宿主）；debuff 类状态 tip 走红染材质位。
3. **QiDialog 改制**：AcceptDialog→Control 模态容器（ColorRect 背板 0.85/0.3s 补间＋MouseFilter 门＋单弹窗互斥）；面板九宫格 dialogue_nine_patch＋按钮沿用现制；全部调用点（胜负面板/装备窗/购入确认/后备/情报）随改。
4. 字体例外：Kreon 系无 CJK——**美术照搬、字体按我方字体制留 Noto**（唯一偏离点，注记在案）。

## 6. 提取物位置

- 源码：`~/Documents/sts2-decompiled/`（ilspy 全量 C#）
- 资产：`~/Documents/sts2-rec/images/ui/`（png 源格式）＋`scenes/ui/hover_tip*.tscn`
- 文件全表：`/tmp/sts2_files.txt`（15668 条）


## 7. 实施记录（2026-10-27）

已照搬：浮窗（hover_tip.png 九宫格双层/55-43-91-32、右侧+10 每帧跟拍、无延迟、金题#EFC851 奶油文#FFF5E2 22px 行距−2 投影3,2、单浮窗制）；弹窗（弃 AcceptDialog → QiDialogBox Control 模态、dialogue_nine_patch 27/28/27/28、背板补间 0.85/0.3s、单弹窗互斥、内容挂 content()）。
偏离三处（均已在案）：①字体留我方字体制（Kreon 无 CJK）；②多关键词 tip 暂为单泡多行（STS2 为多泡竖排 VFlow）；③按钮沿用我方 QiPrimary/QiGhost（STS2 按键为各弹窗 bespoke 整图）。

## 8. 检视页（器灵详情）照搬（2026-10-27 第二批）

- **蓝本件**：`NInspectCardScreen`（全屏暗背板 0.9＋单卡 Spring 放大 2.0＋左右箭头换卡＋升级勾选）＋ `NHoverTipCardContainer`（衍生牌＝**真卡节点**竖排 4px、锚定主卡旁侧对齐；`card_hover_tip.tscn` 内置 `%Card` NCard，deck 视觉）。SwordSage 例：`ExtraHoverTips → HoverTipFactory.FromCardWithCardHoverTips<SovereignBlade>()` 即卡挂卡。
- **我方落地**（器灵详情页，QiPrepBay._open_detail）：主卡 270×345（面板＋被动，金色被动文字）＋右侧「功法 · 衍生牌」题注＋两张功法工厂术法卡 180×230 竖排（STS2 真卡制）；make_detail_layer 泛化为 Control＋可选尺寸（老单卡调用零改动）。
- 偏离注记：衍生牌未套 hover_tip 气泡皮（STS2 卡直接裸列，同制）；换卡箭头/升级勾选暂不需要（单器灵单详情）。
- 连带裁定：**点击/拖拽分家**——QiDragCard 增 `drag_armed`（起拖即置位，按压周期复位；NOTIFICATION_DRAG_BEGIN 为全树广播、force_drag 亦触发），详情页只在「释放且本周期未起拖」时开——拖卡换位/收后备不再误弹详情（probe_detail 双试断言）。
