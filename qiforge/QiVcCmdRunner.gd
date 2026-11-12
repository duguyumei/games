## 统一命令队列——原版 CommandRunner 1:1（Nosebleed.Pancake.GameCommands/CommandRunner.cs，277 行）。
## 结构 1:1 制（2026-11-12 宪法）首件：方法集对齐原版 8 法＋两属性——
##   OnDisable(:191) / Stop(:199) / UpdateCommandRunner(:218) / EnqueueCommand(:227) /
##   ClearCommands(:241) / Wait(:251) / WaitRoutine(:260) ＋ IsProcessing(:150) / Count(:176)。
## 旧自创件退役（差异登记#9）：push 同步 tick／barrier 屏障／uid 去重／drain 同步排空／signal all_done。
## 引擎映射：IEnumerator 协程 ⇔ GDScript async（泵 await 命令 Callable 跑完＝yield 完一条）；
##   MonoBehaviour 单协程泵 ⇔ async 循环（EnqueueCommand 空闲即启，自排空，无宿主 _process 驱动）；
##   StopCoroutine 即杀 ⇔ 代际号（当前命令跑完即止——即杀粒度差登记于引擎映射条）；
##   OnDisable（组件禁用停泵）在 RefCounted 无对应事件，保留方法对齐、由宿主退出时调用。
## ISIL 实证住 design-docs/references/吸血鬼爬行者_伤害管线逆向_v0.1.md §6.2。
extends RefCounted

var _command_routine := false        # _commandRoutine（CommandRunner.cs:144）——泵在跑标记（null ⇔ false）
var _current_command := Callable()   # _currentCommand（:146）——在飞命令（null ⇔ 空 Callable）
var _command_queue: Array = []       # _commandQueue（:148）Queue<IEnumerator> → Callable FIFO
var _pump_gen := 0                   # 引擎映射：Stop 代际号（替代 StopCoroutine 即杀）

## IsProcessing（:150）——_currentCommand != null || _commandQueue.Count > 0
func IsProcessing() -> bool:
	return _current_command != Callable() or not _command_queue.is_empty()

## Count（:176）——队列长度
func Count() -> int:
	return _command_queue.size()

## OnDisable（:191）——停泵（RefCounted 无禁用事件，保留对齐）
func OnDisable() -> void:
	Stop()

## Stop（:199）——停泵＋清当前＋清队列
func Stop() -> void:
	_pump_gen += 1
	_command_routine = false
	_current_command = Callable()
	_command_queue.clear()

## EnqueueCommand（:227）——入队；泵未跑即启（原版 StartCoroutine(UpdateCommandRunner) 同构）
func EnqueueCommand(command: Callable) -> void:
	_command_queue.push_back(command)
	if not _command_routine:
		_command_routine = true
		UpdateCommandRunner()

## ClearCommands（:241）——清当前＋清队列（泵不停：跑完当前即自然排空）
func ClearCommands() -> void:
	_current_command = Callable()
	_command_queue.clear()

## Wait（:251）——纯延时命令入队
func Wait(duration: float) -> void:
	EnqueueCommand(WaitRoutine.bind(duration))

## WaitRoutine（:260）——yield WaitForSeconds(duration)
func WaitRoutine(duration: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(maxf(0.01, duration), false).timeout

## UpdateCommandRunner（:218）——泵：出队→跑到完→取下条；空则泵停（_commandRoutine=null 同构）
func UpdateCommandRunner() -> void:
	var gen := _pump_gen
	while gen == _pump_gen and _command_queue.size() > 0:
		_current_command = _command_queue.pop_front()
		var cmd := _current_command
		await cmd.call()
		if gen == _pump_gen:
			_current_command = Callable()
	if gen == _pump_gen:
		_command_routine = false
