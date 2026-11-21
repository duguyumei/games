# 吸血鬼爬行者 Ghidra 取证六案 v0.1

> 2026-11-21 立档（用户批「新增个文档」）。全项目结构审计（2026-11-20）遗留的六项待证据，用 Ghidra 伪码通道一次读掉。
> **通道**：`~/Documents/vc_decomp/ghidra_decomp/`（2117 类 · 14,123 方法 · fail=0）＋ `dump_out/method_table.tsv`（地址↔名称索引）＋ csall 声明层＋ AssetRipper 资产。
> **口径**：伪码＝汇编的便捷视图，**正式引用锚 method_table 地址**（宪法证据分级不变）；csall 方法体空壳处一律以伪码为准；两级证据打架处标「待 lldb」。
> 关联：《手牌系统真值 v0.3》（§4b.2／§十三开放点）、《伤害管线逆向 v0.1》、《终局状态机对齐 v0.1》、全项目结构审计（2026-11-20，会话交付）。

## 一、GameStateMachine.RegisterTransitions 全解（差异登记 #36 复核·定谳）

主证：`ghidra_decomp/Nosebleed.Pancake.GameLogic.GameStateMachine.c` RegisterTransitions @**0x3B4E570**（csall :782 方法体系空壳，作废）。

- **全游戏共 23 个事件订阅**（17 个 lambda 回调 b__30_0..16 ＋ 6 个 SetState* 方法组），**另有且仅有 3 条谓词 AddTransition**，全部 `from = DungeonMovementState`（漫游态→事件格入口）：
  | 谓词 | 地址 | 条件体 | 去向 |
  |---|---|---|---|
  | b__30_17 | 0x3B503C0 | 当前格 EventConfig 为空（Unity 判销毁）或 `is EnemyEncounterConfig` | EncounterStart |
  | b__30_18 | 0x3B505EC | `is GuardianEncounterConfig` | EncounterStart |
  | b__30_19 | 0x3B5073C | `is PassiveEventConfig` | PassiveEventState |
  公共总闸＝`_dungeonMovementState != null && HasExecuted`；EventConfig 取自 `GameModel→DungeonModel→CurrentEvent→EventConfig`（接口槽 3）。
- **战斗环内零谓词、纯事件回调驱动**。两个此前未知的环上细节：
  - **PlayerTurn 出口不挂自身 StateExecuted，而挂 `PlayerModel.TurnEnded` 模型事件**（b__30_4 @0x3B4FE4C→PlayerEndTurn）；
  - **PostPlayerEndTurnState 出口自判生死**：`CurrentEncounter.CurrentHealth > 0 ? EnemyTurn : EncounterDefeated`（b__30_6 @0x3B4FF0C；CurrentHealth＝IEncounterModel 槽 1 double，DoEnemiesGoFirst＝槽 6 bool——槽序经三处独立汇编印证）。
  - 其余环跳：EncounterStart→(b__30_1 DoEnemiesGoFirst ? EnemyTurn : PrePlayerTurn)；EnemyTurn→(b__30_2)→PrePlayerTurn→(b__30_3)→PlayerTurn；PlayerEndTurn→(b__30_5)→PostPlayerEndTurn；败北旁路 PlayerModel.PlayerDied→(b__30_10)→PlayerDiedState，复活→(b__30_11)→回 PrePlayerTurn。
- **#36 修正文案（待用户批后改登记）**：「零谓词转移」→「仅 3 条入口型谓词转移（漫游→事件格），战斗环内零谓词、StateExecuted/模型事件回调 SetState 驱动」。
- 残留待 lldb：①两个方法组槽位（Globals.PassiveEventFinishedEvent/DungeonEventLeftEvent 的绑定二选一）；②`SetStateEncounterStart` @0x3B4F2AC 全库零调用者＝死代码嫌疑。

## 二、弃牌/打出飞行「主程」＝TransformMover2D 单层（DOTween 主程假说代码层不成立）

主证：DiscardPileView.MoveToCardPile @**0x3BB7EE8**、CardView.MoveTo @**0x3BEAFA0**、TransformMover2D.Update @0x3BC1DD8。

