class_name BaseState
extends Node

signal enter_started
signal enter_finished
signal do_started(delta: float)
signal do_finished(delta: float)
signal exit_started
signal exit_finished

@export var Entity:BaseCharacter
@export var AniPlayer:AnimationPlayer
@export var _InputController:InputController
@export var NextStates:Dictionary[String,Node]
@export var BufferedStates:Array[Node]
@export var Substates:Dictionary[String,Node]

## 生命周期统一入口。子类实现钩子，避免覆盖入口漏掉通知。
## await 兼容同步和异步钩子；结束信号在钩子实际完成后发出。
func enter() -> void:
	enter_started.emit()
	_on_enter()
	enter_finished.emit()

func do(_delta: float) -> void:
	do_started.emit(_delta)
	_on_do(_delta)
	do_finished.emit(_delta)

func exit() -> void:
	exit_started.emit()
	_on_exit()
	exit_finished.emit()

## 进入状态的具体逻辑。
func _on_enter() -> void:
	pass

## 状态每帧执行逻辑，delta 单位为秒。
func _on_do(_delta: float) -> void:
	pass

## 离开状态的清理逻辑。
func _on_exit() -> void:
	pass

func _check(signalName:String):
	if Substates.has(signalName):
		Substates[signalName].enter()
