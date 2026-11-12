## VC 制战斗引擎（纯逻辑无 UI；复刻阶段 2026-10-31 立档）。
## 模型＝单主角 vs 血池波次遭遇（去目标制，2026-10-31 用户裁定）：
##   · 玩家攻击不打点选目标——front＝最前存活敌、all＝对每个存活敌各全额（原作范围武器语义）；
##   · 遭遇＝总池＋活跃位＋回合末补位轮换（都死了＝活跃清空且总池耗尽）；
##   · 敌方回合＝全场意图合并成一次总打击（只过一次玩家护甲）；护甲意图进遭遇护甲池；
##   · 玩家护甲＝每回合开始按护甲属性刷新（配合并结算制）；
##   · 动态升级（2026-11-10 三公理·集合制，取代连击；全文见 design-docs/动态升级系统_v0.3.md）：
##     每张卡带型集（三真型单集、flex＝全集），「接」＝型集有交集、「换」＝无交集——
##     A1 升级（打出 p → 手牌中与 p 接且等级 ≤p 者：等级+1、费用+1〔费用锁定牌不加费〕）；
##     A2 切招（p 与上一张换 → 手牌中与 p 换者：等级与费用复原初始）；
##     A3 万能打出（p 为 flex → 手牌全体费用复原初始，结算在 A1 后）。
##     执行顺序＝①A2 → ②A1 → ③A3 → ④记型；离开手牌即复原；未获内功＝三步全跳。
##     气＝回合开始重置到当前上限（基础 2 可成长，护栏 6；洗牌换气暂缓——2026-11-07 撤下）。
extends RefCounted

signal changed
signal event(text: String)
signal ended(result: String)
signal hit_landed(target: Dictionary, amount: int, kind: String, crit: bool)
signal played_changed            # 已打出区变更（增/删/清空——视觉层对账用，2026-11-06 规格§6）
signal piles_shuffled(src: String)   # 洗牌事件（src=discard/played；飘字/日志可选）
signal card_shattered(uid: int)  # 卡碎裂（第 5 次打出——视觉层碎裂动画/探针用，2026-11-06 碎牌机制）
signal enemy_action_started(e: Dictionary, act: Dictionary)   # 敌方动作起拍（2026-11-12 命令化：将来逐敌动画挂口——对位原版 PlayViewAnimation；无动画期当帧过）
# —— 手牌逐卡事件（2026-11-12 结构 1:1：原版 CardPileModel.CardAdded/CardRemoved 逐卡事件制；
# 抽牌批走 cards_drawn＝PlayerView.DrawCardsCommand 单命令对位，原版 TryAddCardToTop
# addToView=false 时逐卡事件不发、视图命令整批走）——
signal cards_drawn(cards: Array)              # 抽牌批（视图＝DrawCardsCommand 整批命令）
signal hand_card_removed(card: Dictionary, dest: String, batch)   # 离手（dest=played/discard/shatter/exhaust；batch＝同批张数→视图加速钟 max(N,3)——CardPileModel.OnCardAdded 汇编 039-042 直证）
signal hand_card_added(card: Dictionary)      # 非抽加牌（敌方塞卡等——对位 addToView=true 路径）

const DATA := preload("res://qiforge/QiVcData.gd")
const TARGETING := preload("res://qiforge/QiVcTargeting.gd")   # 索敌库＋模拟单链（2026-11-07 逆向重构）
const EFFECTS := preload("res://qiforge/QiVcEffects.gd")       # 效果处理器注册表（同轮）
const ACTIONS := preload("res://qiforge/QiVcEnemyActions.gd")  # 意图动作族（同轮）
const CMDQ := preload("res://qiforge/QiVcCmdRunner.gd")        # 统一命令队列（2026-11-12 原版 CommandRunner 同构）

var rng := RandomNumberGenerator.new()
var player: Dictionary = {}
var encounter: Dictionary = {}
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var round_no := 0
var phase := "player"
var result := ""

var current_form := ""        # 上一张打出的剑型（型集判定用：short/long/great/flex；""＝无——回合开始归无）
var upgrade_enabled := false  # 动态升级＝内功「动态升级」赋予（2026-11-07 教程轮沿袭：宝箱获得——开局不带）
var might_pct := 0            # 本回合伤害增幅（与等级倍率相乘）
var xp_gained := 0            # 本场击杀所得经验（战后写回 run——2026-11-01 经验轮）
var _run: Dictionary = {}     # 2026-11-07 属性轮：run 引用（stat op dungeon 型回写 dungeon_stats）
var starting_stats := {}      # 四层之一：三层基线（base＋progression＋dungeon——setup 时合成）
var encounter_stats := {}    # 四层之二：本场增量（encounter 型黄卡——随实例销毁清零）
var _pending_strikes: Array = []   # 2026-11-08 落账延迟：待击中帧结算的伤害事件队列（账单制）
var _play_gen := 0                 # 出牌代（2026-11-09 连打制：每张牌的账单事件带代标，演出逐代排队消费）
var _strike_total := 0             # 2026-11-08 余段空放制：本次打出的飞行总段数（演出拍数权威）
var pending_visual := false        # true＝有表现层逐击回调（屏 setup 置位）；false＝play_card 尾自动全落（探针）
var xp_credit: Dictionary = {}   # uid → 已入账经验（2026-11-09 死帧入账制：屏幕放珠取 +N 用，纯演出凭证）
var played_pile: Array = []   # 已打出区（2026-11-06 四区制规格 v1：已结算未进弃牌堆，按打出序）
var shattered: Array = []     # 碎掉的卡 [{id, uid}]（2026-11-06 碎牌机制：战后从 run 卡组永久移除）
var _deck_total := 0          # 四区不变量基准（setup 时锁定；碎牌时同步减）

var _card_uid := 0
var _enemy_uid := 0
var _intents := {}            # 已退役（2026-11-07：意图挂敌 e.current_intent——保留声明防并行 AI 撞写报错）
var _last_action := {}        # 敌 uid -> 上一拍动作 kind（防连出）
var cmds := CMDQ.new()        # 统一命令队列（敌方动作/效果表现命令——2026-11-12 CommandRunner 1:1 自排空泵）
var _screen_attached := false # 有屏标记：true＝表现命令入队（泵串行排空）；false（探针/无屏）＝直执行不入队
var fx_launcher: Callable = Callable()   # 效果表现命令体（Screen 注入：(payload) async；未注入＝fx 不入队）

