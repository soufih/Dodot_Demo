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

func excute_attack(Movement:int):
	before_attack(Movement)

	during_attack(Movement)

	after_attack(Movement)

func before_attack(Movement:int):
	pass

func during_attack(Movement:int):
	apply_damage(Movement)

func after_attack(Movement:int):
	pass

func apply_damage(Movement:int):
	for body in Hitboxs.get_child(Movement).get_overlapping_bodies():
		if body.is_in_group("Enemy"):
			var Damage:DamagePorperty = Porperty.BaseDamage.duplicate(true)
			Damage.Damage = Damage.Damage * Porperty.DamageMultipler[Movement]
			DamageSystem.damage_assess(EquipmentOwner,body, Damage)

func set_self_owner(who: BaseCharacter):
	if who:
		EquipmentOwner = who
