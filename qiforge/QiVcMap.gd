## VC 制地图屏（复刻线 2026-10-31）：层节点推进＝用户裁定「层推进应该是地图系统」。
## DUNGEON 序＝楼层链：已清（玉绿）/当前（琥珀＋进入钮）/未至（压暗）；底栏主角面板＋重开地牢。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const VC := preload("res://qiforge/QiVcData.gd")

signal enter_enc()
signal restart_run()

var run: Dictionary = {}

func setup(run_ref: Dictionary) -> void:
	run = run_ref

func _ready() -> void:
	_fill(self)
	_build()

## 铺满父级（显式锚属性＋清偏移——代码实例化控件上 set_anchors_preset 实测不生效，
## 2026-11-01 probe_vc_ui 定案；tscn 根节点不受此坑影响）
func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

func _build() -> void:
	var root_v := VBoxContainer.new()
	_fill(root_v)
	root_v.offset_left = 60.0
	root_v.offset_right = -60.0
	root_v.offset_top = 40.0
	root_v.offset_bottom = -40.0
	root_v.add_theme_constant_override("separation", 14)
	root_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_v)

	var title := Label.new()
	title.text = "地牢 · 深入"
	QISTYLE.font(title, 34, true)
	QISTYLE.text_color(title, QISTYLE.TEXT_MAIN)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_v.add_child(title)

	var cur: int = clampi(int(run.get("enc", 0)), 0, VC.DUNGEON.size())
	for i in VC.DUNGEON.size():
		var enc_id := String(VC.DUNGEON[i])
		var spec: Dictionary = VC.ENCOUNTERS[enc_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_v.add_child(row)
		var state := "cleared" if i < cur else ("current" if i == cur else "locked")
		var state_text: String = {"cleared": "已清", "current": "当前", "locked": "未至"}[state]
		var state_color: Color = {"cleared": QISTYLE.JADE, "current": QISTYLE.AMBER_BRIGHT,
			"locked": QISTYLE.TEXT_SUB}[state]
		var num_l := Label.new()
		num_l.text = "第 %d 层" % (i + 1)
		QISTYLE.font(num_l, QISTYLE.FS_BIG)
		QISTYLE.text_color(num_l, state_color)
		num_l.custom_minimum_size = Vector2(110, 0)
		num_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(num_l)
		var name_panel := PanelContainer.new()
		name_panel.add_theme_stylebox_override("panel", QISTYLE.panel(0.5))
		name_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_panel)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 14)
		name_panel.add_child(inner)
		var name_l := Label.new()
		name_l.text = "%s　（波次 %d · 补位 %d/回合末）" % [String(spec["name"]),
			(spec["pool"] as Array).size(), int(spec["refill"])]
		QISTYLE.font(name_l, QISTYLE.FS_BODY)
		QISTYLE.text_color(name_l, QISTYLE.TEXT_MAIN if state != "locked" else QISTYLE.TEXT_SUB)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_l)
		var state_l := Label.new()
		state_l.text = state_text
		QISTYLE.font(state_l, QISTYLE.FS_BODY)
		QISTYLE.text_color(state_l, state_color)
		state_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(state_l)
		if state == "current":
			var go := Button.new()
			go.text = "进入"
			QISTYLE.apply_primary(go)
			go.pressed.connect(func(): enter_enc.emit())
			row.add_child(go)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_v.add_child(spacer)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 22)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_v.add_child(bottom)
	var hp_l := Label.new()
	hp_l.text = "主角 %d/%d · 内功：%s" % [int(run.get("hp", VC.PLAYER_BASE["hp"])),
		int(run.get("mhp", VC.PLAYER_BASE["hp"])),
		"、".join(PackedStringArray((run.get("neigong", []) as Array).map(
			func(n): return String(VC.NEIGONG.get(n, {}).get("name", n)))))]
	QISTYLE.font(hp_l, QISTYLE.FS_BIG)
	QISTYLE.text_color(hp_l, QISTYLE.TEXT_MAIN)
	hp_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(hp_l)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(sp2)
	var re := Button.new()
	re.text = "重开地牢"
	QISTYLE.apply_ghost(re)
	re.pressed.connect(func(): restart_run.emit())
	bottom.add_child(re)