func setup(run: Dictionary) -> void:
	rng.seed = int(run.get("seed", 20261031))
	upgrade_enabled = DATA.has_neigong(run, "combo_stack")   # 动态升级＝内功赋予（id 沿用 combo_stack——宝箱硬编码联动；2026-11-07 教程轮：宝箱解锁）
	_run = run   # 2026-11-07 属性轮：stat op 的 dungeon 型需回写 run.dungeon_stats（持有引用不拷贝）
	var pb: Dictionary = DATA.PLAYER_BASE
	player = {"hp": int(run.get("hp", pb["hp"])), "mhp": int(run.get("hp", pb["hp"])),
		"armor": 0, "armor_stat": 0,
		"qi": 0, "qi_max": int(run.get("qi_max", DATA.QI_BASE_MAX)),   # 气上限＝基础 2，局外 run.qi_max／局内效果可成长
		"draw_per_turn": int(pb["draw_per_turn"]),
		"stances": {},   # 〔2026-11-08 状态制退役〕式层数池——引擎不再读写，留空壳兼容旧显示引用（文本轮清）
		"recovery": 0, "hand_cap_mod": 0}
	# 属性四层（2026-11-07 属性轮，对应原版 GetStartingX 三参＋本场增量）：
	# starting ＝ base＋progression（meta）＋dungeon（run）；encounter 层本场黄卡直接加，
	# 随战斗实例销毁清零（＝原版 OnEncounterDefeated 重算回基线）。meta 由宿主注入 run._meta。
	var meta: Dictionary = run.get("_meta", {})
	starting_stats = DATA.get_starting_stats(meta, run)
	encounter_stats = {}
	apply_stats_to_player()
	var deck: Array = run.get("deck", DATA.START_DECK)
	draw_pile = []
	discard_pile = []
	exhaust_pile = []
	hand = []
	played_pile = []   # 已打出区＝战斗内状态，不进存档（规格§8）
	for cid in deck:
		draw_pile.push_back(_make_card(String(cid)))
	_deck_total = draw_pile.size()
	_shuffle(draw_pile)
	check_piles()
	# 遭遇：run.enc_spec 直接给定（地图明雷组队）或按 run.enc 查 DUNGEON 序
	var enc_id := ""
	var spec: Dictionary = run.get("enc_spec", {})
	if spec.is_empty():
		enc_id = String(DATA.DUNGEON[clampi(int(run.get("enc", 0)), 0, DATA.DUNGEON.size() - 1)])
		spec = DATA.ENCOUNTERS[enc_id]
	encounter = {"id": enc_id, "name": String(spec.get("name", "未知遭遇")),
		"active_max": int(spec.get("active_max", 3)), "refill": int(spec.get("refill", 0)),
		"armor": 0, "active": [], "reserve": (spec.get("pool", []) as Array).duplicate()}
	var rows: Array = spec.get("rows", [])   # 队列制编队：[[前排...],[后排...]]（嵌套=排）
	if not rows.is_empty():
		for ri in rows.size():
			for cid2 in (rows[ri] as Array):
				var re: Dictionary = _make_enemy(String(cid2))
				re["row"] = ri
				encounter["active"].push_back(re)
	else:
		for i in int(spec["active_max"]):
			if not encounter["reserve"].is_empty():
				encounter["active"].push_back(_make_enemy(String(encounter["reserve"].pop_front())))

func start() -> void:
	round_no = 0
	_round_start()
	changed.emit()

## ── 属性四层（2026-11-07 属性轮）──
## 合成现值：starting（三层基线）＋ encounter（本场）。stat op 入账后调本函数把派生值
## 刷到 player（hp 上限/发牌数等即时生效；might/luck 等结算时经 stat_val 现读）。
func apply_stats_to_player() -> void:
	# 双轴血上限（wiki 真值分轴）：max_hp＝固定值（黄卡 Gain 3 Max Health）；max_hp_pct＝养成
	# 百分比（PowerUp +10%/级，pct 轴 100 基＝×1.0——超出部分才算加成）。涨上限同涨当前血。
	var new_mhp := int(round(float(DATA.PLAYER_BASE["hp"]) * stat_mult("max_hp_pct"))) \
		+ stat_val("max_hp")
	if new_mhp > int(player["mhp"]):
		player["hp"] = int(player["hp"]) + (new_mhp - int(player["mhp"]))
	player["mhp"] = new_mhp
	player["draw_per_turn"] = int(DATA.PLAYER_BASE["draw_per_turn"]) + stat_val("deal_count")
	# 抽牌动画测试口（2026-11-12 用户令·临时）：启动参数 --qi-draw=N 覆盖每回合抽牌数
	# （测 1/5/8 场景——F6 从编辑器跑不传参时可用终端：
	#   "$GODOT" --path . res://qiforge/QiVcRoot.tscn -- --qi-draw=5 ）
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qi-draw="):
			player["draw_per_turn"] = clampi(int(a.substr(10)), 1, 10)

func stat_val(axis: String) -> int:
	return int(starting_stats.get(axis, 0)) + int(encounter_stats.get(axis, 0))

func stat_cn(axis: String) -> String:
	for s in DATA.STATS:
		if String(s["id"]) == axis:
			return String(s["cn"])
	return axis

## pct 乘区现读（100 基＝×1.0）：might/greed/growth/luck/curse/area/duration/risk/charm
func stat_mult(axis: String) -> float:
	return float(stat_val(axis)) / 100.0

func _make_card(cid: String) -> Dictionary:
	_card_uid += 1
	var def: Dictionary = DATA.CARDS.get(cid, {})
	return {"uid": _card_uid, "id": cid, "def": def,
		"exhaust": bool(def.get("exhaust", false)),
		"lv": 0, "cost_delta": 0,   # 2026-11-10 动态升级双轨：等级（效果强度）＋费增量（气费附加）——只在手牌内非零
		"uses": 0}   # 2026-11-06 碎牌：使用计数＝**一回合之内**（3 次裂痕＋1 次，第 5 次碎；回合开始清零）

func _make_enemy(eid: String) -> Dictionary:
	var spec: Dictionary = DATA.ENEMIES[eid]
	_enemy_uid += 1
	# 2026-11-07 属性轮：curse 乘区（100 基=×1）——诅咒轴放大敌血（难度轴，wiki「Increase enemy strength」）
	var hp_scaled := maxi(1, int(round(float(int(spec["hp"])) * (stat_mult("curse") if not starting_stats.is_empty() else 1.0))))
	return {"uid": _enemy_uid, "id": eid, "name": String(spec["name"]), "side": "enemy",
		"alive": true, "hp": hp_scaled, "mhp": hp_scaled, "armor": 0,
		"boss": bool(spec.get("boss", false)), "actions": spec["actions"],
		"row": 0}   # 敌阵队列制 v0.1：row=0 前排（唯一行动排）；armor＝每敌甲（原版 EnemyModel.Armor）

func _shuffle(pile: Array) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp

#region 回合流
func _round_start() -> void:
	# 2026-11-06 碎牌口径（用户裁定）：使用计数＝**一回合之内**——回合开始全体清零；
	# 没碎的卡下回合从头再计 3+1；碎掉的已移出各区，不受影响（碎＝永久，跨回合不复活）
	for card in hand:
		card["uses"] = 0
	for card in draw_pile:
		card["uses"] = 0
	for card in discard_pile:
		card["uses"] = 0
	for card in played_pile:
		card["uses"] = 0
	for card in exhaust_pile:
		card["uses"] = 0
	# 护甲每回合刷新制：回合开始按护甲属性重获护甲（配合敌方合并结算）
	player["armor"] = int(player["armor_stat"])
	# 2026-11-07 终裁：气＝回合开始重置到当前上限（重置在前、抽牌在后；洗牌换气**暂缓撤下**——
	# 气源只剩本重置，上限＝成长轴：局外 run.qi_max／局内 qi_max 效果，护栏 QI_CAP）
	player["qi"] = int(player["qi_max"])
	draw_cards(int(player["draw_per_turn"]))
	might_pct = 0
	current_form = ""      # 上一张剑型回合归无（动态升级：每回合首张不构成切招）
	decide_intents()
	phase = "player"

