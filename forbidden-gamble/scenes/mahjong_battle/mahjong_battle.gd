extends Control

## 麻将演武（真气语法 v3.6 拍结构的演出场：摸牌→自动效果→附属行为→打出恰一次）。
## 根协调器：驱动 MJMatch 请求/应答状态机（玩家走 UI，敌方走 MJAI 贪心）＋装配区块组件。
## 区块组件在 ui/ 下（参照《我地麻》逆向研究的桌面分工，零资产提取、仅结构参照）：
##   top_bar 顶栏（返回/问号词条/设置/拍·行动方）｜top_center 气海背牌墙（浮窗＝记牌器）｜
##   fighter_panel 信息簇（气血行居左旁挂心法、丹田数领衔资源条、敌方手牌带＝防御翼·手牌恒中·
##   攻击翼、河/副露区在手牌带**下方**起排、运行态挂武学名）｜river_panel 气河区（定宽：敌方在
##   手牌带下行居左、我方与副露同行居左；批次一行不拆、溢行我上排敌下排）｜meld_strip 副露区
##   （定宽：敌方在手牌带下行居右、我方与牌河同行居右；一行三组、溢组我上排敌下排）｜
##   play_line 最新打出行（中部垂直水平居中；滞后入河——该侧下一拍开始才落河）｜hand_strip 丹田
##   牌行（落底）｜action_row 打出行（手牌上方：防御｜暗杠·攻击｜变招·打出；窄片描边＋资源小字＋
##   运行态）｜claim_popup 截牌窗（居中覆盖层）｜settings/glossary 弹层｜log_panel 战报（定宽居中）｜
##   tip_float 浮窗。
## 交互总纲（2026-09-16 用户令）：先选牌再点按钮——打出/变招的可用性由选区实时闸；
## 攻击武学两击（备付→发动）；底部提示行退役；机制说明住顶栏问号词条。
## 美术边界：占位牌面（代码绘制）＋同风格演出；正式美术后补。

var match_ := MJMatch.new()
var ai := MJAI.new()
var _current_request: Dictionary = {}
var _selected: Dictionary = {}  # 手牌索引 -> true（打出选弃/变招选组；索引＝引擎手牌序，非显示序）
var _selected_meld := -1        # 副露组索引（变招·换组目标；与手牌选区互斥）
var _marker_seen := ""
var _playing := {}              # side -> {batch, kind}：最近打出展示区数据源（POSTURE/TECH_FIRE 钩子喂）
var _fresh_ids: Array = []      # 刚摸到的牌实例 id（TILE_DRAWN 喂，含武学效果摸的牌；保留一整拍——打出即清）
var _tech_armed_id := ""        # 攻击武学备付态（第一击自动选付法；第二击发动）
# 敌方演出节奏（秒）——预览/自动驾驶会调小快进；玩家默认 0.6/0.35
var enemy_step_pause := 0.6
var enemy_after_pause := 0.35

# —— 区块组件 ——
var _top_bar: MJBTopBar
var _top_center: MJBTopCenter
var _enemy_panel: MJBFighterPanel
var _enemy_river: MJBRiverPanel    # 气河区·敌方（敌方手牌带左翼——贴手牌左，2026-09-17 用户令）
var _enemy_melds: MJBMeldStrip     # 副露区·敌方（敌方手牌带右翼——贴手牌右）
var _play_line: MJBPlayLine     # 最新打出行（打出交换区——普攻/虚招/反击/付式；滞后入河）
var _log_panel: MJBLogPanel
var _player_river: MJBRiverPanel   # 气河区·我方（与副露同行居左，手牌上方）
var _player_panel: MJBFighterPanel
var _player_melds: MJBMeldStrip    # 副露区·我方（与我方牌河同行居右）
var _defense_buttons: Array[Button] = []
var _hand_strip: MJBHandStrip
var _action_bar: MJBActionRow    # 打出行（手牌上方）：单行紧凑居中——防御｜变招·打出｜暗杠·攻击
var _claim_popup: MJBClaimPopup  # 截牌窗（居中弹窗——2026-09-16 用户复归令）
var _claim_box: VBoxContainer    # ＝截牌窗内容盒（m13 检视面）
var _settings_popup: MJBSettingsPopup
var _glossary_popup: MJBGlossaryPopup
var _banner: Label
var _overlay: PanelContainer
var _overlay_box: VBoxContainer
var _overlay_label: Label

# —— 打出行按钮与小字（选区/运行态实时刷写） ——
var _play_button: Button
var _play_cap: Label
var _bian_button: Button
var _bian_cap: Label
var _defense_caps: Array[Label] = []
var _tech_buttons: Dictionary = {}   # tech_id -> {button: Button, caption: Label}

var _claim_selected := {}  # 批位索引 -> true（弹窗内选牌：可截项默认全选）


