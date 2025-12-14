class_name BaseWeapon
extends AnimatedSprite2D

var Porperty:WeaponPorperty
var Rank:int = 1
var Hitboxs:Marker2D
var EquipmentOwner: BaseCharacter


func _ready() -> void:
	Porperty =  WeaponManager.get_weapon_porperty(self.name)
	Hitboxs = get_node("Hitboxs")
	add_to_group("Weapon")

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
	apply_damage(_Movement)

##攻击后
func after_attack(_Movement:int):
	pass

##应用伤害
func apply_damage(Movement:int):
	for body in Hitboxs.get_child(Movement).get_overlapping_bodies():
		if body.is_in_group("Enemy"):
			var Damage:DamagePorperty = Porperty.BaseDamage.duplicate(true)
			Damage.Damage = Damage.Damage * Porperty.DamageMultipler[Movement]
			DamageSystem.damage_assess(EquipmentOwner,body, Damage)

##设置武器的拥有者
func set_self_owner(who: BaseCharacter):
	if who:
		EquipmentOwner = who