func end_turn() -> void:
	if phase != "player":
		return
	var batch := hand.size()   # 同批张数→弃牌加速钟（原版 cardsBeingAddedAtOnce）
	for card in hand:
		_strip_lv(card)   # 离开手牌即复原（动态升级口径）
		discard_pile.push_back(card)
		hand_card_removed.emit(card, "discard", batch)   # 视图＝弃牌飞行（discardCardConfig×max(N,3)）
	hand = []
	# 2026-11-06 用户令：回合结束瞬间气即回到上限（不等新回合开始——弃牌动画/敌方回合
	# 期间显示的已是新值）；_round_start 里同款重置兜开局首拍（幂等）
	player["qi"] = int(player["qi_max"])
	# 2026-11-06 四区制（规格 v1）：回合结束＝已打出区整堆平移弃牌堆（**不洗**——洗只在下次
	# 抽牌需要时发生）；打出时已逐张复原（离开手牌即复原——见 play_card）
	discard_pile.append_array(played_pile)
	played_pile = []
	played_changed.emit()
	if not discard_pile.is_empty():
		event.emit("回合结束：手牌与已打出牌冲弃")
	check_piles()
	# 2026-11-06 用户令「先弃完再抽」终裁＝真同步：弃牌数据落账后战斗**停摆**，
	# 等屏上弃牌动画播完回调 discard_anim_done()，才跑敌方回合＋新回合抽牌——
	# 牌堆计数等一切数字跟动画严格同步。探针/无屏直跑：end_turn 后连调 discard_anim_done() 同步推进。
	phase = "discarding"
	changed.emit()

## 终局弃手牌（2026-11-11 对齐原版 OnEncounterDefeated→DiscardHand：胜利时序手牌走
## 弃牌流程弃走，不再瞬隐）——hand＋已打出区整体冲弃（数据落账发 changed；表现层
## _rebuild_hand 对消失 uid 自动放飞弃堆动画、弃堆计数同步涨；check_piles 守恒）。
## 战斗快照本就随胜利作废，此转移只为表现层与弃堆计数与普通冲弃完全同构。
func discard_hand_finale() -> void:
	if hand.is_empty() and played_pile.is_empty():
		return
	var batch := hand.size()
	for card in hand:
		_strip_lv(card)
		discard_pile.push_back(card)
		hand_card_removed.emit(card, "discard", batch)   # 终局弃手＝同一弃牌飞行管线
	hand = []
	discard_pile.append_array(played_pile)
	played_pile = []
	played_changed.emit()
	check_piles()
	changed.emit()

## 弃牌表现完成回调（屏驱动；幂等——phase 已推进则忽略）
func discard_anim_done() -> void:
	if phase != "discarding":
		return
	phase = "enemy"
	changed.emit()
	enemy_round()   # 纯逻辑自动流转：UI 层只管按信号播表现，不手搓回合步进

## 敌方回合＝PerformIntents（2026-11-07 逆向对齐：**逐敌执行**动作——每敌独立结算、
## 独立过玩家甲；推翻 10-31「合并一次总打击」裁定）＋回合末补位＋（未终局）进入下一回合
## 敌方回合（2026-11-12 原版制改造·PerformIntents 同构）：入队阶段＋收口两段——
## 原版＝逐敌〔EnemyAction.Execute 模型**同步**＋演出协程包成命令 EnqueueCommand〕
## 三明治，EnemyTurnState.WaitForTurnEnd＝WaitWhile(IsProcessing‖IsAnyViewUpdating)。
## 我方（2026-11-12 CommandRunner 1:1）：有屏＝每敌先 Wait(0.12) 呼吸位（原版 Wait(seconds)
## 同构）再入队 EnemyActCommand；灼烧逐敌同构命令；回合收口＝轮询 IsProcessing 排空
## （WaitForTurnEnd 同构）→ enemy_round_end。
## 无屏/探针：_screen_attached=false＝无表现层，模型结算直执行不入队（原版不存在无屏态，
## 探针专用路径——drain 旧自创件随队列重写退役）。
func enemy_round() -> void:
	if phase != "enemy":
		return
	settle_all_strikes()   # 落账延迟兜底：演出未落完的账单先全落（终局判定随之收口）
	# ① 逐敌构建（对应 PerformIntents 逐敌循环）
	var actions: Array = []
	for e in encounter["active"].duplicate():
		if not e["alive"]:
			continue
		if int(e.get("row", 0)) > 0:
			continue   # 敌阵队列制（三原则①）：后排永不行动
		var act: Dictionary = e.get("current_intent", {})
		if int(e.get("skip", 0)) > 0:
			act = {"kind": "skip"}   # 跳过也是一条命令（占演出位，原版同构）
		elif act.is_empty():
			continue
		actions.push_back([e, act])
	# ①½ 灼烧逐敌构建（「本回合结束后」——先于补位；穿池甲）
	var burns: Array = []
	if int(encounter.get("burn", 0)) > 0:
		var bt := int(encounter["burn"])
		encounter["burn"] = 0
		for e in _alive_active().duplicate():
			burns.push_back([e, bt])
	if not _screen_attached:
		# 探针/无屏：模型结算直执行（无表现层；玩家倒下即弃余敌＝旧 clear 对位）
		for a in actions:
			if int(player["hp"]) <= 0:
				break
			_exec_enemy_action(a[0], a[1])
		for b in burns:
			if int(player["hp"]) <= 0:
				break
			_exec_enemy_burn(b[0], int(b[1]))
		enemy_round_end()
		return
	for a in actions:
		cmds.Wait(0.12)   # 逐敌节奏呼吸位（原版 Wait(seconds) 同构；旧 push delay 随队列重写退役）
		cmds.EnqueueCommand(EnemyActCommand.bind(a[0], a[1]))
	for b in burns:
		cmds.EnqueueCommand(EnemyBurnCommand.bind(b[0], int(b[1])))
	while cmds.IsProcessing():   # WaitForTurnEnd 同构（泵自排空，消费者轮询）
		await (Engine.get_main_loop() as SceneTree).process_frame
	enemy_round_end()

## enemy_act 命令体（原版三明治命令层）：执行→玩家倒下则弃队列余敌
func EnemyActCommand(e: Dictionary, act: Dictionary) -> void:
	_exec_enemy_action(e, act)
	if int(player["hp"]) <= 0:
		cmds.ClearCommands()   # 玩家倒下：弃队列余敌（对位同步循环 break），终局在 end 段收口

