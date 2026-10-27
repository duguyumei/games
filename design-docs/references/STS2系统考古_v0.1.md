# STS2 系统考古（v0.1）

> 2026-10-27 立档。服务「STS2 优先参照立约」（通用系统先参照《杀戮尖塔2》→《尸姬之梦》→自研 ≤1%）的首轮系统级考古。源＝`~/Documents/sts2-decompiled`（Godot 4.5.1 .NET 反编译，**仅 C#**——.tscn 场景与本地化资源不在包内，涉及场景锚点数值处已注明不可见）；尸姬＝`~/Documents/shiji-decompiled`。全部断言经双重核实（检索代理初查＋主会话亲读关键文件复核），出处逐条 file:line。浮窗／弹窗两项已于《STS2浮窗与弹窗调研》落档，本轮不重做；本文覆盖其余点名项：反震／反击管线＋UI 五件（详情展示／升级预览／购买按钮／卡牌比例／打出动画）。

## 0. 结论总览

| 考古项 | STS2 | 尸姬 | 我方现状 | 差距要点 |
|---|---|---|---|---|
| 反震 | ✅ Thorns：**受伤前**内联递归、固定值、可格挡、属性防环 | ✅ 雷反：受伤后延迟队列、可连锁、父链查重 | 规则 v0.7§77 已立（按比例·间接·落地后延迟队列） | 防环原理已同构（间接≠攻击）；时机/口径不同（见 §1） |
| 反击 | ❌ **全库缺席**（穷尽检索，见 §2） | ✅ BeHitAft→TreeAction→AtkTarget(CanHitBack) | 规则 v0.7§78 已立（每回合上限 N 次）；**引擎暂无实现**（无内容用到） | 参照系＝尸姬；上限制为我方自加数值闸 |
| 详细信息展示 | ✅ NInspectCardScreen：单卡 2.0×＋勾选框切升级态＋左右翻页 | — | 详情卡 270×345 工厂件（点击开，drag_armed 分家） | 无升级态切换、无翻页浏览（§3） |
| 升级效果查看 | ✅ NUpgradePreview：**原卡→升级卡并列双真卡**＋绿字 diff | — | 纯方向按钮文字页（无真卡对照） | **主要差距**：STS2 全用真卡对照（§4） |
| 购买按钮 | ✅ NMerchantSlot：无 SOLD 遮罩（买断槽消失）、半价绿签、买不起红签＋摇摆 | — | 紫边框操作商品＋确认弹窗；买不起＝flash 提示 | 缺红价签实时态/摇摆反馈；我方买断后 restock 与 STS2 相反（§5） |
| 卡牌展示比例 | ✅ 唯一基准 300×422＋场合缩放系数表 | 敌 130×238／我 202×232（实测档） | 三尺寸工厂制（用户裁定，禁缩放） | **两制互斥**：STS2＝一基准＋缩放；对齐＝改约，须裁定（§6） |
| 待打出/待生效动画 | ✅ NCardPlayQueue 队列→PlayContainer 停驻→NCardFlyVfx 抛物线离场 | — | 自研：功法飞行缩放 0.26s／普攻三段突进 | 无「待打出队列」形态；卡不落打出区（§7） |

---

## 1. 反震（Thorns）管线

### 规格（出处逐条）

