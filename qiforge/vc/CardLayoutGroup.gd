## 原版 CardLayoutGroup 1:1（Nosebleed.Pancake.View/CardLayoutGroup.cs，1083 行）——
## 手牌槽位布局基类（槽位行排布：间距钳制＋扇形旋钮＋选中卡劈开）。
## 【死路径照抄】AlignOnSecondaryAxis/FanCardPosition 的 Y 弧线在原版不可达
## （AlignChildrenAlongAxis 对副轴提前 return——2026-11-12 汇编实证＝平排死代码），
## 按宪法照抄保留并注明——将来若被接通即为原版行为。
## 引擎映射：Unity LayoutGroup 自动驱动 → ForceLayoutRefresh 手动驱动（加/删/换选时调）；
## RectTransform y-up → Godot Control y-down（槽基线＝容器底带，槽心即卡心锚）。
## GetSelectedCardOffset 的原版代数体为坏点——劈开量代数按真值档 v0.2 实装式
## （repel 曲线×64＋左右劈开，方向左右分堆），登记待 ISIL 复核。
extends Control

const VC := preload("res://qiforge/vc/VcConfig.gd")
const FAN_CONFIG := preload("res://qiforge/vc/CardFanConfig.gd")

static var s_min_cards_to_fan := 2          # s_minCardsToFan（:12，静态构造赋 2，:1081）

const SLOT_HALF := 50.0                     # 槽 100×100 之半（CardSlot.prefab:61）

# [HAND] 多卡诊断（2026-11-12 用户令：只查多卡排列；诊断完删）
const DEBUG_MIN_CARDS := 6                  # ≥6 张才打详细布局（劈开曲线 MinMaxCardsForSplit 也从 6 起）
var _debug_rev := 0                         # 布局版本号——HandPileView 据此抓一次落定快照

var _max_spacing_between_elements := 115.0  # _maxSpacingBetweenElements（:14，场景序列化实测；
                                            # GlobalConfig.handPileConfig.cardSpacing=14 的消费者
                                            # 未接入此字段——对账项登记真值档 v0.3）
var _fanning_config = null                  # _fanningConfig（:16）→ vc/CardFanConfig
var _selectedIndex := -1                    # _selectedIndex（:18）
var _spacing := 0.0                         # CalculateSpacingAlongAxis 产出
var _start_offset := 0.0                    # AlignOnPrimaryAxis 产出（容器内起始 x）

func _init() -> void:
	_fanning_config = FAN_CONFIG.new()

## MaxSpacingBetweenElements 属性（:20）
func MaxSpacingBetweenElements() -> float:
	return _max_spacing_between_elements

## SelectedIndex 属性（:46）
func SetSelectedIndex(index: int) -> void:
	_selectedIndex = index

func GetSelectedIndex() -> int:
	return _selectedIndex

## ForceLayoutRefresh（:60）——重算四步布局（原版被 LayoutGroup 自动调；我方加/删/换选手调）
func ForceLayoutRefresh() -> void:
	CalculateLayoutInputHorizontal()
	CalculateLayoutInputVertical()
	SetLayoutHorizontal()
	SetLayoutVertical()
	_debug_rev += 1
	var ev := String(get_meta("hand_ev", "refresh"))
	remove_meta("hand_ev")
	_debug_dump_layout(ev)

## 四布局入口（Unity LayoutGroup 基类抽象——GDScript 无抽象，基类空占位、子类覆写）
func CalculateLayoutInputHorizontal() -> void:
	pass

func CalculateLayoutInputVertical() -> void:
	pass

func SetLayoutHorizontal() -> void:
	pass

func SetLayoutVertical() -> void:
	pass

## OnEnable（:77）/ OnDisable（:107）——订阅 _fanningConfig.ConfigUpdated；SO 热更事件未搬，占位
func OnEnable() -> void:
	pass

func OnDisable() -> void:
	pass

