extends Node
class_name BaseEnemyStateManager

@export var Entity: BaseEnemy
@export var Current: BaseState
@export var Hatebox: Area2D
@export var HateTimer: Timer
var Previous: BaseState
var _exiting_tree := false

func _ready() -> void:
	_exiting_tree = false
	Entity.death.connect(_check.bind("death"))
	Entity.breaked.connect(_check.bind("breaked"))
	Entity.end_breaked.connect(_on_end_breaked)
	Hatebox.body_entered.connect(_on_target_entered)
	Hatebox.body_exited.connect(_on_target_exited)
	HateTimer.timeout.connect(_on_hate_timeout)
	Current.enter()

func _exit_tree() -> void:
	_exiting_tree = true
	# 场景销毁时，兄弟节点的退出顺序不保证计时器仍在树内。
	if is_instance_valid(Entity):
		_disconnect_signal(Entity.death, _check.bind("death"))
		_disconnect_signal(Entity.breaked, _check.bind("breaked"))
		_disconnect_signal(Entity.end_breaked, _on_end_breaked)
	if is_instance_valid(Hatebox):
		_disconnect_signal(Hatebox.body_entered, _on_target_entered)
		_disconnect_signal(Hatebox.body_exited, _on_target_exited)
	if is_instance_valid(HateTimer):
		_disconnect_signal(HateTimer.timeout, _on_hate_timeout)

func _disconnect_signal(source: Signal, callback: Callable) -> void:
	if source.is_connected(callback):
		source.disconnect(callback)

func _can_handle_events() -> bool:
	return not _exiting_tree and is_inside_tree() \
		and is_instance_valid(Entity) and Entity.is_inside_tree() \
		and not Entity.is_queued_for_deletion() \
		and is_instance_valid(Hatebox) and Hatebox.is_inside_tree() \
		and is_instance_valid(HateTimer) and HateTimer.is_inside_tree()

func _physics_process(delta: float) -> void:
	if not Entity.Atived:
		return
	# 兼容直接修改属性的调用，死亡优先于硬直和 AI 行为。
	if Entity.CurrentHealth <= 0:
		_check("death")
	elif Entity.Toughness <= 0:
		_check("breaked")
	if has_target():
		HateTimer.stop()
		_check("target_found")
	Current.do(delta)

func switch_state(next_state: BaseState) -> void:
	if next_state == null or next_state == Current:
		return
	Previous = Current
	Current.exit()
	Current = next_state
	Current.enter()

func _check(signal_name: String) -> void:
	if not _can_handle_events():
		return
	if Current.NextStates.has(signal_name):
		switch_state(Current.NextStates[signal_name] as BaseState)

func has_target() -> bool:
	for body in Hatebox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			return true
	return false

func _on_target_entered(body: Node2D) -> void:
	if not _can_handle_events():
		return
	if body.is_in_group("Hero"):
		HateTimer.stop()
		if Entity.Atived:
			_check("target_found")

func _on_target_exited(body: Node2D) -> void:
	if not _can_handle_events():
		return
	if body.is_in_group("Hero") and not has_target():
		HateTimer.start(5.0)

func _on_hate_timeout() -> void:
	if not _can_handle_events():
		return
	if not has_target():
		_check("target_lost")

func _on_end_breaked() -> void:
	if not _can_handle_events():
		return
	_check("end_breaked")
	if has_target() or not HateTimer.is_stopped():
		_check("target_found")