## enemy_act 执行体：信号口→模型结算→changed
func _exec_enemy_action(e: Dictionary, act: Dictionary) -> void:
	enemy_action_started.emit(e, act)   # 将来逐敌动画挂口（现在无接＝当帧过）
	if String(act.get("kind", "")) == "skip":
		var why := "缴械/冰冻"
		if bool(e.get("just_spawned", false)):
			why = "替补登场，本次不行动"
			e["just_spawned"] = false
		event.emit("「%s」%s" % [String(e["name"]), why])
		e["skip"] = int(e["skip"]) - 1
		return
	_last_action[int(e["uid"])] = String(act.get("kind", ""))
	ACTIONS.execute(self, e, act)   # 原版 EnemyAction.Execute（模型结算＋事件）
	changed.emit()

## enemy_burn 命令体
func EnemyBurnCommand(e: Dictionary, bt: int) -> void:
	_exec_enemy_burn(e, bt)

## enemy_burn 执行体
func _exec_enemy_burn(e: Dictionary, bt: int) -> void:
	event.emit("灼烧：「%s」受到 %d 点" % [e["name"], bt])
	_damage_enemy(e, bt, true)
	changed.emit()

## fx 效果表现命令体（Screen 注入 fx_launcher 则转发执行；命令体自含落定＝await 转发跑完）
func FxViewCommand(op: Dictionary) -> void:
	if fx_launcher.is_valid():
		await fx_launcher.call(op)

## 敌方回合收口（原序保留：补位→终局→下一回合）
func enemy_round_end() -> void:
	if phase != "enemy":
		return
	# ② 回合末补位（轮换制）：候补排到**队尾**（最深排之后）——队列制下排尾本就不行动，
	# 轮到顶上时才按原则②跳过一次（顶替通道统一在 _promote_rows）
	for i in encounter["refill"]:
		if _alive_active().size() >= int(encounter["active_max"]):
			break
		if encounter["reserve"].is_empty():
			break
		var nu: Dictionary = _make_enemy(String(encounter["reserve"].pop_front()))
		var max_row := 0
		for e2 in encounter["active"]:
			if e2["alive"]:
				max_row = maxi(max_row, int(e2.get("row", 0)))
		nu["row"] = max_row + 1
		encounter["active"].push_back(nu)
		event.emit("「%s」候补入场（队尾）" % nu["name"])
	# ③ 终局判定 / 下一回合
	if check_end():
		return
	round_no += 1
	_round_start()
	changed.emit()

func check_end() -> bool:
	if player["hp"] <= 0:
		phase = "over"
		result = "lose"
		ended.emit("lose")
		return true
	if _alive_active().is_empty() and encounter["reserve"].is_empty():
		phase = "over"
		result = "win"
		ended.emit("win")
		return true
	return false
#endregion

#region 出牌（去目标制：无目标选择；动态升级＝内功「动态升级」门控——2026-11-10 三公理集合制）
func card_lv(card: Dictionary) -> int:
	return int(card.get("lv", 0))

func card_cost(card: Dictionary) -> int:
	# 气费＝卡面底价＋动态升级费增量（活查询：手牌显示/可打校验/扣费三处同源）；
	# free＝升级选出的卡免一次费（2026-11-08 对齐原版 SetCardFreeToPlay——打出后消耗）
	if bool(card.get("free", false)):
		return 0
	return int(card["def"].get("cost", 0)) + int(card.get("cost_delta", 0))

func can_play(card: Dictionary) -> bool:
	return phase == "player" and int(player["qi"]) >= card_cost(card)

## 离开手牌即复原（动态升级口径）：打出/弃置/碎牌/消耗均清等级与费增量——覆盖
## 「进弃牌堆/回合结束/抽到进场＝初始值」全部复原路径（A2 切招复原另行就地清）。
func _strip_lv(card: Dictionary) -> void:
	card["lv"] = 0
	card["cost_delta"] = 0

## —— 动态升级三公理（2026-11-10 集合制定稿）——
## 执行顺序＝①A2 判定 → ②A1 升级 → ③A3 万能 → ④记型（play_card 内）。
## 接/换谓词见 QiVcData.FORM_SETS：接/换是完美二分——A1 升级集与 A2 复原集天然互斥，无优先级。
## A2 切招：打出牌与上一张「换」（型集无交集）→ 手牌中与打出牌「换」者：等级与费用复原初始。
func _dyn_switch_reset(p_form: String) -> void:
	if current_form == "" or not DATA.forms_switch(p_form, current_form):
		return
	# 名单只列真正掉级的牌（lv/费增量 >0）——没实际损失时不误导「复原」（2026-11-10 审计改）
	var names := PackedStringArray()
	for c in hand:
		if DATA.forms_switch(String(c["def"].get("stance", "")), p_form) \
				and (card_lv(c) > 0 or int(c.get("cost_delta", 0)) > 0):
			_strip_lv(c)
			names.push_back(String(c["def"].get("name", "")))
	if names.is_empty():
		event.emit("切招！")
	else:
		event.emit("切招！%s 复原" % "、".join(names))

## A1 升级：手牌中与打出牌「接」（型集有交集）且等级 ≤ 打出牌者：等级 +1、费用 +1
## （「cost_lock」词条＝费用锁定不加费，万能牌专用）。打出牌自身已离手，不参与。
func _dyn_upgrade(p_form: String, p_lv: int) -> void:
	var names := PackedStringArray()
	for c in hand:
		if not DATA.forms_connect(String(c["def"].get("stance", "")), p_form):
			continue
		if card_lv(c) > p_lv:
			continue
		c["lv"] = card_lv(c) + 1
		if not bool(c["def"].get("cost_lock", false)):
			c["cost_delta"] = int(c.get("cost_delta", 0)) + 1
		names.push_back("%s Lv%d" % [String(c["def"].get("name", "")), card_lv(c)])
	if not names.is_empty():
		event.emit("升级：%s" % "、".join(names))

## A3 万能打出：打出牌为 flex（型集＝全集）→ 手牌中与它「接」者（＝全体）费用复原初始。
## 结算在 A1 后（「给等级、费用推回起点」），等级不清。现役零张 flex 卡，照公理写全待内容轮。
func _dyn_wild_cost_reset(p_form: String) -> void:
	if p_form != "flex":
		return
	for c in hand:
		c["cost_delta"] = 0
	event.emit("变招！手牌费用复原")

