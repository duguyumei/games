## VC 制战斗屏（2026-11-01 同壳轮：机柜/左右舷/顶带与地图屏共用 QiVcCabinet——
## 用户裁定「左右不变，只有中间的地图变成战斗区域」；顶带＝等级＋经验条，战斗中实时涨）。
## 2026-11-04 场景化（用户令「静态的进编辑器拖」）：静态骨架住 QiVcBattle.tscn
## （机柜＝QiVcCabinet.tscn 实例子场景；敌阵容器/属性列/按钮/式徽锚同住场景）——
## 位置/大小编辑器里拖；代码只做动态件：敌阵/属性 chips/式徽图标/手牌扇/结算浮层照旧生成，
## 贴图与按钮皮运行时挂（HUD 件不走编辑器导入）。手牌＝屏级扇排＋点击施放，照旧。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QI_CAB := preload("res://qiforge/QiVcCabinet.gd")
const VC := preload("res://qiforge/QiVcData.gd")
const VC_BATTLE := preload("res://qiforge/QiVcBattle.gd")
const VC_REWARD := preload("res://qiforge/QiVcReward.gd")   # 战斗内升级三选一（2026-11-05 经验特效轮）
const XP_FX := preload("res://qiforge/QiXpFx.gd")           # 经验珠特效层（2026-11-05 经验美术轮）
const COMBAT_FX := preload("res://qiforge/QiCombatFx.gd")   # 战斗特效层（2026-11-06 直刺闭环轮）
const VC_TARGETING := preload("res://qiforge/QiVcTargeting.gd")  # 账单→拍映射（2026-11-08 余段空放制）
const QI_FXSPEC := preload("res://qiforge/QiVcFxSpec.gd")    # 特效档案表（2026-11-07 语法轨）
const COMBO_BADGE := preload("res://qiforge/QiComboBadge.gd")  # 连击徽（2026-11-06；2026-11-10 连击退役→隐藏待裁）
const SHOW_COMBO_BADGE := false   # 金丹徽显隐门（2026-11-10 用户裁「先隐藏看看」——动态升级无全局连击数可显；使用点全带判空，重开改 true 即可）
const QI_PAUSE := preload("res://qiforge/QiVcPause.gd")  # 世界冻结·引用计数（2026-11-09 贴原版 TimeManager）
const INTENT_BAR := preload("res://qiforge/QiIntentBar.gd")  # 敌方总行为（2026-11-06）
const KW_TIP := preload("res://qiforge/QiKeywordTooltip.gd")  # 卡词条浮窗组件（2026-11-10 挂卡下制）
const CMDQ := preload("res://qiforge/QiVcCmdRunner.gd")  # 统一命令队列（2026-11-12 原版 CommandRunner 同构）
const FXA := preload("res://qiforge/QiFxAtlas.gd")           # 特效图集（死亡墨屑等）
const QI_ORBIT := preload("res://qiforge/QiQiOrbit.gd")      # 气珠轨道（气值＝绕珠粒子数）
const CARD := preload("res://qiforge/QiCardStyle.gd")
const ENEMY_CARD := preload("res://qiforge/QiEnemyCard.gd")
const QIFONTS := preload("res://qiforge/QiFontBank.gd")
const ICONS := preload("res://qiforge/QiVcIcons.gd")
const TILT_SHADER := preload("res://qiforge/assets/card_tilt_glint.gdshader")
## 手牌倾斜（2026-11-03 用户令「我就想在新手第一关就见到倾斜效果」）：
## 每张手牌渲进 SubViewport（2× 超采保清晰）→ 贴图 ＋ 单应透视/边缘反光着色器。
## 内层因此是纯贴图——事件必须归外壳（手牌标准做法）；倾斜/光效由 _hand_lerp_tick 统一驱动。
const TILT_SS := 3.0          # 超采样倍数（2026-11-08：2.0 时金线与卡面交界的 1px 硬边去不掉，提到 3.0）
const TILT_MARGIN := 1.18     # 显示矩形外扩（防倾斜切角）
const TILT_MAX := 0.50        # 倾斜最大量（喂 shader 的 tip）
const TILT_SMOOTH := 12.0     # 倾斜跟手平滑

## 手牌手感常量（2026-11-11 原版 1:1 资产真值轮——真值/出处全表：
## design-docs/references/吸血鬼爬行者_手牌系统真值_v0.1.md）。
## 原版手牌卡 180×277、我方 216×304 → 像素值×1.2 换算；角度/比例/时长不换算。
static var HAND_W := CARD.size_of("hand").x
static var HAND_H := CARD.size_of("hand").y
const HAND_K := 216.0 / 180.0               # 换算比 1.2（我方手牌卡宽/原版手牌卡宽；2026-11-12 试过对齐 180 原版宽——观感无变化已还原）
const HAND_BAND := 860.0                    # 行宽封顶（自拟：受左右舷 HUD 限制；原版实测 906）
const HAND_SPACING_MAX := 115.0 * HAND_K    # 卡间净距封顶（原版 _maxSpacingBetweenElements 115）
## 〔弧退役〕原版 MaxPositionOffset 32/PositionOffsetCurve＝死代码（AlignChildrenAlongAxis 次轴
## 直接 return，FanCardPosition 从未被调用）——手牌平排，2026-11-12 实机图＋汇编双证
const HAND_ROT_MAX := deg_to_rad(3.5)       # 视觉倾角上限（2026-11-12 汇编层破案：布局写 ±15° 在**槽位层**，
											# 卡视觉层每帧被 RotateToFollowVelocity 钳到 ±3.5°〔draggedRotationAmountDegrees
											# 实测〕——原版静止手牌≈直立微倾；15° 只是不可见布局值）
const HAND_REPEL_BASE := 64.0 * HAND_K      # 劈开 repel 基量（SelectedCardRepelAmount 64）
const HAND_REPEL_MAX := 64.0 * HAND_K       # 劈开 repel 曲线量（MaxRepelOffset 64）
const HAND_SPLIT_MIN_N := 6.0               # 劈开量过渡牌数区间（MinMaxCardsForSplit 6→20）
const HAND_SPLIT_MAX_N := 20.0
const HAND_SPLIT_L := Vector2(0.0, 48.0 * HAND_K)   # 左翼基础劈开 min→max（LeftSplitMinMaxOffset 0→48）
const HAND_SPLIT_R := Vector2(0.0, 96.0 * HAND_K)   # 右翼劈开（RightSplitMinMaxOffset 0→96——右翼翻倍）
static var HAND_LIFT := 38.0 * HAND_K       # 悬停抬升·可付费（hoverHeightOffset 38）
const HAND_LIFT_BAD := 15.0 * HAND_K        # 悬停抬升·不可付费（invalidHeightOffset 15）
const HAND_POP := Vector2(1.5, 1.5)         # 悬停放大·可付费（scaleTo 1.5）
const HAND_POP_BAD := Vector2(1.05, 1.05)   # 悬停放大·不可付费（invalidScaleTo 1.05）
const HAND_MOVE_SPEED := 750.0 * HAND_K     # 位移速度（moveSpeed 750——匀速寻的脆感；只服务悬停/劈开等布局微移）
const HAND_DRAW_TIME := 0.2                 # 抽牌单卡飞行时长（drawCardConfig rotate/scaleDuration 0.2 实测）
const HAND_DRAW_STAGGER := 0.2              # 抽牌节拍（postDrawWait 0.2 实测——命令定长＝流水制，旧 0.07 自拟错峰退役）
const HAND_DECEL := 0.5 * HAND_K            # 减速带（decelerateDistance 0.5）
const HAND_SCALE_DUR := 0.05                # 缩放时长（scaleDuration）
const HAND_SHAKE_AMP := 5.0 * HAND_K        # 不可付费摇头幅度（invalidShakeAmplitude 5）
const HAND_SHAKE_TIME := 0.3                # 摇头时长（invalidShakeTime 0.3，vibrato 15）
const HAND_SHELL_EXTRA := 80.0              # 壳额外高（盖住弹起后超出卡面的上沿）
const DRAW_PILE_CENTER := Vector2(55.0, 1025.0)     # 老屏常量（仅兜底）
const DISCARD_PILE_CENTER := Vector2(1866.0, 1025.0)

## 原版曲线（键值/斜率照资产 1:1；Godot Curve 自由切线＝Hermite 同构）
## 〔弧曲线退役〕PositionOffsetCurve 随 FanCardPosition 死代码退役——真值存 references 参数表
static var _repel_curve: Curve = null

static func hand_repel_curve() -> Curve:
	## RepelFalloffCurve：(0,-1)[斜5.78] (0.99,1)[双0斜] (1,0)[斜-105]——相邻卡曲线值 -1 抵掉基量
	## （2026-11-11 审计修：0.99 键原版切线双 0，初版误写左斜 5.78）
	if _repel_curve == null:
		_repel_curve = Curve.new()
		_repel_curve.add_point(Vector2(0.0, -1.0), 0.0, 5.784103)
		_repel_curve.add_point(Vector2(0.99, 1.0), 0.0, 0.0)
		_repel_curve.add_point(Vector2(1.0, 0.0), -105.16883, 0.0)
	return _repel_curve

signal battle_over(result: String)

var run: Dictionary = {}
var battle: RefCounted = null
var _pool_hp_max := 1
var _win_pending := false       # 胜利收尾中：等珠到齐＋升级弹窗全关再弹横幅（2026-11-05 用户令时序）
var _death_fx_until := 0        # 死亡碎裂特效到期时刻（ms）：没播完不许弹胜利横幅
var _win_retry_armed := false   # 已挂重推定时器（防重复挂）
var _end_overlay_waiting := false   # 结束面板在等溶解播完
var _xp_flights := 0            # 在飞经验珠数
var _xp_orbs_amt := 0           # 在飞珠总经验值（2026-11-09 逐珠制：显示值＝数据−在飞，条/弹窗共此时钟）
var _xp_spawned := {}           # 已放珠的敌 uid（同帧多次 _refresh 不重复放）
var _xp_fx: Control = null      # 经验珠特效层（z 90；全 IGNORE）
var _combat_fx: Control = null  # 战斗特效层（z 85；全 IGNORE）
var _combo_badge: Control = null  # 连击徽（贴气珠右侧；z 68）
var _intent_bar: Control = null   # 敌方总行为条（敌阵上方）
var _intents_hidden := false     # 出手演出期间藏了意图（重建敌阵时要把新节点也藏住）
var _finale := false             # 场上已无敌：进入终局（珠立即放飞、手牌隐藏）
var _aura_layer: Control = null   # 敌卡底光层（独立，整层重建，避免叠光）
var _aura_pending: Array = []     # 待定位的底光（卡片布局要等一帧才准）
var _hit_events: Array = []     # 本次出牌的命中快照（uid/伤害/目标矩形；归活跃拍驱动独占）
var _replay_active := false     # 连打制（2026-11-09）：拍驱动串行化——同一时刻只跑一个
var _replay_queue: Array = []   # 连打排队：上一张播完才起拍（原版 CommandRunner 队列同构）
var _played_uid := -1           # 本次打出的手牌 uid（决定它走「出招」而不是「丢牌」动画）
var _played_cid := ""           # 本次打出的卡 id（查特效档案；空/无档案＝继续走旧笔锋线）
var _played_from := Vector2.ZERO
var _fx_busy_until := 0   # 特效占线墙钟（错峰用，ms）
var _shake_prev := 0      # 上次震屏墙钟（连击节流：防 _shake 的 base 吃到上一次的中间位移）
var _replay_on := false   # 击拍留尸窗口：本轮特效还没播到，被打死的敌卡先别消失
var _dying := {}          # uid -> 敌卡（已死但还没到它那一拍）
var _last_beat := {}      # uid -> 本轮最后一次打到它的击序（活到这一拍才收尸）
var _qi_prev := -1        # 上一帧看到的气值（洗牌回气算增量）
var _hp_prev := -1        # 上一帧血量（受击特效判定）
var _hit_vignette: TextureRect = null
var _qi_orbit: Control = null  # 出招笔锋起点（打出的手牌中心）
var _hit_stop_until := 0        # 顿帧墙钟截止（ms）
var _reward_ui: Control = null  # 战斗内升级三选一（条满立即弹·2026-11-09 贴原版零特效令）
var _enemy_cards := {}          # uid -> 敌卡（增量对账：节点身份稳定，2026-11-06 规格§7）
var _enemy_holder: Control = null
var _played_cards := {}         # uid -> wrap（已打出区右侧留位粗排；正式视觉归用户，规格§6）
var _cardq := CMDQ.new()   # 统一命令队列·卡动画线（2026-11-12 原版 CommandRunner 制；墙钟退役）

var _top_refs := {}             # 机柜顶带（等级/经验/层数）
var _wing_refs := {}            # 机柜舷位（血/抽/弃）
var _pool_bar: ProgressBar = null
var _pool_text: Label = null
var _enc_armor_label: Label = null
var _reserve_label: Label = null
var _merged_label: Label = null
var _event_lbl: Label = null
var _enemy_row: VBoxContainer = null
var _stat_left: GridContainer = null
var _stat_right: GridContainer = null
var _stat_vals: Dictionary = {}
var _end_btn: Button = null
var _coin_lbl: Label = null
var _play_all_btn: Button = null
var _stance_box: HBoxContainer = null
var _overlay: Control = null

var _hand_wraps: Array = []        # 屏级扇排（老屏同制：直接挂屏、视口坐标）
var _hand_focus: Control = null    # 悬停焦点（弹起位）
var _kw_tip_host: Control = null   # 悬卡词条浮窗宿主 wrap（组件挂 wrap 下，经 meta "kw_tip" 取）
var _preview_layer: Control = null  # 悬卡预览层（伤害/气/盾；z 92 全 IGNORE）
var _preview_nodes: Array = []      # 预览件（换焦点/移开即清）
var _tilt_t := 0.0                 # 倾斜/光泽带驱动时钟

func setup(run_ref: Dictionary) -> void:
	run = run_ref
	_finale = false   # 新战斗：终局标志清空
	_xp_orbs_amt = 0  # 新战斗：在飞珠显示锁清零（2026-11-09 逐珠制）
	battle = VC_BATTLE.new()
	battle.setup(run)
	battle._screen_attached = true   # 有屏标记（2026-11-12 命令队列制）：敌方动作/效果表现命令走 tick 串行
	battle.fx_launcher = _launch_fx_cmd   # 效果表现启动器注入（现在＝刷新＋即时落定，动画将来挂）
	battle.pending_visual = true   # 落账延迟制（2026-11-08）：伤害账单等击中帧逐事件结算
	_pool_hp_max = _pool_hp_total_max()
	battle.changed.connect(_refresh)
	battle.event.connect(_on_event)
	battle.ended.connect(_on_ended)
	battle.piles_shuffled.connect(_on_piles_shuffled)
	battle.played_changed.connect(_rebuild_played)
	battle.hit_landed.connect(_on_hit_landed)

func _ready() -> void:
	_wire_scene()
	# 卡动画命令线（2026-11-12 原版制·统一 runner）：启动器随 push 注入——
	# removed＝弃堆飞出、added＝抽堆起点淡入（完成回调交队列落定）
	# 经验珠特效层（盖在手牌之上、结算浮层之下）：只在战斗屏建
	_xp_fx = XP_FX.new()
	add_child(_xp_fx)
	_combat_fx = COMBAT_FX.new()
	add_child(_combat_fx)
	_aura_layer = Control.new()
	_aura_layer.z_index = 5
	_aura_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aura_layer)
	_qi_orbit = QI_ORBIT.new()
	_qi_orbit.z_index = 66   # 与气珠同级：前层 68、后层 65 由内部子节点负责
	add_child(_qi_orbit)
	var qw := find_child("QiWidget", true, false) as Control
	if qw != null:
		_qi_orbit.call_deferred("setup", qw.get_global_rect().get_center() - global_position)
	# 受击红晕（全屏，平时透明）
	# 受击红晕：只压在**战斗区下沿**（手牌区上边框那条带），不整屏泛红
	_hit_vignette = TextureRect.new()
	_hit_vignette.texture = _vignette_tex()
	_hit_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 只覆盖**战斗面板**（与 FrameBattle 对齐：x 373..1547，底边 y=856），不碰左右两栏
	_hit_vignette.position = Vector2(373.0, 636.0)
	_hit_vignette.size = Vector2(1174.0, 220.0)
	_hit_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_vignette.modulate = Color(0.62, 0.18, 0.12, 0.0)
	# 层级压在剑与手牌之下（剑 z5、手牌 z0..60），只盖住战斗区纸面
	_hit_vignette.z_index = 3
	add_child(_hit_vignette)
	_intent_bar = INTENT_BAR.new()
	_intent_bar.position = Vector2(852.0, 176.0)
	_intent_bar.size = Vector2(216.0, 66.0)
	_intent_bar.z_index = 66
	add_child(_intent_bar)
	if SHOW_COMBO_BADGE:
		_combo_badge = COMBO_BADGE.new()
		_combo_badge.position = Vector2(1604.0, 678.0)   # 上移 24，给气珠轨道让位   # 略高于结束回合钮（完全对齐反而死板）
		_combo_badge.z_index = 68
		add_child(_combo_badge)
	battle.start()
	# 2026-11-05 用户令「开局抽牌动画」：去掉 await+二次 _refresh——start() 末尾必发 changed
	# （首刷全走信号），二次全量手牌重建会把首抽飞入动画在 1 帧内吞掉；
	# 手排用视口坐标无首帧容器 size 依赖，旧「等一帧防重叠」理由已不成立

## 铺满父级（显式锚属性＋清偏移——代码实例化控件上 set_anchors_preset 实测不生效，
## 2026-11-01 probe_vc_ui 定案）
func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

#region 场景骨架收线（静态件住 QiVcBattle.tscn——位置/大小编辑器拖；此处运行时收尾）
## 机柜（$Cabinet＝QiVcCabinet.tscn 实例）贴图＋刷新引用；场景底图；按钮样式/信号；
## 属性 chips 按表填进左右两列；式徽底部锚点＝StanceBox 编辑器位置。
func _wire_scene() -> void:
	# 机柜件已并入本场景（2026-11-04 用户令「每个场景单独绘制」）——%名直达，无子场景
	QI_CAB.wire_scene(self)
	_top_refs = QI_CAB.collect_top(self)
	_wing_refs = QI_CAB.collect_wings(self)
	_wire_scene_art()
	_end_btn = QI_CAB._uniq(self, "EndBtn") as Button
	_play_all_btn = QI_CAB._uniq(self, "PlayAllBtn") as Button
	if _end_btn != null:
		_style_plaque(_end_btn, true)
		_end_btn.pressed.connect(func(): battle.end_turn())
	if _play_all_btn != null:
		_style_plaque(_play_all_btn)
		_play_all_btn.pressed.connect(func(): battle.play_all())
	# 排序面板 2026-11-04 用户令去掉（_build_sort_panel 留档）
	_stat_left = QI_CAB._uniq(self, "StatLeft") as GridContainer
	_stat_right = QI_CAB._uniq(self, "StatRight") as GridContainer
	_enemy_row = QI_CAB._uniq(self, "EnemyRow") as VBoxContainer
	_stance_box = QI_CAB._uniq(self, "StanceBox") as HBoxContainer
	_coin_lbl = QI_CAB._uniq(self, "CoinLabel") as Label
	if _coin_lbl != null:
		QISTYLE.font(_coin_lbl, QISTYLE.FS_BODY, true)
		QISTYLE.text_color(_coin_lbl, Color(0.24, 0.18, 0.12))
	var coin := QI_CAB._uniq(self, "CoinIcon") as TextureRect
	if coin != null:
		coin.texture = ICONS.icon("greed")
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_SCALE
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fill_stat_chips()

