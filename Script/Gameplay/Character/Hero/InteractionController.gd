class_name InteractionController
extends Node


@export var detector: InteractionDetector

var interacting := false
var current_interactable: Interactable


func try_interact() -> void:
	if interacting:
		if current_interactable is ClimbableLadder:
			owner.emit_signal("end_climb")
		return

	var target = detector.get_current_interactable()

	if target == null:
		return

	if not target.can_interact(owner):
		return

	current_interactable = target

	target.interact(owner)
	detector.dismiss_interaction_prompt(target)


func _on_input_controller_interact_pressed() -> void:
	try_interact()
