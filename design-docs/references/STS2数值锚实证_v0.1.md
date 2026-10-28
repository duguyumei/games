# STS2 数值锚实证（v0.1）

> 2026-10-28 数值锚定轮实证底档，服务《基础规则 v0.8》§11 锚表与后续敌人优化轮。数据源＝STS2 反编译仓 `~/Documents/sts2-decompiled`（数值全在 C# 模型层；`sts2-extract` 的 .tres 全是视觉/动画资源无数值），全部出处 file:line。**锚值本身＝2026-10-28 用户裁定**（放大基数理由：我方状态 ±1/层为最小粒度，基数大则叠层占比小、膨胀慢；且我方有免费普攻轴与多打多结构差异），本档只存对照实证，锚非照抄。

## 1. 换算锚实证（卡牌定价带）

- **Strike（5 角色同值）**：1 费 / 6 伤 / 升级 +3（变 9）。`MegaCrit.Sts2.Core.Models.Cards/StrikeIronclad.cs:19,25,39`
- **Defend（5 角色同值）**：1 费 / 5 格挡 / 升级 +3（变 8）。`.../DefendIronclad.cs:17,20,31`
- Ironclad 初始特殊卡 Bash：2 费 8 伤＋2 易伤，升级 +2 伤 +1 易伤。`.../Bash.cs:20,25,40-41`
- **1 费攻击卡（39 张）**：主体 5-9 伤（众数 9）；低端 3-4（带附加/多段），高端 10-13（Headbutt 9 / PommelStrike 9 / Defile 13 / GuidingStar 12 / MoltenFist 等 10）。
- **2 费纯伤卡（7 张）**：15-18（Predator 15 `Predator.cs:15`、Cinder 18 `Cinder.cs:18`）；附带效果型降至 6×2 / 6 / 3×多段。
- **1 费格挡技能（16 张）**：3-9，众数 8（Leap 9 / ShrugItOff 8 / TrueGrit 7 / Armaments·Backflip 5）。
- 参考：1 费非普通 UltimateStrike 14 伤 / UltimateDefend 11 格挡（升级 +6/+4）。

**我方对照**：1 能量＝10 伤＝10 盾（用户裁定）。伤锚 ≈ 实证带（6/费）1.5~1.7 倍；盾:伤汇率我方 1:1 vs 实证 5:6（0.83）——我方盾相对更值钱（多单位分配摩擦＋回合末清空）。

## 2. 升级增幅实证

全卡池 486 处 `UpgradeValueBy(n)` 分布：+1×188、+2×102、+3×105、+4×34、+5×25、+6×11、+8×5、+10×8、+11×3、+15×1、+25×3。典型：Strike 6→9（+50%）、Defend 5→8（+60%）、普通攻击卡普遍 +2~+3、格挡技能 +2~+3、高伤 2 费卡 +5~+6（Predator +5 `Predator.cs:33`、Cinder +6 `Cinder.cs:44`）。**即升级幅度 ≈ 基础值 25%~60%**。

**我方对照**：升级四档总预算 60~80%（用户裁定，高一档）——升级是构筑大头的项目定位使然；上限禁翻倍。

## 3. 玩家侧常量

- 初始 HP：Ironclad 80（`Models.Characters/Ironclad.cs:33`）/ Silent 70 / Defect 75 / Necrobinder 66 / Regent 75。
- 初始金币 99（Ironclad.cs:35）；能量 3（`Models/CharacterModel.cs:84`）；抽牌 5（`Combat/CombatManager.cs:40`）；手牌上限 10（`Entities.Cards/CardPile.cs:21`）。
- 初始卡组：9~12 张（Ironclad 5 Strike+4 Defend+1 Bash，Ironclad.cs:43-55；Silent 12 张）。
- 药水槽 3（`Entities.Players/Player.cs:303`）。

## 4. 经济锚

