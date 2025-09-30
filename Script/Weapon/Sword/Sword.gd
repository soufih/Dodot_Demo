extends BaseWeapon

@onready var Ani: AnimationPlayer = $AnimationPlayer

func during_attack():
	Ani.play("Attack")