- **力本体**：`Models.Powers/ThornsPower.cs:11-24`——Buff 型、`StackType=Counter`（数值层数）。触发条件：`target==Owner && dealer!=null && (props.IsPoweredAttack() || cardSource is Omnislice)`。
- **触发时机**：**受伤前**。伤害主管线 `Commands/CreatureCmd.cs:240-270` 顺序＝`Hook.ModifyDamage`（数值修正）→ **`Hook.BeforeDamageReceived`（←反震在此，`CreatureCmd.cs:262`）** → `DamageBlockInternal`（格挡）→ `ModifyHpLost` → `LoseHpInternal`（扣血）。反震伤害**先于原伤害完整结算**（含它自己的死亡处理）。
- **触发方式**：钩子内**内联 `await` 递归**同一条 `CreatureCmd.Damage`（`ThornsPower.cs:22`），非入队延迟。`Hook.cs:403-412`＝按监听器顺序逐个 await 的同步循环。全库唯一重写此钩子的 Power 就是 Thorns（复核：grep `BeforeDamageReceived` 全库仅 CreatureCmd/ThornsPower/Hook/AbstractModel 四处）。
- **伤害口径**：固定 `Amount` 点（与来袭伤害无关、不吃力量/虚弱），`ValueProp.Unpowered | SkipHurtAnim`——**可格挡**（不含 `Unblockable`；官方注释 `ValueProps/DamageProps.cs:27-31`：Unpowered＝「力造成的、但仍可被格挡的伤害，如 Thorns」）。被打者不播受击动画（SkipHurtAnim）。
- **防环**：靠**伤害属性语义单向衰减**——反震伤带 `Unpowered` 且无 `Move` 位 → `IsPoweredAttack()=false`（`ValuePropExtensions.cs:5-12`）→ 不再触发对方的受击触发类 Power。**不是显式重入锁，天然不可连锁**。
- **格挡前触发 ⇒ 被完全格挡也反震**；`AbstractModel.cs:573-574` 官方注释：即使实际伤害为 0 钩子仍调用。
- **可致死**：嵌套 Damage 同走 `CreatureCmd.cs:371-408` 击杀回收（`Kill` 于 `:408`；注释 `:413-417`「对方全侧视为击杀者」）。原伤害不因攻击者死于反震而取消（`dealer.IsDead` 只在进入管线时查一次，`:242-245`）。
- **UI**：Power 图标走通用 `NPower`/`NPowerContainer`（`Nodes.Combat/NCreatureStateDisplay.cs:166`），触发＝`Flash()`→图标粒子（`NPower.cs:248-256`）；伤害数字/火花走标准管线（`CreatureCmd.cs:306-321`）。**无反震专属 vfx**。
- **同族受击触发 Power**（`AfterDamageReceived`＝落地后触发，与 Thorns 的 Before 相反）：FlameBarrier（被攻击后反固定值）、Reflect（反弹**被格挡值**）、PainfulStabs/PersonalHive（塞诅咒牌）、CurlUp（受击获格挡）等 22 Power＋6 遗物。

### 管线还原图

```
攻击方 ──Damage(dealer→target, props=Move)──► │ Hook.ModifyDamage        数值修正
                                              │ Hook.BeforeDamageReceived ◄─ Thorns:
                                              │                            Flash + Damage(dealer←target,
                                              │                              Unpowered|SkipHurtAnim)
                                              │                            └─ 递归走同一条管线：
                                              │                               格挡→扣血→可致死
                                              │                               (Unpowered ⇒ 不再触发
                                              │                                任何 IsPoweredAttack 钩子 ⇒ 防环)
                                              │ DamageBlockInternal      原伤害格挡
                                              │ LoseHpInternal           原伤害扣血
                                              │ AfterDamageGiven/Received 落地后钩子(FlameBarrier 族)
                                              └ Kill(击杀列表)
```

### 与我方对照（基础规则 v0.7 §77：反震＝受伤时按比例对来源**间接伤害**）

| 轴 | STS2 | 我方 v0.7 | 备注 |
|---|---|---|---|
| 触发时机 | 受伤**前**（格挡前） | 受伤**后**（延迟队列，落地后置位） | 尸姬雷反同为落地后 |
| 数值口径 | 固定层数值，可格挡 | 按比例，间接（穿盾穿挡、不可增减） | 我方口径＝用户裁定，间接伤已定档 |
| 防环 | 属性语义衰减（Unpowered 不可再触发） | 间接伤害**按定义不触发反震/反击**（v0.7 §79） | **原理已同构**✅ |
| 连锁 | 不可能 | 不可能（间接定义封死） | 一致 |
| 递归方式 | 内联 await 递归 | 延迟队列（尸姬制） | 我方队列制与尸姬一致 |

