extends Node

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	for i in get_children():
		if i.is_in_group("Chr"):
			i.velocity.y += gravity
			i.move_and_slide()
