extends Label


func _on_interaction_target_changed(target: Interactable) -> void:
	visible = is_instance_valid(target)
	text = "[E] %s" % target.get_interaction_text() if visible else ""
