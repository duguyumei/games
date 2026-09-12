class_name DojoConfig

# 演武场（战斗工作台）的静态交接载荷：dojo.tscn 写入，battle.gd 优先读取。
# 静态类＝零侵入：不进 autoload、不动 ExpeditionSession、不落盘。

static var active := false
static var enemy_id := ""
static var techniques: Array[String] = []
static var xinfa: Array[String] = []
static var weapon_school := ""
static var weapon_level := 0
static var armor_defend := 0
static var hp := 0  # 0＝用 player.json 默认气血
static var deck: Array = []  # 空＝用 player.json 默认真气牌组


static func clear() -> void:
	active = false
	enemy_id = ""
	techniques = []
	xinfa = []
	weapon_school = ""
	weapon_level = 0
	armor_defend = 0
	hp = 0
	deck = []
