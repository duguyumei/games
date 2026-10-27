## qi-forge 字体银行（2026-10-25 用户裁定修乱码；**2026-10-28 用户裁定字体统一**）：
## 病根＝Godot 默认字体是拉丁子集、零 CJK 字形，macOS 上全靠系统回退撑着（不可靠、导出必挂）。
## 修法＝捆绑 Noto Sans SC（OFL）：
## 1) 全局默认字体：根窗口 theme.default_font＝Noto（所有无覆盖小字）；
## 2) 展示字（display）＝同 Noto——黄油体（zcool）2026-10-28 用户裁定退役（标题花、久看累），
##    全项目标题/正文统一 Noto Sans SC；display() 保留为兼容入口直接返 Noto，旧调用零改动；
## 3) Noto 用 load_dynamic_font 运行时加载——不经 .import（避免与开着的编辑器抢缓存），三态通吃。
## 注意：导出时需在 export preset 把 res://assets/fonts/noto_sans_sc.ttf 加进 include filter（非导入资源不会自动打包）。
extends RefCounted

const QIF_ZCOOL: FontFile = preload("res://assets/fonts/zcool_huangyou.ttf")   # 已退役（库文件留存备查）
const NOTO_PATH: String = "res://assets/fonts/noto_sans_sc.ttf"

static var _noto: FontFile = null

## Noto Sans SC（运行时动态加载，进程内单例）
static func noto() -> FontFile:
	if _noto == null:
		_noto = FontFile.new()
		var err: int = _noto.load_dynamic_font(NOTO_PATH)
		if err != OK:
			push_error("QiFontBank: Noto 加载失败 err=", err, " path=", NOTO_PATH)
			_noto = QIF_ZCOOL	# 兜底别断流程
	return _noto

## 展示字＝Noto（2026-10-28 统一裁定；兼容入口——所有标题调用方自动跟随）
static func display() -> FontFile:
	return noto()

## 默认主题（default_font＝Noto；缓存单例——对话框/浮窗层等不吃 Control 主题继承的子树直接挂它）
static var _default_theme: Theme = null

static func default_theme() -> Theme:
	if _default_theme == null:
		_default_theme = Theme.new()
		_default_theme.default_font = noto()
	return _default_theme

## 挂到根窗口做全项目默认字体（幂等：已有默认字体则不重挂）
static func apply_default_font(root: Window) -> void:
	if root.theme != null and root.theme.get_default_font() != null:
		return
	root.theme = default_theme()
