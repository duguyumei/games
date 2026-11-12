## 原版 View 基类 1:1（Nosebleed.Pancake.View/View.cs，61 行）。
## 引擎映射：MonoBehaviour 生命周期 → Godot（Awake→_init/_ready、OnDestroy→_exit_tree）；
## GameView 单例登记簿未搬（其职责＝updating view 登记，消费者仅 RemoveAllFinished 一处——
## 我方以直接调用替代，差异登记「GameView 未搬」）。
extends Control

func _init() -> void:              # Awake（View.cs:8，空实现）
	pass

func _ready() -> void:             # Start（View.cs:12）——原版向 GameView 注册；GameView 未搬＝无操作
	pass

func _exit_tree() -> void:         # OnDestroy（View.cs:29）——原版退订 GameView；无对应＝无操作
	pass

func SyncView() -> void:           # SyncView（View.cs:59，抽象）——基类空占位，子类覆写
	pass