## VC 制属性列（2026-11-04 用户裁定）：左＝临时属性（原版 PlayerStatContainer (temporary)），
## 右＝永久属性（permanent）；每行 4 个；数值先默认（百分比 100／计数 0），机制后补。
func _fill_stat_chips() -> void:
	if _stat_left == null or _stat_right == null:
		return
	_stat_vals = {}
	for s in VC.STATS:
		var def: Dictionary = s
		var parent: Control = _stat_left if String(def["side"]) == "L" else _stat_right
		_stat_vals[String(def["id"])] = _mk_stat_chip(parent, def)

## 场景底图＋柔光罩已入场景（2026-11-04 贴图改随 .import 走，编辑器可见可拖）；
## 此处只剩兜底：底图文件缺失时回退旧黑机柜
func _wire_scene_art() -> void:
	# 场景里的按钮统一纸匾皮（2026-11-05）
	var pb := get_node_or_null("%PlayAllBtn") as Button
	if pb == null:
		pb = find_child("PlayAllBtn", true, false) as Button
	if pb != null:
		_style_plaque(pb)
	var eb := get_node_or_null("%EndBtn") as Button
	if eb == null:
		eb = find_child("EndBtn", true, false) as Button
	if eb != null:
		_style_plaque(eb, true)
	# 顶带定位（场景节点在 Control 里 offsets 不生效，代码兜底）
	if QI_CAB._art("scene") == null:
		QI_CAB.build(%ScenePlate as Control)

## 墨金匾额按钮样式（自绘；AI 按钮不采用）
## 宣纸匾额贴图（程序画：深木框＋内金线＋纸面＋四角钉；九宫格用）
static var _plaque_cache: Dictionary = {}

static func _plaque_texture(fill: Color, frame: Color) -> ImageTexture:
	var key := "%s|%s" % [fill.to_html(), frame.to_html()]
	if _plaque_cache.has(key):
		return _plaque_cache[key]
	var w := 120
	var h := 76
	var r := 8.0
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	for y in h:
		for x in w:
			var dx: float = absf(float(x) + 0.5 - cx) - (cx - r)
			var dy: float = absf(float(y) + 0.5 - cy) - (cy - r)
			var ox: float = maxf(dx, 0.0)
			var oy: float = maxf(dy, 0.0)
			var d: float = sqrt(ox * ox + oy * oy) - r
			if d > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var inset: float = -d
			var c: Color
			if inset < 5.0:
				c = frame.darkened(0.25)
			elif inset < 7.0:
				c = frame
			elif inset < 8.0:
				c = Color(0.62, 0.48, 0.22)
			else:
				var t: float = float(y) / float(h - 1)
				c = fill.lerp(fill.lightened(0.10), 1.0 - t)
			# 四角小钉
			var px: int = x
			var py: int = y
			var dot := (px >= 11 and px <= 15 and py >= 11 and py <= 15) or (px >= w - 16 and px <= w - 12 and py >= 11 and py <= 15) or (px >= 11 and px <= 15 and py >= h - 15 and py <= h - 11) or (px >= w - 16 and px <= w - 12 and py >= h - 15 and py <= h - 11)
			if dot:
				c = frame.darkened(0.1)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_plaque_cache[key] = tex
	return tex

func _style_plaque(b: Button, mirror := false) -> void:
	# 2026-11-05 用户令：按钮不用纸匾，直接放在剑的护手槽里，只留文字
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.16, 0.13, 0.10, 0.92)
	plate.border_color = Color(0.45, 0.38, 0.26, 0.9)
	plate.set_border_width_all(1)
	plate.content_margin_left = 4.0
	plate.content_margin_right = 4.0
	plate.set_corner_radius_all(14)  # 圆角贴合透镜内沿（内沿已削平，不再漏底）
	# 2026-11-05 用户令：悬停不改底色，只亮金边；按下才压深
	var hover: StyleBoxFlat = plate.duplicate()
	var pressed: StyleBoxFlat = plate.duplicate()
	pressed.bg_color = Color(0.10, 0.08, 0.06, 0.95)
	b.add_theme_stylebox_override("normal", plate)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	# 禁用态＝同一张底（2026-11-08 用户令：不可用时底不变，只是没字）；
	# 不给 disabled 覆盖的话 Godot 会退回主题默认的半透明禁用皮
	b.add_theme_stylebox_override("disabled", plate)
	b.add_theme_color_override("font_disabled_color", Color(0.91, 0.86, 0.72))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.91, 0.86, 0.72))
	b.add_theme_color_override("font_hover_color", Color(0.93, 0.79, 0.46))
	b.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.05))

## 式区（状态制 2026-11-08：式＝当前剑型状态非资源——容器只显**当前型一枚**徽，
## 无型不显；断链反馈＝美术线后续）：容器住场景（%StanceBox＝HBox）
## 当前武器型槽（2026-11-08 用户令：不再是「式」方块，直接显示**剑图标**；
## 变招＝在原型上加金色标记，不做第四型。数字一律不显示——式已不是资源）
var _last_form := ""      # 最后一次非 flex 的型（flex 时继续显示它）
static var _form_icons: Dictionary = {}

func _refresh_stance() -> void:
	if _stance_box == null or battle == null:
		return
	for c in _stance_box.get_children():
		c.queue_free()
	var form := String(battle.current_form)
	if form != "" and form != "flex":
		_last_form = form
	# 剑型＝状态，与「连击是否解锁」无关：只要出了牌就该显示（2026-11-08 用户报打出后不显示）
	if form == "":
		return
	var show_form := form if form != "flex" else _last_form
	if show_form == "":
		return
	# 与卡面**同一套图标资源**（assets/ui/type_*.png），背景统一墨黑＋金边——
	# 不再用另一套自绘图标（2026-11-08 用户指正：跟卡上的武器图标不一致）
	var badge := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	sb.border_color = Color(0.79, 0.65, 0.34)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(roundi(4.0))
	sb.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", sb)
	badge.custom_minimum_size = Vector2(54.0, 54.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # 不被 HBox 拉成竖长条，保持正方形
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stance_box.add_child(badge)
	var stex: Texture2D = ResourceLoader.load(
		"res://qiforge/assets/ui/type_%s%s.png" % [show_form, "_gold" if form == "flex" else "_light"])
	if stex != null:
		var ic := TextureRect.new()
		ic.texture = stex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 6.0
		ic.offset_top = 6.0
		ic.offset_right = -6.0
		ic.offset_bottom = -6.0
		badge.add_child(ic)
	# 变招待定：加一圈金环（不是第四型）
	if form == "flex":
		var ring := Panel.new()
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0, 0, 0, 0)
		rsb.border_color = Color(0.98, 0.82, 0.34)
		rsb.set_border_width_all(2)
		rsb.set_corner_radius_all(roundi(5.0))
		ring.add_theme_stylebox_override("panel", rsb)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(ring)

