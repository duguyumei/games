# 吸血鬼爬行者 手牌与战斗 HUD 拆解（v0.1）

> 2026-11-03 立档。对象＝《吸血鬼爬行者》(Vampire Crawlers: The Turbo Wildcard from Vampire Survivors, Poncle × Nosebleed)。
> 证据四路：①三张实机战斗截图（2546×1647，内容区 2546×1591＝1273×795 pt 的 2×，下称 px/pt）；②游戏 `GlobalConfig.json` 一手数值；③本地 `sharedassets*.assets` 里读出的 ScriptableObject 资产与 `global-metadata.dat` 字段名；④开源 mod 源码（真人按真实类名写的反射代码）。
>
> **边界**：本机没有可读的反编译 C#（IL2CPP，全盘无 `dump.cs`/DummyDll）；本文的"代码"只到类/字段/方法签名与配置值，不含方法体。截图外的一手数值均注出处，可复核。
>
> **2026-11-03 用户口述更正**：手牌悬停**有相让**（邻牌让位、手牌整体重排）。此前「配置无让位参数⇒不让位」的推断作废——让位量由 `CardFanConfig` 的椭圆/曲线决定，不在 GlobalConfig。

## 0. 一句话骨架

- **手牌**＝屏底居中的 **3D 椭圆扇**：逐卡旋转＋顶端拱起＋邻卡相让；悬停＝预览（×1.5／抬升 38／可打脉冲／不可打抖动），点击或拖拽出牌，显式排序（法力／颜色／类型＋长按换方式），0.5s 延迟重排。
- **战斗 HUD**＝顶部蓝条（Lv 在右）＋左舷图标列（遗物／队伍／血心）＋右舷图标列（属性／资源／蓝珠）＋中区敌阵与手牌。

---

## 1. 手牌位置与排列（三图实测）

| 项 | 实测（源图 px） | 折到 1920×1080 |
|---|---|---|
| 锚点 | 屏幕底部居中（手牌中心 x≈47–50%） | x≈960 |
| 手牌总宽（6 张） | ≈1330（≈52% 宽） | ≈1000 |
| 单卡（中段最正的一张） | ≈300×475（≈11.8%W×29.9%H） | ≈226×323 |
| 底边距 | 87（≈5.5% 高） | ≈59 |
| 相邻中心距 | ≈206–280（透视，右宽左窄） | ≈150–210 |
| 重叠 | ≈25–30% 卡宽 | — |
| 扇角（顶边投影） | 左端 ≈-18°、中段 ≈0°、右端 ≈+10~12° | 2D 近似可用 ±15° |
| 拱形 | 中段卡顶比两端高 45–95（≈3–6% 高） | 30–65 |
| Z 序 | 右压左；悬停卡置顶 | — |
| 悬停 | 单卡 ×1.5、上抬 ≈75–100、顶端到 ≈55% 高 | 卡 ≈340×540 |

**三条判断**：

1. **是扇形，不是直排**：顶边斜率逐卡差 5–7°。
2. **不是纯 2D 旋转**：端卡变窄、字被横向压缩（右端卡视觉比左端大约 1.3×）——3D 卡偏航＋透视。2D 复刻用旋转只能形似，要"端卡变窄"得走单应/透视。
3. **相让为真**（用户确认）：悬停卡放大时邻牌让位、手牌整体重排；三图里悬停最右卡→其余整体左移、悬停中段卡→两侧外移，即相让的投影。让位参数不在 GlobalConfig，见 §5 的 `CardFanConfig`。

---

## 2. 手牌交互

### 2.1 悬停（预览，不改顺序）

| 项 | 值 | 出处 |
|---|---|---|
| 放大 | ×1.5，0.05s（ease 10 进／27 出），移速 750 | `hoverCardConfig` |
| 抬升 | +38 | 同上 |
| 倾斜 | 跟手 0.7（速度 2）；静止自动 ±4° 摆动 | 同上 |
| 可打出 | 额外 ×1.2 脉冲（0.2s 曲线） | `hoveringPlayablePositionScale*` |
| 不可打出 | 只 ×1.05＋抬升 15＋抖动（幅度 5／0.3s／15 次） | `invalid*` |
| 阴影 | 悬停 (24,-24) | `hoveringShadowDistance` |

截图 6 张全部可付（法力 5，费 1/3/2/0/0/1），三张都是"可打出悬停"。

### 2.2 出牌

- 点击或拖拽同一入口：`PlayableCard.TryPlayCard`（mod 注释原话"鼠标/拖拽"）→ `PlayerModel.TryPlayCard(card, isAutoPlay)`；可付 `CanAffordCard`。
- 无目标制（单血池），点即结算。
- **打出全部**：按连击最优顺序自动打，间隔 0.1s 起、每张 ×0.97、下限 0.02s，按钮加速 ×3（`generalCardConfig`）。
- **结束回合**；无牌可打时 `AreAnyCardsInHandPlayable` 可触发自动结束（设置"自动结束回合"）。
- 出牌后 `playedCardDelay 1.2s`。

