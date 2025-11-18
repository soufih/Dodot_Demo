extends BaseStateManager

@onready var Hero: BaseCharacter = $".."
@onready var Sprite:AnimatedSprite2D = $"../AnimatedSprite2D"
@onready var ani:AnimationPlayer = $"../AnimationPlayer"

var jumping:bool
var attacking:bool
var dead:bool = false
var breaked:bool = false

func check():
	if !jumping && !attacking && !dead:
		if Hero.CurrentHealth <= 0:
			change_state(6)
			return

		if Hero.Toughness <= 0:
			change_state(7)
			return

		if Input.is_action_just_pressed("Attack") && Hero.is_on_floor():
			change_state(4)
		elif Input.is_action_just_pressed("Jump") && Hero.is_on_floor():
			change_state(2)
		elif (Input.is_action_pressed("MoveRight") || Input.is_action_pressed("MoveLeft")) && Hero.is_on_floor():
			change_state(1)
		elif Hero.is_on_floor():
			change_state(0)
		elif !Hero.is_on_floor():
			change_state(3)
		if !attacking:
			if Input.is_action_just_pressed("SwitchWeapon"):
				$SwitchWeapon.switch_weapon()
