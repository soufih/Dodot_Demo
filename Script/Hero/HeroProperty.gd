extends BaseCharacter
class_name HeroProperty

@onready var ani: AnimationPlayer = $AnimationPlayer
@onready var Spirte: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super.beginning()
	add_to_group("Hero")
	ResourceManager.instantiate_item(0, $WeaponPosition)


@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	super.running()
	if Input.get_action_strength("MoveRight"):
		if $WeaponPosition.get_children().size() != 0:
			$WeaponPosition.get_child(0).scale.x=1
		Spirte.flip_h = false
	elif Input.get_action_strength("MoveLeft"):
		if $WeaponPosition.get_children().size() != 0:
			$WeaponPosition.get_child(0).scale.x=-1
		Spirte.flip_h = true

		
func change_weapon(weapon_path: String):
	if $WeaponPosition.get_children().size() != 0:
		$WeaponPosition.get_child(0).queue_free()
	var weapon = load(weapon_path).instantiate()
	$WeaponPosition.add_child(weapon)
	weapon.z_index = -1
