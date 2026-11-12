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

## AlignChildrenAlongAxis（:305）——副轴（弧线）提前 return＝死代码实证；主轴走 AlignOnPrimaryAxis
func AlignChildrenAlongAxis(axis: int, is_vertical: bool) -> void:
	if axis == 1:
		return                        # 副轴早退（平排真凶；弧线＝FanCardPosition 不可达）
	AlignOnPrimaryAxis(axis, size.x if not is_vertical else size.y)

## AlignOnPrimaryAxis（:333）——逐槽：扇形旋钮（FanCardRotation）→间距推进→选中卡劈开
## （GetSelectedCardOffset）→落位
func AlignOnPrimaryAxis(_axis: int, _rect_size: float) -> void:
	var n := get_child_count()
	if n == 0:
		return
	CalculateSpacingAlongAxis(0, false)
	_start_offset = GetModifiedStartOffset(0, _total_slot_width(), size.x)
	var x := _start_offset
	var i := 0
	for ch in get_children():
		var slot: Control = ch
		FanCardRotation(i)
		x += _spacing
		x += GetSelectedCardOffset(i, n)
		slot.position = Vector2(x, _slot_base_y())
		x += slot.size.x
		i += 1

## AlignOnSecondaryAxis（:471）——【死代码照抄】副轴弧线排布（原版不可达）
func AlignOnSecondaryAxis(_axis: int, _rect_size: float) -> void:
	var axis_offset := 0.0
	var i := 0
	for ch in get_children():
		FanCardPosition(axis_offset, i)
		(ch as Control).position.y += axis_offset
		i += 1

## GetModifiedStartOffset（:548）——起始偏移（*0.25 权重 :730 的居中语义）
func GetModifiedStartOffset(_axis: int, required_space_without_padding: float, rect_size: float) -> float:
	return maxf(0.0, (rect_size - required_space_without_padding) * 0.5)

## GetChildAlignmentOffset（:748）——对齐偏移（中排布局恒 0 路径，占位保名）
func GetChildAlignmentOffset(_is_vertical: bool, _rect_size: float, default_offset: float,
		_actual_flexible_size: float, _expected_flexible_size: float) -> float:
	return default_offset

## FanCardPosition（:840）——【死代码照抄】副轴弧线偏移：t=i/(n−1)（单卡 t=0.5）×
## PositionOffsetCurve × MaxPositionOffset，负号作用于 y（:877-881）
func FanCardPosition(axis_offset: float, card_num: int) -> void:
	var n := get_child_count()
	var t := 0.5 if n <= 1 else float(card_num) / float(n - 1)
	axis_offset = -_fanning_config.PositionOffsetCurve.sample_baked(t) * _fanning_config.MaxPositionOffset

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

## GetSelectedCardOffset（:963）——选中卡劈开：RepelFalloffCurve(距离比)×MaxRepelOffset＋
## SelectedCardRepelAmount（:1016-1021）＋左右分堆 GetLeft/RightSplitOffset（:1024/1032）。
## 原版代数体坏点——实装式按真值档 v0.2（方向：选中左卡左让、右卡右让；选中卡自身 0）
func GetSelectedCardOffset(card_index: int, number_of_cards: int) -> float:
	if _selectedIndex < 0 or _selectedIndex >= number_of_cards:
		return 0.0
	if card_index == _selectedIndex:
		return 0.0
	var left := card_index < _selectedIndex
	var span := float(number_of_cards - 1)
	var d := absf(float(card_index - _selectedIndex)) / maxf(1.0, span)
	var falloff: float = _fanning_config.RepelFalloffCurve.sample_baked(clampf(d, 0.0, 1.0))
	var repel: float = falloff * _fanning_config.MaxRepelOffset \
		+ _fanning_config.SelectedCardRepelAmount
	var split: float = _fanning_config.GetLeftSplitOffset(number_of_cards) if left \
		else _fanning_config.GetRightSplitOffset(number_of_cards)
	var mag := repel + split
	return -mag if left else mag

# ── 内部（引擎映射）───────────────────────────────────────────────────

func _total_slot_width() -> float:
	var total := 0.0
	for ch in get_children():
		total += (ch as Control).size.x
	return total

## 槽基线（引擎映射）：Unity 槽锚 (0,0)-(0,0)＝容器底左、槽心抬 50 → Godot y-down 底带
func _slot_base_y() -> float:
	return maxf(0.0, size.y - 100.0)
