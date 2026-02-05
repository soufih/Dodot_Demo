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
		if !Hero.is_on_floor() && Current.name != "Falling":
			change_state(3)
			return
		if Hero.is_on_floor() && Input.is_action_just_pressed("Attack"):
			change_state(4)
			return
		if Hero.is_on_floor() && Input.is_action_just_pressed("Jump"):
			change_state(2)
			return
		if Hero.is_on_floor() && (Input.is_action_pressed("MoveRight") || Input.is_action_pressed("MoveLeft")) && Current.name != "Run":
			change_state(1)
			return
		if Hero.is_on_floor() && !Input.is_anything_pressed() && Current.name != "Idle":
			change_state(0)
			return
		if !attacking:
			if Input.is_action_just_pressed("SwitchWeapon"):
				$SwitchWeapon.switch_weapon()
