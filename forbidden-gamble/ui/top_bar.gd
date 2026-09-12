extends Panel

# 顶栏组件：地图名 + 状态行 + 构筑/设置按钮。按钮经信号上抛给 board.gd。

signal build_pressed()
signal settings_pressed()

func _ready() -> void:
	($Bar/BuildButton as Button).pressed.connect(func(): build_pressed.emit())
	($Bar/GearButton as Button).pressed.connect(func(): settings_pressed.emit())

func refresh(map_name: String, hp: int, max_hp: int, ap: int, ap_start: int, ap_spent: int, alert: Dictionary) -> void:
	($Bar/TitleLabel as Label).text = map_name
	var status := "气血 %d/%d ｜ 行动力 %d/%d ｜ 已消耗 %d ｜ 禁地·%s Lv%d" % [
		hp, max_hp, ap, ap_start, ap_spent, str(alert["name"]), int(alert["level"]),
	]
	if int(alert["next_at"]) > 0:
		status += "（下一级 %d）" % int(alert["next_at"])
	if int(alert.get("hunt_next", -1)) > 0:
		status += " ｜ 气息 %d（追杀线 %d）" % [int(alert.get("qixi", 0)), int(alert["hunt_next"])]
	if not str(alert.get("hunter", "")).is_empty():
		status += " ｜【%s 正在追杀你】" % str(alert["hunter"])
	if int(alert.get("sneak", 0)) > 0:
		status += " ｜【迷踪香·余%d】" % int(alert["sneak"])
	($Bar/StatusLabel as Label).text = status
