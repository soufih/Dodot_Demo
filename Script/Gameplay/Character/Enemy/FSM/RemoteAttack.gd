extends "res://Script/Gameplay/Character/Enemy/FSM/Attack.gd"

@export var BulletData: ElementaryBullet
@export var BulletSpeed: float = 500.0
var Target: Vector2

func _on_enter():
	var hero := get_tree().get_first_node_in_group("Hero") as Node2D
	if is_instance_valid(hero):
		Target = hero.global_position
		if Entity.scale.y * (Target.x - Entity.global_position.x) > 0:
			Entity.scale.x = abs(Entity.scale.x)
		else:
			Entity.scale.x = -abs(Entity.scale.x)
	await super._on_enter()

func spawn_bullet():
	if not _active:
		return
	var origin: Vector2 = Entity.get_node("BulletSpawn").global_position
	BulletPoolManager.spawn(BulletData,
		Entity, origin, origin.direction_to(Target), BulletSpeed, "Hero")
