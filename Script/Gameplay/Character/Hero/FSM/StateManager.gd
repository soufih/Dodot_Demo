extends BaseStateManager

enum State{
	Idle,
	Run,
	Jumping,
	Falling,
	Attack,
	SwitchWeapon,
	Death,
	Break,
	Interact,
}

@onready var Hero: BaseCharacter = $".."
@onready var Sprite:AnimatedSprite2D = $"../AnimatedSprite2D"
@onready var ani:AnimationPlayer = $"../AnimationPlayer"
@onready var InteractBox:Area2D = $"../InteractBox"

var jumping:bool = false
var attacking:bool = false
var dead:bool = false
var breaked:bool = false
var interacting:bool = false

func check():
	if Hero.CurrentHealth <= 0:
		change_state(State.Death)
		return

	if Hero.Toughness <= 0:
		change_state(State.Break)
		return

	if attacking || dead || interacting:
		return

	if Input.is_action_just_pressed("Interact") && InteractBox.has_overlapping_areas():
		change_state(State.Interact)
		return
	if jumping:
		return
	if !Hero.is_on_floor() && Current.name != "Falling":
		change_state(State.Falling)
		return

	if !Hero.is_on_floor():
		return

	if Input.is_action_just_pressed("Jump"):
		change_state(State.Jumping)
		return
	if Input.is_action_just_pressed("Attack"):
		change_state(State.Attack)
		return
	if (Input.is_action_pressed("MoveRight") || Input.is_action_pressed("MoveLeft")) && Current.name != "Run":
		change_state(State.Run)
		return
	if Hero.velocity.x == 0 && Current.name != "Idle":
		change_state(State.Idle)
		return

	if Input.is_action_just_pressed("SwitchWeapon"):
			$SwitchWeapon.switch_weapon()