func _ready() -> void:
	_build_ui()
	var cfg := {"seed": int(Time.get_unix_time_from_system()) % 100000}
	if RunSession.active and RunSession.state != null:
		# 挑战模式：值拷贝快照注入（对手卡＋玩家构筑/血量带入）；敌方 AI 权重由对手卡覆写
		var opp := RunSession.opponent()
		if not opp.is_empty():
			cfg = RunSession.state.build_match_cfg(opp)
			var ai_cfg: Dictionary = opp.get("ai", {})
			if ai_cfg.has("suit_weights"):
				ai.suit_weights = ai_cfg["suit_weights"]
			if ai_cfg.has("defense_hp_ratio"):
				ai.defense_hp_ratio = float(ai_cfg["defense_hp_ratio"])
			if ai_cfg.has("charge_threat_power"):
				ai.charge_threat_power = int(ai_cfg["charge_threat_power"])
			CodexState.discover(str(opp.get("id", "")))  # 交战即发现（图鉴发现制）
	match_.setup(cfg)
	# 注册须在 setup 之后：setup 换新事件表（防旧局监听复用），先注会挂在死表上
	match_.hooks.on(MJHooks.POSTURE, self, Callable(self, "_on_posture_played"))
	match_.hooks.on(MJHooks.TECH_FIRE, self, Callable(self, "_on_tech_fired"))
	match_.hooks.on(MJHooks.TILE_DRAWN, self, Callable(self, "_on_tile_drawn"))
	match_.start_battle()
	_pump()


# POSTURE＝打出批次确定：喂最新打出区（普攻/虚招/反击）；打出＝本拍终了，新牌标记随拍清。
func _on_posture_played(input: Dictionary) -> void:
	_playing[String(input.get("side", ""))] = {
		"batch": (input.get("batch", []) as Array).duplicate(),
		"kind": String(input.get("kind", "")),
	}
	if String(input.get("side", "")) == "player":
		_fresh_ids.clear()


# TILE_DRAWN＝摸牌（含破绽拍/缺牌补充/岭上/武学效果）：玩家整拍内新到的牌都记"刚摸到"。
func _on_tile_drawn(input: Dictionary) -> void:
	if String(input.get("side", "")) != "player":
		return
	for t in input.get("tiles", []):
		_fresh_ids.append((t as MJTile).get_instance_id())


# TECH_FIRE＝重击付式：功法打出的式也进最新打出区（2026-09-17 用户令），随后照常滞后入河。
func _on_tech_fired(input: Dictionary) -> void:
	_playing[String(input.get("side", ""))] = {
		"batch": (input.get("tiles", []) as Array).duplicate(),
		"kind": "tech",
	}


# ———— 驱动循环 ————

func _pump() -> void:
	while true:
		_refresh()
		_dump_battle_state()
		if match_.state == "over":
			_show_result()
			return
		# 破绽拍横幅（回气拍已退役；marker 带拍号——连拍不吞演出）
		if match_.last_marker != _marker_seen:
			_marker_seen = match_.last_marker
			var marker_side := _marker_seen.split(":")[1] if _marker_seen.split(":").size() > 1 else ""
			if _marker_seen.begins_with("flaw:"):
				_banner_show("破绽 · %s 只自然摸牌" % ("你" if marker_side == "player" else "对方"))
		_current_request = match_.next_request()
		if _current_request.is_empty():
			_show_result()
			return
		# 滞后入河·让位（2026-09-17 用户令修正：**该侧下一拍开始才落河**）——一侧的最新打出
		# 保留整个对方拍期间可读（含被截置灰）；其自身行动拍请求出现＝该侧新拍开始，旧批落河。
		var req_phase := String(_current_request["phase"])
		var req_side := String(_current_request["side"])
		if req_phase == "free_fire" or req_phase == "posture":
			_playing.erase(req_side)
		if req_side == "enemy":
			_banner_show("对方回合")
			_action_bar.set_enabled(false)  # 敌方演出期间禁用旧按钮：过期点击会替敌方提交决策＋双泵驱动（卡死根源）
			await get_tree().create_timer(enemy_step_pause).timeout
			var decision := ai.decide(_current_request)
			_flash_decision(decision)
			match_.decide(decision)
			await get_tree().create_timer(enemy_after_pause).timeout
		else:
			_banner_show("你的回合")
			_prepare_player_phase()
			return  # 等玩家操作；按钮回调里再调 _pump()


# ———— 玩家各阶段 UI（打出行单行紧凑居中：防御｜变招·打出｜暗杠·攻击，2026-09-17 间距令） ————