## 手牌排序面板（原版 SortHandButton (parent) 位≈(1757,797)）：标题＋法力/颜色两键，点了即重排
func _build_sort_panel() -> void:
	var sortp := Panel.new()
	sortp.position = Vector2(1756.0, 740.0)
	sortp.size = Vector2(158.0, 150.0)
	sortp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.82)
	ssb.border_color = QISTYLE.AMBER
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(8)
	sortp.add_theme_stylebox_override("panel", ssb)
	add_child(sortp)
	var title := _mk_label(sortp, "手牌排序", QISTYLE.FS_SMALL, QISTYLE.TEXT_MAIN)
	title.position = Vector2(0.0, 6.0)
	title.size = Vector2(158.0, 24.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 2:
		var b := Button.new()
		b.text = "法力" if i == 0 else "颜色"
		QISTYLE.apply_ghost(b)
		b.position = Vector2(10.0, 34.0 + float(i) * 54.0)
		b.size = Vector2(138.0, 48.0)
		b.pressed.connect(_on_sort_pressed.bind("mana" if i == 0 else "color"))
		sortp.add_child(b)

func _on_sort_pressed(mode: String) -> void:
	battle.sort_hand(mode)

## 单个属性图标位：72×72 深底金框，上自绘像素图标、下数值；返回值 Label（刷新用）
func _mk_stat_chip(parent: Control, def: Dictionary) -> Label:
	var color := Color(String(def["color"]))
	var p := Panel.new()
	p.custom_minimum_size = Vector2(56.0, 56.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.05, 0.55)
	sb.border_color = Color(color.r, color.g, color.b, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var tex := TextureRect.new()
	tex.texture = ICONS.icon(String(def["id"]))
	tex.position = Vector2(14.0, 2.0)
	tex.size = Vector2(28.0, 28.0)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tex)
	var v := Label.new()
	v.text = "0"
	QISTYLE.font(v, QISTYLE.FS_SMALL, true)
	QISTYLE.text_color(v, QISTYLE.CREAM)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.position = Vector2(0.0, 28.0)
	v.size = Vector2(56.0, 24.0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	return v

func _mk_label(parent: Control, text: String, size: int, color: Color, big := false) -> Label:
	var l := Label.new()
	l.text = text
	QISTYLE.font(l, size, big)
	QISTYLE.text_color(l, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
#endregion

#region 刷新（changed 单一入口）
func _refresh() -> void:
	if battle == null:
		return
	# 顶带：等级/经验（2026-11-09 贴原版令：条/数字瞬切＝数据镜子，不走补间）
	_refresh_top(0.0)
	if _coin_lbl != null:
		_coin_lbl.text = str(int(run.get("copper", 0)))
	# 舷位：血心＋抽/弃计数＋气珠（气值／每回合回复）
	var p: Dictionary = battle.player
	QI_CAB.refresh_wings(_wing_refs, int(p["hp"]), int(p["mhp"]),
		battle.draw_pile.size(), battle.discard_pile.size(),
		int(p["qi"]), int(p.get("qi_base", 0)))
	_qi_prev = int(p["qi"])
	var hp_now := int(p["hp"])
	if _hp_prev >= 0 and hp_now < _hp_prev:
		_player_hit_fx(_hp_prev - hp_now, int(p["mhp"]))
	_hp_prev = hp_now
	if _qi_orbit != null and _qi_orbit.has_method("set_value"):
		_qi_orbit.set_value(int(p["qi"]))
	# 血池行已撤（2026-11-04 原版无此信息）——只保留刷新敌阵
	_refresh_enemies()
	_place_intent_bar()
	# 属性列（2026-11-07 属性轮：显示真值——四层合成现值（starting＋encounter），
	# 与 run.stats 占位脱钩；pct 轴按 100 基、计数轴直读）
	for s in VC.STATS:
		var sid := String(s["id"])
		var val_lbl: Label = _stat_vals.get(sid)
		if val_lbl == null:
			continue
		var val: int = battle.stat_val(sid)
		val_lbl.text = ("%d%%" % val) if bool(s["pct"]) else str(val)
	_refresh_stance()
	if _intent_bar != null:
		_intent_bar.update_from(battle)
	_sync_intents()
	# 安全阀：预判收尾但战斗没结束（还活着）→ 复原，避免手牌永久不见
	if _finale and String(battle.phase) == "player" and not (battle.encounter["active"] as Array).is_empty() \
			and Time.get_ticks_msec() >= _fx_busy_until:
		_finale = false
	if _combo_badge != null:
		_combo_badge.update_from(battle)
	_rebuild_hand()
	# 两个按钮同进退（2026-11-06 用户指正：战斗结束时只有「结束回合」被置灰，
	# 跟「打出全部」一个死一个活——要么一起灰、要么一起亮）
	var can_act := String(battle.phase) == "player" and not result_pending() and not _finale
	# 2026-11-08 用户令：不可用时保持和可用时一样的底（不置灰），只是**没有字**且点不动
	# 2026-11-09 用户令：终局也不许整钮连底隐藏——按钮永远可见，_finale 只并进无字判断
	if _end_btn != null:
		_end_btn.disabled = not can_act
		_end_btn.text = "结束回合" if can_act else ""
	if _play_all_btn != null:
		_play_all_btn.disabled = not can_act
		_play_all_btn.text = "打出全部" if can_act else ""
	_check_level_modal()      # 死帧入账制：数据进账刷完即判阈值（条满瞬间开三选一，2026-11-09 贴原版终裁）
	_maybe_wait_discard()

## 弃牌表现→逻辑真同步（2026-11-06 用户令）：弃牌命令全部落定后回调 battle 推进
## （2026-11-12 原版制：等队列清空＝WaitWhile(IsProcessing) 同构；无弃牌＝当帧即回调）
func _maybe_wait_discard() -> void:
	if String(battle.phase) != "discarding":
		return
	if _cardq.is_busy():
		await _cardq.all_done
	if battle != null and String(battle.phase) == "discarding":
		battle.discard_anim_done()

func _refresh_enemies() -> void:
	if _enemy_row == null:
		return
	# ── 增量对账（2026-11-06 规格§7）：按 uid 对账——新增建、消失删、存在**复用原节点**
	# 只更新位置/档位（血量无血条不刷）——受击闪/抖动/血条动画将来挂这些稳定节点上，
	# 整批重建会把它们吃掉。uid 消失＝阵亡 → 从其卡心放经验珠（2026-11-05 特效轮保持；
	# 对账制下 uid 一次性出表，天然不重复放珠）
	var alive_uids := {}
	for e in battle.encounter["active"]:
		alive_uids[int(e["uid"])] = true
	# 击拍留尸（2026-11-07 用户裁定「特效打到才有伤害」）：模型先算完，但敌卡不能先消失——
	# 本轮有特效回放时，死掉的卡先留在原地，等它最后一次被击中的那一拍再收（_beat_death）。
	for euid in _enemy_cards.keys():
		if not alive_uids.has(euid):
			# 回放期间一律兜住：此刻击表可能还不完整（changed 是逐次发的），不能按表筛
			if _replay_on:
				if not _dying.has(int(euid)):
					_dying[int(euid)] = _enemy_cards[euid]
				continue
			var dead: Control = _enemy_cards[euid]
			_enemy_cards.erase(euid)
			if is_instance_valid(dead):
				_spawn_xp_orb(dead.get_global_rect().get_center(), int(euid))
				_enemy_death_fx(dead)
	var acts: Array = battle.encounter["active"]
	if acts.is_empty():
		if _replay_on:
			return          # 回放期不清场：留尸还在这个容器里，等击拍/收尾再拆
		_enemy_holder = null
		for h in _enemy_row.get_children():
			h.queue_free()
		return
	if _enemy_holder == null or not is_instance_valid(_enemy_holder):
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(1200.0, 420.0)
		holder.size = Vector2(1200.0, 420.0)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_row.add_child(holder)
		_enemy_holder = holder
	# 敌阵队列制排布（2026-11-07 v0.1）：row＝横排——每排按本排人数居中并排，
	# 纵深排向右上错位压暗（row 越深越暗、z 越低）；后排无行动语义（意图位空）
	var card_w := 190.0
	var gap := 50.0
	var by_row: Array = []
	for e2 in acts:
		var rr := int(e2.get("row", 0))
		while by_row.size() <= rr:
			by_row.push_back([])
		by_row[rr].push_back(e2)
	for rr in by_row.size():
		var members: Array = by_row[rr]
		var cnt := members.size()
		var total_w := float(cnt) * card_w + float(cnt - 1) * gap
		var start_x := (1200.0 - total_w) * 0.5
		for j in cnt:
			var e: Dictionary = members[j]
			var euid := int(e["uid"])
			var tier := String(e.get("tier", "small"))
			var card: Control = _enemy_cards.get(euid)
			var is_new := false
			if card == null or not is_instance_valid(card):
				card = ENEMY_CARD.make(e, tier, absi(String(e.get("name", "")).hash()) % 3)
				card.set_meta("euid", euid)
				_enemy_holder.add_child(card)
				_enemy_cards[euid] = card
				_cache_card_img.call_deferred(card)
				is_new = true
			else:
				ENEMY_CARD.refresh(card, e, tier)
			# 站位（2026-11-08 用户令「死人后不用重新居中」）：同排减员＝活卡**原位不动**
			# （洞留着）；只有 ①新建卡进场 ②排迁移（排清整排上移 row 变化）才落位/移动
			var old_row := -1 if is_new else int(card.get_meta("row", -1))
			card.set_meta("row", rr)
			if not _replay_on and (is_new or old_row != rr):   # 回放期间冻结站位
				var tgt := Vector2(start_x + float(j) * (card_w + gap) + float(rr) * 26.0,
					40.0 - float(rr) * 26.0)
				if is_new:
					card.position = tgt
				else:
					if card.has_meta("move_tw"):
						var old_tw: Tween = card.get_meta("move_tw")
						if old_tw != null and old_tw.is_valid():
							old_tw.kill()
					var tw := card.create_tween()
					card.set_meta("move_tw", tw)
					tw.tween_property(card, "position", tgt, 0.18)\
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if rr > 0:
				card.modulate = Color(0.86, 0.86, 0.86, 1.0) if rr == 1 else Color(0.72, 0.72, 0.72, 1.0)
			else:
				card.modulate = Color(1.0, 1.0, 1.0, 1.0)
			card.z_index = 10 - rr
			# 底光（幂等）：对账制下同一张卡会被反复刷新，必须「有就更新、没有才建」，
			# 否则每刷一次叠一层，光会越来越深（2026-11-06 用户发现的「打完变深」）
			var ik := _intent_kind(euid)
			var aura := card.get_node_or_null("IntentAura") as TextureRect
			if ik == "":
				if aura != null:
					aura.queue_free()
			else:
				if aura == null:
					aura = TextureRect.new()
					aura.name = "IntentAura"
					aura.texture = _glow_tex()
					aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					aura.size = Vector2(206.0, 116.0)
					aura.position = Vector2((190.0 - 206.0) * 0.5, 238.0)
					aura.z_index = -1
					aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
					card.add_child(aura)
				# 光跟着卡一起压暗（叠放层次一致），不再做反向补偿
				aura.modulate = Color(0.95, 0.30, 0.20, 0.30) if ik == "attack" \
					else Color(0.30, 0.56, 1.0, 0.28)
## 底光延迟定位：容器布局要等一帧，global_position 才准
	# 出手演出期间敌阵可能重建：新意图节点要跟着藏住，否则会"中途又冒出来"
	if _intents_hidden:
		_apply_intent_hidden()
		if _intent_bar != null:
			_intent_bar.visible = false

func _flush_auras() -> void:
	if _aura_layer == null:
		return
	for p in _aura_pending:
		var card: Control = p[0]
		if not is_instance_valid(card):
			continue
		var ik: String = p[1]
		var aura := TextureRect.new()
		aura.texture = _glow_tex()
		aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		aura.size = Vector2(206.0, 116.0)
		var r: Rect2 = card.get_global_rect()
		aura.position = Vector2(r.position.x + (190.0 - 206.0) * 0.5, r.position.y + 238.0) \
			- _aura_layer.global_position
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aura.modulate = Color(0.95, 0.30, 0.20, 0.24) if ik == "attack" \
			else Color(0.30, 0.56, 1.0, 0.22)
		_aura_layer.add_child(aura)
	_aura_pending.clear()

## 凸多边形半平面裁剪（Voronoi 用）：保留靠 a 一侧（到 a 比到 b 近的部分）
func _clip_half(poly: Array, a: Vector2, b: Vector2) -> Array:
	var mid := (a + b) * 0.5
	var nrm := b - a
	var out: Array = []
	var n := poly.size()
	for i in n:
		var p1: Vector2 = poly[i]
		var p2: Vector2 = poly[(i + 1) % n]
		var d1 := nrm.dot(p1 - mid)
		var d2 := nrm.dot(p2 - mid)
		if d1 <= 0.0:
			out.push_back(p1)
		if (d1 < 0.0 and d2 > 0.0) or (d1 > 0.0 and d2 < 0.0):
			var t := d1 / (d1 - d2)
			out.push_back(p1.lerp(p2, t))
	return out

## 敌卡死亡（2026-11-06）：卡牌游戏的死＝「这张牌没了」，别做成爆炸。
## 白闪 → 卡面去色下沉淡出 → 几点墨屑外溅；全部 0.32s 内收，与经验珠并行。
## 卡一建好就缓存一张「完整渲染图」（黑框/米底/人像俱全、无特效污染）。
## 死亡碎裂直接切这张图——不靠死亡瞬间的屏幕状态，也不复制节点（复制会丢样式）。
func _cache_card_img(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(card):
		return
	var r2: Rect2 = card.get_global_rect().grow(10.0)
	var shot2 := get_viewport().get_texture().get_image()
	if shot2 == null or shot2.is_empty():
		return
	var rs := Rect2i(roundi(r2.position.x), roundi(r2.position.y),
		roundi(r2.size.x), roundi(r2.size.y))
	rs = rs.intersection(Rect2i(0, 0, shot2.get_width(), shot2.get_height()))
	if rs.size.x < 8 or rs.size.y < 8:
		return
	card.set_meta("cached_img", ImageTexture.create_from_image(shot2.get_region(rs)))

func _enemy_death_fx(dead: Control) -> void:
	# 外扩 10px：卡的墨色边框画在内容矩形之外，不外扩就只切到「米底＋人像」，
	# 看起来像人碎了而不是卡碎了（2026-11-08 用户指正）
	var r: Rect2 = dead.get_global_rect().grow(8.0)
	# 免疫「腰斩」：死亡特效是异步 tween（慢放 1.12s），而 _end_replay 会重建敌卡容器、
	# 把旧容器整个 queue_free —— 正在播动画的卡会连根被砍。先把它挪到屏幕层再播。
	# 不 reparent（2026-11-08 用户指正）：换父节点后位置怎么复位都会偏——卡一律留在原位烧
	dead.set_meta("dying_fx", true)
	var _unused_r := r
	# 调试：QI_SLOW_DEATH 把墨屑/白闪放慢 4 倍，方便截图验收（正常 0.32s）
	# A 方案（2026-11-08 用户定）：抓屏前把卡恢复原色、等一帧渲染 → 拿到「完整又干净」的卡面。
	# 之前直接抓屏拿到的是受击高亮态的卡，碎块发白；用卡自身贴图又丢了卡壳底板。
	var fx_scale := 10.0 if OS.has_environment("QI_SLOW_DEATH") else 1.0
	# 不抓屏：把这张卡单独渲一遍进 SubViewport 再取图——拿到的是卡本身（含黑框/米底），
	# 不受死亡瞬间任何淡出/受击高亮影响（2026-11-08 用户令：直接用我原本这个卡）
	# 焚纸（2026-11-08 用户令）：给卡挂溶解 shader，threshold 0→1 烧穿；不做取图、不切块
	var burn_mat := ShaderMaterial.new()
	burn_mat.shader = load("res://qiforge/assets/card_burn.gdshader")
	burn_mat.set_shader_parameter("threshold", 0.0)
	burn_mat.set_shader_parameter("edge_width", 0.22)
	(dead as CanvasItem).material = burn_mat
	for ch in dead.find_children("*", "CanvasItem", true, false):
		var ci := ch as CanvasItem
		if ci != null:
			ci.material = burn_mat
	var burn_time := 0.25 * fx_scale   # 2026-11-08 用户令：整体压到 0.25s
	# 胜利横幅等到溶解播完再弹（这一行之前被误删了，补回）
	_death_fx_until = maxi(_death_fx_until, Time.get_ticks_msec() + int(0.45 * fx_scale * 1000.0))
	var twb := create_tween()
	twb.tween_method(func(v: float) -> void: burn_mat.set_shader_parameter("threshold", v),
		0.0, 1.0, burn_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	twb.tween_callback(func() -> void:
		if is_instance_valid(dead):
			dead.queue_free())
	return
	# 原卡立刻撤下（碎块已经接管画面）
	dead.queue_free()

func _spawn_qi_motes(n: int, origin: Vector2) -> void:
	# 路线（2026-11-06 用户令）：从弃牌堆**左侧**起飞 → 绕到气珠**上方** → 从**右下偏中心**进入。
	# 三次贝塞尔，比直线多一个「绕过目标」的弧，读起来是气在流动而不是子弹。
	var orb := find_child("QiWidget", true, false) as Control
	var entry := (orb.get_global_rect().get_center() - global_position) if orb != null \
		else Vector2(1583.0, 726.0)
	var from := origin + Vector2(-64.0, -26.0)
	var cnt := mini(n, 12)
	var made: Array = []
	var entry_angs: Array = []
	var durs: Array = []
	var slots: Array = _qi_orbit.plan_slots(cnt) if _qi_orbit != null else []
	var step := 0.055
	var fly := 1.8 if OS.has_environment("QI_SLOW_FLY") else 0.95   # 入轨前要减速到接近轨道速度
	for i in cnt:
		# 与轨道气珠同一外观（同一实例一路走到底）
		var mote := QI_ORBIT.make_bead(18.0)   # 与轨道气粒同尺寸同外观
		made.append(mote)
		var sz := mote.size.x
		mote.pivot_offset = mote.size * 0.5
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.modulate = Color(1, 1, 1, 0.0)
		# 与轨道气粒**同一绝对层级**（轨道 66 + 子 2 = 68）：并入时层级不变，才不会掉层闪一下
		mote.z_index = 68
		add_child(mote)
		# 每次现算一条捕获螺旋（随机入口角，跨度不足自动加圈）
		var entry_deg: float = fmod(float(i) * 47.0 + float(_rail_seed) * 31.0, 360.0)
		var rail: Dictionary = _make_rail(entry, entry_deg)
		var path: PackedVector2Array = rail["pts"]
		var slot_ang: float = float(rail["entry"])
		var join_t: float = float(rail["join_t"])
		var join_th: float = float(rail["join_th"])
		var trail := Line2D.new()
		trail.width = 6.0
		var wc := Curve.new()
		wc.add_point(Vector2(0.0, 0.05))
		wc.add_point(Vector2(0.55, 0.55))
		wc.add_point(Vector2(1.0, 1.0))
		trail.width_curve = wc
		trail.default_color = Color(0.30, 0.48, 0.80, 0.85)
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.z_index = 67   # 拖尾压在气珠之上、气粒之下
		trail.modulate.a = 0.0
		add_child(trail)
		var en_ang: float = slot_ang
		entry_angs.append(en_ang)
		# 速度曲线：起点快，**终点恰好等于轨道线速度**（相切 + 同速 = 无缝入轨）
		var plen: float = _path_len(path)
		# 时长按路径长度自适应：螺旋越长越慢，不会因为“路变长”而显得一直在冲
		var dur: float = clampf(plen / 760.0, 0.85, 1.95)
		durs.append(dur)
		var v_end: float = QI_ORBIT.SPIN * 70.0
		var v_beg: float = maxf(360.0, 2.0 * plen / maxf(dur, 0.05) - v_end)
		var k0: float = clampf(v_beg * dur / maxf(plen, 1.0), 0.0, 3.0)
		var k1: float = clampf(v_end * dur / maxf(plen, 1.0), 0.0, 1.0)
		var qa: float = k0 + k1 - 2.0
		var qb: float = 3.0 - 2.0 * k0 - k1
		var tw := mote.create_tween()
		tw.tween_interval(float(i) * step)
		tw.tween_method(func(raw: float) -> void:
			var t: float = clampf(qa * raw * raw * raw + qb * raw * raw + k0 * raw, 0.0, 1.0)
			var p := _path_point(path, t)
			mote.position = p - mote.size * 0.5
			var pts := PackedVector2Array()
			var span: float = lerpf(0.14, 0.012, t)
			for k in 7:
				var u: float = maxf(0.0, t - float(k) * span * 0.16)
				pts.append(_path_point(path, u))
			pts.reverse()
			trail.points = pts
			var vis := clampf(t * 1.2, 0.0, 1.0)
			var a0: float = maxf(0.65, sin(vis * PI) * 0.98)
			# 飞行途中经过气珠**背面**时同样要被挡住（与轨道气粒同一套规则）：
			# 进入珠面越多越透明——否则会看到气粒从珠子正面穿过去
			var off: Vector2 = p - entry
			if off.y < 0.0:
				var hide: float = clampf((56.0 - off.length()) / 22.0, 0.0, 1.0)
				a0 *= (1.0 - hide * 0.95)
			mote.modulate.a = a0
			# 最后半圈＝已经在环绕轨道上，按角度决定层级：后半圈必须在气珠**后面**
			if t >= join_t:
				var u2: float = clampf((t - join_t) / maxf(0.0001, 1.0 - join_t), 0.0, 1.0)
				var th_now: float = join_th + PI * u2
				mote.z_index = 65 if sin(th_now) < 0.0 else 68
			# 拖尾在最后 25% 行程内淡出到 0：避免到站后还留一条亮线（看起来像「闪一下」）
			trail.modulate.a = mote.modulate.a * 0.9 * clampf((1.0 - t) / 0.25, 0.0, 1.0)
			# 末端被吸进去：缩小
			mote.scale = Vector2.ONE   # 全程不变形：并入后由轨道按深度接管
		, 0.0, 1.0, dur)
		tw.tween_property(trail, "modulate:a", 0.0, 0.06)
		tw.tween_callback(trail.queue_free)
	# 不再飘 +1（2026-11-06 用户裁定）：气粒入轨本身已经表达了数量，数字只做珠内跳变
	for j2 in cnt:
		var arrive_j: float = float(j2) * step + float(durs[j2] if j2 < durs.size() else 0.95)
		var twj := create_tween()
		twj.tween_interval(arrive_j)
		twj.tween_callback(func() -> void:
			if _qi_orbit != null and j2 < made.size():
				_try_adopt(made[j2], float(entry_angs[j2])))
	var tw2 := create_tween()
	var max_dur := 0.0
	for dd in durs:
		max_dur = maxf(max_dur, float(dd))
	tw2.tween_interval(float(cnt - 1) * step + maxf(max_dur, 0.9))
	tw2.tween_callback(func() -> void:
		_qi_pop()
		if _qi_orbit != null:
			_qi_orbit.hold = false
			_qi_orbit.set_value(maxi(0, _qi_orbit._pending)))

## 环外绕行路径：起点 → 外圈入口 → 沿外圈到目标角 → 径向切进轨道
func _qi_path(from: Vector2, slot_ang: float, center: Vector2, lane := 0.0) -> PackedVector2Array:
	# 外圈绕行 + **螺旋收轨**：最后一段一边向内收、一边沿切向前进，
	# 终点与轨道相切，并入时不需要改方向（2026-11-06 用户指正“吸附感”）
	var fx_out: float = 1.38 + lane * 0.18
	var fy_out: float = 2.20 + lane * 0.30
	var tilt := -0.20
	var a0 := PI
	var da := wrapf(slot_ang - a0, 0.0, TAU)     # 只顺时针
	var spiral := 0.95                            # 螺旋段覆盖的角度
	var da_arc: float = maxf(0.0, da - spiral)
	var pts := PackedVector2Array()
	pts.append(from)
	var steps := 14
	for k in steps + 1:
		var a: float = a0 + da_arc * float(k) / float(steps)
		pts.append(_ring_pt(center, a, fx_out, fy_out, tilt))
	for k in range(1, 13):
		var u: float = float(k) / 12.0
		var a: float = a0 + da_arc + spiral * u
		pts.append(_ring_pt(center, a, lerpf(fx_out, 1.0, u), lerpf(fy_out, 1.0, u), tilt))
	return pts

func _ring_pt(center: Vector2, a: float, fx: float, fy: float, tilt: float) -> Vector2:
	return center + Vector2(cos(a) * 86.0 * fx, sin(a) * 34.0 * fy).rotated(tilt)

## 受击：四周暗红晕 + 血珠缩一下 + 伤害数字（2026-11-07 用户令：不做敌方特效）
func _player_hit_fx(dmg: int, mhp: int) -> void:
	if _hit_vignette == null:
		return
	# 红晕强度按**伤害占比**线性给：1 点伤害只是淡淡一粉，半血伤害才压到深红
	var ratio: float = clampf(float(dmg) / maxf(float(mhp), 1.0), 0.0, 1.0)
	var heavy: bool = ratio >= 0.5
	var peak: float = clampf(0.05 + ratio * 1.05, 0.05, 0.55)
	var tw := _hit_vignette.create_tween()
	tw.tween_property(_hit_vignette, "modulate:a", peak, 0.07)
	tw.tween_property(_hit_vignette, "modulate:a", 0.0, 0.30)
	var orb := find_child("HpWidget", true, false) as Control
	if orb != null:
		var base := orb.scale
		var t2 := orb.create_tween()
		t2.tween_property(orb, "scale", base * Vector2(0.90, 0.90), 0.06).set_trans(Tween.TRANS_QUAD)
		t2.tween_property(orb, "scale", base * Vector2(1.06, 1.06), 0.10).set_trans(Tween.TRANS_BACK)
		t2.tween_property(orb, "scale", base, 0.14)
		var ctr: Vector2 = orb.get_global_rect().get_center() - global_position
		var fl := Label.new()
		fl.text = "-%d" % dmg
		QISTYLE.font(fl, 40 if heavy else 34, true)
		QISTYLE.text_color(fl, Color(0.78, 0.13, 0.09))
		fl.add_theme_color_override("font_outline_color", Color(0.99, 0.96, 0.90, 0.95))
		fl.add_theme_constant_override("outline_size", 5)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fl.z_index = 93
		fl.position = ctr + Vector2(-14.0, -62.0)
		fl.modulate.a = 0.0
		add_child(fl)
		var t3 := fl.create_tween()
		t3.tween_property(fl, "modulate:a", 1.0, 0.06)
		t3.parallel().tween_property(fl, "position:y", fl.position.y - 34.0, 0.55)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t3.parallel().tween_property(fl, "modulate:a", 0.0, 0.26).set_delay(0.30)
		t3.tween_callback(fl.queue_free)
	_enemy_attack_lunge()
	_hide_intents(0.85)   # 2026-11-07 用户令：敌人攻击时，总行为条与敌卡底光先隐去
	if heavy:
		_hit_stop(52)
		_shake(2.5, 0.12)


## 意图可见性（2026-11-08 用户口径）：只有**玩家可操作**时显示；
## 自动播放/特效演出/敌人行动/弃抽阶段一律隐藏。
func _intents_should_show() -> bool:
	if battle == null:
		return false
	if String(battle.phase) != "player":
		return false
	if Time.get_ticks_msec() < _fx_busy_until:
		return false
	return true

## 立即按判据刷新意图可见性
func _sync_intents() -> void:
	var show := _intents_should_show()
	if _intent_bar != null:
		_intent_bar.visible = show
	for a in _all_intent_auras():
		a.visible = show
## 敌人出手期间隐去「总行为条 + 敌卡底光」，攻击结束后再出现
func _hide_intents(dur: float) -> void:
	_intents_hidden = true
	if _intent_bar != null:
		_intent_bar.visible = false
	_apply_intent_hidden()
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func() -> void:
		_intents_hidden = false
		_sync_intents())   # 按"玩家是否可操作"决定给不给看

## 把当前所有敌卡的意图底光藏起来（重建后也要再调一次）
func _apply_intent_hidden() -> void:
	for a3 in _all_intent_auras():
		a3.visible = false

## 当前敌阵里所有意图底光（活节点）
func _all_intent_auras() -> Array:
	var out: Array = []
	if _enemy_row == null:
		return out
	for h in _enemy_row.get_children():
		for c in h.get_children():
			if c is Control:
				var a3 := (c as Control).get_node_or_null("IntentAura") as CanvasItem
				if a3 != null:
					out.push_back(a3)
	return out

## 敌方出招：攻击意图的敌卡**前冲**一下（2026-11-07 用户令：改成前冲，不做刀光）
func _enemy_attack_lunge() -> void:
	var cards: Array = []
	for h in _enemy_row.get_children():
		for c in h.get_children():
			if c is Control and c.has_meta("euid"):
				var k := _intent_kind(int(c.get_meta("euid")))
				if k == "attack":
					cards.append(c)
	for k in cards.size():
		var card: Control = cards[k]
		var base: Vector2 = card.position
		var tw := card.create_tween()
		tw.tween_property(card, "position", base + Vector2(-26.0, 8.0), 0.10)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "position", base, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 受击红晕贴图（中间透明、四周暗朱）
static var _vig_cache: Texture2D = null
static func _vignette_tex() -> Texture2D:
	if _vig_cache != null:
		return _vig_cache
	var g := Gradient.new()
	# 竖向渐变：上端透明 → 下端不透明（贴合手牌区分界线）
	g.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.30),
		Color(1, 1, 1, 1.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = 128
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	_vig_cache = t
	return t

## 到站：入口角度被占用就先挂在轨道末端等（2026-11-06 用户令：不许重叠，宁可等）
func _try_adopt(n: Control, ang: float) -> void:
	if _qi_orbit == null:
		return
	if _qi_orbit.angle_busy(ang, 0.44):
		var tw := create_tween()
		tw.tween_interval(0.05)
		tw.tween_callback(func() -> void: _try_adopt(n, ang))
		return
	_qi_orbit.adopt(n, ang)

## 五条**固定的连接轨道**（2026-11-06 用户方案「棒棒糖」）：
## 每条从弃牌堆附近起，末端**与环绕轨道相切**地接上去；轨道本身不绘制。
const RAIL_ANGLES := [170.0, 135.0, 100.0, 65.0, 30.0]   # 入口角（度，屏幕坐标 0=右 90=下）
var _qi_rails: Array = []
var _rail_seed := int(Time.get_ticks_msec() / 1000) % 5                                 # PackedVector2Array + 入口角

## 捕获螺旋（2026-11-06 定稿）：一个函数 f(θ) 描述整条轨道。
##   f = 1 + (f0-1)(1-u)^2 ,  u=(θ-θ0)/span
## 性质：f 恒 ≥ 1（在环外）、f'(span)=0（接点切线＝轨道切线）、θ 单调（全程顺时针）。
## 跨度不足 120° 时加整整一圈（把半径收缩摊到更长角度，避免曲率爆掉）。
const RAIL_MIN_SPAN := 2.0944      # 120°

func _make_rail(center: Vector2, entry_deg: float) -> Dictionary:
	var a: float = deg_to_rad(entry_deg)
	var th0 := PI * 0.5                     # 起点：弃牌堆在气珠正下方
	var tile := 2.0 * PI
	_rail_tilt = -0.20
	var span := wrapf(a - PI - th0, 0.0, tile)
	while span < RAIL_MIN_SPAN:
		span += tile
	var f0 := maxf(2.0, (_discard_center() - center).length() / 70.0)
	var pts := PackedVector2Array()
	var n := 90
	for i in n + 1:
		var u: float = float(i) / float(n)
		var th: float = th0 + span * u
		var f: float = 1.0 + (f0 - 1.0) * (1.0 - u) * (1.0 - u)
		pts.append(_rail_pt(center, th, f))
	# 后段：半圈完全走环绕轨道（f=1）
	var join_th := th0 + span
	for i in range(1, 61):
		pts.append(_rail_pt(center, join_th + PI * float(i) / 60.0, 1.0))
	return {"pts": pts, "join_t": float(n) / float(n + 60), "join_th": join_th, "entry": a}

var _rail_tilt := -0.20

func _rail_pt(center: Vector2, th: float, f: float) -> Vector2:
	return center + Vector2(cos(th) * 86.0 * f, sin(th) * 34.0 * f).rotated(_rail_tilt)

func _path_len(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total

func _path_point(path: PackedVector2Array, t: float) -> Vector2:
	if path.size() < 2:
		return path[0] if path.size() == 1 else Vector2.ZERO
	var total := 0.0
	var seg: Array = []
	for i in range(path.size() - 1):
		var d := path[i].distance_to(path[i + 1])
		seg.append(d)
		total += d
	if total <= 0.001:
		return path[0]
	var want: float = clampf(t, 0.0, 1.0) * total
	var acc := 0.0
	for i in range(seg.size()):
		var d: float = seg[i]
		if acc + d >= want:
			var u: float = (want - acc) / maxf(d, 0.0001)
			return path[i].lerp(path[i + 1], u)
		acc += d
	return path[path.size() - 1]

func _cbez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)

func _qbez(p0: Vector2, c: Vector2, p1: Vector2, t: float) -> Vector2:
	var a := p0.lerp(c, t)
	var b := c.lerp(p1, t)
	return a.lerp(b, t)

## 珠内数字弹一下（最后一颗到账时）
func _qi_pop() -> void:
	var lbl := find_child("QiText", true, false) as Label
	if lbl == null:
		return
	lbl.pivot_offset = lbl.size * 0.5
	var t1 := lbl.create_tween()
	t1.tween_property(lbl, "scale", Vector2(1.42, 1.42), 0.09)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.parallel().tween_property(lbl, "modulate", Color(1.18, 1.22, 1.30, 1), 0.09)
	t1.tween_property(lbl, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.parallel().tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.18)

var _qi_mote_cache: Texture2D = null
func _qi_mote_tex() -> Texture2D:
	if _qi_mote_cache != null:
		return _qi_mote_cache
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	g.colors = PackedColorArray([
		Color(0.72, 0.86, 1.0, 1.0), Color(0.40, 0.62, 0.94, 0.98),
		Color(0.22, 0.40, 0.72, 0.55), Color(0.16, 0.30, 0.56, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 96
	t.height = 96
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_qi_mote_cache = t
	return t

## 洗牌表现（2026-11-06）：两个牌堆一起抖（牌从弃牌堆洗回抽牌堆，两边都变了），
## 两个计数都跳；气从**来源牌堆**升起（src=discard→弃牌堆，src=played→已打出区）
func _on_piles_shuffled(src: String) -> void:
	for nm in ["DrawPile", "DiscardPile"]:
		var pile := find_child(nm, true, false) as Control
		if pile == null:
			continue
		var base := pile.position
		var tw := pile.create_tween()
		for i in 4:
			var off := Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
			tw.tween_property(pile, "position", base + off, 0.035)
		tw.tween_property(pile, "position", base, 0.07)
	for ln in ["DrawCount", "DiscardCount"]:
		var lbl := find_child(ln, true, false) as Label
		if lbl == null:
			continue
		lbl.pivot_offset = lbl.size * 0.5
		lbl.scale = Vector2.ONE
		var tw2 := lbl.create_tween()
		tw2.tween_property(lbl, "scale", Vector2(1.38, 1.38), 0.09)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(lbl, "modulate", Color(1.35, 1.20, 0.85, 1), 0.09)
		tw2.tween_property(lbl, "scale", Vector2.ONE, 0.16)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.16)
	# 洗牌换气：回复量＝几颗气，一颗一分（2026-11-06 用户令「按实际回复量」）
	var gained := 0
	if battle != null and _qi_prev >= 0:
		gained = int(battle.player["qi"]) - _qi_prev
		if gained > 0:
			if _qi_orbit != null:
				_qi_orbit.hold = true        # 先别追平，等气粒飞到再一颗颗入轨
			var origin := _discard_center()
			if src == "played":
				origin = Vector2((PLAYED_X + 216.0 * 0.5), (PLAYED_TOP + PLAYED_BOTTOM) * 0.5)
			_spawn_qi_motes(gained, origin)
		if OS.has_environment("QI_DEBUG_CENTERS"):
			print("[shuffle] gained=", gained, " src=", src)
	# 洗牌特效过后再抽牌（逻辑层对接）：登记占线墙钟
	_cardq.push_wait(0.32)   # 洗牌占位延时命令（2026-11-12 原版制：added 屏障统一覆盖「洗完再抽」）

## 洗牌换气：N 点气 = N 颗小气粒，从抽牌堆沿弧线飞进气珠（2026-11-06 用户令）
## 每颗带一条短拖尾；最后一颗到账时气珠跳数字＋飘 +N
## 把行动条对准敌卡的实际中心（不是视口中心——卡片有既定排布）
func _place_intent_bar() -> void:
	if _intent_bar == null or _enemy_row == null:
		return
	var x0 := 1e9
	var x1 := -1e9
	for h in _enemy_row.get_children():
		for c in h.get_children():
			if c is Control and c.has_meta("euid"):
				var r: Rect2 = (c as Control).get_global_rect()
				x0 = minf(x0, r.position.x)
				x1 = maxf(x1, r.position.x + r.size.x)
	if x1 < x0:
		return
	_intent_bar.position.x = (x0 + x1) * 0.5 - _intent_bar.size.x * 0.5
	_intent_bar.position.y = 176.0

## 敌方这回合的动作类型（2026-11-07 意图接口化：走 battle.intent_kind_of 公共口——
## 不行动的敌〔后排／补位顶替第一回合／缴械冰冻〕返回空＝无意图光带，杜绝显示层偷跑）
func _intent_kind(uid: int) -> String:
	if battle == null:
		return ""
	for e in battle.encounter["active"]:
		if int(e["uid"]) == uid:
			var k: String = battle.intent_kind_of(e)
			if k == "attack" or k == "multi":
				return "attack"
			if k == "armor":
				return "armor"
			return ""
	return ""

## 卡下沿光带（运行期生成）：竖直方向由上到下渐隐、水平方向中间实两头虚。
## 读作「卡牌下边框在往下发光」，而不是「卡底下放了个灯」。
static var _glow_cache: Texture2D = null
static func _glow_tex() -> Texture2D:
	if _glow_cache != null:
		return _glow_cache
	var w := 96
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v: float = 1.0 - float(y) / float(h - 1)
		v = pow(v, 1.7)
		for x in w:
			var u: float = absf(float(x) / float(w - 1) - 0.5) * 2.0
			var hf: float = clampf((1.0 - u) / 0.45, 0.0, 1.0)
			hf = pow(hf, 1.4)
			img.set_pixel(x, y, Color(1, 1, 1, v * hf))
	_glow_cache = ImageTexture.create_from_image(img)
	return _glow_cache

## 敌人剪影色（按名字哈希分色，敌种可辨；亮度压过近黑底）
func _enemy_tint(nm: String) -> Color:
	var palette: Array = [Color("8f9aa8"), Color("9a86a8"), Color("a87f7f"),
		Color("7fa890"), Color("a8946e")]
	return palette[absi(nm.hash()) % palette.size()]

func _mk_enemy_hbox() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
#endregion

#region 手牌（老战斗屏手感全制移植 2026-11-01 用户裁定「和之前一样」＋改点击施放）
## 牌堆真实中心（2026-11-06 用户发现：老屏常量把卡飞去了屏幕外）
func _pile_center(node_name: String, fallback: Vector2) -> Vector2:
	var c := find_child(node_name, true, false)   # 这两个节点没有 unique name，按名字找
	if c is Control:
		var cc := c as Control
		# 动画锚「看得见的牌堆贴图」（2026-11-11 修偏下）：容器 rect（116 高）比视觉
		# 牌堆贴图（98 高、顶部对齐）大一截——锚容器中心比视觉牌堆低 ~9px，飞牌落点
		# 看着沉到剑柄牌堆下方。原版飞向视图真实布局位＝视觉位（CardAddedViewCommand
		# 协程编排、终点＝TryAddCard 的 slot 位，非写死坐标）
		for ch in cc.get_children():
			if ch is TextureRect and String(ch.name).find("Stack") >= 0:
				return (ch as TextureRect).get_global_rect().get_center() - global_position
		return cc.get_global_rect().get_center() - global_position
	return fallback

func _draw_center() -> Vector2:
	return _pile_center("DrawPile", DRAW_PILE_CENTER)

func _discard_center() -> Vector2:
	return _pile_center("DiscardPile", DISCARD_PILE_CENTER)

## 屏级扇排＋帧 Lerp 逼近（k=Δ×7）＋焦点瞬弹（只弹内层卡面 ×1.5，壳稳定）＋邻牌不让位；
## 新抽卡自抽牌堆位飞入；消失卡（打出/冲弃）飞向弃牌堆位缩小淡出（0.32s、stagger 0.05）。
func _rebuild_hand() -> void:
	var old_uids := {}
	for w in _hand_wraps:
		old_uids[int(w.get_meta("hand_uid", -1))] = true
	var new_uids := {}
	for card in battle.hand:
		new_uids[int(card["uid"])] = true
	if OS.has_environment("QI_DEBUG_CENTERS"):
		print("[centers] draw=", _draw_center(), " discard=", _discard_center())
	var fly_i := 0
	var removed_ct := 0
	var drawn_ct := 0
	for card in battle.hand:
		if not old_uids.has(int(card["uid"])):
			drawn_ct += 1
	var played_now := {}
	for pcard in battle.played_pile:
		played_now[int(pcard["uid"])] = true
	for w in _hand_wraps:
		var wuid := int(w.get_meta("hand_uid", -1))
		if not new_uids.has(wuid):
			if wuid == _played_uid:
				_anim_card_play_out(w)   # 打出的卡：先出招——落区/碎裂由 play_out 尾段分流
			elif played_now.has(wuid):
				continue                  # 已打出区接管（play_all 等非点击路径；_rebuild_played 已收）
			elif _shattered_uids().has(wuid):
				_anim_card_shatter(w)    # 2026-11-06 碎牌：play_all 连打中碎掉的卡——原地碎裂消散
			else:
				_anim_card_fly(w, float(fly_i) * 0.05)
				fly_i += 1
				removed_ct += 1
		else:
			w.queue_free()
	_played_uid = -1
	_hand_wraps = []
	var new_i := 0   # 新抽卡错峰序（2026-11-05 开局抽牌动画）
	for card in battle.hand:
		var w := Control.new()
		w.name = "HandCard%d" % int(card["uid"])
		# 壳加高盖住「原位＋弹起位」两段：壳管一切事件（悬停稳定＋弹起卡可点＋底部空区不误触）
		w.size = Vector2(HAND_W, HAND_H + HAND_LIFT + HAND_SHELL_EXTRA)
		w.set_meta("hand_uid", int(card["uid"]))
		var vdef: Dictionary = CARD.tcg_def_of(card["def"])
		vdef["qi"] = battle.card_cost(card)   # 费用活查询（free 卡显示 0——选卡免一次费可见）
		# 〔2026-11-08 状态制退役〕need 槽实/虚联动（own_stances）——式层数池已退役，注入删
		vdef["crack_level"] = clampi(int(card.get("uses", 0)) - 2, 1, 3)   # 用 3 次=轻、4=中、（5=重）
		vdef["combo_gold"] = battle.card_lv(card) > 0   # 动态升级：已升级的卡费用转金（2026-11-10 起，等级>0＝升过）
		vdef["cracked"] = battle.is_cracked(card)   # 2026-11-06 碎牌：裂痕态卡面画裂纹
		vdef["cur_form"] = String(vdef.get("stance", "")) if OS.has_environment("QI_MATCH_TEST") else String(battle.current_form)   # 型符号高亮用
		var vis: Control = _make_tilt_view(vdef)
		vis.position = _vis_rest(vis)
		w.set_meta("vc_card", vis.get_meta("vc_card"))
		w.add_child(vis)
		# 〔影子不搬〕原版卡下有 112×112 艺术图软影（实测偏移 (10,35)，游玩几乎不可见——
		# 2026-11-11 用户裁定撤：Godot 硬边近似比原版重、弊大于利；真值存 references 参数表〕
		var the_uid := int(card["uid"])
		var the_wrap := w
		w.mouse_filter = Control.MOUSE_FILTER_STOP
		w.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_play_clicked(the_uid))
		w.mouse_entered.connect(func() -> void: _set_hand_focus(the_wrap))
		# 焦点收起不走 mouse_exited（2026-11-03 修「放大后移上去缩回」）：弹起的卡上半截
		# 探出壳矩形会误触离开事件——改 StS2 制每帧轮询＋迟滞（见 _hand_lerp_tick 焦点保持判据）
		# 词条浮窗组件（2026-11-10 原版 KeywordTooltip 制）：挂卡 wrap 下、与卡同生共死
		# （手牌重建＝wrap 销毁＝浮窗随销，孤儿结构上不存在）；组装/定位归组件
		var kw_tip := KW_TIP.new()
		kw_tip.setup(w, {
			"tilt_fn": func() -> float: return w.rotation,
			"anchor_fn": func() -> Rect2: return _card_visual_rect(w),
			"corners_fn": func() -> PackedVector2Array: return _card_face_corners(w),
			"avoid": _hud_avoid()})
		w.set_meta("kw_tip", kw_tip)
		add_child(w)
		_hand_wraps.push_back(w)
		if not old_uids.has(the_uid):
			# 新抽卡：起点＝抽牌堆中心（卡面视觉位），飞入手位由帧 Lerp 接管；
			# 2026-11-05 用户令「开局抽牌动画」：按序错峰 0.07s 一张张飞（从堆里抽一叠的节奏）；
			# 2026-11-11 起编入卡动画命令队列（原版 CardAddedViewCommand 制）：
			# 「先弃完再抽」（2026-11-06 用户令普适版）＋洗牌让路＝队列 added 全局屏障
			# 天然覆盖；错峰 0.07＝命令 WaitFor 错峰。起点姿态先钉在抽堆（fly_in 大延迟
			# 扣住帧 Lerp 不偷跑），命令起飞瞬间释放（launch 置 0）
			w.position = _draw_center() - Vector2(HAND_W, HAND_H) * 0.5 - Vector2(0.0, HAND_LIFT)
			w.scale = Vector2(0.35, 0.35)
			w.rotation = randf_range(-0.22, 0.22)
			w.modulate.a = 0.25
			w.set_meta("fly_in", true)
			w.set_meta("fly_in_delay", 9999.0)
			_cardq.push("added", w, _start_added_cmd, 0.0,
				int(w.get_meta("hand_uid", -1)), true)   # barrier＝先弃完再抽＋串行节拍（0.2/张流水）
			new_i += 1
		# 手牌重建＝旧 wrap 全销毁（2026-11-09 修孤儿浮窗；2026-11-10 组件挂卡下后
		# 结构上已同死，此处显式关＝原版 OnRemovedFromHand 状态转移关窗的行为对齐）：
		print("[VCDIAG][hand] rebuild-drop host_valid=%s" % [is_instance_valid(_kw_tip_host)])   # [VCDIAG] 临时埋点
		_hide_kw_tips()
		_hide_card_preview()
		_hand_focus = null
	# 终局隐藏单向化（2026-11-11 修「手牌隐藏后又闪现」）：终局后任何 changed 触发的
	# 重建（选卡落点/经验到账等），新 wrap 一律保持收起——原版同语义＝离开玩家回合后
	# 手牌交互失效，胜利时序 DiscardHand 弃走，不存在「重新出现」
	if _finale:
		for w in _hand_wraps:
			if is_instance_valid(w):
				w.visible = false
	_layout_hand(false)
	_refresh_playability()

## 消失卡飞出：飞向弃牌堆位缩小淡出（打出/冲弃同走——打出进弃牌堆语义同）
## 消失卡飞弃：进卡动画命令队列（2026-11-12 原版制改造——原 tween 编排搬进启动器，
## 完成回调交队列落定；墙钟登记退役）。手牌冲弃（_rebuild_hand）与已打出区回收
## （_rebuild_played）两路共用本口。
func _anim_card_fly(w: Control, delay: float) -> void:
	_cardq.push("removed", w, _start_removed_cmd, delay,
		int(w.get_meta("hand_uid", -1)))

## removed 命令启动器：飞向弃牌堆缩小淡出（0.32s）。错峰归队列（at 时间戳消化，启动器
## 不吃 delay——再 interval 会双计）。签名＝(payload, done)：payload＝卡 wrap
func _start_removed_cmd(payload, done: Callable) -> void:
	var w := payload as Control
	if not is_instance_valid(w):
		done.call()
		return
	_kill_card_tween(w)   # 互杀保护（2026-11-06）：打出即触发回收链时 play_out/落位 tween 先废
	var tw := create_tween()
	w.set_meta("card_tween", tw)
	var half: Vector2 = w.size * w.scale * 0.5      # 已打出区的卡是缩小态，按实际尺寸居中
	tw.tween_property(w, "position", _discard_center() - half
		- Vector2(0.0, HAND_LIFT), 0.32)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(w, "scale", Vector2(0.3, 0.3), 0.32)
	tw.parallel().tween_property(w, "rotation", 0.15, 0.32)
	tw.parallel().tween_property(w, "modulate:a", 0.0, 0.3).set_delay(0.06)
	tw.tween_callback(w.queue_free)
	tw.tween_callback(done)   # 卡落弃堆（含销毁）＝命令落定（原版 TryAddCard 完成位）

## fx 效果表现命令启动器（2026-11-12 原版制·SetValueCommand 同构占位）：数据已同步
## 结算，此处表现——现在＝刷新（血球/气珠/牌堆计数即时跳）＋落定；将来 heal 飘字/
## 护甲光效挂此（挂动画时 done 延到动画完）
func _launch_fx_cmd(payload, done: Callable) -> void:
	_refresh()
	done.call()

## added 命令启动器：释放帧 Lerp（fly_in 清零）＋淡入。原版 CardAddedViewCommand 节奏
## （2026-11-12 ISIL 实证）：动画全部 fire-and-forget（旋转/缩放/mover/淡入启动即走），
## 命令长度＝固定等 postDrawWait 0.2 → 下一张 0.2s 节拍接续＝连续流水（上一张刚落
## 下一张起飞）——不等淡入完成（旧版段落感真凶：串行卡等 alpha 0.3s＋at 顺延加隔）
func _start_added_cmd(payload, done: Callable) -> void:
	var w := payload as Control
	if not is_instance_valid(w):
		done.call()
		return
	if w.has_meta("fly_in"):
		w.set_meta("fly_in_delay", 0.0)   # 起飞：帧 Lerp 下一帧接管飞入手位
	var twb := w.create_tween()
	twb.tween_property(w, "modulate:a", 1.0, 0.3)   # 淡入与飞行并行（fire-and-forget）
	var twa := w.create_tween()
	twa.tween_interval(HAND_DRAW_STAGGER)
	twa.tween_callback(done)

func _play_clicked(card_uid: int) -> void:
	if String(battle.phase) != "player" or result_pending():
		return
	var clicked_cid := ""
	for c in battle.hand:
		if int(c["uid"]) == card_uid:
			if not battle.can_play(c):
				# 原版点击不可付费＝摇头反馈（PlayableCard.TryPlayCard else PlayInvalidCardShake）
				var w_bad := _hand_wrap_of(card_uid)
				if w_bad != null and w_bad.get_child_count() > 0:
					(w_bad.get_child(0) as Control).set_meta("shake_t", HAND_SHAKE_TIME)
				return
			clicked_cid = String(c.get("id", ""))
			break
	_set_hand_focus(null)
	# 连打制（2026-11-09 对齐原版「输入不锁动画、命令排队」）：数据层当帧出账
	# （扣气/连击/账单算定——原版 TryPlayCard 立即 Execute 同构）；演出簿记**不在此碰**——
	# 拍驱动串行化，本张排队等上一张播完才起拍（原版 CommandRunner 单协程队列同构）。
	battle.play_card(card_uid)   # changed → _refresh → _rebuild_hand（打出的卡走「出招」动画）
	_queue_replay({"uid": card_uid, "cid": clicked_cid,
		"from": _hand_card_center(card_uid), "gen": battle.play_gen(),
		"total": battle.strike_total()})

## 拍驱动串行化（2026-11-09 连打制）：同一时刻只有一个拍驱动在跑；连打时后张排队，
## 前张收尾（_end_replay＋按代落余账）后才轮到它起拍——簿记（_hit_events/_dying/
## _last_beat/_replay_on）归活跃驱动独占，连打不再互相踩。
func _queue_replay(req: Dictionary) -> void:
	_replay_queue.push_back(req)
	_pump_replay()

func _pump_replay() -> void:
	if _replay_active or _replay_queue.is_empty():
		return
	_replay_active = true
	var req: Dictionary = _replay_queue.pop_front()
	_played_uid = int(req["uid"])
	_played_cid = String(req["cid"])
	_played_from = req["from"]
	_hit_events.clear()
	if QI_FXSPEC.has_spec(_played_cid):
		_replay_on = true
		_dying.clear()
		_last_beat.clear()
	_run_thrust(int(req["gen"]), int(req["total"]))

## 拍驱动收尾：收尸＋只落本代余账（不吞排队的下家）→ 放行下一个排队的拍
func _finish_replay(gen: int) -> void:
	if is_instance_valid(battle):
		if is_inside_tree():
			_end_replay()
		battle.settle_all_strikes(gen)
	_replay_active = false
	_pump_replay()

func result_pending() -> bool:
	return _overlay != null and is_instance_valid(_overlay)

## 可打性（老屏同制）：法力不足＝整卡压灰＋费用徽描边转红，实时随 changed 连锁
func _refresh_playability() -> void:
	var i := 0
	for w in _hand_wraps:
		var card: Dictionary = battle.hand[i] if i < battle.hand.size() else {}
		i += 1
		if card.is_empty() or w.get_child_count() == 0:
			continue
		var ok: bool = battle.can_play(card)
		var vis: Control = w.get_child(0)
		vis.modulate = Color(1, 1, 1, 1.0) if ok else Color(0.52, 0.52, 0.52, 0.92)
		var pip: Node = (w.get_meta("vc_card") as Node).find_child("CostPip", false, false)
		if pip != null:
			var icon: Node = pip.find_child("QiIcon", false, false)
			if icon is TextureRect:
				(icon as TextureRect).modulate = Color(1, 1, 1, 1) if ok else Color(1.0, 0.55, 0.5, 1.0)

## 手牌布局（2026-11-11 原版 1:1 资产真值轮）：曲线扇形（弧 32/角 15°/≤2 张不扇）
## ＋悬停翼内劈开（repel 曲线＋split 随 6→20 张过渡）；本函数只落目标位（meta tgt_*），
## 位移动画统一走 _process 速度寻的（_hand_lerp_tick）；焦点卡保留扇角（原版悬起不拍平）。
func _layout_hand(animate: bool) -> void:
	var n := _hand_wraps.size()
	if n == 0:
		return
	var mid := float(n - 1) / 2.0
	var vp := get_viewport_rect().size
	var fi := -1
	if _hand_focus != null and is_instance_valid(_hand_focus):
		fi = _hand_wraps.find(_hand_focus)
	# 间距＝卡间步距（中心距）封顶 115×1.2（2026-11-12 用户实测体感裁定：步距非净距——
	# 3 卡重叠紧凑扇；劈开推量 77 恰好把重叠邻牌推到完整露出，数字链自洽）；带内只压缩不拉伸
	var step := minf(HAND_SPACING_MAX,
		(HAND_BAND - HAND_W) / maxf(1.0, float(n - 1)))
	# 悬停劈开（原版 GetSelectedCardOffset）：split 随牌数 6→20 过渡，repel 曲线按翼内距离取值
	var repel_c := hand_repel_curve()
	var split_t := clampf((float(n) - HAND_SPLIT_MIN_N) / (HAND_SPLIT_MAX_N - HAND_SPLIT_MIN_N), 0.0, 1.0)
	var split_l := lerpf(HAND_SPLIT_L.x, HAND_SPLIT_L.y, split_t)
	var split_r := lerpf(HAND_SPLIT_R.x, HAND_SPLIT_R.y, split_t)
	for i in n:
		var w: Control = _hand_wraps[i]
		var shift := 0.0
		if fi >= 0 and i != fi:
			# 衰减输入归一化（2026-11-12 ISIL 实测定案，推翻旧推定）：左翼 t=(i+1)/sel、
			# 右翼 t=(n-i)/(n-1-sel)——相邻卡 t=1（推满基量）、翼端 t=1/翼宽（略减）
			if i < fi:
				var d_l := clampf((float(i) + 1.0) / float(fi), 0.0, 1.0)
				shift = -(split_l + repel_c.sample_baked(d_l) * HAND_REPEL_MAX + HAND_REPEL_BASE)
			else:
				var d_r := clampf((float(n) - float(i)) / float(n - 1 - fi), 0.0, 1.0)
				shift = split_r + repel_c.sample_baked(d_r) * HAND_REPEL_MAX + HAND_REPEL_BASE
		var x := vp.x * 0.5 + (i - mid) * step + shift - HAND_W * 0.5
		# 〔弧＝平排〕2026-11-12 实机图＋汇编双证定案：原版 FanCardPosition（弧）是**死代码**
		# ——AlignChildrenAlongAxis 对次轴（Y）直接弹栈返回，AlignOnSecondaryAxis 从未被调用，
		# 槽位 Y 全由锚点决定＝齐平。两次 F6（不抬高/不下沉）皆用户对。弧常量与曲线已退役，
		# 真值与六环证据链存 references 参数表 §一·六。
		# 2026-11-04 用户令「手牌贴住屏幕底边」：行锚＝屏底；同日续令整体上提 5px
		var y := vp.y - (HAND_H + HAND_LIFT + HAND_SHELL_EXTRA) - 5.0
		# 扇角（原版 FanCardRotation）：n≥3 线性 −1..+1 ×15°、≤2 张无倾角
		var t_r := ((float(i) / float(n - 1)) * 2.0 - 1.0) if n > 2 else 0.0
		var rot := t_r * HAND_ROT_MAX
		w.set_meta("fan_rot", rot)    # 浮窗梯度用：扇内角度（焦点卡回正不影响这里）
		var vis: Control = w.get_child(0)
		vis.pivot_offset = Vector2(vis.size.x * 0.5, (vis.size.y - HAND_H) * 0.5 + HAND_H * 0.5)
		# 旋转/缩放轴心＝卡面中心（2026-11-12 实测原版卡 RectTransform pivot (0.5,0.5)；
		# 旧壳底边轴心令 ±15° 顶端摆幅加倍——「倾斜太夸张」真凶）
		w.pivot_offset = Vector2(HAND_W * 0.5, HAND_LIFT + HAND_SHELL_EXTRA + HAND_H * 0.5)
		var is_focus := fi == i
		if is_focus:
			# 原版悬起不拍平（保留扇角）；弹起/放大动画归 _apply_hover_anim tween
			w.scale = Vector2.ONE
			w.z_index = 60
			vis.z_index = 0
		else:
			w.z_index = 10 + i   # 右压左；基础 10 起步，保证压在受击红带(3)与剑(5)之上
			vis.z_index = 0
		if not animate and not w.has_meta("fly_in"):
			w.position = Vector2(x, y)
			w.rotation = rot
			w.scale = Vector2.ONE
			if not is_focus:
				vis.rotation = 0.0
				vis.position = _vis_rest(vis)
		w.set_meta("tgt_pos", Vector2(x, y))
		w.set_meta("tgt_rot", rot)

func _process(delta: float) -> void:
	_cardq.tick()   # 卡动画命令队列驱动（2026-11-12 原版制：到点无阻塞即启动）
	if battle != null:
		battle.tick_cmds()   # 敌方动作/效果表现命令驱动（原版 CommandRunner 同构）
	_hand_lerp_tick(delta)
	# 顿帧收尾：墙钟判，不能用补间（time_scale 会连补间一起缩放）
	if _hit_stop_until > 0 and Time.get_ticks_msec() >= _hit_stop_until:
		_hit_stop_until = 0
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	if _hit_stop_until > 0:          # 换屏/退出时绝不能把 time_scale 留在 0.08
		_hit_stop_until = 0
		Engine.time_scale = 1.0
	if get_tree() != null and get_tree().paused:
		QI_PAUSE.release_all()       # 冻结残留兜底（2026-11-08 世界暂停制；11-09 改引用计数全清）

func _hand_lerp_tick(delta: float) -> void:
	const K := 7.0
	var snap_d := 0.75
	for w in _hand_wraps:
		var hw: Control = w
		if not hw.has_meta("tgt_pos"):
			continue
		# 抽牌错峰：delay 未到不飞（2026-11-05 开局抽牌动画）
		var tp: Vector2 = hw.get_meta("tgt_pos")
		var tr: float = hw.get_meta("tgt_rot")
		if hw.has_meta("fly_in_delay"):
			var dl: float = float(hw.get_meta("fly_in_delay"))
			if dl > 0.0:
				hw.set_meta("fly_in_delay", dl - delta)
				continue
			hw.remove_meta("fly_in_delay")
			# 抽牌飞行＝定长 0.2s（2026-11-12 修：原版 drawCardConfig 实测——微移走 mover(750)、
			# 长途飞行走 0.2s 补间制；初版把 750 套到 850px 飞行＝匀速爬 0.95s，慢三倍）
			hw.set_meta("fly_speed", maxf(1.0, hw.position.distance_to(tp)) / HAND_DRAW_TIME)
		var k: float = minf(delta * K, 1.0)
		# 位移＝速度＋减速带寻的（2026-11-11 原版 TransformMover2D 同构——匀速接近、
		# 进减速带按距离比例刹车、到达即停：替换指数 lerp 的「越近越慢」软感）
		if hw.has_meta("fly_speed"):
			_seek_2d(hw, tp, delta, float(hw.get_meta("fly_speed")))
		else:
			_seek_2d(hw, tp, delta)
		hw.rotation = lerpf(hw.rotation, tr, k)
		hw.scale = hw.scale.lerp(Vector2.ONE, k)
		var vis: Control = hw.get_child(0)
		var rest: Vector2 = _vis_rest(vis)
		var shake := _shake_off(vis, delta)
		if hw != _hand_focus:
			# 收回：位置寻的回静止位（缩放收回走 _apply_hover_anim 的 tween）
			vis.rotation = lerpf(vis.rotation, 0.0, k)
			_seek_2d(vis, Vector2(rest.x + shake, rest.y), delta)
		else:
			# 焦点卡：抬起量按可付费分档（hover_lift 由 _apply_hover_anim 落）
			var lift: float = float(vis.get_meta("hover_lift", HAND_LIFT))
			vis.rotation = lerpf(vis.rotation, 0.0, k)
			_seek_2d(vis, Vector2(rest.x + shake, rest.y - lift), delta)
		if hw.position.distance_squared_to(tp) < snap_d and absf(hw.rotation - tr) < 0.001:
			hw.position = tp
			hw.rotation = tr
			hw.scale = Vector2.ONE
			if hw.has_meta("fly_speed"):
				hw.remove_meta("fly_speed")
	# —— 倾斜/光效驱动（2026-11-03）：鼠标指哪边哪边朝里倒＋近侧边框反光；离开回正 ——
	_tilt_t += delta
	var mouse: Vector2 = get_global_mouse_position()
	# 焦点保持判据（StS2 制轮询＋迟滞）：命中区＝壳矩形 ∪ 弹起后卡面矩形——
	# 鼠标在弹起的卡上半区（探出壳外）不丢焦点；两个矩形都离开才收起
	# 悬停进入＝每帧轮询卡面矩形（从最右/最上层往下找），不依赖壳的 mouse_entered
	# hover 进入门（2026-11-11 补终局门）：终局后手牌不可交互（原版＝离开玩家回合即失效
	# ——PlayerTurnState 外手牌点击/hover 全关；我方打出已有 phase 门，这里补 hover 轮询）
	if _hand_focus == null and not _finale and not _hand_wraps.is_empty() and not has_meta("shot_no_hover"):
		for i in range(_hand_wraps.size() - 1, -1, -1):
			var ww: Control = _hand_wraps[i]
			if ww.get_child_count() == 0:
				continue
			if _card_hit(ww, mouse):
				_set_hand_focus(ww)
				break
	if _hand_focus != null and is_instance_valid(_hand_focus) and _hand_focus.get_child_count() > 0:
		# 焦点保持＝卡面命中（容差 2px）∪ 词条浮窗（2026-11-11 判定简化：悬停动画变轻后
		# 拆掉「四边形∪外接框外扩 10px」双保险层——边界抖感的根源是重动画全挂在 hover 上）
		var hold: bool = _card_hit(_hand_focus, mouse, 2.0)
		if not hold:
			hold = _kw_tip_over(mouse)   # 鼠标移到浮窗上仍保持"指着"（2026-11-10 组件 pointer_over）
		if not hold and not has_meta("shot_no_hold"):
			_set_hand_focus(null)
	# 词条浮窗跟随卡位（原版 CheckTooltipScreenPos 每帧重摆同构）：随扇形布局/弹起动画走
	if _kw_tip_host != null and is_instance_valid(_kw_tip_host):
		var kwt = _kw_tip_host.get_meta("kw_tip", null)
		if kwt != null:
			kwt.check_screen_pos()
	for w in _hand_wraps:
		var hw2: Control = w
		if hw2.get_child_count() == 0:
			continue
		var tv: Control = hw2.get_child(0)
		var mat: ShaderMaterial = tv.material as ShaderMaterial
		if mat == null:
			continue
		var r: Rect2 = tv.get_global_rect()
		var ctr: Vector2 = r.position + r.size * 0.5
		# 归一用「当前视觉卡面」半宽高（折掉外扩 margin；含弹起缩放）——
		# 修「放到顶部没倾斜」：旧版按静止半高判 ±1，弹起后探出区全被误判不在卡内
		var half: Vector2 = r.size / (2.0 * TILT_MARGIN)
		var nv: Vector2 = Vector2((mouse.x - ctr.x) / maxf(1.0, half.x), (mouse.y - ctr.y) / maxf(1.0, half.y))
		var inside: bool = absf(nv.x) < 1.0 and absf(nv.y) < 1.0
		var tip_tgt := Vector2.ZERO
		if inside:
			tip_tgt = -Vector2(clampf(nv.x, -1.0, 1.0), clampf(nv.y, -1.0, 1.0)) * TILT_MAX
		# 往复扫（2026-11-08 用户令）：原来 fmod 到顶就瞬间跳回起点，很突兀；改成 0→0.72→0 往返，
		# 且覆盖 ±0.72 整段（0.72≈卡面对角线归一值），从最左上角扫到最右下角
		var cyc: float = fmod(_tilt_t * 0.20, 2.0)
		var sheen_tgt: float = (cyc if cyc <= 1.0 else 2.0 - cyc) * 0.72
		if OS.has_environment("QI_FREEZE_SHEEN"):
			sheen_tgt = 0.40
		var kk: float = clampf(delta * TILT_SMOOTH, 0.0, 1.0)
		var tip: Vector2 = (tv.get_meta("tip", Vector2.ZERO) as Vector2).lerp(tip_tgt, kk)
		var sheen: float = lerpf(float(tv.get_meta("sheen", 0.2)), sheen_tgt, kk)
		var hov: float = lerpf(float(tv.get_meta("hov", 0.0)), 1.0 if inside else 0.0, kk)
		if OS.has_environment("QI_FORCE_TIP"):
			tip = Vector2(0.5, 0.3)
		# 金件光带流转（2026-11-08）：外框与分割线共用同一材质，band_pos 随时间扫过 → 一起亮
		var vc0 = hw2.get_meta("vc_card", null)
		if vc0 != null and is_instance_valid(vc0) and vc0.glint_mat != null:
			var phase: float = float(tv.get_meta("sheen", 0.2))   # 与斜切扫光同一相位 → 光和框一起走
			vc0.glint_mat.set_shader_parameter("band_pos", phase)
			vc0.glint_mat.set_shader_parameter("tip_x", tip.x)   # 金属高光跟着倾斜走
			vc0.glint_mat.set_shader_parameter("tip_y", tip.y)
		tv.set_meta("tip", tip)
		tv.set_meta("sheen", sheen)
		tv.set_meta("hov", hov)
		mat.set_shader_parameter("tip_x", tip.x)
		mat.set_shader_parameter("tip_y", tip.y)
		mat.set_shader_parameter("sheen_phase", sheen)
		mat.set_shader_parameter("hover", hov)

## 手牌倾斜视图（2026-11-03 用户令）：真卡渲进 SubViewport（2× 超采保清晰）→
## 贴图＋单应透视/边缘反光着色器。内层＝纯贴图，事件全归外壳（手牌标准做法）。
func _make_tilt_view(def: Dictionary) -> TextureRect:
	var vp := SubViewport.new()
	vp.size = Vector2i(roundi(HAND_W * TILT_SS), roundi(HAND_H * TILT_SS))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X   # 卡面框线抗锯齿（2026-11-08 用户指正外框锯齿）
	var card: Control = CARD.make_tcg_card(def, "hand")
	card.theme = QIFONTS.default_theme()   # SubViewport 不吃根窗主题
	card.scale = Vector2(TILT_SS, TILT_SS)
	vp.add_child(card)
	var mat := ShaderMaterial.new()
	mat.shader = TILT_SHADER
	mat.set_shader_parameter("strength", 0.09)
	mat.set_shader_parameter("uv_scale", TILT_MARGIN)
	if OS.has_environment("QI_FORCE_TIP"):
		mat.set_shader_parameter("tip_x", 0.5)
		mat.set_shader_parameter("tip_y", 0.3)
	mat.set_shader_parameter("glint_strength", 1.0)
	var tex := TextureRect.new()
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 斜切采样抗锯齿
	tex.name = "TiltView"
	tex.add_child(vp)   # 视口随贴图层同生共死
	tex.texture = vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.size = Vector2(HAND_W, HAND_H) * TILT_MARGIN
	tex.material = mat
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 内层纯贴图——事件全归外壳
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.set_meta("vc_card", card)
	tex.set_meta("tip", Vector2.ZERO)
	tex.set_meta("sheen", 0.2)
	tex.set_meta("hov", 0.0)
	return tex

## 贴图层静止位：贴图比卡面外扩一圈 margin——把内区卡面对回壳的卡位
func _vis_rest(vis: Control) -> Vector2:
	return Vector2(-(vis.size.x - HAND_W) * 0.5, HAND_LIFT + HAND_SHELL_EXTRA - (vis.size.y - HAND_H) * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed \
			or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _hand_focus == null or not is_instance_valid(_hand_focus) or _hand_focus.get_child_count() == 0:
		return
	var vis: Control = _hand_focus.get_child(0)
	var r: Rect2 = vis.get_global_rect()
	var m: float = (TILT_MARGIN - 1.0) * HAND_W * 0.5
	if r.grow(-m).has_point((event as InputEventMouseButton).position):
		_play_clicked(int(_hand_focus.get_meta("hand_uid", -1)))
		accept_event()

func _set_hand_focus(w: Control) -> void:
	if _hand_focus == w:
		return
	# 抽牌飞行中不接焦点（2026-11-12 用户令：飞行中不放大，落地后鼠标仍指着→下一帧轮询
	# 自然接管。原版 dump 未见专门门（deal 命令无交互锁），但其 deal 0.2s 窗口极小；
	# 我方轮询进焦点＋飞行缩放 0.35×悬停 1.5 相乘曾致飞行中明显放大）
	if w != null and (w.has_meta("fly_in_delay") or w.has_meta("fly_speed")):
		return
	# 换焦＝旧卡词条条撤（2026-11-07 用户令分条制：每词条一条独立浮条、只放词条——
	# 卡名/描述等卡面已有信息一律不重复；不带具体数值）
	_hide_kw_tips()
	var prev := _hand_focus
	_hand_focus = w
	if w != null and not get_meta("shot_no_tip", false):
		_show_kw_tips(w)
		_show_card_preview(w)
	else:
		_hide_card_preview()
	_apply_hover_anim(prev, w)
	_layout_hand(true)

## —— 手牌运动/悬停四帮手（2026-11-11 原版 1:1 轮）——

## 速度＋减速带寻的（原版 TransformMover2D 同构）：匀速接近→进减速带按距离比例刹车→到达即停
func _seek_2d(c: Control, target: Vector2, delta: float, speed := HAND_MOVE_SPEED) -> void:
	var d := target - c.position
	var dist := d.length()
	if dist <= 0.001:
		c.position = target
		return
	var v := speed
	if dist < HAND_DECEL:
		v = speed * clampf(dist / HAND_DECEL, 0.02, 1.0)
	var step := v * delta
	if step >= dist:
		c.position = target
	else:
		c.position += d / dist * step

## 不可付费摇头（invalidShake 5/0.3s/vibrato 15）：正弦横摆、按剩余时长衰减；返回本帧 x 偏移
func _shake_off(vis: Control, delta: float) -> float:
	if not vis.has_meta("shake_t"):
		return 0.0
	var t: float = float(vis.get_meta("shake_t")) - delta
	if t <= 0.0:
		vis.remove_meta("shake_t")
		return 0.0
	vis.set_meta("shake_t", t)
	return sin(t * TAU * 15.0) * HAND_SHAKE_AMP * (t / HAND_SHAKE_TIME)

func _hand_card_of(w: Control) -> Dictionary:
	if battle == null:
		return {}
	var uid := int(w.get_meta("hand_uid", -1))
	for c in battle.hand:
		if int(c["uid"]) == uid:
			return c
	return {}

func _hand_wrap_of(uid: int) -> Control:
	for w in _hand_wraps:
		if int((w as Control).get_meta("hand_uid", -1)) == uid:
			return w
	return null

## 悬停两级视觉（原版 DoCardHoveredAnim/DoCardUnhoveredAnim 同构）：
## 可付费＝×1.5/抬 45.6；不可付费＝×1.05/抬 18。〔影子不搬——用户裁定〕
## 缩放走 tween——ease 实测（游戏自带 DOTween.dll 反编译枚举）：
## 上＝InOutCubic（scaleUpEase 10）、收＝OutBack（scaleDownEase 27）；时长 scaleDuration 0.05。
## 抬起位移目标落 meta，由 _hand_lerp_tick 寻的。
## 摇头不挂悬停（2026-11-12 修：原版 PlayableCard.TryPlayCard else PlayInvalidCardShake
## ＝点击不可付费才摇头；初版误挂悬停进入）。
func _apply_hover_anim(prev: Control, next: Control) -> void:
	if prev != null and is_instance_valid(prev) and prev.get_child_count() > 0:
		var pv: Control = prev.get_child(0)
		_kill_hover_tween(pv)
		pv.set_meta("hover_lift", 0.0)
		var tw := pv.create_tween()
		tw.tween_property(pv, "scale", Vector2.ONE, HAND_SCALE_DUR)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pv.set_meta("hover_tween", tw)
	if next != null and is_instance_valid(next) and next.get_child_count() > 0:
		var card := _hand_card_of(next)
		var ok: bool = card.is_empty() or battle.can_play(card)   # 取不到卡数据（异常）按可付费
		var nv: Control = next.get_child(0)
		_kill_hover_tween(nv)
		nv.set_meta("hover_lift", HAND_LIFT if ok else HAND_LIFT_BAD)
		var tw2 := nv.create_tween()
		tw2.tween_property(nv, "scale", HAND_POP if ok else HAND_POP_BAD, HAND_SCALE_DUR)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		nv.set_meta("hover_tween", tw2)

func _kill_hover_tween(vis: Control) -> void:
	if vis.has_meta("hover_tween"):
		var t = vis.get_meta("hover_tween")
		if t is Tween and t.is_valid():
			t.kill()

## 悬卡词条条（分条制，2026-11-07）：竖排于卡右侧，一条一词条（名亮＋说明暗），各条独立
## 悬卡词条（2026-11-10 原版制改版）：组装与显示全归卡下组件（GetCardTooltips＋
## SetActive 同构——无词条不显示，原版无「兜底全文」；卡面 desc 承载全文）
func _show_kw_tips(w: Control) -> void:
	var uid := int(w.get_meta("hand_uid", -1))
	var def := {}
	for c in battle.hand:
		if int(c["uid"]) == uid:
			def = c["def"]
			break
	if def.is_empty():
		return
	var tip = w.get_meta("kw_tip", null)
	if tip == null:
		return
	_kw_tip_host = w
	print("[VCDIAG][hand] kw-show uid=%s" % [uid])   # [VCDIAG] 临时埋点（2026-11-09 排查，完撤）
	if tip.refresh(def):
		tip.set_active(true)

#region 悬卡预览（2026-11-08 立，照用户口径：红字黑框／致命金框／后排小括号／气珠·血球旁 +N）
## 数据源＝battle.preview_play（只读干跑，与实战同源，绝不落账）
func _show_card_preview(w: Control) -> void:
	_hide_card_preview()
	if battle == null or battle.phase != "player":
		return
	var uid := int(w.get_meta("hand_uid", -1))
	var card := {}
	for c in battle.hand:
		if int(c["uid"]) == uid:
			card = c
			break
	if card.is_empty() or not battle.can_play(card):
		return
	var dp: Dictionary = battle.preview_play(card)
	if not bool(dp.get("ok", false)):
		return
	_ensure_preview_layer()
	# ① 敌人伤害（前排＝红字黑框；致命＝金框；后排＝右下角小括号）
	var dmg: Dictionary = dp.get("damage", {})
	var kills: Array = dp.get("kills", [])
	for euid in dmg:
		var val := int(dmg[euid])
		if val <= 0:
			continue
		var cc: Control = _enemy_cards.get(int(euid))
		if cc == null or not is_instance_valid(cc):
			continue
		_mk_dmg_mark(cc, val, kills.has(int(euid)), _enemy_row_of(int(euid)) > 0)
		# 击退标记（2026-11-08 用户令）：带击退的卡，对被命中的敌人加一枚「退」小签
		if float(card["def"].get("knockback", 0.0)) > 0.0:
			_mk_kb_mark(cc)
	# ② 气（气珠在 (1495,704) 110×108）
	var qi := int(dp.get("qi", 0))
	if qi > 0:
		_mk_res_mark("QiText", "+%d" % qi, Color(0.96, 0.80, 0.32))
	# ③ 护盾（血心在 (315,704) 110×108）
		var ar := int(dp.get("armor", 0))
		if ar > 0:
			_mk_res_mark("HpText", "+%d" % ar, Color(0.62, 0.84, 1.0))

func _hide_card_preview() -> void:
	for n in _preview_nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_preview_nodes = []

func _ensure_preview_layer() -> void:
	if _preview_layer != null and is_instance_valid(_preview_layer):
		return
	_preview_layer = Control.new()
	_preview_layer.z_index = 92
	_preview_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_preview_layer)

func _enemy_row_of(euid: int) -> int:
	for e in battle.encounter.get("active", []):
		if int(e["uid"]) == euid:
			return int(e.get("row", 0))
	return 0

## 伤害标（2026-11-08 用户令）：主数字居中；小数字放主数字下面、左对齐、无描边；不套任何矩形框
func _mk_dmg_mark(cc: Control, val: int, lethal: bool, back_row: bool) -> void:
	var r := cc.get_global_rect()
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = r.position
	holder.size = r.size
	_preview_layer.add_child(holder)
	var fs := 46
	var l := Label.new()
	l.text = str(val)
	QISTYLE.font(l, fs, true)
	l.add_theme_color_override("font_color", Color(0.89, 0.16, 0.18))
	l.add_theme_color_override("font_outline_color",
		Color(0.96, 0.80, 0.32) if lethal else Color(0.05, 0.03, 0.03))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 居中＝让标签铺满整张卡再居中对齐（不能拿「估算宽度」的盒子去居中——之前就是这里错位）
	l.position = Vector2(0.0, r.size.y * 0.5 - float(fs) * 0.95)
	l.size = Vector2(r.size.x, float(fs) * 1.5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(l)
	if back_row:
		var sm := Label.new()
		sm.text = str(int(float(val) * 0.5))
		QISTYLE.font(sm, 26, false)
		sm.add_theme_color_override("font_color", Color(0.80, 0.30, 0.28))
		sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 小数字：与主数字同一行，挂在它的右下方（不居中、不靠右）
		var tw := QIFONTS.noto().get_string_size(str(val), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		sm.position = Vector2(r.size.x * 0.5 + tw * 0.5 + 3.0, l.position.y + float(fs) * 0.78)
		sm.size = Vector2(80.0, 32.0)
		holder.add_child(sm)
	_preview_nodes.push_back(holder)

## 资源标：气珠/血心旁浮一个 +N——跟伤害数字同族（彩色数字＋黑描边），锚真实控件而非写死坐标
## 击退小签（预览用）：被命中敌卡右上一枚琥珀「退」字签——与伤害标同构
## （holder 定位敌卡矩形＋登记清理清单。2026-11-09 修两 bug：旧版未进 _preview_nodes
## 致换焦/打出后签永不清理（残留屏幕）、坐标拿敌卡尺寸当 layer 偏移致签挂屏幕
## 左上不贴敌卡）
func _mk_kb_mark(target: Control) -> void:
	var r := target.get_global_rect()
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = r.position
	holder.size = r.size
	_preview_layer.add_child(holder)
	var l := Label.new()
	l.text = "退"
	QISTYLE.font(l, 22, true)
	l.add_theme_color_override("font_color", Color(0.98, 0.78, 0.26))
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.06, 0.95))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(r.size.x - 26.0, r.size.y * 0.42)
	holder.add_child(l)
	_preview_nodes.push_back(holder)

func _mk_res_mark(anchor_name: String, amount: String, col: Color) -> void:
	var a := find_child(anchor_name, true, false) as Control
	if a == null:
		return
	var r := a.get_global_rect()
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = r.position + Vector2(r.size.x - 6.0, -14.0)
	holder.size = Vector2(140.0, 52.0)
	_preview_layer.add_child(holder)
	var l := Label.new()
	l.text = amount
	QISTYLE.font(l, 38, true)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2.ZERO
	l.size = Vector2(100.0, 52.0)
	holder.add_child(l)
	_preview_nodes.push_back(holder)
#endregion

## 气珠/血心＝禁区：浮窗压到它们就翻边（2026-11-08 用户令：从右换成左就行）
func _hud_avoid() -> Array:
	var out: Array = []
	for n in ["QiText", "HpText"]:
		var c := find_child(n, true, false) as Control
		if c != null:
			out.push_back(c)
	return out

func _hide_kw_tips() -> void:
	print("[VCDIAG][hand] kw-hide valid=%s" % [is_instance_valid(_kw_tip_host)])   # [VCDIAG] 临时埋点
	if _kw_tip_host != null and is_instance_valid(_kw_tip_host):
		var tip = _kw_tip_host.get_meta("kw_tip", null)
		if tip != null:
			tip.set_active(false)
	_kw_tip_host = null

## 鼠标是否在当前词条浮窗上（hold 判定——2026-11-10 组件制）
func _kw_tip_over(mouse: Vector2) -> bool:
	if _kw_tip_host == null or not is_instance_valid(_kw_tip_host):
		return false
	var tip = _kw_tip_host.get_meta("kw_tip", null)
	return tip != null and tip.pointer_over(mouse)

## 卡面真实外接矩形（焦点态卡面被放大上浮，外层壳尺寸对不上——浮窗锚这个而不是壳）
func _card_visual_rect(w: Control) -> Rect2:
	if not is_instance_valid(w):
		return Rect2()
	if w.get_child_count() == 0:
		return w.get_global_rect()
	var pts := _card_face_corners(w)
	if pts.is_empty():
		return w.get_global_rect()
	var mn: Vector2 = pts[0]
	var mx: Vector2 = pts[0]
	for q in pts:
		mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.y))
		mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.y))
	return Rect2(mn, mx - mn)

## 鼠标是否指着这张卡：直接判「点在卡面四边形内」（不再用外接框+收边凑数）
func _card_hit(w: Control, p: Vector2, pad := 0.0) -> bool:
	var q := _card_face_corners(w)
	if q.size() != 4:
		return false
	var sign0 := 0.0
	for i in 4:
		var a: Vector2 = q[i]
		var b: Vector2 = q[(i + 1) % 4]
		var e := b - a
		var len := e.length()
		if len < 0.001:
			continue
		var n := Vector2(-e.y, e.x) / len      # 边法线（朝外/朝内一致）
		var d := n.dot(p - a) - pad
		if absf(d) < 0.001:
			continue
		var sg := signf(d)
		if sign0 == 0.0:
			sign0 = sg
		elif sg != sign0:
			return false
	return true

## 卡面「左上/右上」顶角（浮窗按它对齐——外接框的极值点会偏出去一大截）
func _card_corner(w: Control, right: bool) -> Vector2:
	var pts := _card_face_corners(w)
	if pts.size() != 4:
		return Vector2(-1e9, -1e9)
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	if right:
		a = pts[1]
		b = pts[2]
	return a if a.y <= b.y else b

## 卡面四角（屏幕坐标）——浮窗按「靠近自己那一侧的顶角」对齐，斜卡才不会悬在上方
func _card_face_corners(w: Control) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not is_instance_valid(w) or w.get_child_count() == 0:
		return out
	var vis: Control = w.get_child(0)
	# 贴图层是 TILT_MARGIN（1.18）倍，真正看得见的卡面居中、只有 HAND_W×HAND_H
	var face := Rect2((vis.size.x - HAND_W) * 0.5, (vis.size.y - HAND_H) * 0.5, HAND_W, HAND_H)
	var xf := vis.get_global_transform_with_canvas()
	# 卡面被 shader 斜切（tip 归一化 ±0.5）时，节点几何没变——把斜切量换算成像素补上，
	# 浮窗/命中都用「看得见的那张歪卡」（2026-11-08 用户令：鼠标动浮窗也要动）
	var q := [
		xf * face.position,
		xf * Vector2(face.end.x, face.position.y),
		xf * face.end,
		xf * Vector2(face.position.x, face.end.y)]
	# —— 粘着：把 shader 造成的「边缘位移」算成像素补到四角上（2026-11-08 用户令）——
	# shader：t = p/denom + 0.5，denom = 1 + tip_x*0.09*p.x*2 + tip_y*0.09*p.y*2
	# 卡面可见边＝|p/denom| = 0.5 → p = 0.5/(1 - 0.09*tip_x)；再除 uv_scale 1.18 得 UV 位移
	var tv3: Vector2 = vis.get_meta("tip", Vector2.ZERO)
	var sc3: float = vis.scale.x
	var dux := (0.5 / (1.0 - 0.09 * tv3.x) - 0.5) / 1.18
	var duy := (0.5 / (1.0 - 0.09 * tv3.y) - 0.5) / 1.18
	var dx := dux * HAND_W * sc3
	var dy := duy * HAND_H * sc3
	# 纵向语义（2026-11-08 用户指正）：指针往上＝上边框后退（远离观者）→ 顶边**往下收**；
	# 指针往下＝上边框靠近观者 → 顶边**往上抬**。故纵向取反，横向不变。
	q[1] += Vector2(dx, dy)    # TR
	q[2] += Vector2(dx, -dy)   # BR
	q[3] += Vector2(-dx, -dy)  # BL
	q[0] += Vector2(-dx, dy)   # TL
	for v in q:
		out.push_back(v)
	return out
#endregion

## 战报事件（原版事件行已撤——此处留钩子，后面接飘字/日志）
func _on_event(text: String) -> void:
	if _event_lbl != null:
		_event_lbl.text = text

## ══ 战斗特效轮（2026-11-06 用户令：先把直刺这一刀做成完整闭环）══════════════
## 时序：手牌出招 0.11s → 笔锋 0.09s → 命中（白闪＋顿帧＋屏震＋墨点＋数字）→ 卡入弃牌堆。
## 目标矩形在**旧节点**上快照（changed 之后敌阵会整批重建），特效因此不依赖卡片存活。
const HIT_STOP_MS := 34

## 手牌卡中心（全局）：笔锋起点
func _hand_card_center(uid: int) -> Vector2:
	for w in _hand_wraps:
		if int(w.get_meta("hand_uid", -1)) == uid:
			var r: Rect2 = (w as Control).get_global_rect()
			return Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.4)
	return Vector2(960.0, 900.0)