**结论**：我方反震的防环原理与 STS2 同构（伤害类型语义单向衰减），数值口径（比例/间接）与时机（落地后）是我方+尸姬血统，均有出处，无需改。可选采纳点仅一条：STS2 的「**被完全格挡也反震**」（钩子在格挡前）——我方按「受伤时」措辞理解为已受伤害才反，若用户想要「格挡也触发」需改措辞。〔暂不改，待点〕

---

## 2. 反击（受击后打出攻击动作）

### STS2 缺席断言（已穷尽两条链）

- **逻辑链**：`Models.Powers/`（260 文件全列）、`Models.Relics/`、`Models.Cards/`、`Models.Monsters/`、`Entities.Intents/`、`Entities.Creatures/`、`Entities.Actions/`、`GameActions*/`、`MonsterMoves*/`、`Hooks/`、`Commands/` 全域，关键词（大小写不敏感）：`Counter / Retaliate / Riposte / Revenge / Vengeance / Punish / Backlash / Reprisal / AttackBack / OnAttacked / AfterAttacked / counterattack / counter strike / retort / avenge / retribution / payback`——**全部命中为噪声**（`PowerStackType.Counter` 枚举名、RNG 计数器、`EncounterInfo`/`Scavenge` 子串）。主会话复核 `retaliate|riposte|counterattack|counter-attack` 零命中。
- **意图链**：`MonsterMoves.Intents/` 意图类型全集＝Attack(Single/Multi)/Buff/Debuff/Defend/DeathBlow/Escape/Heal/Sleep/Status/Stun/Summon/Unknown/Hidden——无「反击」意图；怪物行为纯回合制意图驱动，管线无受击插队攻击路径。
- **钩子面穷尽**：受击方可响应的钩子仅 `BeforeDamageReceived`（仅 Thorns 重写）/`AfterDamageReceived(Late)`（22 Power+6 遗物，全部是数值伤害或塞牌/自增益）/`AfterBlockBroken`。`Models.Powers/` 内引用 `AttackCommand` 的 8 个文件全部是监听**自己发动的**攻击，无一构造新攻击。
- **结论**：STS2 所有报复性反馈都是「数值伤害/塞牌」，不存在「受击后执行一次攻击动作」。**反击的参照系落尸姬**（立约的第二顺位），符合预期。

### 尸姬制规格（fallback 实读）

- **受击侧管线**：`RetrainerBase.cs:710 BeAtk()`＝伤害修正（:719）→ 防御/护盾/扣血（:721-757）→ 死亡触发（:776）→ **:786 `TriggerManager.BeHitAft_Event_Emit(…, From, this)`**。
- **分发**：`TriggerManager.cs:252-295`——逐效果 `AddNewNode` 后调 `BeHitAftTargetTriggerEvent`，再广播 `OtherBeHitAftTargetTriggerEvent` 给卡/双方英雄/全体单位；眩晕屏蔽由 `GetIfStunBlock` 决定。
- **反击样例（雷反）**：`IE_301.cs:5-45`＝受击后取 `RDemage×BuffCount×(1+加成)` 压入 `IETAction_301`；`IETAction_301.cs:43-46 EffectOn()`＝对近敌 `AtkTarget(…, CanHitBack: true)`——**受击后真实打出一次攻击，且该攻击可再被反（允许连锁）**。另有回合末延迟反击变体 `IE_3021`（记 HitFrom，回合末打回）。
- **防环**：`TriggerNode.cs:24-34 AddNewNode` 沿父链查 `NodeId`（instanceID+Name+Id+TriggerTag 组成），**同链同效果只响一次**（非次数上限，与连锁自由兼容）。
- **规模**：实现 `BeHitAftTargetTriggerEvent` 的道具效果共 91 个。

### 与我方对照

