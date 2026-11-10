extends "res://Script/Gameplay/Character/Enemy/FSM/Attack.gd"

@export var BulletData: ElementaryBullet
@export var BulletSpeed: float = 500.0

func spawn_bullet():
	if not _active:
		return
	var origin: Vector2 = Entity.get_node("BulletSpawn").global_position
	BulletPoolManager.spawn(BulletData,
		Entity, origin, origin.direction_to(Target), BulletSpeed, "Hero")

func _on_do(_delta: float) -> void:
	var enemy := Entity as BaseEnemy
	var hero := get_tree().get_first_node_in_group("Hero") as Node2D
	Target = hero.global_position if is_instance_valid(hero) \
		else enemy.global_position + Vector2(enemy.facing_dir, 0)
