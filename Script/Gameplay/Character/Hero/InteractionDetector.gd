class_name InteractionDetector
extends Area2D


var interactables: Array[Interactable] = []


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		interactables.append(area)


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		interactables.erase(area)


func get_current_interactable() -> Interactable:
	if interactables.is_empty():
		return null

	return interactables[0]