我方规则（v0.7 §78：反击＝受伤时对敌方一次普攻反击，反击 N＝**一回合最多 N 次**）——「延迟队列＋防环查重」已随雷反实装（`QiBattle.gd:312-318` 血统键去重、`:553-554` 延迟反射），与尸姬同构；「每回合上限 N」为我方自加数值闸（STS2/尸姬均无此轴，属允许的自研数值层）。**引擎侧反击本体暂未实装**（当前无内容用到，无欠账）。尸姬给的可选补充件：回合末延迟反击变体（IE_3021 形态）、`CanHitBack` 式「允许连锁」开关——我方当前按间接封死连锁，口径以用户裁定为准，暂不动。

---

## 3. 详细信息展示（检视页 NInspectCardScreen）

### 规格

- **本体**：`Nodes.Screens/NInspectCardScreen.cs:32`（Control；场景 `scenes/screens/inspect_card_screen`）。**单张大卡＋左右翻页＋升级勾选框**——不是并列对照页。
- **尺寸**：卡基准 300×422（`Nodes.Cards/NCard.cs:497 defaultSize`），检视打开 1.75×→**补间至 2.0×**（`NInspectCardScreen.cs:256,276`，0.15s Spring.Out）＝**600×844**。
- **节点树**（`_Ready :220-247`）：`Backstop`(全屏点击关闭)＋`Card`(NCard 本体)＋`LeftArrow/RightArrow`(±100px Back 弹入)＋`HoverTipRect`(关键词浮窗对齐区)＋`%Upgrade`(「查看升级」勾选框＋VIEW_UPGRADES 文案)。开屏动画：backstop 淡入 alpha 0.9/0.25s；关闭＝cancel/pauseAndBack 热键或点 Backstop。
- **升级态呈现＝同一张卡勾选切换**（`UpdateCardDisplay :352-377`）：勾选→克隆→`UpgradePreviewType=Deck`→`UpgradeInternal()`→`ShowUpgradePreview()`；未勾→已升级卡 `CardCmd.Downgrade` 还原显示基础版。勾选框仅在 `MaxUpgradeLevel>0` 显示（:386）；卡已升级或网格传入 `viewAllUpgraded` 时自动置勾（:388-395）。
- **入口＝10 处共享单例**（`NGame.GetInspectCardScreen()` 懒加载，`Nodes/NGame.cs:890-896`）：卡组视图/卡牌图鉴/卡牌奖励三选一/选卡屏/捆绑选择/商店货架/历史回放/多人查看等。**输入分家**：左键＝选择，**右键/accept＝开检视**（`NCardHolder.cs:315-331`：左键发 `Pressed`，其余发 `AltPressed`）。
- 战斗内抽/弃/消耗堆查看屏（NCardPileScreen）C# 层无检视接线（场景内连接无法排除，如实注记）。

```
右键卡 ─► Open(全部可见卡, index, viewAllUpgraded) ─► SetCard
            ├─ 箭头翻页（Left/Right, 卡从±100px 滑入 0.25s Expo）
            ├─ %Upgrade 勾选框：off=基础版 / on=升级克隆(绿diff)
            └─ 关键词浮窗对齐 HoverTipRect
```

### 与我方对照

我方＝详情卡 270×345 工厂放大件（`QiCardStyle.make_detail_layer`，点击开、drag_armed 分家）——「点击看大卡」骨架同向。差距：①无「查看升级」切换（我方升级是方向二选一，检视页可做成**方向 A/B 双勾选或双按钮切换**显示对应升级态）；②无左右翻页（奖励页/卡组查看时可加）。**注意**：我方三尺寸制禁缩放，2.0× 直接缩卡与工厂制冲突——若做翻页检视，形态应是「依次显示同档详情卡」而非整体放大（对齐建议 A3，§8）。

---

## 4. 升级效果查看（决定升级前）

### 规格

