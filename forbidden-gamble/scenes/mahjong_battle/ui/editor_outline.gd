@tool
class_name MJBEditorOutline
extends Control

## 编辑器布局边框（2026-09-18 用户令：每个区块加边框，不然编辑器里不好看）。
## **仅编辑器渲染**：给布局骨架各区块画半透明描边＋节点名，拖动/改尺寸实时跟随；
## 运行时自隐藏＋停处理＝零视觉污染零开销。目标清单＝显式路径（改名/挪层在此同步）。


const COL_LINE := Color(0.98, 0.85, 0.30, 0.55)
const COL_TEXT := Color(0.98, 0.85, 0.30, 0.85)
const FONT_SIZE := 12

# 布局骨架目标（顶层根名省略；路径用场景树中文名）
const TARGETS := [
	"顶栏",
	"敌方信息",
	"中央区",
	"中央区/桌布",
	"中央区/桌上内容",
	"中央区/桌上内容/敌方背牌带",
	"中央区/桌上内容/三列",
	"中央区/桌上内容/三列/左列",
	"中央区/桌上内容/三列/中列",
	"中央区/桌上内容/三列/右列",
	"中央区/桌上内容/三列/左列/敌方河",
	"中央区/桌上内容/三列/中列/打出展示",
	"中央区/桌上内容/三列/中列/战报",
	"中央区/桌上内容/三列/右列/敌方副露",
	"中央区/桌上内容/河副露行",
	"中央区/桌上内容/河副露行/我方河",
	"中央区/桌上内容/河副露行/我方副露",
	"中央区/桌上内容/按钮行",
	"中央区/桌上内容/手牌",
	"我方信息",
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		visible = false
		set_process(false)


func _process(_delta: float) -> void:
	queue_redraw()  # 拖动/布局变化实时跟随（编辑器内；运行时 _process 已停）


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var root: Node = get_parent()
	for path in TARGETS:
		var n: Node = root.get_node_or_null(String(path))
		if n == null or not (n is Control) or not (n as Control).visible:
			continue
		var c: Control = n as Control
		var r := Rect2(c.global_position - global_position, c.size)
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		draw_rect(r, COL_LINE, false, 1.0)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 14),
			String(c.name), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COL_TEXT)