func _prepare_player_phase() -> void:
	_selected.clear()
	_selected_meld = -1
	_tech_armed_id = ""
	_action_bar.clear_buttons()
	_action_bar.set_enabled(true)
	_defense_buttons.clear()
	_defense_caps.clear()
	_tech_buttons.clear()
	_play_button = null
	_play_cap = null
	_bian_button = null
	_bian_cap = null
	_hand_strip.update_hand(match_.fighter("player").hand, _selected, _candidate_ids(), _fresh_ids)  # 清选区后立即重绘：残影不得照到新拍手牌
	_player_melds.update_melds(match_.fighter("player").melds, _selected_meld)
	var phase := String(_current_request["phase"])
	match phase:
		"free_fire":
			_add_defense_button()
			# 攻击功法＝变招之左：不能发动也展示（灰色），浮窗看所需式——2026-09-16 用户令
			_add_attack_buttons()
			_add_bian_button()
			_add_play_button()
			# 暗杠＝打出右侧（2026-09-17 用户令）：**手里有四张全同才显示**——能晒＝可点，
			# 非自由拍＝灰；没有机会＝不显示（无占位）
			for option in _current_request.get("ankan_options", []):
				_add_ankan_button(String(option["key"]), true)
		"posture":
			_add_defense_button()
			# 攻击武学常驻（2026-09-17 用户令：不可点击≠消失）——打出阶段锁死置灰，敌方拍整行照旧禁用
			_add_attack_buttons(true)
			_add_bian_button()
			_add_play_button(true)
			for key in _ankan_keys():
				_add_ankan_button(key, false)  # 有四张但非自由拍：灰
		"claim":
			# 招架（截牌）：打出行**保留但整行置灰**（2026-09-17 用户令：变灰不消失）；
			# 无选项静默放行；有选项＝居中弹窗（点牌改选，默认全选）
			_add_defense_button()
			_add_attack_buttons(true)
			_add_bian_button()
			_add_play_button(true)
			for key in _ankan_keys():
				_add_ankan_button(key, false)
			_sync_buttons()
			_action_bar.set_enabled(false)  # 置灰须在选区同步之后（同步会按选区重亮打出键）
			var options: Array = _current_request.get("claim_options", [])
			if options.is_empty():
				_submit({"claim": null})
				return
			_prepare_claim_selection()
			_claim_popup.open_popup(_current_request, _claim_selected,
				Callable(self, "_submit"), Callable(self, "_toggle_claim_select"))
			return
	_sync_buttons()


# 攻击武学·两击交互（2026-09-17 用户令，替代付法列表视图）：
# 第一击＝备付——自动选中首个手牌付法（选中态＝升起），其余能付的牌标候选（金边）；
# 第二击＝发动——选区恰合某付法即发该法；不合则重选首个；纯明式付法（无手牌）第二击直发。
func _on_tech_button(tech_id: String) -> void:
	var plans: Array = []
	for tech in _current_request.get("techniques", []):
		if String(tech["id"]) == tech_id:
			plans = tech.get("plans", [])
			break
	var match_index := _selection_plan_match(plans)
	if match_index >= 0:
		_tech_armed_id = ""
		_submit({"fire": [tech_id], "fire_variant": match_index})
		return
	var has_hand_plan := false
	for plan in plans:
		if (plan as Dictionary).get("ids", []).size() > 0:
			has_hand_plan = true
			break
	if _tech_armed_id == tech_id and not has_hand_plan:
		_tech_armed_id = ""
		_submit({"fire": [tech_id], "fire_variant": 0})  # 纯明式付法：无手牌可选，第二击直发
		return
	_tech_armed_id = tech_id
	for plan in plans:
		if (plan as Dictionary).get("ids", []).size() > 0:
			_select_plan(plan)
			break
	_refresh_armed_style()
	_render_selection()


# 备付态样式刷写：当前备付武学的按钮微金调，其余复原（2026-09-17 审计项——两击有视觉反馈）。
func _refresh_armed_style() -> void:
	for tid in _tech_buttons:
		var entry: Dictionary = _tech_buttons[tid]
		var b: Button = entry["button"]
		if is_instance_valid(b):
			MJBActionRow.set_armed_style(b, String(tid) == _tech_armed_id)


# 选区（手牌索引集）是否恰等于某手牌付法的实例 id 集——命中返回该付法在 plans 里的下标。
func _selection_plan_match(plans: Array) -> int:
	if _selected.is_empty():
		return -1
	var hand := match_.fighter("player").hand
	var sel_ids := {}
	for k in _selected.keys():
		var i := int(k)
		if i < 0 or i >= hand.size():
			return -1
		sel_ids[hand[i].get_instance_id()] = true
	for pi in range(plans.size()):
		var plan: Dictionary = plans[pi]
		var ids: Array = plan.get("ids", [])
		if int(plan.get("melds", 0)) != 0 or ids.size() != sel_ids.size():
			continue
		var all_in := true
		for id in ids:
			if not sel_ids.has(int(id)):
				all_in = false
				break
		if all_in:
			return pi
	return -1


# 按付法实例 id 集选中对应手牌索引。
func _select_plan(plan: Dictionary) -> void:
	_selected.clear()
	var hand := match_.fighter("player").hand
	for id in plan.get("ids", []):
		for i in range(hand.size()):
			if hand[i].get_instance_id() == int(id):
				_selected[i] = true
				break


# 备付候选（金边）：已备付武学的全部手牌付法所涉实例 id（选中态除外——组件内排除）。
func _candidate_ids() -> Array:
	if _tech_armed_id.is_empty():
		return []
	var out: Array = []
	for tech in _current_request.get("techniques", []):
		if String(tech["id"]) != _tech_armed_id:
			continue
		for plan in tech.get("plans", []):
			for id in (plan as Dictionary).get("ids", []):
				out.append(int(id))
	return out


