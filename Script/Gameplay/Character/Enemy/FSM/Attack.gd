extends BaseState

signal on_attack(i:bool)

@export var Spirte:AnimatedSprite2D
@export var Hitbox: Area2D

func do(_delta):
	on_attack.emit(true)
	AniPlayer.play("Attack")
	await Spirte.animation_finished


func apply_damage(Movement: String):
	for body in Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero") && Spirte.frame == 9:
			DamageSystem.damage_assess(Entity, body, Entity.Porperty.Movementlist[Movement])


func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("Hero"):
		await Spirte.animation_finished
		on_attack.emit(false)
