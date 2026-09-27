extends Node2D

@export var Ani:AnimationPlayer
@export var Owner:CharacterBody2D
@export var WeaponNode:Node2D
@export var Hitbox:Area2D
@export var WeaponTexture:Sprite2D

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
	EquipmentSlotSystem.current_weapon_changed.connect(_on_current_weapon_changed)

	var WeaponName = ResourceManager.get_item_name(EquipmentSlotSystem.CurrentWeapon)
	Weapon = WeaponManager.get_weapon_porperty(WeaponName)

	Ani.play("Reset")


func _on_current_weapon_changed():
	var WeaponName = ResourceManager.get_item_name(EquipmentSlotSystem.get_current_weapon())
	Weapon = WeaponManager.get_weapon_porperty(WeaponName)
	var WeaponId = EquipmentSlotSystem.get_current_weapon()
	WeaponTexture.texture = ResourceManager.get_item_icon(WeaponId)


func _on_hero_on_attack(CCount:int) -> void:
	ComboCount = CCount
	if Weapon == null:
		return
	

	Context = create_context()
	before_attack()

##结束攻击后复位
func _on_hero_end_attack() -> void:
	if Weapon == null:
		return
	Ani.play("Reset")


func _on_hero_breaked() -> void:
	Ani.play("Reset")


func before_attack():
	if Weapon == null:
		return
	for action:WeaponAction in Weapon.BeforeAttack:
		action.execute(Context)

	if Ani.has_animation(Type[Weapon.Type]+ComboAnimations[ComboCount]):
		Ani.play(Type[Weapon.Type]+ComboAnimations[ComboCount])


func during_attack():
	if Weapon == null:
		return
	for action:WeaponAction in Weapon.DuringAttack:
		action.execute(Context)


func after_attack():
	if Weapon == null:
		return
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
