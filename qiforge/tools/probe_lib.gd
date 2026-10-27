## 探针公共件（2026-10-28 用户裁定「静默测试」）：无头视口矫正＋跑法约定。
## Godot --headless 的哑窗口会把 canvas_items＋expand 拉伸算成 1920×1920（锚点百分比全歪）；
## 改 ASPECT_KEEP 后设计尺寸 1920×1080 原样生效（窗口模式无影响——本就 16:9 全屏）。
## 用法（UI 探针 _run 首行）：await PROBE_LIB.fit(self)
## 跑法约定：探针默认 --headless（静默无窗）；仅截图验收短暂开窗。
extends RefCounted

const WANT := Vector2i(1920, 1080)

static func fit(tree: SceneTree) -> void:
	if tree.root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP \
			and tree.root.content_scale_size == WANT:
		return
	tree.root.content_scale_size = WANT
	tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await tree.process_frame