# 护体（护身槽·守功法）＝行动窗口内免费即时：free_fire/posture 两阶段可放。
# 左区；小字＝罡气价（生效中＝剩N拍＋运行高亮）；点过之后立即同步按钮态
# （罡气是请求构建时的旧值，不刷新会静默失败打转——用户卡住报告的第二根源）。
func _add_defense_button() -> void:
	var iron: Dictionary = _current_request.get("iron", {})
	for tech in _current_request.get("techniques", []):
		if String(tech["kind"]) != "defense":
			continue
		var cost := int(tech.get("gang_qi_cost", 0))
		var tech_id := String(tech["id"])
		var on_defend := func() -> void:
			if match_.try_defense("player", tech_id):
				# 护体不改手牌——预选保真（2026-09-17 用户令：点防御武学不清选中）
				var kept_sel := _selected.duplicate()
				var kept_meld := _selected_meld
				_after_free_action()
				_selected = kept_sel
				_selected_meld = kept_meld
				_render_selection()
			_sync_defense_buttons()
		var made := _action_bar.add_capped_button(String(tech["name"]), "罡%d" % cost, on_defend)
		var b: Button = made["button"]
		b.set_meta("defense_button", true)  # m13 自动驾驶以此识别（文本已名only化）
		b.set_meta("defense_cost", cost)
		MJBTipFloat.bind_tech(b, match_.techniques["player"].get(tech_id))
		b.disabled = not bool(tech["can_use"])
		if bool(iron.get("active", false)):
			b.disabled = true
		_defense_buttons.append(b)
		_defense_caps.append(made["caption"])


func _sync_defense_buttons() -> void:
	var p := match_.fighter("player")
	for b in _defense_buttons:
		if is_instance_valid(b):
			b.disabled = p.iron_active or p.gang_qi < int(b.get_meta("defense_cost"))


# 变招＝先选牌再点按钮（与打出同一逻辑，2026-09-16 用户令）：选 1 张手牌＝换一张（机会−1）；
# 选整组（手牌暗组/副露明组）＝换组（机会−3）。免费即时、不占打出。
func _add_bian_button() -> void:
	var made := _action_bar.add_capped_button("变 招", "机会 %d" % match_.fighter("player").bian_opps,
		func(): _try_bian())
	_bian_button = made["button"]
	_bian_cap = made["caption"]
	MJBTipFloat.bind(_bian_button, "变招", [
		"选 1 张手牌＝换一张（机会−1）",
		"选整组＝换组（机会−3）"])


# 打出（free_fire＝确认打出预选；posture＝弃牌确认）。
func _add_play_button(posture_mode := false) -> void:
	var on_play := func() -> void:
		if posture_mode:
			_submit_posture()
		else:
			_on_play_button()
	var made := _action_bar.add_capped_button("打 出", "%d 张" % _play_need(), on_play)
	_play_button = made["button"]
	_play_cap = made["caption"]
	if posture_mode:
		_play_button.name = "ConfirmButton"


# 暗杠（打出右侧，2026-09-17 用户令）：手里四张全同才显示——能晒＝可点，非自由拍＝灰。
func _add_ankan_button(kan_key: String, usable: bool) -> void:
	var made := _action_bar.add_capped_button("暗杠·%s" % kan_key, "免费",
		func(): _submit({"ankan": kan_key}))
	(made["button"] as Button).disabled = not usable
	MJBTipFloat.bind(made["button"], "暗杠·%s" % kan_key, [
		"手里四张全同＝免费自晒（不占打出、不开截牌窗）",
		"四张入副露成重式，岭上摸 1，罡气 +1"])


# 手里的暗杠机会（四张全同的 key）——posture/claim 请求不带 ankan_options，自行扫手牌。
func _ankan_keys() -> Array:
	var counts := {}
	for t in match_.fighter("player").hand:
		var key := (t as MJTile).key()
		counts[key] = int(counts.get(key, 0)) + 1
	var out: Array = []
	for key in counts:
		if int(counts[key]) >= 4:
			out.append(key)
	out.sort()
	return out


# 攻击功法＝变招之左：不能发动也展示（灰色）、浮窗看所需式——任何阶段常驻；
# lock＝本拍不可发（打出阶段），全置灰。
func _add_attack_buttons(lock := false) -> void:
	for tech in _current_request.get("techniques", []):
		if String(tech["kind"]) != "attack":
			continue
		var tech_id := String(tech["id"])
		var made := _action_bar.add_capped_button(String(tech["name"]),
			_recipe_caption(match_.techniques["player"].get(tech_id)),
			func(): _on_tech_button(tech_id))
		var b: Button = made["button"]
		b.disabled = lock or not bool(tech["can_use"])
		MJBTipFloat.bind_tech(b, match_.techniques["player"].get(tech_id))
		_tech_buttons[tech_id] = {"button": b, "caption": made["caption"]}


func _recipe_caption(tech: MJTechnique) -> String:
	if tech == null:
		return ""
	var parts: Array[String] = []
	for symbol in tech.recipe:
		parts.append("%s×%d" % [symbol, int(tech.recipe[symbol])])
	return "＋".join(parts)


