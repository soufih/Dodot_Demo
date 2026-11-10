extends BaseCharacter
class_name BaseEnemy

var Porperty:EnemyConfig
var Atived:bool = false

@export var facing_nodes: Array[Node2D] = []
var facing_dir: int = 1
var move_dir: int = 0
var _facing_locked := false
var _sprite_position: Vector2
var _facing_transforms: Dictionary[Node2D, Transform2D] = {}

@onready var drop_component: DropComponent = $DropComponent
@onready var facing_sprite: AnimatedSprite2D = $AnimatedSprite2D

func beginning():
	_sprite_position = facing_sprite.position
	for node in facing_nodes:
		_facing_transforms[node] = node.transform
	set_facing(facing_dir)
	super.beginning()
	add_to_group("Enemy")
	Porperty = EnemyManager.get_enemy_porperty(self.name)
	if !Porperty:
		push_warning("Can't Find Enemy Porperty")
		return
		
	drop_component.items = Porperty.Drop

	MaxHealth = Porperty.MaxHealth
	CurrentHealth = MaxHealth
	MaxToughness = Porperty.MaxToughness
	Toughness = MaxToughness
	ToughnessRecover = Porperty.ToughnessRecover
	AbnormalConditionResist = Porperty.AbnormalConditionResist
	DamageResist = Porperty.DamageResist


## 朝向只从显式方向计算，不读取负缩放的分解结果。
func set_facing(direction: int) -> void:
	if _facing_locked or direction == 0:
		return
	facing_dir = signi(direction)
	facing_sprite.flip_h = facing_dir < 0
	facing_sprite.position = Vector2(_sprite_position.x * facing_dir, _sprite_position.y)
	var mirror := Transform2D(Vector2(facing_dir, 0), Vector2.DOWN, Vector2.ZERO)
	for node in _facing_transforms:
		node.transform = mirror * _facing_transforms[node]


func set_move_direction(direction: int, speed: float) -> void:
	move_dir = 0 if _facing_locked else signi(direction)
	velocity.x = move_dir * speed
	set_facing(move_dir)


func lock_attack_facing(direction: int) -> void:
	set_move_direction(0, 0.0)
	set_facing(direction)
	_facing_locked = true


func unlock_attack_facing() -> void:
	_facing_locked = false