- 战斗金币：普通 10-20 / 精英 35-45 / Boss 100（`Models/EncounterModel.cs:68-93`，字段 MinGoldReward/MaxGoldReward）。
- 商店卡价：普通 50 / 非普通 75 / 稀有 150；×rand[0.95,1.05]，打折 ÷2（`Entities.Merchant/MerchantCardEntry.cs:40-50,124-128`）。
- 删卡价：首删 75，每次已删 +25（`MerchantCardRemovalEntry.cs:20-22,32`）。
- 遗物价：普通 175 / 非普通 225 / 稀有 275 / 商店专属 200；×rand[0.85,1.15]（`Models/RelicModel.cs:304-312`）。

## 5. Act 1 敌方数值带（敌人优化轮预算参照）

进阶值制：`AscensionHelper.GetValueIfAscension(级别, 进阶值, 基础值)`（`Helpers/AscensionHelper.cs:22`）；HP 字段 MinInitialHp/MaxInitialHp；伤害 SingleAttackIntent(x)/MultiAttackIntent(x,n)；格挡 CreatureCmd.GainBlock(n)。均在 `MegaCrit.Sts2.Core.Models.Monsters/`。

**区间汇总**：普通战主力怪 HP 44-80（小怪/召唤 6-25），单次行动伤 3-18（主体 6-14），防御动作格挡 3-13；精英单体 HP 61-140、伤 4-19；Boss HP 173-252、单段 6-26。

代表例（基础值）：FossilStalker 51-53，冲撞 9/咬住 12；HauntedShip 63 固定，横扫 13；PunchConstruct 55 固定，重拳 14、蓄力 +10 格挡（PunchConstruct.cs:33-39,99）；TwoTailedRat ×3 各 17-21，抓挠 8；精英 TerrorEel 140 固定，撞击 16（TerrorEel.cs:35-45）；Boss WaterfallGiant 240 固定，踩 15/水压枪 20 起步（WaterfallGiant.cs:68-82）。

**承伤带反推参照**：Act1 普通战敌方回合输出 ≈ 12-28（2-3 敌），对玩家 70-80 HP ≈ 每回合 17-35%——我方难度统计口径（阵亡数/全灭率/回合数/跨场耐久曲线）见《基础规则 v0.8》§11 标定纪律。

## 6. 多单位血量持久化两案（回血制参照结论）

两份参照源**都没有**「跨场多单位 HP 持久化」完整实现，我方回血制属自研（架构各借半步）：

- **STS2 Necrobinder·Osty**：战斗内常驻独立 HP 友方单位（`Osty : MonsterModel` 与敌同基类，`Monsters/Osty.cs:13,27-29`；HP 由召唤量定 `Commands/OstyCmd.cs:66-79`；复活＝尸体留场＋重召 `OstyCmd.cs:53-83`）。**不跨场**：每场由初始遗物 1 HP 重召（`Models.Relics/BoundPhylactery.cs:21,36-47`），战斗态每场重建（`Entities.Players/Player.cs:793-795`），存档无 Osty 字段。可借＝战斗内多单位架构（同基类/HP 挂战斗单位/原地复活模式）。
- **尸姬之梦**：阵容持久（编队 `Save_Obj.TeamRetrainer`＋后备 `PlayerStaticRetrainers`，`shiji-decompiled/Save_Obj.cs:147,93`），但 **HP 每场满血重置**（`RetrainerManager.cs:130-150` `ResetData()` Hp_Now=Hp_MaxGet；全库无战斗 HP 回写队伍代码）；阵亡者波次结束满血归队（`RS09_NewEnemy.cs:66-78`）；战斗内复活卡 2001（`UI_RetrainerReBack.cs:32-56`）。可借＝队伍/后备两层存档结构＋一场内多波次保留制（IfBattleEnd 标志，`RetrainerManager.cs:104-127`）。
- 单角色持久经济层（何时回/定价/奖励位权衡）＝STS2/StS 通用骨架平移，统计口径换成「队伍总 HP＋单器灵 HP」两条。

我方自研件＝战斗结束写回＋全 run 不重置＋回血三通道（后备每场后回血/金币/奖励位，见《基础规则 v0.8》§7）。