## 出牌全流程（动态升级制）：定格等级/型 → 扣气 → 离手复原 → ⓪效果（按本张等级倍率）
## → ①A2 切招复原 → ②A1 同型升级 → ③A3 万能费用复原 → ④记型（内功门控——未获＝三步全跳）。
func play_card(card_uid: int) -> void:
	if phase != "player":
		return
	var card := {}
	for c in hand:
		if int(c["uid"]) == card_uid:
			card = c
			break
	if card.is_empty():
		return
	var def: Dictionary = card["def"]
	var cost := card_cost(card)
	if int(player["qi"]) < cost:
		event.emit("气不足")
		return
	player["qi"] = int(player["qi"]) - cost
	# —— 定格（打出瞬间冻结本张等级与型——公理结算全以此为准，离手复原不影响）——
	var p_lv := card_lv(card)
	var p_form := String(def.get("stance", ""))
	if p_form == "":
		# 无型牌不存在（2026-11-10 用户裁）——打出即卡表数据违例，直接报错；
		# 三公理照跳（防「空型＝半个万能牌」的放大失败模式）
		push_error("无型牌打出（卡表违例——所有卡必须带 stance）：id=%s" % String(card["id"]))
	hand.erase(card)
	card["free"] = false   # 免费标消耗（免一次——原版 SetCardFreeToPlay 同构）
	card["uses"] = int(card.get("uses", 0)) + 1
	_strip_lv(card)   # 离开手牌即复原（已打出区展示沿用打出前视图，不回读这两轨）
	if int(card["uses"]) >= 5:
		# 2026-11-06 碎牌机制（原版损坏制，**一回合之内**口径：普通 3 次生裂痕、裂痕态再
		# 1 次、第 5 次碎——防单回合少数牌无限循环）：第 5 次打出效果照常结算（ops 照跑），
		# 卡从卡组永久移除。召唤弱化死神＝后续轮，此轮不做（用户令）。
		shattered.push_back({"id": String(card["id"]), "uid": int(card["uid"])})
		_deck_total -= 1
		hand_card_removed.emit(card, "shatter", 1)   # 视图＝DestroyPile 溶解（destroyableCardConfig）
		card_shattered.emit(int(card["uid"]))
		event.emit("「%s」承受不住，彻底碎裂——从卡组永久消失" % String(def.get("name", "")))
	elif bool(card.get("exhaust", false)):
		exhaust_pile.push_back(card)
		hand_card_removed.emit(card, "exhaust", 1)   # 视图＝DestroyPile（消耗堆）
	else:
		# 2026-11-06 四区制（规格 v1）：打出→已打出区（回合末才整堆进弃牌堆——出牌历史的载体）。
		# 〔2026-11-08 撤令〕「零连击交互卡直弃」旧分支已随连击制退役——打出的卡默认一律进
		# 已打出区（右上角，玩家看得到刚打出的牌），回合末统一平移弃牌堆。
		played_pile.push_back(card)
		hand_card_removed.emit(card, "played", 1)   # 视图＝OnCardPlayedFull（离手→已打出区）
		played_changed.emit()
	# —— ⓪ 效果执行（2026-11-07 逆向重构）：伤害走单链（与 preview 物理同源），
	# 非伤害走 QiVcEffects 处理器注册表（对应原版 CardEffect.Execute 分发）；
	# 倍率＝本张打出时等级（动态升级占位公式：每级总输出 +30%——正式词条曲线待内容轮）
	_play_gen += 1   # 连打制（2026-11-09 对齐原版命令队列）：本张账单事件统一带新代标
	var mult := DATA.level_mult(p_lv)
	for op in card["def"].get("ops", []):
		if String(op.get("op", "")) == "dmg":
			_run_damage_op(op, def, mult)
		else:
			EFFECTS.run_op(self, op, mult)   # 数据结算**同步**（原版 CardEffect.OnExecuted 同构）
			# 效果表现命令化（原版 PlayerStatView.SetValueCommand 同构）：有屏才入队
			# （无屏＝无表现层不入队；fx_launcher 未挂动画＝当帧落定，结构先行）
			if fx_launcher.is_valid():
				cmds.EnqueueCommand(FxViewCommand.bind({"op": String(op.get("op", "")),
					"value": int(op.get("value", op.get("count", 0)))}))
	# —— 动态升级三公理（结算在效果之后＝doc 4.2「先效果后升级」——本张抽进手的新牌以
	# 初始值参与 A1）；内功门控：未获内功＝三步全跳、等级与费用纹丝不动；
	# ④记型不受门控（式槽显示沿用 2026-11-08 裁定）
	if upgrade_enabled and p_form != "":
		_dyn_switch_reset(p_form)
		_dyn_upgrade(p_form, p_lv)
		_dyn_wild_cost_reset(p_form)
	if p_form != "":
		current_form = p_form
	check_piles()
	if pending_visual and not _pending_strikes.is_empty():
		## 落账延迟：伤害账单等表现层击中帧逐事件结算，终局判定延后到 settle 内
		changed.emit()
		return
	settle_all_strikes()   # 无屏/无账单：立即全落＋终局判定（同步路径）
	changed.emit()

## 伤害单链入口（2026-11-08 落账延迟制，对应原版「账单算定→WeaponCollision 击中落账」：
## calculate 模拟产出事件流账单 → **入待落账队列，击中帧逐事件结算**（血量/死亡/数字同步动）。
## 无表现层（探针/无屏直跑 pending_visual=false）→ play_card 尾自动全落＝同步行为不变。
func _run_damage_op(op: Dictionary, def: Dictionary, mult: float) -> void:
	var params: Dictionary = EFFECTS.generate_damage_params(op, def, mult, self)
	var res: Dictionary = TARGETING.calculate({"enemies": encounter["active"],
		"params": params, "rng": rng})
	for ev in (res["events"] as Array):
		(ev as Dictionary)["gen"] = _play_gen   # 连打制：事件带代标（settle 按代收口，不吞下家）
		_pending_strikes.push_back(ev)
	_strike_total = int(res.get("total_strikes", 0))

## 当前出牌代（屏幕拍驱动串行化用）
func play_gen() -> int:
	return _play_gen

## 逐事件落账（表现层击中帧回调；hit→真扣血+hit_landed 信号跳数，death→出列/经验/顶替）
func settle_next_strike() -> bool:
	if _pending_strikes.is_empty():
		return false
	var ev: Dictionary = _pending_strikes.pop_front()
	if String(ev.get("type", "")) == "hit":
		_real_hit(ev.get("e", {}), int(ev.get("amount", 0)), bool(ev.get("is_crit", false)))
	else:
		_real_death(ev.get("e", {}))
	changed.emit()
	return not _pending_strikes.is_empty()

## 全落兜底（无屏/回合推进/演出中断）：落完待账 → 终局判定在此收口。
## gen＝-1（默认）落完全部队（探针/回合推进语义不变）；≥0＝只落本代及更早——
## 连打制（2026-11-09）：上一张演出收尾不得吞掉下一张排队的账单。
func settle_all_strikes(gen := -1) -> void:
	while not _pending_strikes.is_empty() \
			and (gen < 0 or int((_pending_strikes[0] as Dictionary).get("gen", -1)) <= gen):
		settle_next_strike()
	if phase == "player":
		check_end()

## 待落账事件快照（表现层演出驱动用——不动队列；gen≥0 只取该代——连打制：各拍驱动
## 只消费自己那张牌的账单，不含排队中下家的事件）
func strike_snapshot(gen := -1) -> Array:
	if gen < 0:
		return (_pending_strikes as Array).duplicate()
	var out: Array = []
	for ev in _pending_strikes:
		if int((ev as Dictionary).get("gen", -1)) == gen:
			out.push_back(ev)
	return out

