extends BaseState

signal on_attack(i: bool)

@export var Spirte:AnimatedSprite2D
@export var Hitbox:Area2D
var Hero

func enter():
	Hero = get_tree().get_first_node_in_group("Hero")

func do(_delta):
	#追踪玩家
	for body in Hitbox.get_overlapping_bodies():
		if body.is_in_group("Hero"):
			var HeroPos = body.global_position
			var SelfPos = Entity.global_position
			if Entity.scale.y*(HeroPos.x-SelfPos.x) > 0:
				Entity.scale.x = abs(Entity.scale.x)
			else:
				Entity.scale.x = -abs(Entity.scale.x)
			
			if HeroPos > SelfPos:
				$"../Move".Direct = 1
			else:
				$"../Move".Direct = -1
#
	#获取玩家位置
	if Hero:
		Target = Hero.global_position

	AniPlayer.play("Attack")
	await AniPlayer.animation_finished

var Target:Vector2

@export var BulletData: ElementaryBullet
@export var BulletSpeed: float = 500.0

func spawn_bullet():
	var origin: Vector2 = $"../../../BulletSpawn".global_position
	BulletPoolManager.spawn(BulletData,
		Entity, origin, origin.direction_to(Target), BulletSpeed, "Hero")
func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("Hero"):
		await Spirte.animation_finished
		get_parent().Attacking = false