- **全链无任何位移型 DOTween**（无 DOMove/DOLocalMove）：位移 100% 由 TransformMover2D.Update 帧驱动（`effSpeed = dist<decelDist ? speed×(dist/decelDist) : speed`，`step=effSpeed×deltaTime`，步长平方≥距离平方即钳达）。DOTween 只挂 RotateTo（DORotate，ease 硬编码 10=InOutCubic）与 ScaleTo（DOScale）。
- MoveToCardPile 调用序（Discard 版）：SetFacingDirection(2)→读 discardCardConfig→clamp speedMult（MaximumCardMoveSpeedMultiplier=-1＝永不封顶）→RotateTo(55,180,90, 0.2/mult, 0.02/mult)→ScaleTo(0.2,0.2,1, 0.1/mult, 0.05/mult, ease10)→`CardView.MoveTo(_pileRoot.position)`（内部设默认 500/10）→**覆盖** `SetSpeed(250×mult)`＋`SetDecel(0.5/mult)`→登记 `_cardsMovingToPile`＋TargetChanged→PlaySound。
- CardView.MoveTo 不新建 mover：取卡上 `_transformMover`，SetTargetPosition（激活 Update）→500/10→ResetOnComplete→挂到达回调。mover 是卡 prefab 自带组件（Awake 中 enabled=false）。
- **⚠ 与 lldb 实测两级打架（待 lldb 重测）**：伪码层无主程 Tween，但实测 65-110ms／mover 只跑尾段 ~50px 的观感与 250×mult 匀速模型对不上（差一个数量级）。调和候选＝Canvas 缩放单位差／speedMult 实际取值／实测对象为短距卡。双断点重测时顺带读 mover 实际步长。
- **三堆同构（批4 弹药）**：Draw 版 MoveToCardPile @0x3BB9CD0 **与 Discard 同偏移直读 discardCardConfig 全套**（进抽堆动画复用弃牌视觉配置）；Combo 版 @0x3BB53C8 **不覆盖速度**（沿用 MoveTo 默认 500/10）＋slam 用 comboPileConfig（raisedScale/raiseTime/raiseEase，GC+0x3B8/0x3BC/0x3C0）＋TryPlayComboCalloutAudio。
- 打出落位链 `MoveToPlayedPositionCardBehaviour d__1` @0x3DAB780：也是 mover；`playedCardDelay`＝generalCardConfig @GC+0x30。d__9 协程补：gameObject 不活跃时走 `TeleportToCardPile` 瞬移分支。

## 三、cardDiscardLogBase=1000 消费者＝DiscardHandCommand 发射间隔（两钟并存·定谳）

- 唯一消费者＝`PlayerView._DiscardHandCommand_d__146.c` MoveNext @**0x3C68CCC**：`totalTime = Math.Log(N, cardDiscardLogBase)`（@GC+0xA4）→`timePerCard = totalTime/N`→逐卡发射；`isSwitching` 且 totalTime 超过 `MaxSwitchDiscardTime`（@GC+0x9A4）时封顶并乘 `SpeedMultiplierWhenMaxReached`（@GC+0x9AC）。
- DrawCardsCommand d__147 @0x3C699AC 确认用 **cardDrawLogBase（@GC+0xA0）**，两字段未混用。全库 +0xA4 直读者仅 d__146 一处（基址 GlobalConfig 的 28 处候选逐一排除）。
- **与真值档的「矛盾」实为分工**：对数钟＝逐卡**发射间隔**（d__146）；`max(N,3)`＝飞行**速度乘区**（CardPileModel.OnCardAdded，真值档 ISIL :039-042 已定谳）。两钟并存各司其职，§4b.2 开放点销案。
- ⚠ 本轮代理曾报「MinimumCardPileSpeedMultiplier 全库无消费者＝死配置」——**与 ISIL 定谳冲突，以 ISIL 档为准**（代理检索面未覆盖 CardPileModel），待 `CardPileModel.c` 复核后终销。

## 四、武器时长构成（胜利空窗案 a 路弹药）

- **AnimatedWeapon 单次攻击时长＝clip.length ×1 次播放 ×速度乘区 1.0**：`StartWeaponAttack d__11` @0x3AED188 读 `clip.length`，`remainingAnimTime = length − _timeInAnimToDamage`，Animancer.Play(clip) 无 speed 参数，两次等待之和恰为 clip 全长；受 Time.timeScale。锚点实例：Whip **0.333s**（伤害帧 0.1665 居中）、Garlic 2.0s、InfiniteCorridor 1.167s、Vandalier 2.683s。`SetCooldownMultiplier` 只缩放 GunWeapon 系动画速度（`speed=1/(X×(mult−1)+1)`），与 AnimatedWeapon 无关。
- **Knife（连环刺对位）不是 AnimatedWeapon，是 Projectile 弹体**（Projectile_Knife.prefab：_moveSpeed 12／_speedScalesWithAmount 1／_minLifeTime 0.5／_maxLifeTime 5；ProjectileCollision：_collisionRadius 0.5／_minActiveTime 1／_hitAllOnFirstHit 0／_deactivateType 1）。**无固定演出时长**——命中/寿命/出屏决定。
- **整次打出节奏**＝`baseAmount(5~15 把) × 逐把发射间隔`：`DelayMultiplierEquation(count,p) = p[1] + p[0]^count ×(1−p[1])`（@0x3DD49CC，pow 递减）× `rand(_minMaxFireDelay)`（Knife＝rand(0.1,0.2)s）；每把生成时写 `Weapon._cooldownMultiplier`。
- Knife 卡真值顺带到手（Card_A_0_Knife.asset，Odin bytes）：onPlayEffect＝**2×DamageEffect**（RightLeft 索敌／_critChance 0.1／_critMultiplier 1.5／pierce 1／_minMaxFireDelay (0.1,0.2)／_alignWithTarget true）；onDraw/onDiscard/onEndTurn 全空；升级 DamageLevelConfig level0-4 `baseAmount = 5/6/10/12/15`。
- **对 a/b 两路裁定的意义**：原版「出招余程」不是固定语法轨，是**弹体物理＋发射间隔链的涌现时长**（最后一把弹体命中/寿命耗尽即收，minActiveTime 1s 兜底）。我方 2.02s 固定轨无原版数字可对：a 路＝按发射间隔公式＋弹体参数复刻涌现节奏；b 路＝压手感须登记差异。
- 锚不到：DelayMultiplierEquation 的 p[0]/p[1] 序列化值（GlobalConfig 资产内未定位，待资产）。

