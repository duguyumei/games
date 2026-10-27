# 归档：StR Root 入口线（2026-10-28 用户裁定「旧的不要的场景都归档，不要影响现在的项目」）

## 归档了什么

- `scenes/Root.tscn` —— StR 基础游戏根场景（旧入口；现行主场景＝`res://qiforge/QiRoot.tscn`，见 project.godot）。内嵌整套旧流程屏：标题页/主菜单/新开菜单/**开局心法遴选（RunStartOptions，10-25 制五选二）**/战斗/手牌/回合覆盖层/奖励覆盖层等。
- `scripts/Root.gd`（＋.uid）—— Root.tscn 根脚本（空壳 extends Control）。
- `scripts/ui/RunStartOptions.gd`（＋.uid）—— 旧开局遴选屏脚本。现行开局＝主菜单「新的开局」→固定队（幽冥剑＋天丝）直接进备战，遴选屏已退役。
- `qiforge/tools/probe_{shot,deck,modal,issues,card_rects,longtext 旧版}.gd` —— 宿在 Root.tscn 上的旧线探针（截图走查/旧 v0.4 卡组模型/AcceptDialog 时代回归件）。

## 为什么安全

- 主场景自存档轮起就是 `qiforge/QiRoot.tscn`；QiRoot 直接挂 QiPrepBay/QiBattleScreen，与 Root.tscn 零耦合（引用扫描确认）。
- autoload（Scenes/Scripts/FileLoader…）预载的 StR 内容层**未动**——动了会炸启动；它们是休眠内容，不会自行打开。
- `probe_longtext` 已重写为纯工厂直测（缩号保护断言保留，宿主脱离旧屏），仍在 `qiforge/tools/` 现役。
- 现役截图能力不受影响：QiRoot/QiPrepBay/QiBattleScreen 自带 `--qi-shot`，奖励弹窗/详情页有 probe_shot_reward/probe_detail。

## 现役探针清单（归档后）

battle_logic／battle_ui／battle_drag／qiv3／prep／prep_drag／detail／geo／longtext（新版）／reward／flow_win／save／upgrade／shop_deny＋dialog/modal_tip（弹窗浮窗件）。

## 剩余 StR demo 层（未归档，待剥离清单另批）

autoload 预载的 combatants/ui 场景与 action 管线脚本；StR 示例卡图音主题。整层剥离须连 autoload 一起重整，属独立批次。