## CalculateSpacingAlongAxis（:133）——副轴间距累计并钳 ≤ _maxSpacingBetweenElements：
## 间距＝min(上限, (带宽−槽总宽)/(n−1))；n≤1 无间距（单卡居中走 start offset）
func CalculateSpacingAlongAxis(_axis: int, _is_vertical: bool) -> void:
	var n := get_child_count()
	if n <= 1:
		_spacing = 0.0
		return
	var total := 0.0
	for ch in get_children():
		total += (ch as Control).size.x
	var avail := size.x - total
	_spacing = clampf(avail / float(n - 1), 0.0, _max_spacing_between_elements)

## AlignChildrenAlongAxis（:305，汇编直译）——分流：(!is_vertical)==axis 相等→副轴
## （弧线 AlignOnSecondaryAxis，尾跳 0x3B333B0 实证）；不等→主轴（行排）。
## 横组实参 (0,false)→主轴 / (1,false)→**副轴弧线**（2026-11-12 翻案，旧「早退」判作废）。
func AlignChildrenAlongAxis(axis: int, is_vertical: bool) -> void:
	var route := 0 if is_vertical else 1   # 比较 (!is_vertical)==axis 的 int 化
	if route == axis:
		AlignOnSecondaryAxis(axis, size.y)
	else:
		AlignOnPrimaryAxis(axis, size.x)

## AlignOnPrimaryAxis（:333）——逐槽：扇形旋钮（FanCardRotation）→间距推进→选中卡劈开
## （GetSelectedCardOffset）→落位
func AlignOnPrimaryAxis(_axis: int, _rect_size: float) -> void:
	var n := get_child_count()
	if n == 0:
		return
	CalculateSpacingAlongAxis(0, false)
	# 居中须按「槽宽＋全部间距」的总占用（2026-11-12 日志实锤：旧版只算槽宽 → 行整体
	# 偏右 (带宽−槽总宽)/2，n=8 偏 80 画布单位）
	_start_offset = GetModifiedStartOffset(0,
		_total_slot_width() + _spacing * float(n - 1), size.x)
	var x := _start_offset
	var i := 0
	for ch in get_children():
		var slot: Control = ch
		FanCardRotation(i)
		# 劈开偏移＝**非累积**（2026-11-12 日志乱码 xs=[58,63,61,62,…] 复现定案＋原版 C#
		# AlignOnPrimaryAxis 双证：pos = selectedCardOffset + axisOffset，偏移不回写累积器
		# ——每卡只从自己的基准位让开，不叠加前卡偏移）
		slot.position = Vector2(x + GetSelectedCardOffset(i, n), _slot_base_y())
		# 间距只在卡间（2026-11-12 snap 实锤：行首多一份间距 → 整行右移一个 spacing、
		# 中心 502≠480；Unity LayoutGroup 语义＝放卡→宽+间距）
		x += slot.size.x + _spacing
		i += 1

## AlignOnSecondaryAxis（:471，弧线排布）——逐槽 Y 弧线偏移（FanCardPosition），
## 中间卡下沉、两端归零（PositionOffsetCurve 钟形 0→1→0 峰值 t=0.5 × MaxPositionOffset 32）
func AlignOnSecondaryAxis(_axis: int, _rect_size: float) -> void:
	var i := 0
	for ch in get_children():
		(ch as Control).position.y += FanCardPosition(i)
		i += 1

## GetModifiedStartOffset（:548）——起始偏移（*0.25 权重 :730 的居中语义）
func GetModifiedStartOffset(_axis: int, required_space_without_padding: float, rect_size: float) -> float:
	return maxf(0.0, (rect_size - required_space_without_padding) * 0.5)

## GetChildAlignmentOffset（:748）——对齐偏移（中排布局恒 0 路径，占位保名）
func GetChildAlignmentOffset(_is_vertical: bool, _rect_size: float, default_offset: float,
		_actual_flexible_size: float, _expected_flexible_size: float) -> float:
	return default_offset

