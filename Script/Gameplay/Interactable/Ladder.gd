class_name ClimbableLadder
extends Interactable

@export_range(1.0, 1000.0, 1.0) var climb_speed: float = 120.0
## 攀爬动画是否水平翻转，由梯子固定指定，与进入方向无关。
@export var climb_flip_h: bool = false


func can_interact(actor: Node) -> bool:
	if not actor is HeroProperty:
		return false
	var controller := actor.get_node_or_null("InteractionController") as InteractionController
	var state_manager := actor.get_node_or_null("State")
	return controller != null and not controller.interacting \
		and controller.detector != null \
		and controller.detector.get_overlapping_areas().has(self) \
		and state_manager != null and state_manager.Current != null \
		and state_manager.Current.NextStates.has("on_climb")


func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	var controller := actor.get_node("InteractionController") as InteractionController
	controller.current_interactable = self
	actor.emit_signal("on_climb")


func get_climb_axis_x() -> float:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	return collision.global_position.x if collision != null else global_position.x
