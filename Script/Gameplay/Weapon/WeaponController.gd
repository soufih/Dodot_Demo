extends Node2D

@onready var InputControlller = $"../InputController"
@onready var Ani = $WeaponAnimations
@onready var Owner = $".."
@onready var WeaponNode = $WeaponPivot/Weapon
@onready var Hitbox = $WeaponPivot/Hitbox
@export var ComboAnimations: Array[StringName] = [&"Attack", &"Attack2"]

var Weapon: WeaponPorperty
var Context:WeaponContext
var ComboCount:int
const Type:Dictionary[int, String] = {
	0 : "Sword",
	1 : 'Blade',
	2 : 'Staff',
	3 : 'Bow'
}


func _ready() -> void:
	Weapon = WeaponManager.get_weapon_porperty("Sword")
	Ani.play("Reset")


func _on_hero_on_attack(CCount:int) -> void:
	ComboCount = CCount
	if !Weapon:
		return

	Context = create_context()
	before_attack()

##结束攻击后复位
func _on_hero_end_attack() -> void:
	Ani.play("Reset")


func before_attack():
	for action:WeaponAction in Weapon.BeforeAttack:
		action.execute(Context)

	if Ani.has_animation(Type[Weapon.Type]+ComboAnimations[ComboCount]):
		Ani.play(Type[Weapon.Type]+ComboAnimations[ComboCount])


func during_attack():
	for action:WeaponAction in Weapon.DuringAttack:
		action.execute(Context)


func after_attack():
	for action:WeaponAction in Weapon.AfterAttack:
		action.execute(Context)

##创建上下文供每个攻击动作使用
func create_context():
	return WeaponContext.new(
		Weapon,
		Owner,
		WeaponNode,
		Hitbox,
		ComboCount
	)
