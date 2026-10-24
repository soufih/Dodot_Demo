extends BaseState

@export var interaction_controller: InteractionController
@export var spirte: AnimatedSprite2D

var ladder: ClimbableLadder
var sprite: AnimatedSprite2D
var _previous_flip_h := false


func _on_enter():
	if interaction_controller == null:
		Entity.emit_signal("end_climb")
		return
	ladder = interaction_controller.current_interactable as ClimbableLadder
	if not is_instance_valid(ladder):
		Entity.emit_signal("end_climb")
		return
	interaction_controller.interacting = true
	Entity.climb_started.emit()
	Entity.velocity = Vector2.ZERO
	Entity.global_position.x = ladder.get_climb_axis_x()
	if sprite != null:
		_previous_flip_h = sprite.flip_h
	AniPlayer.play("Climb")
	# Climb 动画通过方法轨道启动 AnimatedSprite2D，先应用轨道再暂停精灵。
	AniPlayer.advance(0.0)
	if sprite != null:
		sprite.flip_h = ladder.climb_flip_h
		sprite.pause()


func _on_do(_delta: float):
	if not is_instance_valid(ladder) or not is_instance_valid(interaction_controller) \
		or not is_instance_valid(interaction_controller.detector) \
		or not interaction_controller.detector.get_overlapping_areas().has(ladder):
		Entity.emit_signal("end_climb")
		return
	if _InputController.is_banned:
		Entity.velocity = Vector2.ZERO
		if sprite != null:
			sprite.pause()
		return
	var direction := _InputController.get_climb_direction()
	Entity.velocity = Vector2(0.0, direction * ladder.climb_speed)
	if sprite != null:
		if is_zero_approx(direction):
			sprite.pause()
		else:
			sprite.play("Climb")
	Entity.move_and_slide()
	if direction > 0.0 and Entity.is_on_floor():
		Entity.emit_signal("end_climb")


func _on_exit():
	Entity.velocity = Vector2.ZERO
	if sprite != null:
		sprite.pause()
		sprite.flip_h = _previous_flip_h
	if is_instance_valid(interaction_controller):
		interaction_controller.interacting = false
		interaction_controller.current_interactable = null
	ladder = null
	sprite = null
	Entity.climb_finished.emit()
