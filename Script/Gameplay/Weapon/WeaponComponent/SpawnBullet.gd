extends WeaponAction
class_name SpawnBullet

@export var _BulletScene:PackedScene
@export var _SpawnPosition:Vector2
@export var _Direction:Vector2
@export var _Speed:float
@export var _Porperty:WeaponPorperty


func excute():
	spawn_bullet(_BulletScene, _SpawnPosition, _Direction, _Speed, _Porperty)

##生成弹幕模块
func spawn_bullet(BulletScene:PackedScene, SpawnPosition:Vector2, Direction:Vector2, Speed:float, Porperty:WeaponPorperty) -> void:
	var bullet_instance = BulletScene.instantiate()
	bullet_instance.position = SpawnPosition
	bullet_instance.direction = Direction.normalized()
	bullet_instance.speed = Speed
	bullet_instance.Porperty = Porperty