- **篝火锻造链**：`SmithRestSiteOption.cs:49-74`（无可升级卡则选项禁用）→ `CardSelectCmd.FromDeckForUpgrade`（`Commands/CardSelectCmd.cs:434-472`，筛 `IsUpgradable`，弹 `NDeckUpgradeSelectScreen`）→ 选中即出确认区。**事件/遗物升级全部复用同一屏**（AromaOfChaos/SapphireSeed/Trial/SpiritGrafter/YummyCookie/Pomander——grep 全量核实）。
- **核心控件 NUpgradePreview＝原卡→升级卡并列双真卡**（`Nodes.Cards/NUpgradePreview.cs:15-20` 注释「Rest Site、Armaments 等用」；节点 `%Before/%After/Arrows`，`Reload :118-141`）：
  - Before＝原卡 Normal 渲染；
  - After＝`CloneCard → UpgradeInternal() → UpgradePreviewType(局外=Deck/战斗内=Combat) → ShowUpgradePreview()`＋带浮窗；
  - 战斗内用 `Combat` 预览类型＝动态数值（力量等）也参与预览计算（`CardModel.cs:798-801`）——Armaments 手牌版嵌在 `NPlayerHand %UpgradePreviewContainer`。
- **绿字 diff 系统**：升级预览描述经 `ShowIfUpgradedFormatter` 把改动段包 `[green]`（`Localization.Formatters/ShowIfUpgradedFormatter.cs:46-49`）；数字变化 `{diff}` → 变大绿/变小红（`StsTextUtilities.HighlightChangeText`）。**卡名升级后变绿＋后缀「+」**（`NCard.cs:1296-1311`：cream→`StsColors.green`＋特殊描边；`CardModel.Title` 单级「名+」多级「名+N」）。无独立角标——升级态全靠绿名+绿字表达。
- **网格批量切换**：卡牌库/卡组视图/升级选择屏均有 `%Upgrades`「VIEW_UPGRADES」勾选框，整网格切升级态（`NCardGrid.cs:511-531`→`NGridCardHolder.SetIsPreviewingUpgrade :231-255`，Holder 持 base/upgraded 双克隆换 Model）；搜索框也按升级后文本匹配（`NCardLibrary.cs:988-994`）。

```
篝火 SMITH ─► NDeckUpgradeSelectScreen(网格列出可升级卡)
                ├─ 点卡 ─► 确认区 NUpgradePreview：
                │     [ %Before 原卡 ] ──箭头── [ %After 升级克隆(绿diff) ]  Cancel/Confirm
                ├─ 右键 ─► NInspectCardScreen 大图检视
                └─ %Upgrades 勾选框 ─► 整网格切升级态
```

### 与我方对照（主要差距项）

我方升级选择＝纯方向按钮文字页（奖励页 `_reward_apply` 方向页/商店 `_pick_op_dir`），**无真卡对照**。STS2 全链铁律＝「升级预览一律真卡并列（Before→After），差异用颜色标注，绝不纯文字复述」。对齐建议 A4：方向二选一场景改为**原卡＋两张升级方向卡三卡并列**（或原卡+方向切换式双卡），全部走 QiCardStyle 工厂件；升级差异高亮（绿字）可后置。〔待批〕

---

## 5. 购买按钮（商店槽 NMerchantSlot）

### 规格

