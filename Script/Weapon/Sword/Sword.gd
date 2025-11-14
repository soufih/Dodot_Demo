extends BaseWeapon

@onready var Ani: AnimationPlayer = $AnimationPlayer
@onready var EquipmentOwner: BaseCharacter

func during_attack():
	Ani.play("Attack")

func apply_damage():
	for body in $HitboxsTransform/Area1.get_overlapping_bodies():
		if body.is_in_group("Enemy"):
			DamageSystem.damage_assess(EquipmentOwner,body, Porperty)

func set_self_owner(who: BaseCharacter):
	if who:
		EquipmentOwner = who