## 五、reroll/skip/banish 完整消费链（批9 弹药）

| 环节 | 原版事实 | 锚 |
|---|---|---|
| 局外存储 | ProgressionData `_powerUpLevels` 字典；购买只 +1 级（PurchasePowerUp）；求值＝GetPowerUpMultiplier（枚举 ReRoll=17/Skip=18/Banish=19，`sum += multiplier×level`） | 0x3E238EC／0x3E249A4 |
| 局内注入 | **进局一次性**：InitRunValues→ResetRunValues→PlayerStats.ResetValues→`次数 = PlayerConfig 基础 ＋ 主角色加成 ＋ PowerUp 乘区 ＋ 局内修正`→SimpleStat.SetValue（SimpleStat 底层＝FloatAsset 观察者资产，min=0 钳位） | 0x3D8B720／0x3D8EE58／0x3B5BB20；GetRerolls/Skips/Banishes 0x3B59298/0x3B5948C/0x3B59680 |
| 扣减 | reroll＝Button_Reroll 内 `Rerolls.AddValue(-1)`→翻卡动画→DelayedReroll 重出题；skip＝PlayerModel.OnSkipLevelUpChoices 内 `CardSkips.AddValue(-1)` ＋ **AddXp(round(升级所需×0.2)) 补偿**→关窗；banish＝BanishCard 内 `Banishes.AddValue(-1)`（Button_Banish 只进 banish 模式，Button_CancelBanish 复位） | 0x3E59A00／0x3D9A3C0／0x3E5345C |
| 显示 | UpdateButtons：`Stat.Value > 0` 才 SetActive **按钮父物体（整组隐藏，非置灰）**；UpdateButtonLabels＝本地化串＋余数；扣减后即时刷新 | 0x3E516C0／0x3E52DCC |

- **两处撞我方既定口径（登记不照搬）**：①原版次数耗尽＝整钮隐藏，撞用户 2026-11-09「按钮禁连底隐藏」令——按令执行、登记差异；②skip 的 20% 升级 XP 补偿是玩法决策，落批9 时请用户裁。
- duration 轴顺带定谳＝**卡牌效果时长轴**（非次数轴），消费者三处（FccConfig/CardEffect.OnProjected 投影/DurationEffect 效果写轴）；另发现原版疑似自身 bug：GetStartingDuration @0x3B5A154 的局内修正项误读 CardSkips(+0x90) 的修正量而非 Duration 自己的（待 lldb 终证）。
- 我方批9 最小闭环：run 开始处按 `基础(我方全 0)＋修行购买量` 写入 run 三键（原版的 Fcc/局内修正两源我方无此系统可省）；扣减侧我方 QiVcReward 三回调结构与原版同构。

## 六、onDraw/onDiscard/onEndTurn 钩子语义（批5 弹药）

