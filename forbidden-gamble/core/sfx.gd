extends Node

# 占位音效播放器（autoload）：AudioStreamPlayer 对象池轮播，文件缺失时静默跳过。
# 音效文件由脚本合成（assets/sfx/*.wav），后续可整体替换为正式音效包。

const POOL_SIZE := 6
var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func play(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	for player in _players:
		if not player.playing:
			player.stream = load(path)
			player.play()
			return
	_players[0].stream = load(path)
	_players[0].play()

# 稀有度/档次分级音效：物品稀有度与敌人档次共用 1~4 级。
func play_reveal(juice: int) -> void:
	play("res://assets/sfx/reveal_%d.wav" % clampi(juice, 1, 4))

func play_open(cost: int) -> void:
	play("res://assets/sfx/open_%d.wav" % clampi(cost, 1, 3))

func play_alert(level: int) -> void:
	play("res://assets/sfx/alert_%d.wav" % clampi(level, 1, 3))
