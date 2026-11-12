## 原版 Vampire Crawlers 全局配置真值（结构 1:1 制·2026-11-12 宪法首案）。
## 每值均带出处，禁自拟——改值必须先给新证据。来源面：
##   GlobalConfig.asset   ~/Documents/vc_decomp/rip/ExportedProject/Assets/MonoBehaviour/GlobalConfig.asset
##   FanYaml              ~/Documents/vc_decomp/cfg/HandPileFanConfig.yaml（＝Assets/MonoBehaviour/HandPileFanConfig.asset）
##   SC_Game.unity        ~/Documents/vc_decomp/rip/ExportedProject/Assets/_GameAssets/Scenes/SC_Game.unity
##   Card_Hand.prefab     ~/Documents/vc_decomp/rip/ExportedProject/Assets/GameObject/Card_Hand.prefab
##   CardSlot.prefab      ~/Documents/vc_decomp/rip/ExportedProject/Assets/GameObject/CardSlot.prefab
extends RefCounted

# ── Card_Hand 场景几何（SC_Game.unity / prefab 直读）────────────────────
# 手牌堆根：SC_Game 场景 HandPile RectTransform（SC_Game.unity:789268-789292）
const HAND_ROOT_SCALE := 1.14            # m_LocalScale {1.14,1.14,1.14}（:789279）——上屏倍率真凶
const HAND_ROOT_ANCHORED_POS := Vector2(0.0, 37.0)   # m_AnchoredPosition（:789289）——底中锚＋37px（行锚 37 实证）
const HAND_ROOT_SIZE := Vector2(960.0, 182.0)        # m_SizeDelta（:789290）
const HAND_ROOT_PIVOT := Vector2(0.5, 0.0)           # m_Pivot（:789292）——底中
# 画布：CanvasScaler 参考分辨率 1920×1080（SC_Game.unity:854020-854024，UiScaleMode=1）
# → 1080p 全屏下缩放系数 1.0；父链（场景根→Cards）localScale 全 1——×1.14 是唯一倍率层。
# 卡牌本体：Card_Hand.prefab 根 RectTransform sizeDelta 180×277（Card_Hand.prefab:1534）、
# localScale {1,1,1}（:1524）→ 上屏真实尺寸 = 180×277×1.14 ≈ 205×316。
const CARD_SIZE := Vector2(180.0, 277.0)             # Card_Hand.prefab:1534（画布单位）
# 卡面渲染尺寸（vc_hand 档＝300×422×0.60）：宽 180 与原版 1:1；高随我方美术纵横比 253.2
#（原版 277/纵横比 0.65 更瘦长——原生重排列后续轮，差异登记）。命中壳/槽位数学全用 CARD_SIZE。
const FACE_SIZE := Vector2(180.0, 253.2)
const SLOT_SIZE := Vector2(100.0, 100.0)             # CardSlot.prefab:61（槽 100×100；GhostVisual 180×277＝卡同寸 :122）
# 我方自拟（登记）：卡壳加高盖住「原位＋弹起位」——命中区稳定（hover 抬升 38＋余量 80）；
# 原版命中区＝卡根 RectTransform 180×277。壳顶留白＝抬升＋余量。
const HAND_TOP_PAD := 118.0                          # hoverHeightOffset 38＋壳加高 80
# 卡心在壳内位置（槽位跟随锚＝卡心）：x＝卡宽/2，y＝壳顶留白＋卡高/2
const CARD_CENTER_IN_SHELL := Vector2(90.0, 118.0 + 138.5)

# ── GlobalConfig.asset: cardMovementConfig（:33-49）────────────────────
const CARD_MOVEMENT := {
	"moveSpeed": 500.0,                    # 卡移动速度（px/s，画布单位）
	"decelerateDistance": 10.0,            # 减速带距离
	"addCardToPileWait": 0.05,
	"cardTweenDuration": 0.5,
	"cardWaitDuration": 0.5,
	"moveCardToCentreX": 0.0,
	"ReturnToHandJumpHeight": 500.0,
	"ReturnToHandUpDuration": 0.25,
	"ReturnToHandTopWait": 0.05,
	"ReturnToHandDownDuration": 0.4,
	"SpawnFromTopHeight": 0.0,
	"SpawnFromTopDuration": 0.0,
	"MinimumCardPileSpeedMultiplier": 3.0,
	"MaximumCardMoveSpeedMultiplier": -1.0,
	"cardDrawLogBase": 1000.0,             # 抽牌对数钟底
	"cardDiscardLogBase": 1000.0,          # 弃牌对数钟底
}