## FanCardPosition（:840）——副轴弧线偏移：t=i/(n−1)（单卡 t=0.5）× PositionOffsetCurve ×
## MaxPositionOffset(32)。方向定案（2026-11-12 用户实机口径＋uGUI 源证）：中间高两端低——
## FanCardPosition 本体＝pos −= curve×32（汇编 066 Subtract），代入 uGUI 垂直轴公式
## y = −pos − (1−pivot.y)×h（游戏自带 UnityEngine.UI LayoutGroup.SetChildAlongAxisWithScale
## IsilDump/UnityEngine.UI/UnityEngine/UI/LayoutGroup.txt:2131-2137：xorps 取负＋(1−pivot)）
## ＝中间卡 **上升 32**、两端归零。我此前「中间下沉」系误套 y-up 底边语义，作废。
## Godot y-down：中间升高＝y 减。（引擎映射：C# ref float 参数 → 返回值）
func FanCardPosition(card_num: int) -> float:
	var n := get_child_count()
	var t := 0.5 if n <= 1 else float(card_num) / float(n - 1)
	return -_fanning_config.PositionOffsetCurve.sample_baked(t) * _fanning_config.MaxPositionOffset

## FanCardRotation（:894）——扇形旋钮：t=(i/(n−1)−0.5)×2（:958-959）× RotationOffsetCurve ×
## MaxRotationOffset＋DefaultCardRotation → 写槽 rotation（:949-950）
func FanCardRotation(card_num: int) -> void:
	var n := get_child_count()
	if n < s_min_cards_to_fan:
		return
	var t := 0.5 if n <= 1 else float(card_num) / float(n - 1)
	var lin := (t - 0.5) * 2.0
	var deg: float = _fanning_config.RotationOffsetCurve.sample_baked(clampf(absf(lin), 0.0, 1.0)) \
		* _fanning_config.MaxRotationOffset * signf(lin)
	var slot: Control = get_child(card_num)
	slot.rotation = deg_to_rad(deg + _fanning_config.DefaultCardRotation.z)

## GetSelectedCardOffset（:963）——选中卡劈开（汇编级全解，2026-11-12 ISIL 直译：
## CardLayoutGroup.txt:2579-2666）：侧别归一 t（左＝clamp01((i+1)/sel)、右＝clamp01((n−i)/(n−sel−1))，
## sel+1==n 时右翼 t=0 除零守卫）→ RepelFalloffCurve(t)×MaxRepelOffset(64)＋
## SelectedCardRepelAmount(64) → ±(repel＋GetLeft/RightSplitOffset(n))——左负右正。
##〔v0.3 修正：旧版误用 |i−sel|/(n−1)——相邻卡推量恰相反，汇编定案为侧别式〕
func GetSelectedCardOffset(card_index: int, number_of_cards: int) -> float:
	if _selectedIndex < 0 or _selectedIndex >= number_of_cards:
		return 0.0
	if card_index == _selectedIndex:
		return 0.0
	var left := card_index < _selectedIndex
	var t := 0.0
	if left:
		t = clampf((float(card_index) + 1.0) / float(_selectedIndex), 0.0, 1.0)
	else:
		var denom := float(number_of_cards - 1 - _selectedIndex)
		if denom <= 0.0:
			t = 0.0   # 除零守卫（sel==n−1 时无右翼，原版 jnp 分支同义）
		else:
			t = clampf((float(number_of_cards) - float(card_index)) / denom, 0.0, 1.0)
	var falloff: float = _fanning_config.RepelFalloffCurve.sample_baked(t)
	var repel: float = falloff * _fanning_config.MaxRepelOffset \
		+ _fanning_config.SelectedCardRepelAmount
	var split: float = _fanning_config.GetLeftSplitOffset(number_of_cards) if left \
		else _fanning_config.GetRightSplitOffset(number_of_cards)
	var mag: float = repel + split
	return -mag if left else mag

