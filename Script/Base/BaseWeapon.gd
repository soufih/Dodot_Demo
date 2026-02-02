class_name BaseWeapon
extends AnimatedSprite2D

signal on_attack(Movement:int)

@onready var Porperty:WeaponPorperty = WeaponManager.get_weapon_porperty(self.name)
@export var Hitboxs:Marker2D
@export var Ani: AnimationPlayer

var Rank:int = 1
var EquipmentOwner: BaseCharacter

func _ready() -> void:
	add_to_group("Weapon")
	connect("on_attack", _on_attack)

func _on_attack(Movement:int) -> void:
	pass

##执行攻击
func excute_attack(Movement:int):
	before_attack(Movement)

	during_attack(Movement)

	after_attack(Movement)

##攻击前的准备
func before_attack(_Movement:int):
	pass

##攻击中
func during_attack(_Movement:int):
	pass

##攻击后
func after_attack(_Movement:int):
	pass


##设置武器的拥有者
func set_self_owner(who: BaseCharacter):
	if who:
		EquipmentOwner = who