- **结构**：抽象基类 `Nodes.Screens.Shops/NMerchantSlot.cs:24`（`%Hitbox` 点击区＋`%CostLabel` 价签），四子类 Card/Relic/Potion/CardRemoval；卡槽另持 `%CardHolder`＋`%SaleVisual`（`NMerchantCard.cs:111-124`）。**卡牌预览即真卡**（NCard 塞入），右键开检视页。
- **买断表现**：**无 SOLD OUT 遮罩**——全库 grep `SoldOut|SOLD` 零命中；买断后整槽 `Visible=false` 消失（`NMerchantCard.cs:138-143`）。唯一例外＝Courier 遗物补货（`MerchantEntry.cs:84-91`：`IsOnSale=false; Populate()` 换新卡，槽不消失）。
- **价格链**：`MerchantCardEntry.cs:38-51,118-129`——基础价 50/75/150（按稀有度）×无色 1.15×`Shops` 专用 RNG ±5% 取整；`IsOnSale` 时 `_cost/=2`（整数半价）。读取时再过 `Hook.ModifyMerchantPrice`（遗物加/减价层，`MerchantEntry.cs:19-32`）。删卡 75+25/次（`MerchantCardRemovalEntry.cs:20-33`，已另档）。
- **折扣唯一来源**：`MerchantInventory.cs:100-111`——5 张本角色卡随机 1 张 `SetOnSale()`；无色卡不打折。全库无 Markup/PriceMultiplier 命名物。
- **买不起＝价签实时变红，按钮永不禁用**：`NMerchantCard.cs:156-165` `EnoughGold ? cream : red`（半价绿）；`Initialize` 订阅 `Player.GoldChanged += UpdateVisual`（`NMerchantSlot.cs:253-259`）——金币一变全体槽即时重着色。点击仍触发→`OnPurchaseFailed`（`NMerchantSlot.cs:391-412`）：正弦摇摆 ±10px、0.4s Quad.Out（`WiggleAnimation :422-436`）＋失望音效。
- **hover**：槽 0.65→hover **瞬跳** 0.8，回落 0.5s Expo.Out（`:197-199,328-345`）；hover 时商人的手指向该槽（`MerchantHand.PointAtTarget`）。
- **购买时序**：左键→`OnSelected → await OnTryPurchaseWrapper`（校验库存/金币）→`await CardPileCmd.Add(Deck)`→`await LoseGold`→事件回调：商人手指槽＋`NCardFlyVfx` 飞卡向顶栏卡组（发后不管）→`UpdateVisual` 槽消失。

```
金币变动 ──► GoldChanged ──► 全槽 UpdateVisual：价签 = 不足红 / 半价绿 / 常规米
点击 ──► 校验(即时) ──► await 加卡 ──► await 扣钱 ──► 手指+飞卡(不等待) ──► 槽消失
失败 ──► OnPurchaseFailed：±10px 正弦摇摆 0.4s + 失望音效（按钮不变灰、不锁）
```

### 与我方对照

我方商店＝紫边框操作商品＋确认弹窗，买不起 `_flash("铜钱不足")`（`QiPrepBay.gd:861`）。可采纳：①**价签三色实时态**（红/绿/常规＋金币变动即刷）替代 flash 提示；②买不起点击的**摇摆反馈**（0.4s ±10px）；③买断后槽消失 vs 我方 restock 换新——这是我方既定设计（操作位持续供给），**保留我方制**，不算差距。〔①②待批，见 A5〕

---

## 6. 卡牌展示比例（尺寸体系）

### 规格

- **唯一基准**：`NCard.defaultSize = (300, 422)`（`NCard.cs:497`；场景 `scenes/cards/card.tscn`）。**全游戏所有场合都是这张卡 × 缩放系数**，无第二实物尺寸：

| 场合 | 缩放 | 实际 px | 出处 |
|---|---|---|---|
| 手牌 ≤7 张 | 0.8 | 240×338 | `Helpers/HandPosHelper.cs:113` |
| 手牌 8/9/10/11/12 张 | 0.8×0.95/0.90/0.85/0.80/0.75 | 228→180 宽 | `HandPosHelper.cs:160-171` |
| 拖拽/选目标中 | 0.75 | 225×316 | `Nodes.Combat/NCardPlay.cs:298-303` |
| 打出区（PlayContainer） | 0.8 | 240×338 | `Commands/CardPileCmd.cs:762-765` |
| 弃/抽堆查看、图鉴网格 | 0.8 | 240×338 | `NGridCardHolder.cs:164`、`NCardGrid.cs:629` |
| 奖励三选一 | 0.8（间距 350px） | 240×338 | `NCardRewardSelectionScreen.cs:269,284-291` |
| 商店货架 | 0.65（hover 0.8） | 195×274 | `NMerchantSlot.cs:197-199` |
| 检视页 | 1.75→2.0 | 525→600×844 | `NInspectCardScreen.cs:256,276` |
| 通用预览容器 | 任意 SetCardScale，hover×1.1 | — | `NPreviewCardHolder.cs:112,190-194` |

