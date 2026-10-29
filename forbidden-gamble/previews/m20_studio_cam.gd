@tool
extends Camera3D

## m20 摄影棚读数（2026-09-20 用户令「我怎么调整镜头高度和桌面的哪些部分在画面
## 这不应该是直接在godot里面调整吗」）——挂在真 Camera3D 节点上，
## 编辑器里拖相机/改变换/改 FOV，左上角读数实时刷新；运行（F5/F6）同样工作。
## 读数全用屏占比（不写死 1280×720）：编辑器视口尺寸≠游戏窗，百分比才可比。
## 相机本身是场景节点——用户手调、编辑器存档，这就是「直接在 Godot 里调」。

const FONT := "res://assets/fonts/MaShanZheng-Regular.ttf"
const TILE_W := 19.0 / 26.0

# 2026-09-20 用户令「左上角的黑色区域取消」——读数浮窗默认不建；将来重调机位时勾回即恢复。
@export var show_readout := false:
	set(v):
		show_readout = v
		if show_readout:
			_ensure_overlay()
		if _panel != null and is_instance_valid(_panel):
			_panel.visible = show_readout

var _label: Label
var _panel: PanelContainer
var _last := ""


func _ready() -> void:
	if show_readout:
		_ensure_overlay()
	_refresh()


func _process(_dt: float) -> void:
	if not show_readout:
		return
	_refresh()


func _ensure_overlay() -> void:
	if _label != null and is_instance_valid(_label):
		return
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 12.0
	panel.offset_top = 50.0  # 顶栏占 y0–38（2026-09-18 HUD 轮起）——读数浮窗让位下移
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.88)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	_label = Label.new()
	var font := load(FONT) as Font
	if font != null:
		_label.add_theme_font_override("font", font)
		_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	panel.add_child(_label)


func _refresh() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	var table := get_node_or_null("../Mj3dTable") as Mj3dTable
	if table == null or not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vs: Vector2 = vp.get_visible_rect().size
	if vs.y < 10.0:
		return
	var half := table.net_side * 0.5
	var near_p := Vector3(0, table.rim_height, half + Mj3dTable.RIM_W)
	if is_position_behind(near_p) or is_position_behind(Vector3(0, 0, -half)):
		_label.text = "机位穿桌/朝向反了——拉高或转回俯视"
		return
	var fn := unproject_position(Vector3(0, 0, half))
	var ff := unproject_position(Vector3(0, 0, -half))
	var a := unproject_position(Vector3(-half, 0, half))
	var b := unproject_position(Vector3(half, 0, half))
	var c := unproject_position(Vector3(-half, 0, -half))
	var d := unproject_position(Vector3(half, 0, -half))
	var ratio: float = c.distance_to(d) / maxf(1.0, a.distance_to(b))
	var near_pct: float = unproject_position(near_p).y / vs.y * 100.0
	var felt_pct: float = (fn.y - ff.y) / vs.y * 100.0
	var t1 := unproject_position(Vector3(-TILE_W * 0.5, 0.3, half - 1.0))
	var t2 := unproject_position(Vector3(TILE_W * 0.5, 0.3, half - 1.0))
	var tile_pct: float = t1.distance_to(t2) / vs.x * 100.0
	var txt := "收敛比 %.3f｜近沿 %.0f%% 屏高（>100＝出屏裁切）｜呢面高 %.0f%%\n手牌宽 %.1f%% 屏宽｜桌牌比 %.1f｜沿宽 %.0f\n机位 %s 俯角 %.0f° FOV %.0f" % [
		ratio, near_pct, felt_pct, tile_pct,
		table.net_side, Mj3dTable.RIM_W,
		"(%0.1f, %0.1f, %0.1f)" % [global_position.x, global_position.y, global_position.z],
		-rotation_degrees.x, fov]
	if txt != _last:
		_label.text = txt
		_last = txt
