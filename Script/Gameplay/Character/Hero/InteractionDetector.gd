class_name InteractionDetector
extends Area2D


signal interaction_target_changed(target: Interactable)

var interactables: Array[Interactable] = []
var _dismissed_prompts: Array[Interactable] = []


func _ready() -> void:
	_update_prompt_target()


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		if not interactables.has(area):
			interactables.append(area)
		var on_exit := _on_area_exited.bind(area)
		if not area.tree_exiting.is_connected(on_exit):
			area.tree_exiting.connect(on_exit)
		_update_prompt_target()


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		interactables.erase(area)
		_dismissed_prompts.erase(area)
		_update_prompt_target()


func _exit_tree() -> void:
	interactables.clear()
	_dismissed_prompts.clear()
	interaction_target_changed.emit(null)


func dismiss_interaction_prompt(target: Interactable) -> void:
	if interactables.has(target) and not _dismissed_prompts.has(target):
		_dismissed_prompts.append(target)
	_update_prompt_target()


## 可重复交互完成后刷新同一目标的剩余数量或失败原因。
func refresh_interaction_prompt() -> void:
	_update_prompt_target()

func _update_prompt_target() -> void:
	var target := get_current_interactable()
	interaction_target_changed.emit(null if _dismissed_prompts.has(target) else target)


func get_current_interactable() -> Interactable:
	while not interactables.is_empty() and (not is_instance_valid(interactables[0]) \
		or interactables[0].is_queued_for_deletion()):
		interactables.pop_front()
	if interactables.is_empty():
		return null

	return interactables[0]