## 命中收集（2026-11-08 落账延迟制后此槽退役为调试计数：演出事件改由 _run_thrust 从
## battle.strike_snapshot() 快照驱动——hit_landed 现在在击中帧才发，不再用于预收集）
func _on_hit_landed(target: Dictionary, amount: int, kind: String, crit: bool = false) -> void:
	pass

func _find_enemy_card(uid: int) -> Control:
	if _enemy_row == null:
		return null
	for h in _enemy_row.get_children():
		for c in h.get_children():
			if c is Control and c.has_meta("euid") and int(c.get_meta("euid")) == uid:
				return c
	return null

func _run_thrust(gen: int, total_strikes: int) -> void:
	# ── 落账延迟（2026-11-08 对齐原版：账单在打出瞬间算定，逐击中帧才结算跳数）──
	# ── 余段空放制（2026-11-08 同日续裁）：演出拍数＝卡总段数（strike_total），与账单
	#    事件数解耦——怪死掉后余下的段刀照飞（空放：无闪白无数字），最后一把收招
	#    才收口终局（对应原版武器飞完全程＋胜利 WaitWhile 等表现清空）。
	# ── 连打制（2026-11-09）：本驱动只消费**自己这一代**的账单（快照按代过滤）——
	#    连打时后张排队，前张收尾按代落账，互不吞拍。
	# rect 预快照：结算后敌卡可能重建/消失——演出全程用打出手那刻的卡位。
	var strikes: Array = battle.strike_snapshot(gen)
	var rects := {}
	for e2 in battle.encounter["active"]:
		var card2 := _find_enemy_card(int(e2["uid"]))
		if card2 != null:
			rects[int(e2["uid"])] = card2.get_global_rect()
	var beats: Array = VC_TARGETING.map_strike_beats(strikes, total_strikes)
	var last_rect := Rect2()
	for b in beats:
		var bd: Dictionary = b
		if bool(bd.get("blank", false)):
			bd["rect"] = last_rect   # 空放拍落点＝最近命中位（尸位）
			continue
		var r2: Rect2 = rects.get(int(bd["uid"]), Rect2())
		if r2.size.x > 1.0:
			last_rect = r2
		bd["rect"] = r2
	_hit_events = beats
	if _combat_fx == null or _hit_events.is_empty():
		_finish_replay(gen)           # 无特效件（哑渲染器）兜底全落（本代）
		return
	# ── 语法轨（2026-11-07 直刺 v1）：有档案的卡走 spec 全套；没档案的继续走旧笔锋线 ──
	# 逐张迁移：每迁一张跑一次截图批验收（design-docs/特效管线_v0.1.md §9 T1）
	if QI_FXSPEC.has_spec(_played_cid):
		var spec2: Dictionary = QI_FXSPEC.get_spec(_played_cid)
		var spec_evs: Array = _hit_events.duplicate()
		_last_beat.clear()
		for i in spec_evs.size():
			var sd: Dictionary = spec_evs[i]
			if bool(sd.get("blank", false)):
				continue        # 空放拍不占「最后击序」
			_last_beat[int(sd.get("uid", -1))] = i
			for du in (sd.get("death_uids", []) as Array):
				_last_beat[int(du)] = i   # 本拍落账的死者：收尸拍号＝本拍（同拍收）
		var from_g: Vector2 = _hp_orb_center()      # 墨箭从血珠周围出发
		var now0 := Time.get_ticks_msec()
		var wait0: float = clampf(float(_fx_busy_until - now0) / 1000.0, 0.0, 0.12)
		var scab := bool(spec2.get("scabbard", false))
		var total: float = 0.52
		if _combat_fx != null:
			total = _combat_fx.scabbard_timing(spec2, spec_evs.size()) if scab \
				else _combat_fx.strike_timing(spec2, spec_evs.size())
		_fx_busy_until = now0 + int(total * 1000.0)
		# 我方出手期间隐去敌方意图；中途敌阵重建时由 _refresh_enemies 再次藏住新节点
		_hide_intents(total)

		if wait0 > 0.0:
			await get_tree().create_timer(wait0, false).timeout
			if not is_inside_tree() or _combat_fx == null:
				_finish_replay(gen)
				return
		if scab:
			_combat_fx.scabbard_strike(spec2, spec_evs, from_g,
				func(ev: Dictionary, i: int) -> void: _on_strike_beat(ev, i),
				func(uid0: int) -> bool: return _find_enemy_card(uid0) != null)
		else:
			_combat_fx.strike(spec2, spec_evs, from_g,
				func(ev: Dictionary, i: int) -> void: _on_strike_beat(ev, i))
		await get_tree().create_timer(total, false).timeout
		_finish_replay(gen)           # 演出收尾：本代账单全落（含语法轨未逐段落的部分）
		return
	# 多段攻击（2026-11-06 用户令）：一次打出 N 段伤害，逐段播放——
	# 第一段走完整刀光，其余段只做「命中闪＋伤害数字」。
	# 段间隔按段数自适应（段多则密），总时长不超过 ~0.45s，避免十段卡两秒。
	var n := _hit_events.size()
	var ev0: Dictionary = _hit_events[0]
	var r0: Rect2 = ev0["rect"]
	var to0: Vector2 = r0.get_center() if r0.size.x > 1.0 else Vector2(960.0, 430.0)
	_combat_fx.thrust(_played_from, to0, func() -> void: _on_thrust_hit(ev0, 0))
	# 错峰：上一张牌的特效还没收完时，这一张晚 0.06s 起手（最多 0.12s，绝不成队列）
	var now_ms := Time.get_ticks_msec()
	var wait: float = clampf(float(_fx_busy_until - now_ms) / 1000.0, 0.0, 0.12)
	_fx_busy_until = now_ms + 100 + int(0.16 * 1000.0)
	if wait > 0.0:
		await get_tree().create_timer(wait, false).timeout
	if not is_inside_tree():
		_finish_replay(gen)           # 中途离树兜底：本代账单全落
		return
	var gap: float = clampf(0.45 / float(maxi(1, n)), 0.035, 0.11)
	for i in range(1, n):
		await get_tree().create_timer(gap, false).timeout
		if not is_inside_tree() or _combat_fx == null:
			_finish_replay(gen)
			return
		_on_thrust_hit(_hit_events[i], i)
	## 演出收尾：未逐段落的账单（爆炸追加段等）一次性落完——对应原版 DoAllRemainingDamage
	_finish_replay(gen)