# ———— 选区（先选牌再点按钮：打出/变招共用一条选区流） ————

func _play_need() -> int:
	var phase := String(_current_request.get("phase", ""))
	if phase == "free_fire":
		var p := match_.fighter("player")
		return maxi(1, p.hand.size() - p.rest_cap())  # 与引擎打出恰一次同式
	if phase == "posture":
		return int(_current_request.get("discard_count", 0))
	return 0


# 手牌点选：与打出确认同一条流——free_fire＝打出预选；posture＝弃牌选择；
# 变招换组也经此选（上限放到 4 张：max(打出张数, 组张数)）。选中的再点一下取消。
func _on_tile_clicked(index: int) -> void:
	if String(_current_request.get("side", "")) != "player":
		return  # 敌方请求期间点牌＝无操作（选区与旧按钮不得复活）
	var phase := String(_current_request.get("phase", ""))
	if phase != "free_fire" and phase != "posture":
		return
	_selected_meld = -1  # 手牌与副露选区互斥
	var cap := maxi(_play_need(), 4)
	if _selected.has(index):
		_selected.erase(index)
	elif _selected.size() < cap:
		_selected[index] = true
	_render_selection()


# 副露组点选：整组进出选区（变招·换组目标）；与手牌选区互斥。
func _on_meld_clicked(mi: int) -> void:
	if String(_current_request.get("side", "")) != "player":
		return
	_selected_meld = -1 if _selected_meld == mi else mi
	_selected.clear()
	_render_selection()


func _render_selection() -> void:
	_hand_strip.update_hand(match_.fighter("player").hand, _selected, _candidate_ids(), _fresh_ids)
	_player_melds.update_melds(match_.fighter("player").melds, _selected_meld)
	_sync_buttons()


# 按钮可用性＝选区实时闸（2026-09-16 用户令）：打出＝未选副露且张数恰合；
# 变招＝机会够且选区构成合法目标（1 张手牌／整组）。
func _sync_buttons() -> void:
	if _play_button != null and is_instance_valid(_play_button):
		_play_button.disabled = _selected_meld != -1 or _selected.size() != _play_need()
		if _play_cap != null and is_instance_valid(_play_cap):
			_play_cap.text = "%d 张" % _play_need()
	if _bian_button != null and is_instance_valid(_bian_button):
		_bian_button.disabled = not _bian_ready()
		if _bian_cap != null and is_instance_valid(_bian_cap):
			_bian_cap.text = "机会 %d" % match_.fighter("player").bian_opps


func _bian_ready() -> bool:
	var p := match_.fighter("player")
	if _selected_meld != -1:
		return p.bian_opps >= 3
	if _selected.size() == 1:
		return p.bian_opps >= 1
	return p.bian_opps >= 3 and not _bian_hand_group().is_empty()


# 当前手牌选区是否恰好构成请求里的一个手牌暗组（换组目标）。
func _bian_hand_group() -> Array:
	if _selected.size() < 3:
		return []
	var want := {}
	for k in _selected.keys():
		want[int(k)] = true
	for g in _current_request.get("bian_groups", []):
		if String(g.get("kind", "")) != "hand":
			continue
		var idx: Array = g.get("indexes", [])
		if idx.size() != want.size():
			continue
		var all_in := true
		for i in idx:
			if not want.has(int(i)):
				all_in = false
				break
		if all_in:
			return idx
	return []


# 变招执行：按选区分派（副露组／1 张手牌／手牌暗组）；引擎拒付则原地重对按钮态。
func _try_bian() -> void:
	var p := match_.fighter("player")
	var done := false
	if _selected_meld != -1 and p.bian_opps >= 3:
		done = match_.try_bian_group("player", _selected_meld, [])
	elif _selected_meld == -1 and _selected.size() == 1 and p.bian_opps >= 1:
		done = match_.try_bian_hand("player", int(_selected.keys()[0]))
	else:
		var group := _bian_hand_group()
		if not group.is_empty() and p.bian_opps >= 3:
			done = match_.try_bian_group("player", -1, group)
	if done:
		_after_free_action()
	else:
		_sync_buttons()


# 窗口内免费操作（护体/变招）完成后的公共收尾：请求已过期，重取＋重建按钮＋刷新。
# 终局护栏：免费动作也可能终结战斗（如变招一击致死）——空请求交回 _pump 弹终局，
# 不得带着空请求重建按钮（"phase" 无效键报错——用户实证的变招崩溃根源）。
func _after_free_action() -> void:
	_selected.clear()
	_selected_meld = -1
	_current_request = match_.next_request()
	if _current_request.is_empty():
		_pump()
		return
	_prepare_player_phase()
	_refresh()


func _submit(decision: Dictionary) -> bool:
	# 过期应答闸：只在"当前请求归玩家"时受理——敌方演出期间点旧按钮＝替敌方决策＋双泵，一律忽略
	if String(_current_request.get("side", "")) != "player":
		return false
	_claim_popup.close()
	_selected.clear()  # 提交即清：功法按钮打断预选后的敌方回合渲染不得带出选中残影
	_selected_meld = -1
	_claim_selected.clear()
	match_.decide(decision)
	_pump()
	return true


