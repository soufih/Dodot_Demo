extends BaseWeapon

@onready var Ani: AnimationPlayer = $AnimationPlayer

func during_attack(Movement:int):
	super.during_attack(Movement)
	Ani.play("attack")