# ── GlobalConfig.asset: drawCardConfig（:50-56）───────────────────────
const DRAW_CARD := {
	"rotateDuration": 0.2,
	"rotateDelay": 0.0,
	"scaleDuration": 0.2,
	"scaleDelay": 0.0,
	"rotateFrom": Vector3(-55.0, 180.0, -90.0),   # 出场旋入姿态（3D 欧拉；2D 映射＝−90° 旋入近似）
	"postDrawWait": 0.2,                          # 抽牌命令定长（发射节拍）
}

# ── GlobalConfig.asset: interactableCardConfig（:57-69）───────────────
const INTERACTABLE := {
	"dragDetectionThreshold": 125.0,
	"cardSelection": 20.0,
	"draggedFollowSpeed": 30.0,
	"draggedRotationSpeed": 30.0,
	"rotationDegrees": 3.5,                 # RotateToFollowVelocity 限幅（±3.5°）
	"rotationVelMult": 0.4,                 # draggedRotationVelocityMultiplier
	"slottedRotationMatchSpeed": 0.2,       # UpdateHandTilt 槽位旋转贴合速率
	"holdDurationForDrag": 0.3,
	"longerHoldDuration": 0.6,
	"dragHeightOffset": 10.0,
	"dragXDispositionFromCurrentHover": 15.0,
	"draggedPositionChangeSpeed": 1000.0,
}

# ── GlobalConfig.asset: discardCardConfig（:202-211）──────────────────
const DISCARD_CARD := {
	"postDiscardWait": 0.15,
	"rotateDuration": 0.2,
	"rotateDelay": 0.02,
	"scaleDuration": 0.1,
	"scaleDelay": 0.05,
	"moveSpeed": 250.0,
	"decelerateDistance": 0.5,
	"rotateTo": Vector3(55.0, 180.0, 90.0),
	"scaleTo": Vector2(0.2, 0.2),           # 原值 {0.2,0.2,1}（z 2D 无）
}

# ── GlobalConfig.asset: destroyableCardConfig（:212-222）──────────────
const DESTROYABLE_CARD := {
	"postDestroyWait": 0.015,
	"scaleDuration": 0.05,
	"scaleDelay": 0.05,
	"moveSpeed": 250.0,
	"decelerateDistance": 0.5,
	"scaleTo": Vector2(1.3, 1.3),           # 原值 {1.3,1.3,1.3}
	"dissolveTime": 0.5,
	"minimumDissolveValue": 0.421,
	"multiCardSpeedExponent": 1.1,
	"maxCardDestroySpeed": 5.0,
}

# ── GlobalConfig.asset: hoverCardConfig（:235-247）────────────────────
const HOVER_CARD := {
	"moveSpeed": 750.0,
	"scaleDuration": 0.05,
	"decelerateDistance": 0.5,
	"scaleTo": Vector2(1.5, 1.5),
	"hoverHeightOffset": 38.0,
}

# ── GlobalConfig.asset: handPileConfig（:335-337）─────────────────────
const HAND_PILE := {
	"cardSpacing": 14.0,
	"defaultCardReorderDelayTime": 0.5,     # AreCardPositionsLocked 交互后锁位时长（邻牌收拢延迟）
}

# ── GlobalConfig.asset: runModeConfig（:845-851）──────────────────────
# 手牌上限按地下城开关（DungeonModel.HasHandSizeLimit → PlayerRunSettings.IsHandSizeLimitActive，
# DungeonModel.cs:5035）；默认地下城不启用——我方无此模式，登记缓后（差异登记#5）。
const RUN_MODE := {
	"BaseHandSizeLimit": 4,
	"MaxHandSizeLimit": 7,
	"HandSizeDrawOffset": 0,
}