func _submit_posture() -> void:
	var indexes: Array[int] = []
	for i in _selected.keys():
		indexes.append(int(i))
	_selected.clear()  # 提交即清：敌方回合的渲染不得带出本拍选中残影
	_submit({"discard_indexes": indexes})


# 打出确认（free_fire）：此刻才提交"不发动重击"（空 fire 应答）——预选不占承诺，
# 确认前功法/暗杠/护体/变招按钮照常可用。
func _on_play_button() -> void:
	var carried: Array[int] = []
	for i in _selected.keys():
		carried.append(int(i))
	if not _submit({"fire": []}):
		return
	# _submit→_pump 玩家侧同步走完：同拍 posture 请求已备好、选区已清——预选带回
	if String(_current_request.get("phase", "")) != "posture":
		return
	var need := int(_current_request.get("discard_count", 0))
	for i in carried:
		if _selected.size() < need:
			_selected[i] = true
	_hand_strip.update_hand(match_.fighter("player").hand, _selected, _candidate_ids(), _fresh_ids)
	if _play_button != null and is_instance_valid(_play_button):
		_play_button.disabled = _selected.size() != need
	if not carried.is_empty() and _selected.size() == need:
		_submit_posture()  # 预选足张：点牌→「打 出」一气呵成


# ———— 招架（弹窗内选牌：默认全选，一次按钮多截） ————

func _toggle_claim_select(index: int) -> void:
	if _claim_selected.has(index):
		_claim_selected.erase(index)
	else:
		_claim_selected[index] = true
	_claim_popup.open_popup(_current_request, _claim_selected,
		Callable(self, "_submit"), Callable(self, "_toggle_claim_select"))  # 重建弹窗反映选择态（含按钮计数）


# 进入招架前设置默认全选（可截项）。
func _prepare_claim_selection() -> void:
	_claim_selected.clear()
	var options: Array = _current_request.get("claim_options", [])
	var seen := {}
	for option in options:
		var bi := int(option["batch_index"])
		if not seen.has(bi):
			seen[bi] = true
			_claim_selected[bi] = true


# ———— 刷新（渲染下放组件） ————

func _refresh() -> void:
	var p := match_.fighter("player")
	var e := match_.fighter("enemy")
	_top_bar.set_turn("拍 %d · %s" % [match_.beat, "你的回合" if match_.turn_side == "player" else "对方回合"],
		Color(0.7, 0.85, 0.65) if match_.turn_side == "player" else Color(0.85, 0.65, 0.55))
	_top_center.update_center(match_.wall.live_left(), match_.river)
	_play_line.update(_playing, {"enemy": e.melds, "player": p.melds})
	_enemy_panel.update_panel(e, match_.techniques["enemy"], false, match_.xinfa["enemy"])
	_enemy_melds.update_melds(e.melds)
	_player_panel.update_panel(p, match_.techniques["player"], true, match_.xinfa["player"])
	_hand_strip.update_hand(p.hand, _selected, _candidate_ids(), _fresh_ids)
	_player_melds.update_melds(p.melds, _selected_meld)
	_enemy_river.update_panel(match_.river, _latest_ids("enemy"))
	_player_river.update_panel(match_.river, _latest_ids("player"))
	_log_panel.update_log(match_.log.slice(maxi(0, match_.log.size() - 8)))
	_sync_running_captions()


# 滞后入河：还挂在最新打出区的牌实例 id——气河行暂不显示这些张。
func _latest_ids(side: String) -> Array:
	var info: Dictionary = _playing.get(side, {})
	if info.is_empty():
		return []
	var ids: Array = []
	for t in info.get("batch", []):
		ids.append((t as MJTile).get_instance_id())
	return ids


# 运行态挂按钮（2026-09-16 用户令，替代独立"运行中"行）：护体生效＝剩N拍＋高亮；
# 重击在途＝等N拍＋高亮；否则恢复资源小字（罡气价/配方）。
func _sync_running_captions() -> void:
	var p := match_.fighter("player")
	for i in range(_defense_buttons.size()):
		var b := _defense_buttons[i]
		if not is_instance_valid(b) or i >= _defense_caps.size():
			continue
		var cap: Label = _defense_caps[i]
		if p.iron_active:
			cap.text = "剩%d拍" % p.iron_beats_left
			MJBActionRow.set_running_style(b, true)
		else:
			cap.text = "罡%d" % int(b.get_meta("defense_cost"))
			MJBActionRow.set_running_style(b, false)
	for tech_id in _tech_buttons:
		var entry: Dictionary = _tech_buttons[tech_id]
		var tb: Button = entry["button"]
		if not is_instance_valid(tb):
			continue
		var left := -1
		for c in p.pending:
			if String(c["tech_id"]) == String(tech_id):
				left = maxi(int(c.get("windup", 1)) - int(c.get("elapsed", 0)), 0)
		var cap: Label = entry["caption"]
		if left >= 0:
			cap.text = "等%d拍" % left
			MJBActionRow.set_running_style(tb, true)
		else:
			cap.text = _recipe_caption(match_.techniques["player"].get(tech_id))
			MJBActionRow.set_running_style(tb, false)


