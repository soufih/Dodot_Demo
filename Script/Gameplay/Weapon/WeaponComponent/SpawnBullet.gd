extends WeaponAction
class_name SpawnBullet

## 相对于瞄准方向的偏移：x 为前方距离，y 为侧向距离。
@export var _SpawnPosition: Vector2 = Vector2(32.0, 0.0)
@export var _Speed: float = 500.0
## 直接拖入 ElementaryBullet 或 SeniorBullet 的 .tres 资源。
@export var _BulletData: ElementaryBullet

func execute(context: WeaponContext):
	spawn_bullet(context, _SpawnPosition, _Speed)


func spawn_bullet(context: WeaponContext, SpawnPosition: Vector2, Speed: float) -> void:
	if context == null or not is_instance_valid(context.attacker):
		return
	var attacker = context.attacker
	if not attacker.is_inside_tree():
		return
	var direction: Vector2 = attacker.global_position.direction_to(attacker.get_global_mouse_position())
	if direction.is_zero_approx():
		direction = Vector2.RIGHT.rotated(attacker.global_rotation)
	var origin: Vector2 = attacker.global_position + SpawnPosition.rotated(direction.angle())
	BulletPoolManager.spawn(_BulletData,
		attacker, origin, direction, Speed if Speed > 0.0 else 500.0, "Enemy")