## 本次打出的飞行总段数（2026-11-08 余段空放制——表现层拍数权威，含 amount/弹射段）
func strike_total() -> int:
	return _strike_total

## hooks.hit：真值侧同步落账（账本已推演同序列——甲吸收→血扣除；暴击标注传表现层）
func _real_hit(e: Dictionary, dmg: int, is_crit: bool) -> void:
	var left := dmg
	if int(e.get("armor", 0)) > 0:
		var absorb := mini(int(e["armor"]), left)
		e["armor"] = int(e["armor"]) - absorb
		left -= absorb
	if left > 0:
		e["hp"] = maxi(0, int(e["hp"]) - left)
		event.emit("「%s」受到 %d 点伤害%s" % [String(e["name"]), dmg, "（暴击）" if is_crit else ""])
	hit_landed.emit(e, dmg, "攻击", is_crit)

## hooks.death（对应原版 EnemyModel.ResolveDamage→Died→EncounterModel.EnemyDied）：
## 死帧入账（2026-11-09 贴原版令：数据先行、珠降级纯演出——推翻 11-05 珠到账制）；
## 意图清除/出列/顶替。xp_credit＝按 uid 记一份已入账值，屏幕放珠取 +N 用。
func _real_death(e: Dictionary) -> void:
	_credit_kill_xp(e)
	e["alive"] = false
	e["current_intent"] = {}   # 意图随敌走（对应 CurrentIntent）
	encounter["active"].erase(e)
	event.emit("「%s」离场" % String(e["name"]))
	_promote_rows()

## ── 打出预览（2026-11-06 美术 AI 对接口）：preview_play——只读干跑，绝不落账 ──
## 严格镜像 play_card 的结算推导（等级倍率同口径、遭遇护甲逐段吸收、目标集同源），
## 不掷暴击（预览给基础值）、不动任何真状态（气/等级/费用/敌血全不碰）。
## 返回：ok＝can_play；damage＝{敌uid: 总伤}（多段卡另给顶层 hits/per）；
## **crit_damage＝{敌uid: 暴击档总伤}**（2026-11-07 用户令：预览必须体现暴击——每敌伤害按
## CRIT_MULT 放大的平行档，UI 显示「8（暴击 16）」；随机不进预览、两档并列展示）；
## kills＝推演会死的敌 uid；qi＝净气变化（−实付气，含动态升级费增量）；armor＝获甲（立即生效量）；
## status_add＝状态施加（burn→"encounter"键、缴械/冰冻→"all"键）；status_delta＝预留恒空；
## lv＝本张当前等级（UI 展示用）。
func preview_play(card: Dictionary) -> Dictionary:
	var out := {"ok": false, "damage": {}, "kills": [], "qi": 0, "armor": 0,
		"draw": 0, "heal": 0, "recovery": 0, "qi_max": 0,
		"crit_damage": {},
		"status_add": {}, "status_delta": {},
		"lv": card_lv(card)}
	if not can_play(card):
		return out
	out["ok"] = true
	var def: Dictionary = card["def"]
	# —— 等级/费用镜像（2026-11-10 动态升级：倍率＝本张当前等级占位公式；气费＝底价＋费增量）——
	var mult := DATA.level_mult(card_lv(card))
	var cost := card_cost(card)
	out["qi"] = -cost
	# —— ops 干跑（只推演伤害/护甲/状态；暴击随机不进预览；**敌方护甲不进预览**——
	# 2026-11-07 用户令：预览只给出我方打出的伤害，遭遇护甲的吸收由玩家对照敌方护甲条自行判断）
	# —— ops 干跑（2026-11-07 逆向重构：dmg 走单链只读推演——与 play_card 物理同源；
	## 暴击随机不进预览（crit_chance 置 0 给基础档），crit_damage 为暴击平行档；
	## 敌方护甲不进预览口径——玩家对照敌卡护甲自行判断）
	for op in def.get("ops", []):
		var opk := String(op.get("op", ""))
		if opk == "dmg":
			var params: Dictionary = EFFECTS.generate_damage_params(op, def, mult, self)
			params["crit_chance"] = 0.0
			var res: Dictionary = TARGETING.calculate({"enemies": encounter["active"],
				"params": params, "rng": rng})
			out["damage"] = res["damage"]
			out["kills"] = res["kills"]
			if int(params.get("hits", 1)) > 1:
				out["hits"] = int(params["hits"])
				out["per"] = int(params["damage_per_hit"])
		else:
			match opk:
				"armor":
					out["armor"] = int(out["armor"]) + int(round(float(int(op.get("amount", 0))) * mult))
				"draw":
					out["draw"] = int(out["draw"]) + int(round(float(int(op.get("count", 1))) * mult))
				"heal":
					out["heal"] = int(out["heal"]) + int(round(float(int(op.get("amount", 0))) * mult))
				"recovery":
					out["recovery"] = int(out["recovery"]) + int(op.get("amount", 0))
				"qi_max":
					out["qi_max"] = int(out["qi_max"]) + int(op.get("amount", 0))
				"burn":
					out["status_add"]["encounter"] = {"burn": int(round(float(int(op.get("value", 0))) * mult))}
				"disarm", "freeze":
					out["status_add"]["all"] = {"skip": maxi(1, int(op.get("rounds", 1)))}
				"erase":
					for e in _alive_active():
						var euid2 := int(e["uid"])
						out["damage"][euid2] = int(out["damage"].get(euid2, 0)) + int(e["hp"])
						if not (out["kills"] as Array).has(euid2):
							(out["kills"] as Array).push_back(euid2)
	# 暴击档平行账（2026-11-07 用户令）：每敌基础总伤 ×CRIT_MULT——「8（暴击 16）」两档并列；
	# total＝多段合在一块的总伤（2026-11-07 用户令「预览总共合在一块」）
	var total := 0
	for euid3 in (out["damage"] as Dictionary).keys():
		out["crit_damage"][euid3] = int(out["damage"][euid3]) * DATA.CRIT_MULT
		total += int(out["damage"][euid3])
	out["total"] = total
	# 击退能力回传（2026-11-08 用户令「预览要跟上，跟暴击一样」）：预览不掷真随机——
	# 返回卡的击退几率（0＝无，前端可据此标击退图标/词条）；**打出后**逐击掷定在账单
	# events[].kb（击中帧照账推退）——「随机但打出来时固定」与暴击快照同构
	out["knockback"] = float(def.get("knockback", 0.0))
	return out

## 单段伤害掷定已退役（2026-11-07 逆向重构；2026-11-08 撤溢出轮同日）：
## 伤害全线走 QiVcTargeting.calculate 单链（暴击掷＝roll_crit 连暴链、伤害封顶剩余血量）；
## 非伤害 ops 走 QiVcEffects.HANDLERS。
#endregion

