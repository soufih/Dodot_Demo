extends BaseState

var ladder: ClimbableLadder
var interaction_controller: InteractionController
var sprite: AnimatedSprite2D


func enter():
	interaction_controller = Entity.get_node_or_null("InteractionController") as InteractionController
	if interaction_controller == null:
		Entity.emit_signal("end_climb")
		return
	ladder = interaction_controller.current_interactable as ClimbableLadder
	if not is_instance_valid(ladder):
		Entity.emit_signal("end_climb")
		return
	interaction_controller.interacting = true
	Entity.velocity = Vector2.ZERO
	Entity.global_position.x = ladder.get_climb_axis_x()
	sprite = Entity.get_node_or_null("HeroSpirte") as AnimatedSprite2D
	AniPlayer.play("Climb")
	# Climb 动画通过方法轨道启动 AnimatedSprite2D，先应用轨道再暂停精灵。
	AniPlayer.advance(0.0)
	if sprite != null:
		sprite.pause()


func do(_delta: float):
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


func exit():
	Entity.velocity = Vector2.ZERO
	if sprite != null:
		sprite.pause()
	if is_instance_valid(interaction_controller):
		interaction_controller.interacting = false
		interaction_controller.current_interactable = null
	ladder = null
	sprite = null
