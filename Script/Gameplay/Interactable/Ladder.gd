class_name ClimbableLadder
extends Interactable

@export_range(1.0, 1000.0, 1.0) var climb_speed: float = 120.0
## 攀爬动画是否水平翻转，由梯子固定指定，与进入方向无关。
@export var climb_flip_h: bool = false
@export var collision: CollisionShape2D


func can_interact(actor: Node) -> bool:
	if not actor is HeroProperty:
		return false

	return true


func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	actor.emit_signal("on_climb")


func get_climb_axis_x() -> float:
	return collision.global_position.x if collision != null else global_position.x