- **hover 规范**（`NCardHolder.cs:212,230-232,448-466`）：**放大＝瞬跳**（`Scale=HoverScale` 立即生效），**回落＝0.5s Expo.Out 补间**。手牌特例＝逐帧 lerp（速度 8/帧，阈值吸附）。
- **手牌排版**＝查表制：1–10 张的 X/Y 坐标表＋角度表（±3°~±15°，`HandPosHelper.cs:10-111`）；聚焦卡放大归零角、邻卡被推开最多 100px（`NPlayerHand.cs:805-860`）。
- **卡面内部锚点**在 card.tscn 场景资源里，反编译包无 .tscn——**不可见**（如实注记；C# 侧仅见类型牌匾两常量：边距 17f/最小宽 61f，`NCard.cs:487-489`）。

### 与我方对照（两制互斥，须裁定）

我方＝**三尺寸工厂制**（战场单位 180×230／战场手牌 216×280／备战 235×300，用户裁定：除三档外**不得另立宽高、不得缩放**）。STS2＝**一基准＋场合缩放**。二者架构互斥：照搬 STS2 缩放系＝违反工厂制现行约。可分离采纳（不动三档实物）的只有**行为规范**：①hover 瞬跳放大/补间回落；②手牌超量递减系数（若手牌上限 7 被效果推高）；③奖励/网格场合的间距定标（350px 间距＝0.8 卡宽的 ~1.46 倍）。〔是否采纳待批，见 A6〕

---

## 7. 待打出／打出后待生效动画

### 规格（打出一张卡的完整时序）

- **松手→不飞向目标，入「待打出」队列**：`Nodes.Combat/NCardPlayQueue.cs:122-148 OnLocalCardPlayed`——卡从手牌 reparent 进队列容器、置顶排列；入队补间 0.35s Cubic.Out（`:439-447`）；**队列缩放＝`0.8×(1−i/(i+1))`**（第1张 0.4、第2张 0.53…递增逼近 0.8，`:449-454`）；**队列位置＝打出区目标点向左 `300×i/(i+2)`** 渐次排开（`:456-461`），正向无旋转。注释明示三分法（`:392-396`）：拖拽中的卡在手牌容器；**执行中的卡在 PlayContainer；队列只放已入队未执行的卡**。
- **动作轮到才执行**：`GameActions/PlayCardAction.cs`（队列驱动）→ `CardModel.SpendResources()` **即时扣能量**（能量球零时变红减速，`NEnergyCounter.cs:217-251`）→ 卡移入 PlayContainer：`CardPileCmd.cs:646-683 AddDuringManualCardPlay`（注释：**不为手感等待补间**，仅能力卡 Power 例外 await）——落点＝`PileType.Play`＝**打出区中心上浮 100px、缩放补间至 0.8**（`PileTypeExtensions.cs:57`＋`CardPileCmd.cs:749-776`，0.25s Cubic.Out；快速模式 0.1s/即时 0.01s）。
- **停驻待生效**：卡停在打出区**直到效果全部结算完**＋最少停留 0.15~0.3s（`CardModel.cs:1971-1975 CustomScaledWait`）才按去向离场（弃牌堆/消耗/移除）。**多段/重播**：第 2 次起 `AnimMultiCardPlay`（`NCard.cs:1429-1452`）＝闪黑 0.2s→从 0.5 倍/下方 250px Back.Out 弹回 0.25s——「同一张卡再次生效」有明确视觉重音。
- **离场＝NCardFlyVfx 抛物线甩飞**（`Nodes.Vfx/NCardFlyVfx.cs`——注意在 Vfx 根目录，非 Vfx.Cards）：起点卡位、终点目标堆按钮中心（`PileTypeExtensions.cs:54-59`）；参数每帧混沌随机：时长 1~1.75s、速度 1.1~1.25＋加速度 2~2.5（**加速离场**，非 Tween）、控制点偏移 100~400、弧向背离心屏中心；二次贝塞尔，**卡身朝向速度方向**（LerpAngle 12/帧），行程前 1/3 白→黑、缩放 1→0.1，到达后再缩到 0，拖尾 25% 处淡出（`:165-287`）。消耗分支＝灰化 0.2~0.3s＋NExhaustVfx（`CardPileCmd.cs:558-577`）。