# ── [HAND] 多卡排列诊断（2026-11-12 用户令；诊断完删）────────────────────
## 只在 n≥6 或槽行超出容器时打。字段：
## n/sel/rect/sp/start/row（槽行总宽）/rowC（槽行中心）/shift（行心−容器心）
## overlap（相邻卡重叠）/fit（槽行是否在容器内）；每槽 uid/x/y/rot/fan（弧）/dx（劈开量）；
## face 边界与屏幕越界量。所有坐标＝本布局容器局部（与 position 同一坐标系）。
func _debug_dump_layout(ev: String) -> void:
	var n := get_child_count()
	if n == 0:
		return
	var total := _total_slot_width()
	var step := SLOT_HALF * 2.0 + _spacing
	var row_w := total + _spacing * float(maxi(0, n - 1))
	var row_l := _start_offset
	var row_r := row_l + row_w
	var cont_w := size.x
	var row_c := row_l + row_w * 0.5
	var cont_c := cont_w * 0.5
	var row_fit := row_l >= -0.5 and row_r <= cont_w + 0.5
	var card_overlap := VC.CARD_SIZE.x - step
	var uids: Array = []
	for ch in get_children():
		uids.append(_debug_slot_uid(ch))
	if n < DEBUG_MIN_CARDS and row_fit:
		return
	print("[HAND] layout ev=%s n=%d sel=%d rect=%.1fx%.1f pos=(%.1f,%.1f) sp=%.2f start=%.2f row=%.1f rowC=%.1f rowC_hand=%.1f shift=%+.1f overlap=%.1f fit=%s uids=%s" % [
		ev, n, _selectedIndex, cont_w, size.y, position.x, position.y, _spacing,
		row_l, row_w, row_c, position.x + row_c, row_c - cont_c, card_overlap,
		"1" if row_fit else "0", str(uids)])
	for i in n:
		var slot := get_child(i) as Control
		var dx: float = slot.position.x - (row_l + float(i) * step)
		print("[HAND] slot i=%d uid=%d x=%.1f y=%.1f rot=%.1f fan=%.1f dx=%+.1f" % [
			i, int(uids[i]), slot.position.x, slot.position.y,
			rad_to_deg(slot.rotation), FanCardPosition(i), dx])
	var first := get_child(0) as Control
	var last := get_child(n - 1) as Control
	var first_face_l: float = first.position.x + SLOT_HALF - VC.CARD_SIZE.x * 0.5
	var last_face_r: float = last.position.x + SLOT_HALF + VC.CARD_SIZE.x * 0.5
	var screen_txt := ""
	if is_inside_tree():
		var xf := get_global_transform_with_canvas()
		var p0: Vector2 = xf * Vector2(first_face_l, 0.0)
		var p1: Vector2 = xf * Vector2(last_face_r, 0.0)
		var sw: float = get_viewport().get_visible_rect().size.x
		screen_txt = " screen=[%.0f,%.0f/%.0f] out=(%.0f,%.0f)" % [
			p0.x, p1.x, sw, maxf(0.0, -p0.x), maxf(0.0, p1.x - sw)]
	print("[HAND] bounds slot=[%.1f,%.1f] face=[%.1f,%.1f] cont=[0,%.1f] slot_fit=%s%s" % [
		row_l, row_r, first_face_l, last_face_r, cont_w,
		"1" if row_fit else "0", screen_txt])

func _debug_slot_uid(slot) -> int:
	if slot == null:
		return -1
	var it = slot.SlottedInteractableCard()
	if it == null:
		return -1
	var v = it._card_view
	if v == null or not is_instance_valid(v):
		return -1
	return int(v.get_meta("hand_uid", -1))

# ── 内部（引擎映射）───────────────────────────────────────────────────

func _total_slot_width() -> float:
	var total := 0.0
	for ch in get_children():
		total += (ch as Control).size.x
	return total

## 槽基线（2026-11-12 截图定标修正）：**卡底＝容器底线**——槽心放在「容器底−半卡高」处
##（旧版槽贴容器底→卡下半截沉出带底 88.5 画布单位＝「手牌有一截在屏幕外」真凶）；
## 卡底离屏底的 18% 卡高间隙由 hpv 根锚 offset 提供，两层各管一段。
func _slot_base_y() -> float:
	return size.y - VC.CARD_SIZE.y * 0.5 - SLOT_HALF