| 钩子 | 触发时点 | 调用链（锚） | 语义要点 |
|---|---|---|---|
| onDraw·通知 | 每张卡进手时 | CardModel.OnDrawCard @0x3D4DBD4 → CardEffectsModel.OnDrawCard @0x3D4149C → CardEffect.OnDrawCard（槽 12） | 打给 onPlay/onDiscard/onDraw **三列表**，默认实现＝ResetCardEffect（供效果监听重置） |
| onDraw·执行 | 本轮抽牌收尾 | ClearDrawEffectsAndValidateCard @0x3D972B8 → ClearDrawEffects @0x3D4DE34 → **ExecuteOnDrawEffects @0x3D41898** → CardEffect.Execute @0x3B001E0 → OnExecuted | 只跑 onDraw 列表；**从抽堆进手才算**（抽到别的堆不算）；效果生卡入手立即执行（clear=1）；DrawEffect @0x3B15B8C＝抽 `amount＋玩家额外抽牌stat` 张（递归可再触发）；与 AddCardEffect（凭空生新卡、概率×Luck）相区分 |
| onDiscard·非主动 | 任何卡进弃牌堆（含死亡弃手） | DiscardPileModel.OnCardAdded @0x3D5A020 → CardModel.OnCardDiscarded @0x3D4DFD0 → OnDiscardCard @0x3D41BC0(isIntentional=false) | 每效果执行后**按「打出」计入卡事件**（TriggerCardPlayed） |
| onDiscard·主动 | 随机弃卡命令／换卡效果 | PlayerModel.TriggerOnDiscardEffects @0x3D92128 → TriggerIntentionalDiscardEffects @0x3D4E05C → OnDiscardCard(isIntentional=true) | **主动弃一卡＝两次触发**（入堆非主动一次＋主动一次）；DiscardRandomCardEffect @0x3B155F8＝随机弃 N 张（CommandRunner 异步） |
| onEndTurn·留手 | 回合末（手牌保留不弃） | PlayerModel.OnEndTurn @0x3D90AF0（:6527-6541 **倒序遍历手牌**）→ CardModel.OnEndTurnWithCardInHand @0x3D4DEB0 → **OnEndTurnWithCardInHand @0x3D420E0** | 无 TriggerCardPlayed；ManaBombEndTurnEffect @0x3B23C84＝每回合费−1→≤引爆线则 ResetOnPlayEffects＋**免费自动打出** |

- **数据现实（批5 范围裁剪依据）**：全部 10380 张卡资产里 onDraw/onDiscard/onEndTurn **均为空数组**（仅 onPlay 有 162 张非空）——三钩子的真实数据来源是**宝石运行时注入**（CardEffectGemEffect.OnGemAddedToCard @0x3DCB930，_effectTriggerType 0=OnPlay/1=OnDraw/2=OnDiscard/3=OnCombo/4=OnEndTurn/5=OnKill）。→ 我方批5：**钩子基建照搬、数据面只落 onPlay**＝与原版数据现实一致。
- ✅ **回合末弃手·全路径查毕定谳（2026-11-21 补查销案）**：初版「原版回合末手牌保留不弃」结论**错误，已撤回**——错因＝只查了 `PlayerModel.OnEndTurn`（确无 DiscardHand）就下结论，漏查状态层。**补查定谳：原版回合末确实弃整手**——`PlayerEndTurnState._DelayExecute_d__1` MoveNext @**0x3B72570** :82 直调 `PlayerModel.DiscardHand(GameModel.PlayerModel, true, false)`，随后 `UniTask.WaitUntil` 等收口（displayclass 注入 CommandRunner/GameView 单例＝回合闸双条件同族），尾段 `State.OnExecuteState` 发 StateExecuted 推 PostPlayerEndTurnState。弃手落点在**状态层**而非模型方法——与我方同构（我方 PlayerEndTurnState.gd 也是状态层调 `_end_turn_body` 冲弃）。**DiscardHand 全调用者六处定案**：①回合末 PlayerEndTurnState d__1 :82（true,false）；②终局 d__280:251（false,false）；③④死亡 CheckHealthForDeath @0x3D9B180／OnPlayerDeath @0x3D9B1F0（false,false）；⑤⑥GameModel 手动中止/GameOver :483/:646（false,true；第二 bool＝isGameOver 门 TriggerOnDiscardEffects，与差异登记 #29 一致；第一 bool 语义待 ISIL，不碍结构结论）。**我方「回合末整手冲弃」现行制与原版一致，无需裁定、无需改动。**
- 教训（用户令 2026-11-21）：**取证没查完只许标「未查完」，不许下「定谳/重大发现」级结论**——本案即反面例证（查完即反转）。

## 七、残留待证（更新）

| 项 | 状态 |
|---|---|
| ~~原版回合末是否真的不弃手~~ | **已查毕定谳（§六）：弃手在 PlayerEndTurnState 状态层，我方现行制一致，销案** |
| 弃牌飞行 mover 速度模型 vs 实测时长矛盾（双断点重测＋读实际步长） | 待 lldb |
| MinimumCardPileSpeedMultiplier 消费者复核（对 ISIL 定谳） | 待读 CardPileModel.c |
| RegisterTransitions 两方法组槽位＋SetStateEncounterStart 死代码嫌疑 | 待 lldb |
| DelayMultiplierEquation p[0]/p[1] 序列化值 | 待资产定位 |
| comboPileConfig GlobalConfig:335 段（slam 数值） | 未动（真值档原开放点） |

## 八、待用户裁定项汇总

1. 差异登记 #36 文案修正（§一）。
2. skip 的 20% 升级 XP 补偿是否引入（§五，批9）。
3. 原版「次数耗尽整钮隐藏」vs 我方「按钮禁连底隐藏」令——按令执行、登记差异（§五，随批9 登记）。