func _on_sort_toggled(on: bool) -> void:
	_hand_strip.set_auto_sort(on)
	_refresh()  # 理牌开关变化→整面重排


# ———— 演出（占位 VFX） ————

# 战斗现场落盘（user://mj_battle_log.txt）：引擎态＋UI 请求态＋战报尾部。
# 每次驱动循环覆盖写——卡死时这份文件就是可读的现场（2026-09-16 用户"能读日志吗"落地）。
func _dump_battle_state() -> void:
	var req: Dictionary = match_.next_request() if match_.state == "running" else {}
	var lines: Array[String] = []
	lines.append("=== %s ===" % Time.get_datetime_string_from_system())
	lines.append("state=%s winner=%s beat=%d turn_side=%s req=%s/%s ui_req=%s/%s popup=%s batch=%d" % [
		match_.state, match_.winner, match_.beat, match_.turn_side,
		String(req.get("phase", "")), String(req.get("side", "")),
		String(_current_request.get("phase", "")), String(_current_request.get("side", "")),
		_claim_popup.visible, match_.pending_batch.size()])
	lines.append("player hand=%d gang=%d bian=%d iron=%s pending=%d melds=%d hp=%.2f | enemy hand=%d gang=%d bian=%d iron=%s pending=%d melds=%d hp=%.2f | wall=%d river=%d" % [
		match_.fighter("player").hand.size(), match_.fighter("player").gang_qi,
		match_.fighter("player").bian_opps, match_.fighter("player").iron_active,
		match_.fighter("player").pending.size(), match_.fighter("player").melds.size(),
		match_.fighter("player").hp_fp / 100.0,
		match_.fighter("enemy").hand.size(), match_.fighter("enemy").gang_qi,
		match_.fighter("enemy").bian_opps, match_.fighter("enemy").iron_active,
		match_.fighter("enemy").pending.size(), match_.fighter("enemy").melds.size(),
		match_.fighter("enemy").hp_fp / 100.0,
		match_.wall.live_left(), match_.river.size()])
	for line in match_.log.slice(maxi(0, match_.log.size() - 30)):
		lines.append(line)
	var f := FileAccess.open("user://mj_battle_log.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))


func _banner_show(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


# AI 决策一闪（决策可见性：让玩家看见对方做了什么）
func _flash_decision(decision: Dictionary) -> void:
	var phase := String(_current_request.get("phase", ""))
	var text := ""
	match phase:
		"free_fire":
			text = "对方重击蓄势" if (decision.get("fire", []) as Array).size() > 0 else "对方打出"
			if str(decision.get("defense", "")) != "":
				text = "对方护体"
		"posture":
			match String(_current_request.get("play_kind", "")):
				"counter":
					text = "对方反击（不可截）"
				"xuzhao":
					text = "对方虚招（0 伤，可截走）"
				_:
					text = "对方普攻"
		"claim":
			var claim = decision.get("claim")
			var indexes = decision.get("claim_indexes")
			var claimed := (claim is Dictionary and not (claim as Dictionary).is_empty()) \
				or (indexes is Array and not (indexes as Array).is_empty())
			text = "对方招架——你的打出被截" if claimed else ""
	if not text.is_empty():
		_banner_show(text)


func _show_result() -> void:
	_dump_battle_state()
	_overlay.visible = true
	_overlay_label.text = "⚔ 胜 —— 对方气血耗尽" if match_.winner == "player" else "败 —— 你的气血耗尽"
	if RunSession.active and RunSession.state != null:
		_show_run_result()
		return
	var restart := Button.new()
	restart.text = "再战一局"
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	_overlay_box.add_child(restart)
	var back := Button.new()
	back.text = "回演武场"
	back.pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.DOJO))
	_overlay_box.add_child(back)


# 挑战模式终局（v1.4 §4.3/§5）：写穿锚点——胜(还有下一战)存 settlement 锚发历练转结算屏；
# 组终/败＝clear＋hub 终态屏（D14：组终不再发结算奖励）。
func _show_run_result() -> void:
	var state := RunSession.state
	var outcome := state.apply_result(match_.winner, match_.fighter("player").hp_fp, match_.beat)
	if outcome == "settlement":
		state.grant_lianli(RunSession.shop_cfg().get("reward_lianli", []))
		RunSaver.save_state(state)
		var next_btn := Button.new()
		next_btn.text = "结算 ›"
		next_btn.pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.SETTLEMENT))
		_overlay_box.add_child(next_btn)
	else:
		RunSaver.clear()
		var hub_btn := Button.new()
		hub_btn.text = "回挑战总览"
		hub_btn.pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.CHALLENGE_HUB))
		_overlay_box.add_child(hub_btn)


# ———— 装配 ————

