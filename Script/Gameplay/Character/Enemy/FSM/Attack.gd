extends BaseState

@export var Spirte: AnimatedSprite2D
@export var Hitbox: Area2D
var _generation: int = 0
var _active := false

func _on_enter():
	_generation += 1
	var generation := _generation
	_active = true
	Entity.velocity.x = 0
	AniPlayer.play("Attack")
	var finished_animation: StringName = await AniPlayer.animation_finished
	if generation == _generation and _active and finished_animation == &"Attack":
		get_parent()._check("end_attack")

func _on_exit():
	_active = false
	_generation += 1
	if AniPlayer.current_animation == "Attack":
		AniPlayer.stop()

func apply_damage(movement: String):
	if not _active:
		return
	for body in Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			DamageSystem.damage_assess(Entity, body, Entity.Porperty.Movementlist[movement])