```
[松手]        [入队 0.35s Cubic.Out]     [轮到执行·即时]        [结算中·停驻]                [结算完]
鼠标弹起 ──► NCardPlayQueue 排位     ──► 扣能量(即时·能量球变色) ──► PlayContainer 0.8×     ──► NCardFlyVfx 抛物线
              位置: Play点左300·i/(i+2)    移入打出区 0.25s          停在打出区中心+上浮100px     1~1.75s 加速甩向弃牌堆
              缩放: 0.8·(1−i/(i+1))                                  ≥0.15~0.3s；多段重播=       白→黑 1→0.1→0
              正向无旋转                                              闪黑0.2s+0.5×弹回(Back.Out)  朝速度方向; 消耗=灰化
```

### 与我方对照

我方＝自研两式（立约前写的）：功法卡飞行施放（0.26s 缩 0.42＋淡出→到位瞬间结算，`QiBattleScreen.gd:631-639`）＋普攻三段突进（0.13/0.15/0.30 后撤-突进-回位，`:606-626`）。STS2 制的关键结构差：①**卡不飞向目标**——落点永远是打出区，效果与飞行解耦；②**入队有「待打出」排面**（连打多张时渐次排列，视觉上预告执行顺序）；③**多段效果有重播重音**（同卡闪烁弹回）；④离场是带旋转的加速抛物线（有「甩出去」体感）。对齐建议 A7：打出动画整体重做向 STS2 制靠——功法＝飞入打出区停驻→结算（多段闪烁）→抛物线入弃牌堆；普攻突进可保留为「攻击者身体动作」（STS2 怪物攻击也有身体前扑），但**卡本体不再当飞行物**。〔待批，工作量最大项〕

---

## 8. 对齐建议汇总（2026-10-27 用户已裁定并实装一轮）

| 号 | 建议 | 裁定与落地 |
|---|---|---|
| A1 | 反震维持现状 | **改裁＝即时插入**：雷反/插件反震全部改原地结算（不排延迟队列）；「格挡也触发」未采（我方＝落地后存活才反） |
| A2 | 反击引擎延后 | **已实装**：fanji 状态入状态表＋引擎即时反击（不耗攻次、每回合上限＝层数、血统键防环）；内容待首个使用者 |
| A3 | 检视页升级切换 | 未单做——随 A4 真卡对照覆盖方向选择场景；详情卡本就载升一/升二全文 |
| A4 | 升级选择真卡对照 | **已实装**：QiUpgradePick（功法三卡＋句级 diff 增/删/改标记；被动主卡＋对照块）；奖励页＋商店两处换装；商店方向弹窗改为必须点选（已付费不落空） |
| A5 | 商店失败反馈 | **部分采纳**：摇摆 ±10px/0.4s＋失望音效（暂用仓内音降调——外部 error 音源三路下载未通）；红价签实时态未采（用户只要摇摆+音效）；买断 restock 我方制保留 |
| A6 | hover 规范/比例 | **改裁＝整制采纳**：卡牌改唯一基准 300×422＋场合系数五档（单位 0.60/手牌 0.72/备战 0.78/详情 0.90/迷你 0.11），替代当日早前三档实物制；AGENTS/UI实施已随改 |
| A7 | 打出动画重构 | **裁定不改**：互动模式不同，STS2 打出动画制不采用；战斗动画/特效参照系定为《尸姬之梦》——**本表 A7 与 §7 结论以本裁定为准** |