#region 伤害与目标（每敌独立甲——2026-11-07 对齐原版 EnemyModel.Armor，遭遇甲池退役）
## 内部伤害入口（灼烧/抹除/调试杀用；卡牌伤害走 _run_damage_op 单链）：
## bypass_armor＝跳过敌甲直入（内部精确语义用）
func _damage_enemy(e: Dictionary, amt: int, bypass_armor: bool = false) -> void:
	var left := amt
	if not bypass_armor and int(e.get("armor", 0)) > 0:
		var absorb := mini(int(e["armor"]), left)
		e["armor"] = int(e["armor"]) - absorb
		left -= absorb
		event.emit("护甲抵御了 %d 点" % absorb)
	if left > 0:
		e["hp"] = maxi(0, int(e["hp"]) - left)
		event.emit("「%s」受到 %d 点伤害" % [String(e["name"]), left])
	if int(e["hp"]) <= 0:
		_credit_kill_xp(e)   # 死帧入账（2026-11-09 贴原版令：击杀拍即进账，珠纯演出）
		e["alive"] = false
		e["current_intent"] = {}
		encounter["active"].erase(e)
		event.emit("「%s」离场" % String(e["name"]))
	_promote_rows()

## 敌阵队列制·顶替（2026-11-07 终裁：**死一个就替补一个**——前排始终保持满员，不是整排死完）：
## 前排每死一人 → 紧邻后排（row 最小的后排）**最左存活者**顶上前排（row=0）
## ＋跳过当次行动（原则②：替补上来的那个不行动）；后排其余原地不动。
## 每次死亡各自触发（一次范围杀前排两个＝后排顺位顶两个）。精英占整排＝后批（档留位）。
func _promote_rows() -> void:
	# 2026-11-08 用户裁定对齐刀页「row 全清才 target the row behind」：前排尚有存活者
	# 不顶替；前排全灭→整排上移一行（row≥1 全体 −1），新前排首批 skip=1（原则②跳过
	# 一次行动保持）。旧制「死一个顶一个」同日退役——那会让顶上者提前成为合法目标。
	var front_alive := false
	for e in encounter["active"]:
		if bool(e.get("alive", false)) and int(e.get("row", 0)) == 0:
			front_alive = true
			break
	if front_alive:
		return
	var moved := false
	for e in encounter["active"]:
		if not bool(e.get("alive", false)):
			continue
		var rr := int(e.get("row", 0))
		if rr >= 1:
			e["row"] = rr - 1
			if rr == 1:
				e["skip"] = 1
				e["just_spawned"] = true   # 意图位空＋结算跳过（一次性）
				moved = true
	if moved:
		event.emit("前排尽没，后排整体压上（本次不行动）")

## 顺发池/最大排深/右→左列已退役（2026-11-07 逆向重构）——索敌全线在 QiVcTargeting。

func _front_enemy() -> Dictionary:
	# 队列制：front＝最前排（row 最小）最左存活敌
	var best: Dictionary = {}
	var best_row := 1 << 30
	for e in encounter["active"]:
		if not e["alive"]:
			continue
		var rr := int(e.get("row", 0))
		if rr < best_row:
			best_row = rr
			best = e
	return best

## 前 n 个存活敌（multi 目标档）
func _top_active(n: int) -> Array:
	return _alive_active().slice(0, n)

func _alive_active() -> Array:
	var out: Array = []
	for e in encounter["active"]:
		if e["alive"]:
			out.push_back(e)
	return out
#endregion

#region 意图（2026-11-07 逆向对齐：EnemyModel.CurrentIntent 制＋DecideIntent/PerformIntents）
## 意图决策（对应 EnemyEncounterModel.DecideIntents→EnemyModel.DecideIntent）：
## 意图挂敌自身 e["current_intent"]（对应 CurrentIntent——中心表 _intents 退役）；
## 现阶段单阶段意图池（ENEMIES.actions 平铺），EnemyIntentGroup 血量阶段切池＝数据升级位；
## first_turn_intent（替补登场首回合）由 just_spawned 在执行/显示侧挡（原则②）。
func decide_intents() -> void:
	for e in encounter["active"]:
		if not e["alive"]:
			continue
		e["current_intent"] = _pick_intent(e)

func _pick_intent(e: Dictionary) -> Dictionary:
	## 防连出过滤（对应 _last_action 制）＋ EnemyIntentGroup 阶段池入口：
	## 敌配置带 "intents"（[{hp_above, actions}]，按血量取最高 hp_above ≤ 血量比）优先
	var pool: Array = []
	var groups: Array = e.get("intents", [])
	if not groups.is_empty():
		var ratio := float(int(e["hp"])) / maxf(1.0, float(int(e["mhp"])))
		var best: Array = []
		var best_at := -1.0
		for g in groups:
			var at := float(g.get("hp_above", 0.0))
			if at <= ratio and at > best_at:
				best_at = at
				best = g.get("actions", [])
		pool = best.duplicate() if not best.is_empty() else []
	if pool.is_empty():
		pool = (e["actions"] as Array).duplicate()
	if pool.size() > 1:
		var last := String(_last_action.get(int(e["uid"]), ""))
		var filtered: Array = []
		for a in pool:
			if String(a["kind"]) != last:
				filtered.push_back(a)
		if not filtered.is_empty():
			pool = filtered
	return pool[rng.randi_range(0, pool.size() - 1)]

## 该敌当前意图的预计伤害（对应 GetProjectedDamage）——UI 意图位与探针共用。
## 队列制：后排（row>0）/缴械/替补登场回合恒 0（校验只校验前排——三原则①）
func intent_value(e: Dictionary) -> int:
	if int(e.get("row", 0)) > 0 or int(e.get("skip", 0)) > 0 \
			or bool(e.get("just_spawned", false)):
		return 0
	var act: Dictionary = e.get("current_intent", {})
	if act.is_empty():
		return 0
	return ACTIONS.projected(self, e, act)

## 意图值聚合口（对应 IIntentHolder.TryGetIntentValues→EncounterIntentView）：
## 返回 [{uid, kind, value}]——UI 聚合条的唯一数据源（禁直读内部）
func get_intent_values() -> Array:
	var out: Array = []
	for e in _alive_active():
		if int(e.get("row", 0)) > 0:
			continue
		var act: Dictionary = e.get("current_intent", {})
		if act.is_empty():
			continue
		if bool(e.get("just_spawned", false)) or int(e.get("skip", 0)) > 0:
			continue
		out.push_back({"uid": int(e["uid"]), "kind": String(act.get("kind", "")),
			"value": ACTIONS.projected(self, e, act)})
	return out

## 本回合敌方总威胁（UI 总预警用——逐敌值之和）
func merged_intent_total() -> int:
	var n := 0
	for iv in get_intent_values():
		n += int(iv["value"])
	return n

## 意图类型短名（UI 光带色用：attack/armor/…；不行动＝空）
func intent_kind_of(e: Dictionary) -> String:
	if int(e.get("row", 0)) > 0 or bool(e.get("just_spawned", false)) \
			or int(e.get("skip", 0)) > 0:
		return ""
	return String(e.get("current_intent", {}).get("kind", ""))

