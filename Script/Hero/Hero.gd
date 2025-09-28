extends BaseCharacter

@onready var ani: AnimationPlayer = $AnimationPlayer
@onready var Spirte: AnimatedSprite2D = $AnimatedSprite2D
@onready var HitBox: Node2D           = $AttackArea

func _ready() -> void:
	super.beginning()
	add_to_group("Hero")
	var weapon = preload("res://Scene/Weapon/Sword.tscn").instantiate()
	$Weapon/Area2D.add_child(weapon)

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	super.running()
	if Input.get_action_strength("MoveRight"):
		Spirte.flip_h = false
	elif Input.get_action_strength("MoveLeft"):
		Spirte.flip_h = true
