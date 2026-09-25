extends WeaponAction
class_name SpawnBullet

@export var _BulletScene:String
## 相对于瞄准方向的偏移：x 为前方距离，y 为侧向距离。
@export var _SpawnPosition:Vector2 = Vector2(32.0, 0.0)
## 大于 0 时覆盖子弹场景速度，否则使用场景中的速度。
@export var _Speed:float
@export var _Porperty:WeaponPorperty

@export var _BulletScence:PackedScene


func execute(context: WeaponContext):
	spawn_bullet(context, _BulletScene, _SpawnPosition, _Speed, _Porperty)


## 生成弹幕模块。
func spawn_bullet(context: WeaponContext, BulletScene:String, SpawnPosition:Vector2, Speed:float, _property:WeaponPorperty) -> void:
	if context == null or not is_instance_valid(context.attacker):
		return
	var attacker = context.attacker
	if not attacker.is_inside_tree():
		return

	var scene:PackedScene = _BulletScence
	if scene == null and not BulletScene.is_empty():
		scene = load(BulletScene) as PackedScene
	if scene == null:
		push_warning("SpawnBullet: 请配置子弹场景。")
		return

	var direction:Vector2 = attacker.global_position.direction_to(attacker.get_global_mouse_position())
	if direction.is_zero_approx():
		direction = Vector2.RIGHT.rotated(attacker.global_rotation)

	var spawn_position:Vector2 = attacker.global_position + SpawnPosition.rotated(direction.angle())
	var bullet = scene.instantiate()
	if not bullet is Node2D or not bullet.has_method("setup"):
		push_warning("SpawnBullet: 子弹必须是提供 setup() 的 Node2D。")
		bullet.free()
		return

	# setup() 接收目标坐标。使用生成点前方的坐标，避免鼠标过近时反向发射。
	bullet.setup("Enemy", attacker, spawn_position + direction * 100.0)
	if Speed > 0.0:
		bullet.Speed = Speed
	# 在入树前设置位置与目标，供 Bullet._ready() 计算方向。
	# 现有 Bullet._ready() 会将子弹移到当前场景，并保留全局位置。
	bullet.position = attacker.to_local(spawn_position)
	attacker.add_child(bullet)
	bullet.global_rotation = direction.angle()
