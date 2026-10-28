## v0.5 主流程宿主（run 状态唯一持有者）：备战舱 ⇄ 战斗管线实战环。
## run＝{copper, team[{id,equips,pdir}], reserve[同构], sys_lv, deck[{wid,sid,dir}], group, fight, seed}。
## 战斗屏胜负面板自毁后由此接流程：胜→场序 +1（组内还有场→直接下一场；打完→回备战）；
## 负/弃战→回备战重打同场。「‹ 备战」＝弃战（无奖励）。六类操作池奖励在战斗屏胜局面板内完成。
## 存档（2026-10-27 接入，STS2 制单槽）：开局/进战前（战前快照 _snap）/组收尾/关窗各写一档；
## 主菜单（基地 MainMenu 制）：有档＝「继续游戏」＋「弃档重开」，无档＝只有「新的开局」；
## 备战舱「退出」＝存档回主菜单；顶栏「重战」＝读档回上一场战斗前重打。
## 用法：godot --path . -- --qi-shot → 1.2s 自动截图退出
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")
const QISAVE := preload("res://qiforge/QiSave.gd")
const QIDIALOG := preload("res://qiforge/QiDialog.gd")
const PREP := preload("res://qiforge/QiPrepBay.tscn")
const BATTLE := preload("res://qiforge/QiBattleScreen.tscn")
var _run: Dictionary = {}
var _snap: Dictionary = {}      # 战前快照（重战源；空＝本局尚未开战）
var _back: Button = null

func _ready() -> void:
	QISTYLE.apply_root_theme(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_run()
	var bg := ColorRect.new()
	bg.color = QISTYLE.INK_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	child_entered_tree.connect(_on_child_entered)
	child_exiting_tree.connect(_on_child_exiting)
	_show_menu()
	if "--qi-shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_root_preview.png")
		get_tree().quit()

func _reset_run() -> void:
	_run = QI_DATA.default_run()   # 开局固定队＝幽冥剑＋天丝手套（2026-10-27 用户指定）
	_snap = {}

## 主菜单（2026-10-27 基地 MainMenu 制）：有档＝继续游戏＋弃档重开；无档＝新的开局
func _show_menu() -> void:
	for n in [find_child("QiPrepBay", false, false), find_child("QiBattleScreen", false, false), find_child("QiMenu", false, false)]:
		if n != null:
			n.queue_free()
	var menu := Control.new()
	menu.name = "QiMenu"
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	var title := Label.new()
	title.text = "主菜单"
	QISTYLE.font(title, QISTYLE.FS_TITLE, true)
	title.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var data: Dictionary = QISAVE.read()
	if not data.is_empty() and not (data["run"] as Dictionary).is_empty():
		var saved: Dictionary = data["run"]
		var cont := Button.new()
		cont.text = "继续游戏"
		cont.tooltip_text = "回到上次的局：系统 Lv%d · 第 %d 组 · 第 %d 场（顶栏「重战」＝回上一场战斗前）。" \
			% [int(saved.get("sys_lv", 2)), int(saved.get("group", 0)) + 1, int(saved.get("fight", 0)) + 1]
		cont.custom_minimum_size = Vector2(300, 64)
		QISTYLE.apply_primary(cont)
		QISTYLE.font(cont, QISTYLE.FS_BODY, true)
		cont.add_theme_color_override("font_color", Color("ffe9b0"))
		cont.pressed.connect(func() -> void: _continue_run(data))
		v.add_child(cont)
		var forfeit := Button.new()
		forfeit.text = "弃档重开"
		forfeit.tooltip_text = "放弃当前存档开新局（旧档转备份，直接执行）。"
		forfeit.custom_minimum_size = Vector2(300, 56)
		QISTYLE.apply_ghost(forfeit)
		QISTYLE.font(forfeit, QISTYLE.FS_BODY)
		forfeit.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		forfeit.pressed.connect(func() -> void: _new_run())
		v.add_child(forfeit)
	else:
		var newb := Button.new()
		newb.text = "新的开局"
		newb.tooltip_text = "开始新的一局（开局＝幽冥剑＋天丝手套）。"
		newb.custom_minimum_size = Vector2(300, 64)
		QISTYLE.apply_primary(newb)
		QISTYLE.font(newb, QISTYLE.FS_BODY, true)
		newb.add_theme_color_override("font_color", Color("ffe9b0"))
		newb.pressed.connect(func() -> void: _new_run())
		v.add_child(newb)
	cc.add_child(v)
	menu.add_child(cc)
	# 署名（game-icons.net CC BY 3.0 要求；素材详见 qiforge/assets/gi/README.md）
	var credit := Label.new()
	credit.name = "GiCredit"
	credit.text = "图标素材 game-icons.net（CC BY 3.0）· 作者 Lorc／Delapouite／sbed 等"
	credit.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -34.0
	credit.offset_bottom = -12.0
	QISTYLE.font(credit, QISTYLE.FS_SMALL)
	credit.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(credit)
	add_child(menu)

