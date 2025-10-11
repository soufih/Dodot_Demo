extends BaseCharacter
class_name HeroProperty

@onready var ani: AnimationPlayer = $AnimationPlayer
@onready var Spirte: AnimatedSprite2D = $AnimatedSprite2D
@onready var WeaponPosition: Marker2D = $WeaponPosition

@export var WeaponSlot:Array
@export var RelicSlot:Array
@export var CurrentWeapon:int = 0

func _ready() -> void:
	super.beginning()
	add_to_group("Hero")
	equip_weapon(CurrentWeapon)


@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	super.running()
	if Input.get_action_strength("MoveRight"):
		if WeaponPosition.get_children().size() != 0:
			WeaponPosition.get_child(0).scale.x=1
		Spirte.flip_h = false
	elif Input.get_action_strength("MoveLeft"):
		if WeaponPosition.get_children().size() != 0:
			WeaponPosition.get_child(0).scale.x=-1
		Spirte.flip_h = true


func equip_weapon(WeaponId: int):
	if WeaponPosition.get_children().size() != 0:
		WeaponPosition.get_child(0).queue_free()
	
	ResourceManager.instantiate_item(WeaponId, WeaponPosition)
	WeaponPosition.get_child(0).z_index=-1