func intent_name(e: Dictionary) -> String:
	if int(e.get("row", 0)) > 0:
		return ""   # 后排不行动：无类型无数字，意图位空
	if bool(e.get("just_spawned", false)):
		return ""   # 顶替/替补登场跳过的回合＝不行动：意图位空（2026-11-07 用户口径）
	if int(e.get("skip", 0)) > 0:
		return "缴械"
	var act: Dictionary = e.get("current_intent", {})
	if act.is_empty():
		return ""
	return ACTIONS.display_name(act)
#endregion

#region 牌堆（冲弃＋洗回；手牌上限＝基础＋护腕加成）
## 2026-11-04 用户裁定：手牌**无上限**（抽多少进多少，多了靠视图挤紧；不再有「手牌已满」）
## 2026-11-06 四区制抽牌口径（规格 v1）：①先判后抽（**先洗再抽**——不够先整堆洗，不抽到一半洗，
## 2026-11-07 用户再确认）；②洗的是整堆不是差数（弃牌堆有几张洗几张，接在现有抽牌堆后）；
## ③keep_last_played＝抽牌由打出触发时，已打出区末位（正在结算的那张）不参与回收；
## ④弃牌堆空→二级回收已打出区（整堆平移弃→整堆洗）；⑤两级都空＝抽到为止，不报错不阻塞。
func draw_cards(n: int, keep_last_played := false) -> void:
	if n <= 0:
		return
	if draw_pile.size() < n:
		if not discard_pile.is_empty():
			var moved: Array = discard_pile
			discard_pile = []
			_shuffle(moved)
			draw_pile.append_array(moved)
			piles_shuffled.emit("discard")
			event.emit("弃牌堆整堆洗回抽牌堆")
		elif not played_pile.is_empty():
			var keep_n := 1 if keep_last_played else 0
			var pool: Array = played_pile.slice(0, played_pile.size() - keep_n)
			played_pile = played_pile.slice(played_pile.size() - keep_n, played_pile.size())
			discard_pile.append_array(pool)
			played_changed.emit()
			var moved2: Array = discard_pile
			discard_pile = []
			_shuffle(moved2)
			draw_pile.append_array(moved2)
			piles_shuffled.emit("played")
			event.emit("已打出牌收拢，整堆洗回抽牌堆")
	var drawn: Array = []
	for _i in n:
		if draw_pile.is_empty():
			break   # 两级都空：抽到为止（规格§4）
		var c: Dictionary = draw_pile.pop_front()
		hand.push_back(c)
		drawn.push_back(c)
	check_piles()
	if not drawn.is_empty():
		cards_drawn.emit(drawn)   # 视图＝DrawCardsCommand 整批命令（PlayerView 对位）

## 四区不变量自检（规格§8：手+已打出+弃+抽+消耗 ≡ 卡组总数；违者立刻报不吞）
func check_piles() -> bool:
	var total := hand.size() + played_pile.size() + discard_pile.size() \
		+ draw_pile.size() + exhaust_pile.size()
	if total != _deck_total:
		push_error("牌堆不变量破坏：区和 %d ≠ 卡组 %d" % [total, _deck_total])
		return false
	return true

## 打出全部（原版 Play All，2026-11-04）：按手牌顺序把当前可打的牌依次打出，打不动为止。
func play_all() -> void:
	if String(phase) != "player":
		return
	var guard := 0
	while guard < 60:
		guard += 1
		var pick := -1
		for i in hand.size():
			if can_play(hand[i]):
				pick = i
				break
		if pick < 0:
			break
		play_card(int(hand[pick]["uid"]))

## 手牌排序（2026-11-04 用户裁定「和原版一样」）：法力＝按气费升序；颜色＝按卡色序（红/蓝/黄/紫）再按费。
## 只改手牌数组顺序（模型序＝显示序，同原版 CardPile 重排），随后 changed 让视图重排。
func sort_hand(mode: String) -> void:
	if String(phase) != "player" or hand.size() <= 1:
		return
	if mode == "mana":
		hand.sort_custom(func(a, b):
			return card_cost(a) < card_cost(b))
	elif mode == "color":
		hand.sort_custom(func(a, b):
			var ca := _color_rank(String(a["def"].get("color", "")))
			var cb := _color_rank(String(b["def"].get("color", "")))
			if ca != cb:
				return ca < cb
			return card_cost(a) < card_cost(b))   # 排序吃活费（动态升级费增量入序）)
	else:
		return
	changed.emit()

static func _color_rank(c: String) -> int:
	match c:
		"red": return 0
		"blue": return 1
		"yellow": return 2
		"purple": return 3
		_: return 4

## 死帧入账（2026-11-09 贴原版令）：击杀拍即进账——growth 乘区统一在此乘一次
## （旧制 settle_one 漏乘/settle_all 才乘的暗病随之消除）；xp_credit 供屏幕放珠取 +N。
func _credit_kill_xp(e: Dictionary) -> void:
	var v := int(round(float(DATA.ENEMIES[String(e["id"])].get("xp", 0)) * stat_mult("growth")))
	xp_gained += v
	xp_credit[int(e["uid"])] = v
	changed.emit()

## 金币结算（2026-11-07 属性轮）：胜场金币＝击杀经验值×greed 乘区（100 基=×1）。
## curse 双向（自拟曲线：每 1% 诅咒＝+1% 金币＋经验——wiki「gain additional XP」实证）。
func gold_reward() -> int:
	return int(round(float(xp_gained) * stat_mult("greed")))

## 屏内升级结转用：取走全部已到账经验（显示层 run.xp+xp_gained 合成不受影响）
func consume_xp() -> int:
	var v := xp_gained
	xp_gained = 0
	return v

## 裂痕态查询（视觉/规则用：打过 3 次即带裂痕——第 4 次仍可打，第 5 次碎）
func is_cracked(card: Dictionary) -> bool:
	return int(card.get("uses", 0)) >= 3

## 战后写回源（层推进用；recovery＝红番茄族战后回复、xp_gained＝击杀经验，由宿主在胜利时结转）
func player_out() -> Dictionary:
	## 一次性卡（exhaust）：打掉＝**本局 run 永久移除**（2026-11-09 用户令「后续战斗也没了」
	## ——与碎牌同构，宿主按 cid 删一次出现；本场进消耗区不回收本就成立）
	var exhausted: Array = []
	for card in exhaust_pile:
		exhausted.push_back(String(card["id"]))
	return {"hp": maxi(0, int(player["hp"])), "armor_stat": int(player["armor_stat"]),
		"mhp": int(player["mhp"]), "recovery": int(player.get("recovery", 0)),
		"xp_gained": xp_gained,
		"gold": gold_reward(),   # 2026-11-07 属性轮：胜场金币（greed 乘后——宿主入局外档）
		"shattered": shattered.duplicate(),   # 2026-11-06 碎牌：宿主按此从 run 卡组删
		"exhausted": exhausted}
#endregion
