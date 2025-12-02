extends BaseCharacter
class_name HeroProperty

signal god_mode

@onready var ani: AnimationPlayer = $AnimationPlayer
@onready var Spirte: AnimatedSprite2D = $AnimatedSprite2D
@onready var WeaponPosition: Marker2D = $WeaponPosition

@export var CurrentWeapon:int = 0
@export var Speed:int = 200
@export var GodModeTimer: int = 1

func _ready() -> void:
	super.beginning()
	add_to_group("Hero")
	equip_weapon(CurrentWeapon)


func _physics_process(delta: float) -> void:
	super.physics_running(delta)
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
	if WeaponPosition.get_child(0):
		WeaponPosition.get_child(0).set_self_owner(self)


func _on_god_mode() -> void:
	set_collision_layer_value(2,false)
	set_collision_layer_value(7,true)
	$Godmode.start(GodModeTimer)
	await $Godmode.timeout
	set_collision_layer_value(2,true)
	set_collision_layer_value(7,false)