# ── GlobalConfig.asset: 其余段（本轮消费者缓后，值先落档）────────────
const GENERAL_CARD := {                    # :845 前段 generalCardConfig
	"playedCardDelay": 1.2,
	"baseAutoPlayDelay": 0.1,
	"autoPlayDelayDecreaseMultiplier": 0.97,
	"minimumAutoPlayDelay": 0.02,
	"timeScaleCap": 3.5,
}
const FLIP_CARD := {                       # :312-315
	"rotationTime": 0.2,
	"flipInEase": 11,                       # DOTween Ease 枚举（按游戏自带 DOTween.dll 实测对照）
	"flipOutEase": 12,
}
const DECK_REFILL := {                     # :316-322（弃堆洗回抽堆动画）
	"baseCardMoveDuration": 0.3,
	"startWait": 0.05,
	"discardToDeckDuration": 0.3,
	"endWait": 0.5,
	"minJump": -50.0,
	"maxJump": 200.0,
}
const CARD_CRACK := {                      # cardCrackConfig（碎牌制；timesPlayedToStartCracking/chanceToBreak
	"timesPlayedToStartCracking": 2,       # 两键实测，余键未逐项摘录——接入碎牌视觉轮补全）
	"chanceToBreak": 1.0,
}
const THROWING_PILE := {                   # :380-384（投掷堆；缓后）
	"timetoReachTarget": 0.4,
	"cardRotationsPerSec": 5.0,
}
const FCC_PILE := {                        # :223-234（角色卡堆；缓后）
	"rotateDuration": 0.3,
	"rotateDelay": 0.02,
	"scaleDuration": 0.15,
	"scaleDelay": 0.05,
	"moveSpeed": 250.0,
	"decelerateDistance": 0.5,
	"delayBetweenTweens": 0.2,
	"tweenInDuration": 0.2,
	"tweenEase": 7,
	"pulseScale": 1.25,
	"pulseDuration": 0.25,
}

# ── HandPileFanConfig.yaml（手牌扇形布局全量，:15-112）───────────────
# 曲线键＝[time, value, inSlope, outSlope]（YAML 直读；tangentMode 0＝自由切线）
const FAN := {
	"MaxPositionOffset": 32.0,              # yaml:15
	"PositionOffsetCurve": [
		[0.0, 0.0, 6.9663477, 6.9663477],   # yaml:19-27
		[0.5, 1.0, 0.0, 0.0],               # yaml:28-36
		[1.0, 0.0, -7.0229707, -7.0229707], # yaml:37-45
	],
	"MaxRotationOffset": 15.0,              # yaml:49
	"RotationOffsetCurve": [
		[0.0, 0.0, 1.0, 1.0],               # yaml:54-61（0→1 线性）
		[1.0, 1.0, 1.0, 1.0],               # yaml:62-70
	],
	"DefaultCardRotation": Vector3.ZERO,    # yaml:74
	"SelectedCardRepelAmount": 64.0,        # yaml:75
	"MaxRepelOffset": 64.0,                 # yaml:76
	"RepelFalloffCurve": [
		[0.0, -1.0, 5.784103, 5.784103],    # yaml:81-88
		[0.99, 1.0, 0.0, 0.0],              # yaml:89-97
		[1.0, 0.0, -105.16883, -105.16883], # yaml:98-106
	],
	"MinMaxCardsForSplit": Vector2i(6, 20), # yaml:110
	"LeftSplitMinMaxOffset": Vector2(0.0, 48.0),   # yaml:111
	"RightSplitMinMaxOffset": Vector2(0.0, 96.0),  # yaml:112
}

# ── 散件常量（各出处）─────────────────────────────────────────────────
const MIN_CARD_WAIT := 1.0 / 30.0          # CardPileView.cs:222（帧间最小等待）
const MOVER_ARRIVE_SQ := 0.001             # TransformMover2D.cs:309（到达阈值·距离²）
const MOVER_INIT_SPEED := 0.007812502      # TransformMover2D.cs:16（初始速度）

# ── DOTween Ease 枚举 → Godot Tween 映射（按游戏自带 DOTween.dll 实测对照，2026-11-12）──
# 仅收实测值；未实测值走 Linear 兜底——新增前必须先测（宪法：枚举实测自游戏 DLL）。
const EASE_LINEAR := 1                     # Ease.Linear
const EASE_IN_OUT_CUBIC := 10              # Ease.InOutCubic（抽牌出场实测）
const EASE_OUT_BACK := 27                  # Ease.OutBack（悬停回落实测）
const EASE_TO_TWEEN := {
	1: [Tween.TRANS_LINEAR, Tween.EASE_IN],
	10: [Tween.TRANS_CUBIC, Tween.EASE_IN_OUT],
	27: [Tween.TRANS_BACK, Tween.EASE_OUT],
}

## Ease 枚举→Godot Tween 过渡（未实测值兜底 Linear）
static func ease_tween(ease: int) -> int:
	return EASE_TO_TWEEN.get(ease, EASE_TO_TWEEN[EASE_LINEAR])[0]

static func ease_trans(ease: int) -> int:
	return EASE_TO_TWEEN.get(ease, EASE_TO_TWEEN[EASE_LINEAR])[0]

static func ease_mode(ease: int) -> int:
	return EASE_TO_TWEEN.get(ease, EASE_TO_TWEEN[EASE_LINEAR])[1]