func _on_thrust_hit(ev: Dictionary, idx := 0) -> void:
	# 拍制落账（2026-11-08 余段空放制）：每拍落 settle 条账（1 hit＋紧随 deaths——
	# 死亡无独立特效，出列/放珠由 refresh 对账驱动）；blank 空放拍不落账无反馈（刀照飞）
	for k in int(ev.get("settle", 0)):
		if battle != null:
			battle.settle_next_strike()
	if bool(ev.get("blank", false)):
		return
	var rect: Rect2 = ev["rect"]
	var at: Vector2 = rect.get_center() if rect.size.x > 1.0 else Vector2(960.0, 430.0)
	if _combat_fx != null:
		# 目标还活着才闪白（打死了＝卡已消失，闪一块白会像穿帮）
		var alive := _find_enemy_card(int(ev["uid"])) != null
		_combat_fx.hit(at, int(ev["amount"]), rect if alive else Rect2(), 0, idx, int(ev["uid"]))
	_hit_stop(HIT_STOP_MS)
	_shake(3.5, 0.12)
	_recoil(int(ev["uid"]))   # 击退推退表现归美术线——kb 数据在拍上待消费
	_beat_death(int(ev["uid"]), idx)
	for du in (ev.get("death_uids", []) as Array):
		_beat_death(int(du), idx)

