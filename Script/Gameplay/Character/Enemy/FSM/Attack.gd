extends BaseState

@export var Hitbox: Area2D
var Target: Vector2
var _generation: int = 0
var _active := false

func _on_enter():
	_generation += 1
	var generation := _generation
	_active = true
	var enemy := Entity as BaseEnemy
	var hero := get_tree().get_first_node_in_group("Hero") as Node2D
	Target = hero.global_position if is_instance_valid(hero) \
		else enemy.global_position + Vector2(enemy.facing_dir, 0)
	enemy.lock_attack_facing(int(signf(Target.x - enemy.global_position.x)))
	AniPlayer.play("Attack")
	var finished_animation: StringName = await AniPlayer.animation_finished
	if generation == _generation and _active and finished_animation == &"Attack":
		get_parent()._check("end_attack")


func _on_exit():
	_active = false
	_generation += 1
	(Entity as BaseEnemy).unlock_attack_facing()
	if AniPlayer.current_animation == "Attack":
		AniPlayer.stop()

func apply_damage(movement: String):
	if not _active:
		return
	for body in Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			DamageSystem.damage_assess(Entity, body, Entity.Porperty.Movementlist[movement])