### 2.3 排序（显式操作，模型序即显示序）

- 面板"手牌排序"两键：**法力／颜色**（截图）；完整方式集合：无排序／法力／颜色／类型；法力可分升/降序（`SORT_HAND_*` 文案）。
- **点击＝立即排序；长按 0.3s＝改"排序方式"**（`cardSortConfig`；单键模式；设置项"单键切换卡牌排序"）。
- 默认不自动排序：截图顺序 1,3,2,0,0,1、颜色 青/红/蓝/紫/红/红——非法力序也非颜色序。
- 机制：排序＝交换 `CardPile._cards` 模型顺序，再 `HandPileView.SyncView()`/`RefreshCardsUI()` 重排（SortCardMod 复刻可证）。
- **重排延迟 0.5s**（`defaultCardReorderDelayTime`，设置项"卡牌重新排序延迟"）。

### 2.4 抽／弃／回手（三种动作三种空间语义）

| 动作 | 参数 |
|---|---|
| 抽牌 | 从 (-55,180,-90) 翻转 0.2s，抽后等 0.2s |
| 弃牌 | 转到 (55,180,90)、缩到 0.2、移速 250，0.2s |
| 回手 | 抛物线跳 500 高（0.25 升／0.05 顶停／0.4 落） |
| 卡移动 | 移速 500、减速 10 |

### 2.5 提示（关键词级，不是整卡）

- 三图证据：悬停大蒜画区**不出** tooltip；悬停"空白之书"的"冰冻"、"死东西"的"探索者"才出——光标压到关键词上才出。
- 位置：卡右侧跟随；可叠两框（关键词规则＋持续时间）；屏边距 200/500。

### 2.6 上限与抽牌

- `BaseHandSizeLimit=4`、`MaxHandSizeLimit=7`；每回合抽 3。截图 6 张＝基础 4＋商店 Handsize 两档。

---

## 3. 战斗 HUD 拆解（三图实测）

### 3.1 顶条

- 位置：视口顶部，x≈400–2050（15.7%–80.5% 宽），高≈130px；黑底圆角＋细金边。
- 内容：**蓝色填充条**（左对齐，约 1/3 满）＋右端 **"Lv 15"**。
- 条下（场景层）：敌数 **148**＋骷髅图标（居中偏右）；金币 **3267**＋金币图标（右端）。

### 3.2 左舷（x 0–330，约 13% 宽）

- 顶：4 个方形图标位（100%/40%/1/6）——遗物/属性，图标≈100×100、下挂数值。
- 次：1 个金色宝箱图标（3）。
- 中：4 个竖排头像卡（≈100×120，左侧小数字 2/1/2）——队伍成员。
- 底：血心（≈220×220，数字 84）＋齿轮/设置＋卡堆。

### 3.3 右舷（x 2100–2546，约 17.5% 宽）

- 顶：4 个方形图标位（130%/120%/120%/0%）——属性。
- 次：3 个（7/10/4）——资源。
- 底：蓝珠（直径≈240，数字 5，下方 +1/−1 增减）＋结束回合（≈200×110）＋手牌排序面板（≈240×300：标题＋法力/颜色两键）＋弃牌堆。

### 3.4 中区

- 敌方一排（6 只），每只头顶护甲数字；无目标框、无血条。
- 手牌压在场景下沿，与场景重叠。

### 3.5 语义存疑

- 顶条按用户口述记作**经验条**（Lv 在右）——但截图无法百分百区分"玩家经验"与"遭遇血池"（两者都可能蓝条+Lv）；若后续实机确认是遭遇池，本节改注即可（结构不变，只换语义）。

---

## 4. 配置数值表（GlobalConfig，一手）

### 4.1 手牌

| 项 | 值 |
|---|---|
| `handPileConfig.cardSpacing` | 14 |
| `handPileConfig.defaultCardReorderDelayTime` | 0.5 |
| `cardSortConfig.holdDurationToChangeSortMethod` | 0.3 |
| 手牌上限（runModeConfig） | Base 4 / Max 7 |

### 4.2 悬停

（见 §2.1；另 `moveSpeed 750`、`decelerateDistance 0.5`、`scaleUpEase 10`、`scaleDownEase 27`、`tiltSpeed 2`、`autoTiltSpeed 1`。）

### 4.3 拖拽

`dragDetectionThreshold 125`、`holdDurationForDrag 0.3`、`longer 0.6`、`dragHeightOffset 10`、`dragXDispositionFromCurrentHover 15`、`draggedFollowSpeed 30`、`draggedRotationSpeed 30`、`draggedRotationAmountDegrees 3.5`；辅助设置"延长拖拽识别时间"。