func _build_ui() -> void:
	# 浮窗详情须最先创建：组件 _init 里的 bind（气海标题等）依赖 active 已就位
	var _tip := MJBTipFloat.new()
	add_child(_tip)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# —— 顶部栏：返回｜标题｜拍·行动方｜问号词条｜设置 ——
	_top_bar = MJBTopBar.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(_top_bar)
	_top_bar.back_pressed.connect(func(): get_tree().change_scene_to_file(
		SceneRoutes.CHALLENGE_HUB if RunSession.active else SceneRoutes.DOJO))

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 46
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 4)  # 全局收紧：读数行↔打出行等间隔小些（2026-09-17 用户令）
	add_child(root)

	# —— 顶部中央块（居中）：气海背牌墙＋最近打出一行 ——
	_top_center = MJBTopCenter.new()
	root.add_child(_top_center)

	# —— 敌方区：信息簇＋手牌带（河/副露区住中部两翼列——见下） ——
	_enemy_panel = MJBFighterPanel.new("石仆", true)
	root.add_child(_enemy_panel)

	# —— 中部＝三列（牌河列｜中央列｜副露列，2026-09-17 用户令）：两翼列顶对齐装敌方河/副露区
	# （贴敌手牌带下方起排）；中央列＝打出区（顶部，上移）＋战报（向下占满）——
	# 日志不再吃两侧河/副露列的横向空间，整列上移 ——
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	root.add_child(middle)
	var side_left := VBoxContainer.new()
	side_left.custom_minimum_size = Vector2(MJBRiverPanel.ZONE_W, 0)  # 区宽单源：与河/副露区同列
	middle.add_child(side_left)
	var mid_col := VBoxContainer.new()
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.add_theme_constant_override("separation", 6)
	middle.add_child(mid_col)
	var side_right := VBoxContainer.new()
	side_right.custom_minimum_size = Vector2(MJBRiverPanel.ZONE_W, 0)
	middle.add_child(side_right)
	_enemy_river = MJBRiverPanel.new("enemy")
	side_left.add_child(_enemy_river)
	_enemy_melds = MJBMeldStrip.new("enemy")
	side_right.add_child(_enemy_melds)
	_play_line = MJBPlayLine.new()  # 打出交换区：中央列顶部（上移），双块定宽标签不跳位
	mid_col.add_child(_play_line)
	_log_panel = MJBLogPanel.new()
	_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL  # 战报向下占满中央列
	mid_col.add_child(_log_panel)

	# —— 我方：牌河＋副露同行（河居左·副露居右，与敌方两区等宽对齐）→ 信息簇 → 打出行 → 手牌（落底） ——
	var river_meld_row := HBoxContainer.new()
	river_meld_row.add_theme_constant_override("separation", 12)
	river_meld_row.custom_minimum_size = Vector2(0, 64)  # 预留（≈副露组高 64）：成河/成露不推挤下方控件
	root.add_child(river_meld_row)
	_player_river = MJBRiverPanel.new("player")
	river_meld_row.add_child(_player_river)
	var row_gap := Control.new()
	row_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	river_meld_row.add_child(row_gap)
	_player_melds = MJBMeldStrip.new("player")
	_player_melds.on_group_clicked = Callable(self, "_on_meld_clicked")
	river_meld_row.add_child(_player_melds)
	_player_panel = MJBFighterPanel.new("玩家")
	root.add_child(_player_panel)
	_action_bar = MJBActionRow.new()
	root.add_child(_action_bar)
	# 打出行与手牌之间留空：升起的选中牌（上移 10px）不得挡按钮——净空 12px（全局行距 4 已计入）
	var raise_gap := Control.new()
	raise_gap.custom_minimum_size = Vector2(0, 14)
	raise_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(raise_gap)
	_hand_strip = MJBHandStrip.new()
	_hand_strip.on_tile_clicked = Callable(self, "_on_tile_clicked")
	root.add_child(_hand_strip)

	# —— 弹层：设置（齿轮）｜词条（问号）｜截牌窗（居中） ——
	_settings_popup = MJBSettingsPopup.new()
	add_child(_settings_popup)
	_top_bar.settings_pressed.connect(func(): _settings_popup.open(_hand_strip.auto_sort()))
	_settings_popup.sort_toggled.connect(func(on: bool): _on_sort_toggled(on))
	_glossary_popup = MJBGlossaryPopup.new()
	add_child(_glossary_popup)
	_top_bar.help_pressed.connect(func(): _glossary_popup.open())

	_claim_popup = MJBClaimPopup.new()
	add_child(_claim_popup)
	_claim_box = _claim_popup.box

	# —— 回合横幅 ——
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6))
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	# —— 终局遮罩 ——
	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	var osb := StyleBoxFlat.new()
	osb.bg_color = Color(0, 0, 0, 0.72)
	_overlay.add_theme_stylebox_override("panel", osb)
	add_child(_overlay)
	_overlay_box = VBoxContainer.new()
	_overlay_box.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_theme_constant_override("separation", 16)
	_overlay.add_child(_overlay_box)
	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 40)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(_overlay_label)