## 受击后仰（重建会吃掉它——无所谓，那一帧已经打出去了）
## 击退（纯表现，2026-11-08）：被击中且判定击退 → 卡整体向右退出 18px 再回弹归位。
## 逻辑位置不变（蓝本 PlayKnockbackVFX 同口径）。
func _knockback_card(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	var base := card.position
	var tw := card.create_tween()
	tw.tween_property(card, "position", base + Vector2(18.0, 0.0), 0.07)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate", Color(1.35, 1.20, 0.85), 0.07)
	tw.tween_property(card, "position", base + Vector2(-3.0, 0.0), 0.10)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(card, "position", base, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate", Color(1, 1, 1), 0.14)

func _recoil(uid: int, amount := 7.0) -> void:
	var card := _find_enemy_card(uid)
	if card == null:
		return
	var base := card.position
	var brot := card.rotation
	# 抖动：左右 4 下 + 一点旋转，再回位（受击震动，2026-11-08 用户令）
	var tw := card.create_tween()
	for k in 4:
		var amp := amount * (1.0 - 0.2 * float(k))
		var dx := amp * (1.0 if k % 2 == 0 else -1.0)
		tw.tween_property(card, "position", base + Vector2(dx, amp * 0.35), 0.035)\
			.set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(card, "rotation", brot + deg_to_rad(1.6) * (1.0 if k % 2 == 0 else -1.0), 0.035)
	tw.tween_property(card, "position", base, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "rotation", brot, 0.10)

## ── 语法轨每击回调（2026-11-07 直刺 v2）：剑到位的那一帧才做卡面反应与收尸 ──
## 卡面三件：白闪（打中了的主信号）／留洞（穿刺痕迹）／后缩；手感走档案口径（轻）。
func _on_strike_beat(ev: Dictionary, idx: int) -> void:
	# 拍制落账（2026-11-08 余段空放制）：每拍落 settle 条账（1 hit＋紧随 deaths）；
	# blank 空放拍纯飞过——无闪白无顿帧无数字（对应原版死目标段跳过）
	for k in int(ev.get("settle", 0)):
		if battle != null:
			battle.settle_next_strike()
	if bool(ev.get("blank", false)):
		return
	var uid := int(ev.get("uid", -1))
	var crit := bool(ev.get("crit", false))
	var card := _find_enemy_card(uid)
	var at := Vector2(960.0, 430.0)
	if card != null and is_instance_valid(card):
		var cr: Rect2 = card.get_global_rect()
		at = Vector2(cr.position.x + cr.size.x - 12.0, cr.position.y + 16.0)
		_hit_flash(card, 0.50 if crit else 0.30)
		_strike_mark(card, idx, crit)
	_hit_stop(22)
	_shake_throttled(1.8, 0.08)
	_recoil(uid, 6.0)
	# 击退表现（2026-11-08 用户令·方案A）：被推出去一截再弹回，逻辑位不变
	if bool(ev.get("kb", false)):
		_knockback_card(card)   # 击退的推退动画归美术线（2026-11-08 用户令）——kb 数据在拍上待消费
	if _combat_fx != null and int(ev.get("amount", 0)) > 0:
		_combat_fx.number_stack(at, int(ev.get("amount", 0)), idx, crit)
	_check_finale()
	_beat_death(uid, idx)
	for du in (ev.get("death_uids", []) as Array):
		_beat_death(int(du), idx)   # 本拍带走的死者（多亡同拍）同拍收尸放珠

## 卡面白闪（2026-11-07 用户令「做在卡面上」）：整卡压一层白，0.12s 收
func _hit_flash(card: Control, a: float) -> void:
	var p := ColorRect.new()
	p.color = Color(1, 1, 1, a)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2.ZERO
	p.size = card.size
	p.z_index = 52
	card.add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.15)
	tw.tween_callback(p.queue_free)

## 卡面墨点（2026-11-07 用户改为「墨箭命中即消失」）：箭不留长口子，只在卡上
## 砸出一个小墨斑＋几点碎墨，0.4s 收回。多段的数字靠 number_stack 逐个飘。
func _strike_mark(card: Control, idx: int, crit: bool) -> void:
	var center: Vector2 = card.size * 0.5 \
		+ Vector2(randf_range(-34.0, 34.0), randf_range(-40.0, 28.0))
	var root := Node2D.new()
	root.position = center
	root.z_index = 50
	card.add_child(root)
	var blot := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 9:
		var a := TAU * float(k) / 9.0
		var rr := (8.0 if crit else 6.4) * (0.5 + 0.7 * absf(sin(float(k) * 2.4 + 0.8)))
		pts.push_back(Vector2(cos(a), sin(a)) * rr)
	blot.polygon = pts
	blot.color = Color(0.07, 0.06, 0.05, 0.94)
	root.add_child(blot)
	for k in 3:
		var a2 := randf() * TAU
		var d := randf_range(10.0, 30.0)
		var dot := Polygon2D.new()
		var r := randf_range(1.2, 2.8)
		dot.polygon = PackedVector2Array([
			Vector2(-r, -r * 0.6), Vector2(r, -r * 0.8), Vector2(r * 0.7, r * 0.7)])
		dot.position = Vector2(cos(a2), sin(a2)) * d
		dot.color = Color(0.10, 0.08, 0.06, 0.85)
		root.add_child(dot)
	# 一小滴往下拖
	var drip := Line2D.new()
	drip.width = 2.6
	var dc := Curve.new()
	dc.add_point(Vector2(0.0, 1.0))
	dc.add_point(Vector2(1.0, 0.10))
	drip.width_curve = dc
	drip.default_color = Color(0.07, 0.06, 0.05, 0.8)
	drip.add_point(Vector2(1.0, 3.0))
	drip.add_point(Vector2(2.0, randf_range(10.0, 20.0)))
	root.add_child(drip)
	root.scale = Vector2(0.4, 0.4)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2.ONE, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.28)
	tw.tween_property(root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(root.queue_free)

## 血珠中心（全局）：墨箭的发射原点
func _hp_orb_center() -> Vector2:
	var orb := find_child("HpWidget", true, false) as Control
	if orb != null and is_instance_valid(orb):
		return orb.get_global_rect().get_center()
	return _played_from

## 出牌预判收尾：这张牌的推演能把场上所有敌人打死 → 立刻进"不可操作"（手牌收起；
## 按钮不藏——留底无字，2026-11-09 用户令禁连底隐藏）只是隐藏 UI，特效与结算全部照常；
## 判错由 _refresh 的安全阀复原。
## 〔2026-11-11 退役〕预判瞬隐制（_predict_end_and_hide）整体退役——用户令对齐原版：
## 原版无「出牌瞬间预判必胜→手牌瞬隐」路径，交互失效与手牌退场都发生在**死亡结算后**
## （EncounterDefeatedState→离开玩家回合＝交互失效；OnEncounterDefeated→DiscardHand
## ＝手牌走弃牌动画弃走）。我方统一由 _check_finale 在死亡拍一口承担。

## 终局判定（2026-11-08 用户令·按拍判；2026-11-11 对齐原版改版）：这一拍结算后场上
## 已无存活敌人 → ① _finale 置位（交互失效——hover 门/打出 phase 门/按钮无字；
## 按钮不藏留底无字，2026-11-09 用户令）② **手牌走弃牌动画弃走**（原版 OnEncounterDefeated
## →DiscardHand 同构：数据层 hand+played 整体冲弃，表现层 _rebuild_hand 对消失 uid 自动
## 放飞弃堆动画；弃堆计数同步涨）
## 死亡特效保持与平时一致（用户：先保持一致，看了再改）
func _check_finale() -> void:
	if _finale or battle == null:
		return
	if not (battle.encounter["active"] as Array).is_empty():
		return
	_finale = true
	battle.discard_hand_finale()

## 击拍收尸：这一拍就是它的最后一击 → 此刻才放死亡特效＋经验珠
func _beat_death(uid: int, idx: int) -> void:
	if not _dying.has(uid):
		return
	if int(_last_beat.get(uid, -1)) != idx:
		return
	var card = _dying[uid]          # 可能已被释放：不能声明成有类型的变量
	_dying.erase(uid)
	_enemy_cards.erase(uid)
	if is_instance_valid(card):
		# 2026-11-09 用户令：**立即发珠**（珠动画与燃烧动画同步起跑；推翻 11-08「烧完再发珠」）
		_spawn_xp_orb(card.get_global_rect().get_center(), uid)
		_enemy_death_fx(card)

## 回放结束：没等到自己那一拍的死卡（无击事件等）在这里统一收
func _end_replay() -> void:
	if not _replay_on and _dying.is_empty():
		return
	_replay_on = false
	for uid in _dying.keys():
		var card = _dying[uid]      # 同上：可能已释放
		_enemy_cards.erase(uid)
		if is_instance_valid(card):
			_spawn_xp_orb(card.get_global_rect().get_center(), int(uid))
			_enemy_death_fx(card)
	_dying.clear()
	_last_beat.clear()
	if battle != null:
		_refresh_enemies()

## 震屏节流：6 连击若每下起一次 _shake，base 会被上一次的中间位移污染（整屏漂走）
func _shake_throttled(amount: float, dur: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _shake_prev < 90:
		return
	_shake_prev = now
	_shake(amount, dur)

## 屏震：只晃本屏根，不动窗口（窗口位移会露出桌面）
func _shake(amount: float, dur: float) -> void:
	var base := position
	var tw := create_tween()
	for i in 4:
		var off := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tw.tween_property(self, "position", base + off, dur / 5.0)
	tw.tween_property(self, "position", base, dur / 5.0)

## 顿帧：Engine.time_scale 会连自己的计时一起缩放——必须用墙钟收尾
func _hit_stop(ms: int) -> void:
	if _hit_stop_until > 0:
		return
	_hit_stop_until = Time.get_ticks_msec() + ms
	Engine.time_scale = 0.08

## 打出的卡：先向上「出招」再入弃牌堆（原来直接飞弃牌堆＝读作丢牌）
func _anim_card_play_out(w: Control) -> void:
	_kill_card_tween(w)   # 互杀保护（2026-11-06）：同卡旧飞行动画先废再起
	var start := w.position
	var tw := create_tween()
	w.set_meta("card_tween", tw)
	tw.tween_property(w, "position", start + Vector2(0.0, -92.0), 0.07)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(w, "scale", Vector2(1.05, 1.05), 0.07)
	# 2026-11-06 用户裁定：出招后卡片立刻飞右上角，不悬停——特效与落位并行，
	# 强力卡的多段效果可以在卡片落位之后继续结算（蓝本即如此）
	# 2026-11-06 四区制（规格 v1）：出招后不进弃牌堆——落**已打出区**（停在场上，
	# 不淡出不销毁；回合末/断连击由 _rebuild_played 走 _anim_card_fly 飞弃）；
	# 碎牌（第 5 次打出）：不落区——原地碎裂消散（效果已照常结算）
	if _shattered_uids().has(int(w.get_meta("hand_uid", -1))):
		_shatter_tail(w, tw)
	else:
		var n2: int = battle.played_pile.size()
		var idx2: int = maxi(0, n2 - 1)
		var pose: Dictionary = _played_target(w, idx2, n2)
		w.z_index = int(pose["z"])
		tw.tween_property(w, "position", pose["pos"], 0.22)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(w, "scale", pose["scale"], 0.22)
		tw.parallel().tween_property(w, "rotation", pose["rot"], 0.22)
		tw.parallel().tween_property(w, "modulate:a", 1.0, 0.22)

func _shattered_uids() -> Dictionary:
	var out2 := {}
	for sm in battle.shattered:
		out2[int(sm["uid"])] = true
	return out2

## 2026-11-06 碎牌：原地碎裂消散（抖两下＋碎块四散＋淡出；正式碎裂特效归用户，此为留位）
func _anim_card_shatter(w: Control) -> void:
	_kill_card_tween(w)   # 互杀保护（2026-11-06）
	var tw := create_tween()
	w.set_meta("card_tween", tw)
	_shatter_tail(w, tw)

func _kill_card_tween(w: Control) -> void:
	if w.has_meta("card_tween"):
		var old: Tween = w.get_meta("card_tween")
		if old != null and old.is_valid():
			old.kill()
		w.remove_meta("card_tween")

func _shatter_tail(w: Control, tw: Tween) -> void:
	var base: Vector2 = w.position
	var sc: float = maxf(0.2, w.scale.x)
	var card_size: Vector2 = Vector2(HAND_W, HAND_H) * sc
	var c := base + card_size * 0.5
	# 抖三下（前摇）→ 淡出
	tw.tween_property(w, "position", base + Vector2(8.0, -4.0), 0.05)
	tw.tween_property(w, "position", base - Vector2(7.0, 3.0), 0.05)
	tw.tween_property(w, "position", base + Vector2(4.0, 0.0), 0.04)
	tw.parallel().tween_property(w, "modulate:a", 0.0, 0.20).set_delay(0.02)
	tw.parallel().tween_property(w, "scale", w.scale * Vector2(1.06, 0.93), 0.24)
	tw.tween_callback(w.queue_free)
	_shatter_flash(c, card_size)
	_shatter_shards(c, sc)

## 碎裂瞬间：卡形白闪（整张卡一记过曝，比光斑更像「炸开」）
func _shatter_flash(c: Vector2, card_size: Vector2) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.set_corner_radius_all(14)
	p.add_theme_stylebox_override("panel", sb)
	p.size = card_size * 1.02
	p.position = c - p.size * 0.5
	p.pivot_offset = p.size * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 71
	p.modulate.a = 0.0
	add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 0.92, 0.03)
	tw.parallel().tween_property(p, "scale", Vector2(1.05, 1.05), 0.06)
	tw.tween_property(p, "modulate:a", 0.0, 0.14)
	tw.tween_callback(p.queue_free)

## 碎块：先炸开（0.2s）再受重落（0.4s），边走边转边缩
func _shatter_shards(c: Vector2, sc: float) -> void:
	var tex := _fx_art("fx_shard")
	for i in 16:
		var s := TextureRect.new()
		s.texture = tex
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz := randf_range(20.0, 66.0) * clampf(sc, 0.6, 1.6)
		s.size = Vector2(sz, sz)
		s.pivot_offset = s.size * 0.5
		s.position = c - s.size * 0.5 + Vector2(randf_range(-50, 50), randf_range(-64, 64))
		s.rotation = randf_range(-PI, PI)
		var tint := Color(1.0, 1.0, 1.0, 1.0)
		if i % 3 == 0:
			tint = Color(0.42, 0.50, 0.63, 1.0)
		s.modulate = Color(tint.r, tint.g, tint.b, 0.0)
		s.z_index = 70
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		var ang := randf_range(0.0, TAU)
		var dist := randf_range(80.0, 230.0)
		var burst: Vector2 = s.position + Vector2(cos(ang), sin(ang)) * dist
		var ft := s.create_tween()
		ft.tween_interval(0.01 + 0.012 * float(i))
		ft.tween_property(s, "modulate:a", 1.0, 0.03)
		ft.parallel().tween_property(s, "position", burst, 0.22)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ft.parallel().tween_property(s, "rotation", s.rotation + randf_range(-2.4, 2.4), 0.22)
		ft.parallel().tween_property(s, "scale", Vector2(0.82, 0.82), 0.22)
		ft.tween_property(s, "position", burst + Vector2(randf_range(-18, 18), randf_range(70, 150)), 0.42)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ft.parallel().tween_property(s, "rotation", s.rotation + randf_range(-2.0, 2.0), 0.42)
		ft.parallel().tween_property(s, "modulate:a", 0.0, 0.42).set_delay(0.16)
		ft.tween_callback(s.queue_free)

## 软圆点（运行期生成，墨气/柔光通用）
static var _dot_cache: Texture2D = null
static func _soft_dot() -> Texture2D:
	if _dot_cache != null:
		return _dot_cache
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_dot_cache = t
	return t

## 特效贴图运行时读（同 HUD 件：绕开 .import）
static var _fx_cache := {}
static func _fx_art(name: String) -> Texture2D:
	if _fx_cache.has(name):
		return _fx_cache[name]
	var p := "res://qiforge/assets/hud/%s.png" % name
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	var t: Texture2D = null
	if img != null and not img.is_empty():
		t = ImageTexture.create_from_image(img)
	_fx_cache[name] = t
	return t

## ── 已打出区（2026-11-06 表现层接手）：右侧纵堆 —— 新牌在**下**且最大，
## 旧牌往上收、压暗一档；逐张横向漂移 + 微旋出「错落」，张数多时自动压缩间距。
const PLAYED_X := 1678.0          # 堆的左沿（允许遮挡右侧效果图标，原作也遮）
const PLAYED_TOP := 20.0
const PLAYED_BOTTOM := 560.0
const PLAYED_SC := 1.0            # 已打出区＝手牌同尺寸（壳里已是手牌档，再乘 0.72 会二次缩小）
const PLAYED_SC_NEW := 1.0        # 与旧牌同档
const PLAYED_H := 304.0 * PLAYED_SC

func _rebuild_played() -> void:
	if battle == null:
		return
	var n: int = battle.played_pile.size()
	var live := {}
	for card in battle.played_pile:
		live[int(card["uid"])] = true
	# 消失（回合末冲弃/断连击/洗回抽牌堆）→ 飞弃牌堆淡出
	for uid in _played_cards.keys():
		if not live.has(uid):
			var gone: Control = _played_cards[uid]
			_played_cards.erase(uid)
			if is_instance_valid(gone):
				_anim_card_fly(gone, float(uid % 3) * 0.05)
	# 新到：点击路径由 _anim_card_play_out 全程接管；其余路径（play_all/兜底）在此落位
	var fresh := {}
	for uid2 in live:
		if _played_cards.has(uid2):
			continue
		var w := _take_wrap(uid2)
		if w == null:
			continue
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 场上牌不可点
		var vis: Control = w.get_child(0)
		vis.scale = Vector2.ONE
		vis.rotation = 0.0
		vis.position = _vis_rest(vis)
		_played_cards[uid2] = w
		fresh[uid2] = true
		if uid2 != _played_uid:
			var tw := create_tween()
			tw.tween_interval(0.02)
			tw.tween_callback(func() -> void: _apply_played_pose(w, _played_index(uid2), n, 0.25))
	# 老居民重排（fresh 的落位已在跑，不抢）
	for card in battle.played_pile:
		var uid3 := int(card["uid"])
		if fresh.has(uid3):
			continue
		var w3: Control = _played_cards.get(uid3)
		if w3 != null and is_instance_valid(w3):
			_apply_played_pose(w3, _played_index(uid3), n, 0.25)

func _played_index(uid: int) -> int:
	var i := 0
	for card in battle.played_pile:
		if int(card["uid"]) == uid:
			return i
		i += 1
	return maxi(0, i - 1)

## 已打出区姿态：pos（wrap 左上）/ scale / rot / alpha / z
func _played_pose(idx: int, n: int) -> Dictionary:
	var is_new := idx >= n - 1
	var step := 0.0
	if n > 1:
		var avail: float = PLAYED_BOTTOM - PLAYED_TOP - 304.0 * PLAYED_SC_NEW
		step = minf(PLAYED_H * 0.60, avail / float(n - 1))
	var jx := 5.0 * sin(float(idx) * 1.9 + 0.6)
	var rot := deg_to_rad(1.5 if idx % 2 == 0 else -1.3)
	if is_new:
		jx = 0.0
		rot = deg_to_rad(-0.6)
	return {
		"pos": Vector2(PLAYED_X + jx, PLAYED_TOP + step * float(idx)),
		"scale": Vector2.ONE * (PLAYED_SC_NEW if is_new else PLAYED_SC),
		"rot": rot,
		"alpha": 1.0 if is_new else 0.88,
		"z": 40 + idx,
	}

## 把「卡面可视左上角」对齐到堆位：拿子卡当前的全局矩形反推偏移（自校正，
## 不依赖 wrap 内部结构——wrap 比卡高，含悬停抬升的余量）
func _played_target(w: Control, idx: int, n: int) -> Dictionary:
	var pose := _played_pose(idx, n)
	if w == null or not is_instance_valid(w) or w.get_child_count() == 0:
		return pose
	var vis := w.get_child(0) as Control
	if vis == null:
		return pose
	var sc: float = (pose["scale"] as Vector2).x
	var cur_off: Vector2 = vis.get_global_rect().position - w.global_position
	var ratio := sc / maxf(0.001, w.scale.x)
	pose["pos"] = (pose["pos"] as Vector2) - cur_off * ratio
	return pose

func _apply_played_pose(w: Control, idx: int, n: int, dur: float) -> void:
	if w == null or not is_instance_valid(w):
		return
	var pose := _played_target(w, idx, n)
	w.z_index = int(pose["z"])
	if dur <= 0.0:
		w.position = pose["pos"]
		w.scale = pose["scale"]
		w.rotation = pose["rot"]
		w.modulate.a = pose["alpha"]
		return
	var tw := w.create_tween()
	tw.tween_property(w, "position", pose["pos"], dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(w, "scale", pose["scale"], dur)
	tw.parallel().tween_property(w, "rotation", pose["rot"], dur)
	tw.parallel().tween_property(w, "modulate:a", pose["alpha"], dur)

## 落位坐标（出招动画收尾用）
func _played_slot(uid: int) -> Vector2:
	return _played_pose(_played_index(uid), maxi(1, battle.played_pile.size()))["pos"]

func _take_wrap(uid: int) -> Control:
	for w in _hand_wraps:
		if int(w.get_meta("hand_uid", -1)) == uid:
			return w
	return null

## ══ 经验线（2026-11-09 贴原版终裁：**死帧入账制**）══════════════════════════
## 击杀拍＝battle 侧当帧进账（数据先行，原版 AddGrowthXp 同构）；屏幕 _refresh 里判
## 阈值→**立即**弹三选一＋世界冻结（模态插队，不等任何特效）。经验珠降级纯演出：
## 死亡同帧起跑、落地放 +N（数值取 xp_credit，纯凭证不复责）；胜利收尾仍等珠飞完
## （演出忙信号，原版 WaitWhile(IsAnyViewUpdating) 同构）。旧「珠到账才入账」队列制
## （xp_pending/settle_one/settle_all/弹窗期只入账）随令退役。

## 顶带刷新（2026-11-09 贴原版令·终版「逐珠制」）：等级数字只在**选卡关窗后**才变
## （弹窗期间停旧级＋满条，「先弹窗、后升级」）；经验条画**显示值**——数据减在飞珠，
## 逐珠落地逐格涨（原版 CrystalEmitterView 水晶到位逐颗顶条同构）。
func _refresh_top(dur: float) -> void:
	var lvl := int(run.get("level", 1))
	var need := VC.xp_to_next(lvl)
	var xp := mini(_xp_shown_total(), need)
	QI_CAB.refresh_top(_top_refs, lvl, xp, int(run.get("floor", 0)),
		VC.FLOORS.size(), need, dur)

## 显示值（条与弹窗共用的唯一时钟）：数据总账 − 在飞珠经验。珠落地时它逐格上涨，
## 最后一颗到位那刻顶满 → _check_level_modal 开窗——条满与开窗同一事件（原版
## 「条视图里 DoViewLevelUp」同构），结构性杜绝「弹窗开着条没满」。
func _xp_shown_total() -> int:
	return int(run.get("xp", 0)) + int(battle.xp_gained) - _xp_orbs_amt

func _spawn_xp_orb(from: Vector2, uid: int) -> void:
	_xp_flights += 1
	var amt := int(battle.xp_credit.get(uid, 0))
	battle.xp_credit.erase(uid)               # 取走即清（+N 凭证一次性）
	_xp_orbs_amt += amt                       # 显示锁：这颗的量在落地前不计入显示值
	if _xp_fx == null:
		_xp_orb_arrived(from, amt)
		return
	# 2026-11-09 用户令：去掉连飞错峰——多珠同帧齐发（原错峰为防 +N 数字糊在一起）
	_xp_fx.fly(from, _top_refs.get("xp_fill"), func(at): _xp_orb_arrived(at, amt))

## 珠落地（逐珠制）：+N 飘字＋解锁显示值（条逐格涨）＋_refresh 尾部判阈开窗。
## 数据早已在击杀拍入账——落地只驱动**显示**，不碰账。
func _xp_orb_arrived(at: Vector2, amt: int) -> void:
	_xp_flights -= 1
	_xp_orbs_amt -= amt
	if String(battle.phase) == "over" and String(battle.result) != "win":
		return                                     # 败北：珠清场（经验本就没写回 run）
	if _xp_fx != null:
		_xp_fx.land(at, amt)
	_refresh()

## 经验只入账、不归并升级（延迟制：level 等选完关窗才变——原版 ChooseCardModal
## 关闭回调里才 LevelUp 的同构）
func _bank_xp() -> void:
	if battle != null and battle.xp_gained > 0:
		run["xp"] = int(run.get("xp", 0)) + int(battle.consume_xp())
	_refresh()

## 阈值开窗（2026-11-09 贴原版终裁·逐珠制）：判据＝**显示值**满（数据−在飞珠），
## 即最后一颗珠落地、条顶满的那一帧才开窗——条满与开窗同一事件，结构性杜绝
## 「弹窗开着条没满」（原版弹窗住在条视图、由条满触发同构）。数据死亡帧已入账，
## 模态插队规则不变（胜利态照弹、收尾等窗关）；败北不弹（经验本就不写回）。
func _check_level_modal() -> void:
	if _reward_ui != null:
		return
	if String(battle.phase) == "over" and String(battle.result) != "win":
		return
	if _xp_shown_total() >= VC.xp_to_next(int(run.get("level", 1))):
		_open_reward()

## 到账经验结转＋逐级归并（2026-11-08 连升时序令：只升一级——level+1、扣本级需求、
## 溢出保留供下一级；2026-11-09 贴原版零特效令：两级之间不再播动画间隔，关窗即判、
## 够就直弹下一窗。全量归并＋pending_picks 计数制退役——弹窗由「条满」事件驱动、关窗逐级消化）
func _sync_level() -> void:
	if battle != null and battle.xp_gained > 0:
		run["xp"] = int(run.get("xp", 0)) + battle.consume_xp()
	var lvl := int(run.get("level", 1))
	var need := VC.xp_to_next(lvl)
	if int(run.get("xp", 0)) >= need:
		run["level"] = lvl + 1
		run["xp"] = int(run.get("xp", 0)) - need

func _open_reward() -> void:
	if _reward_ui != null:
		return
	# 弹窗前断焦（2026-11-09 修词条浮窗残留）：换焦轮询跑在 _process 里，下面
	# paused=true 会把它冻住——不主动撤，「击退」等词条浮窗与伤害预览会冻结在屏上
	# 残留到关窗后（触发升级的那次打出必中：满级一击＝悬停刚打出的卡）
	_set_hand_focus(null)   # 连锁撤词条浮窗＋伤害预览＋焦点（换焦路径同一条）
	print("[VCDIAG][hand] reward-open-drop")   # [VCDIAG] 临时埋点
	# 〔2026-11-10 天赐置空〕旧天赐「飞星术/撩月斩」随卡表砍除退役——三张基础卡经
	# reward_offers 自然出题（NEW_ONLY_UNTIL_LEVEL 已闭防空池）；天赐制留内容轮再启
	var gifts: Array = []
	_reward_ui = VC_REWARD.new()
	_reward_ui.z_index = 95          # 盖过手牌（0..60）与特效层（90），低于结算浮层（100）
	_reward_ui.setup(run, gifts)
	_reward_ui.card_chosen.connect(_on_card_chosen)
	_reward_ui.done.connect(_on_reward_done)
	add_child(_reward_ui)
	# 手牌收起（2026-11-08 用户令：升级时不显示手牌；不是"盖住"，是真的收起来）
	for w in _hand_wraps:
		if is_instance_valid(w):
			w.visible = false
	# 2026-11-08 用户令「弹窗开＝全世界冻结」＋2026-11-09 贴原版 TimeManager 引用计数制：
	# 升级三选一是模态旁路（原版 ChooseCardModal 同构）——剑冻在半空、珠冻在半空，
	# 选完关窗恢复、余下的段接着飞（弹窗挂 WHEN_PAUSED 自身照跑；演出层全为节点
	# Tween/create_timer(false) 暂停敏感）
	QI_PAUSE.request("reward")

func _on_reward_done() -> void:
	QI_PAUSE.release("reward")   # 世界恢复：余下的攻击段/飞行珠接着飞
	# 手牌回来（2026-11-11 修「先隐藏又闪现」：终局后不回——原版＝离开玩家回合即交互
	# 失效，胜利时序 DiscardHand 弃走；我方 _predict_end_and_hide 已收起＝单向保持）
	if not _finale:
		for w in _hand_wraps:
			if is_instance_valid(w):
				w.visible = true    # 手牌回来
	if _reward_ui != null and is_instance_valid(_reward_ui):
		_reward_ui.queue_free()      # 关窗＝销毁（原来只置空，弹窗留在屏幕上不消失）
	_reward_ui = null
	# 2026-11-09 贴原版令·逐珠制：关窗此刻才升**一级**——等级数字跳新值、条按显示值
	# 重画（溢出保留）；连升走 _check_level_modal（显示值判据：还有冻在半空的珠就等
	# 它落地再弹下一窗，全落地＝立即弹——原版 ContinueXpFillAfterLevelUp 同构）。
	_sync_level()
	_refresh()
	if _win_pending and _xp_shown_total() < VC.xp_to_next(int(run.get("level", 1))):
		_try_finish_win()   # 显示值不满且胜利挂起 → 收胜（够级的话留给开窗链）

## 选卡落点（2026-11-09 修·双落点）：cid 恒入 run 牌组（跨场持久——战斗四区是开局
## 快照、从不写回，只进手牌＝「下一场就没了」）；战斗已结束（胜利收尾）＝不进
## 手牌，直接落抽牌堆（计数即涨；下一场开局随牌组洗入）；战斗仍在打＝另赠当场
## 上手一张＋免一次费（对齐原版 MoveChosenCardToHand＋SetCardFreeToPlay）。
## _deck_total 同步＋1＝check_piles 不变量（手牌增援与碎牌 −1 同理）。
func _on_card_chosen(cid: String) -> void:
	run["deck"].push_back(cid)
	if battle == null:
		return
	battle._deck_total += 1
	if String(battle.phase) == "over":
		battle.draw_pile.push_back(battle._make_card(String(cid)))
		_refresh()
		return
	var c: Dictionary = battle._make_card(String(cid))
	c["free"] = true                 # 免一次费（打出后消耗）
	battle.hand.push_back(c)
	_refresh()

## 胜利收尾：珠到齐＋升级全关→残余保底入账→（还有突破就弹）→胜利浮层
## （2026-11-09 贴原版零特效令：满级忙窗挂钟随升级动画链一并退役——弹窗由「条满」
## 事件驱动＋世界冻结天然互斥，胜利收尾不再需要对表）
func _try_finish_win() -> void:
	if not _win_pending or _xp_flights > 0 or _reward_ui != null:
		return
	if Time.get_ticks_msec() < _death_fx_until:
		# 碎卡特效还没播完：挂一次定时器到点重推，避免没有后续回调时横幅永不出现
		if not _win_retry_armed:
			_win_retry_armed = true
			var wait := float(_death_fx_until - Time.get_ticks_msec()) / 1000.0 + 0.03
			get_tree().create_timer(wait).timeout.connect(func() -> void:
				_win_retry_armed = false
				_try_finish_win())
		return
	if _cardq.is_busy():
		# 终局弃牌命令还没落定（2026-11-12 原版制：WaitWhile(IsProcessing) 同构——
		# 等最后一张手牌落进弃堆再收胜利）。落定后**重入**不落底：等待期间经验珠可能
		# 已开升级弹窗（顶部 _reward_ui 复查＝双窗竞态守卫，await 直落底会丢——审计修）
		await _cardq.all_done
		_try_finish_win()
		return
	_bank_xp()               # 保底入账（数据已在击杀拍进账——此处理顺写回；2026-11-09
	#                         # 死帧入账制：xp_pending/settle_all 队列退役，无「没放出来的经验」一说）
	_refresh()
	_sync_level()
	_refresh()
	_win_pending = false
	# 2026-11-09 用户令：0.8s 呼吸段删（当日早些时候），贴原版补回 100ms 微垫
	# （原版 EncounterDefeatedState 转场前 UniTask.Delay(100, ignoreTimeScale:false)——
	# 吃世界时钟、暂停敏感；浮层带「返回地图」确认键——点击才回地图）
	await get_tree().create_timer(0.1, false).timeout
	if not is_inside_tree():
		return
	_show_end_overlay("win")

func _stop_xp_flights() -> void:
	_xp_flights = 0
	_xp_orbs_amt = 0
	if _xp_fx != null:
		_xp_fx.clear()

func _on_ended(result: String) -> void:
	if result == "win":
		_win_pending = true
		_refresh()             # 先补刷：终局判定早于刷新时，阵亡敌的珠还没出生就被结算了
		_try_finish_win()      # 珠还在飞就等（到账回调续推）
		return
	_stop_xp_flights()        # 败北：经验作废
	_show_end_overlay("lose")

func _show_end_overlay(result: String) -> void:
	# 唯一出口保险：不管从哪条路进来，只要溶解还没播完就先不弹（2026-11-08 用户实测抢跑）
	if result == "win" and Time.get_ticks_msec() < _death_fx_until:
		if not _end_overlay_waiting:
			_end_overlay_waiting = true
			var wait2 := float(_death_fx_until - Time.get_ticks_msec()) / 1000.0 + 0.02
			get_tree().create_timer(wait2).timeout.connect(func() -> void:
				_end_overlay_waiting = false
				_show_end_overlay("win"))
		return
	_refresh()
	_overlay = Control.new()
	_overlay.z_index = 100   # 盖住手牌（手牌 z 序已抬到 0..60）
	_overlay.anchor_left = 0.0
	_overlay.anchor_top = 0.0
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	_fill(scrim)
	_overlay.add_child(scrim)
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -160.0
	center.offset_right = 160.0
	center.offset_top = -90.0
	center.offset_bottom = 90.0
	center.add_theme_constant_override("separation", 18)
	_overlay.add_child(center)
	var title := _mk_label(center, "胜利！" if result == "win" else "败北", 46,
		QISTYLE.JADE if result == "win" else QISTYLE.RED, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "返回地图" if result == "win" else "返回地图（重整旗鼓）"
	QISTYLE.apply_primary(btn)
	btn.pressed.connect(func(): battle_over.emit(String(result)))
	center.add_child(btn)
	add_child(_overlay)

## 战后写回源（宿主取 run 状态用）
func player_out() -> Dictionary:
	var out: Dictionary = battle.player_out()
	# 2026-11-05 经验特效轮：升级/经验已在屏内随珠到账结转——快照回传，Root 不再重算
	out["run"] = run
	return out

## 血池读数：活跃存活＋总池全员（遭遇总剩余血）
func _pool_hp_now() -> int:
	var n := 0
	for e in battle.encounter["active"]:
		if e["alive"]:
			n += int(e["hp"])
	for eid in battle.encounter["reserve"]:
		n += int(VC.ENEMIES[String(eid)]["hp"])
	return n

func _pool_hp_total_max() -> int:
	var n := 0
	for eid in VC.ENCOUNTERS[String(VC.DUNGEON[clampi(int(run.get("enc", 0)), 0, VC.DUNGEON.size() - 1)])]["pool"]:
		n += int(VC.ENEMIES[String(eid)]["hp"])
	return n