### 4.4 抽弃/移动/连击堆

（见 §2.4；连击堆：举起 ×2/0.5s、砸下 0.1s ease 26、粒子 10→100000 每层 +100、震屏 0.1/30Hz/0.1s、火焰开关。）

### 4.5 通用

`playedCardDelay 1.2`、`baseAutoPlayDelay 0.1`、`minimumAutoPlayDelay 0.02`、`autoPlayDelayDecreaseMultiplier 0.97`、`autoPlayButtonSpeedup 3`、`tooltipScreenBoundSettings 200/500`。

---

## 5. 代码／资产对应

| 规则 | 出处 |
|---|---|
| 手牌模型序 | `PlayerModel.HandPile.CardPile._cards`（`CardPileModel`），`TryPeekIndex`／`TrySwapCards` |
| 手牌视图 | `HandPileView.SyncView()`／`RefreshCardsUI()`／`DEBUG_UpdateCardsInHand()`；`PileRoot` 下 `CardView`；`CardGroup._activeCardSlots` |
| 出牌 | `PlayableCard.TryPlayCard`／`OnCardPlayRequested`；`PlayerModel.TryPlayCard`／`CanAffordCard`／`AreAnyCardsInHandPlayable`／`IsCardInCombo` |
| 卡面 | `CardView._costText`／`_appliedCardConfig`／`CardHighlight` |
| **扇形配置** | `sharedassets3.assets` 的 `HandPileFanConfig`（类应为 `CardFanConfig`）；字段 `_elipseRadiusX/_elipseRadiusZ`、`_arcHeightMultiplier`、`FanCardPosition`/`FanCardRotation`、`s_minCardsToFan`、`_closedAngle`/`_currentCircleAngle`；同类还有 ComboPile/Throwing/ChooseCard/Candidate/SelectedPile 各自的 FanConfig |
| 排序设置 | `sharedassets0.assets` 的 `Int_HandSortMode`（值 0）、`Bool_IsSingleSortButtonMode`（值 0） |
| 本地化 | `SORT_HAND_MAIN_LABEL`＝手牌排序、`SORT_HAND_MANA`＝法力、`SORT_HAND_COLOR`＝颜色、`SORT_HAND_UNSORTED`＝无排序、`SORT_HAND_TYPE`＝类型、`SORT_SETTING_HINT`＝点击排序/长按改方式、`CARD_REORDER_DELAY`＝卡牌重新排序延迟 |

---

## 6. 与我方战斗屏（QiVcScreen＋QiVcCabinet）的差距

| 区 | 参考 | 我方现状 | 差距 |
|---|---|---|---|
| 顶条 | 粗蓝条＋右端 Lv | 琥珀细经验条＋"N 阶"＋层数徽 | 配色/高度/Lv 位置 |
| 左舷 | 图标位列（遗物/队伍/血心） | 只有血心＋抽牌堆 | 缺图标列 |
| 右舷 | 属性/资源/蓝珠（数字+增减）/结束回合/排序 | 只有气珠（写"气"字）＋弃牌堆 | 缺图标列、蓝珠无数字、结束回合在中区 |
| 状态 | 图标位＋数值 | 中区一行文字（气/护甲/三式/连击） | 未图标化、位置不对 |
| 中区 | 敌阵＋手牌 | 血池行＋事件行＋敌阵＋状态行＋手牌 | 血池/状态行的位置语义不同 |

---

## 7. 未定／待核

1. **相让的具体量**：截图跨局/跨机位，无法逐帧定量；需同一局录屏（鼠标横扫）才能测出让位曲线与锚点。
2. **HandPileFanConfig 精确值**：字段名已定位，数值需 typetree/字段布局（AssetRipper 或 Il2CppDumper 路线）才能解。
3. **顶条语义**：经验 vs 遭遇池（用户口述经验条，按口述记）。

---

## 8. 出处

- 截图：用户 2026-11-03 实机（三张，23:24/23:25/23:27）。
- 数据：`GlobalConfig.json`／`CardDatabase.json`／`PlayerConfig.json`／`Translations`（[VampireCrawlersFiles](https://github.com/SurvivatonsAndMore/VampireCrawlersFiles)，1.5.x）。
- 代码结构：[BetterCards](https://github.com/TovaK66/BetterCards)、[SortCardMod](https://github.com/ZTMYO/VampireCrawlersMods)、[Advisor](https://github.com/SoloWaltz/vampire-crawlers-advisor)。
- 本地资产：`…/Vampire Crawlers.app/Contents/Resources/Data/sharedassets0.assets`、`sharedassets3.assets`、`il2cpp_data/Metadata/global-metadata.dat`。