func _continue_run(data: Dictionary) -> void:
	_run = data["run"]
	_snap = data["snap"]
	find_child("QiMenu", false, false).queue_free()
	_show_prep()

func _new_run() -> void:
	QISAVE.clear()
	_reset_run()
	QISAVE.write(_run, _snap)
	find_child("QiMenu", false, false).queue_free()
	_show_prep()

## 备战舱顶栏「退出」＝存档后回主菜单
func _exit_to_menu() -> void:
	QISAVE.write(_run, _snap)
	_show_menu()

func run() -> Dictionary:
	return _run

func _show_prep() -> void:
	var prep := PREP.instantiate()
	prep.run_data = _run
	add_child(prep)

func spawn_battle() -> void:
	# 组末越界守卫（2026-10-28 修「组毕再出战＝零敌人空战斗，只能手点结束回合收尾」）：
	# 无下一场时拒绝开战回备战；正常流程不该走到这（备用舱出战钮已封死），此处兜底。
	var gi: int = int(_run.get("group", 0))
	if gi >= QI_DATA.GROUPS.size() \
			or int(_run.get("fight", 0)) >= QI_DATA.GROUPS[gi]["fights"].size():
		push_warning("spawn_battle：无下一场（组末越界），拒绝开战")
		_show_prep.call_deferred()
		return
	_snap = _run.duplicate(true)   # 战前快照（重战源；写档后再开战）
	QISAVE.write(_run, _snap)
	var bt := BATTLE.instantiate()
	bt.run_data = _run
	add_child(bt)

## 重战＝快速读档回到上一场战斗前重打（快照源；同 seed→同敌同意图，可反复用）
func _rewind_battle() -> void:
	if _snap.is_empty():
		var arr: Array = QIDIALOG.create(self, "重战", Vector2(480, 240), "知道了")
		var box: Control = arr[1]
		if box != null:
			var lb := Label.new()
			lb.text = "本局尚未开战，暂无战前记录。"
			box.content().add_child(lb)
			box.popup_centered(Vector2i(480, 240))
		return
	_run = _snap.duplicate(true)   # 复制再赋值——快照本体保留，支持反复重战
	var bt := find_child("QiBattleScreen", false, false)
	if bt != null:
		bt.set_meta("qi_rewind", true)   # 退出回调见旗标→不再走胜负分支，直接重开战
		bt.queue_free()
	else:
		var prep := find_child("QiPrepBay", false, false)
		if prep != null:
			prep.queue_free()
		spawn_battle()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		QISAVE.write(_run, _snap)   # 备战舱内购买/升级等改动关窗即存

func _on_child_entered(node: Node) -> void:
	if node.name == "QiBattleScreen":
		_back = Button.new()
		_back.name = "BackToPrep"
		_back.text = "‹ 弃战"
		_back.tooltip_text = "放弃本场回备战舱（本场无奖励，重打同场）。"
		_back.set_anchor(SIDE_LEFT, 0.012)
		_back.set_anchor(SIDE_RIGHT, 0.075)
		_back.set_anchor(SIDE_TOP, 0.082)
		_back.set_anchor(SIDE_BOTTOM, 0.128)
		_back.offset_left = 0.0
		_back.offset_top = 0.0
		_back.offset_right = 0.0
		_back.offset_bottom = 0.0
		QISTYLE.apply_ghost(_back)
		QISTYLE.font(_back, QISTYLE.FS_SMALL)
		_back.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		_back.pressed.connect(_on_back)
		add_child(_back)

func _on_child_exiting(node: Node) -> void:
	if node.name != "QiBattleScreen":
		return
	if _back:
		_back.queue_free()
		_back = null
	if node.has_meta("qi_rewind"):
		spawn_battle.call_deferred()   # 重战：换回快照局重开本场
		return
	var result := String(node.get_meta("qi_result", ""))
	if result == "win":
		QI_DATA.apply_team_out(_run, node.get_meta("qi_team_out", []))   # 耐久写回（§7 跨场持久）
		QI_DATA.reserve_tick(_run)   # 后备池每场战后回血（含阵亡缓复）
		_run["fight"] = int(_run.get("fight", 0)) + 1
		var gi: int = int(_run.get("group", 0))
		if gi < QI_DATA.GROUPS.size() and int(_run["fight"]) < QI_DATA.GROUPS[gi]["fights"].size():
			spawn_battle.call_deferred()   # 内含战前快照＋写档
		else:
			QISAVE.write(_run, _snap)      # 组收尾回备战＝稳定检查点（快照留作备战舱重战）
			_show_prep.call_deferred()
	else:
		_show_prep.call_deferred()

func _on_back() -> void:
	var battle := find_child("QiBattleScreen", false, false)
	if battle:
		battle.queue_free()
