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

var _max_spacing_between_elements := 115.0  # _maxSpacingBetweenElements（:14，场景序列化实测；
                                            # 2026-11-13 消费者定案＝AlignOnPrimaryAxis 的
                                            # extraSpace 钳制上限——handPileConfig.cardSpacing=14
                                            # 与布局无关（真值档 §4b.1 关账））
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

## CalculateSpacingAlongAxis（:133，2026-11-13 全链重定案）——extraSpace＝
## clamp((容器宽 − Σ子项首选宽)/(n−1), 0, 115)。子项首选宽走 Unity LayoutUtility 语义：
## 槽无 LayoutElement（CardSlot.prefab 四组件实证）→ preferred=0 →
## **间距＝clamp(906/(n−1), 0, 115)＝115（n≤8 恒顶格）**。〔旧实装「Σ槽宽100」系 survey
## 虚构——原版根本没有 _spacing 字段，间距只活在 AlignOnPrimaryAxis 的 extraSpace；旧式
## n=8 恰好重合（15.1+100≈115）故满手一直看着对，n=3 偏宽整整 100＝用户 F6 抓出〕
func CalculateSpacingAlongAxis(_axis: int, _is_vertical: bool) -> void:
	var n := get_child_count()
	if n <= 1:
		_spacing = 0.0
		return
	var total_preferred := 0.0          # Σ LayoutUtility.GetPreferredSize（槽 LE-less＝0）
	_spacing = clampf((size.x - total_preferred) / float(n - 1),
		0.0, _max_spacing_between_elements)

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
## （GetSelectedCardOffset）→落位。步进＝childSize＋extraSpace（汇编 4FEA510→pos+=childSize
## 尾段实证）；childSize＝min+(pref−min)f+flex（LayoutUtility，槽 LE-less＝0）→
## **步进＝纯间距 115**＝卡心距。〔旧「+槽宽100」虚构；卡心距 115 canvas→上屏 ×1.14≈131px，
## 卡宽 205 → 邻卡叠 ~74px＝原版紧叠扇〕
func AlignOnPrimaryAxis(_axis: int, _rect_size: float) -> void:
	var n := get_child_count()
	if n == 0:
		return
	CalculateSpacingAlongAxis(0, false)
	# 占用＝ΣchildSize(=0)＋间距×(n−1)（原版 requiredSpace 同构——LE-less 下=纯间距段）
	_start_offset = GetModifiedStartOffset(0, _spacing * float(n - 1), size.x)
	var x := _start_offset
	var i := 0
	for ch in get_children():
		var slot: Control = ch
		FanCardRotation(i)
		# 劈开偏移＝**非累积**（2026-11-12 日志乱码 xs=[58,63,61,62,…] 复盘定案＋原版 C#
		# AlignOnPrimaryAxis 双证：pos = selectedCardOffset + axisOffset，偏移不回写累积器
		# ——每卡只从自己的基准位让开，不叠加前卡偏移）
		slot.position = Vector2(x + GetSelectedCardOffset(i, n), _slot_base_y())
		x += _spacing
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

# ── 内部（引擎映射）───────────────────────────────────────────────────

## 槽基线（2026-11-12 UsedCardSlots 链定案，真值档 §九）：原版布局组 childAlignment=4
## MiddleCenter、padding 0（SC_Game:999895-901）——**槽心＝容器垂直中心**（容器 906×224.3
## 中心＝带底上方 114.85）。旧「卡底＝容器底线」自制模型作废（整手高 ~47px 真凶之一）。
func _slot_base_y() -> float:
	return size.y * 0.5 - SLOT_HALF
