extends StaticBody2D

@export var detectBox:Area2D
var entered:bool

func _input(event: InputEvent) -> void:
	if !Input.is_action_just_pressed("Down"):
		return
	for body in detectBox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			$CollisionShape2D.set_deferred("disabled", true)
			entered = true
			pass



func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Hero") && entered:
		$CollisionShape2D.set_deferred("disabled", false)
		entered = false
		pass
