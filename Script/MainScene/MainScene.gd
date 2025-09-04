extends Node
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var TestMap = preload("res://Scene/Map/TestMap.tscn").instantiate()
	var Hero = preload("res://Scene/Hero/Hero.tscn").instantiate()
	self.add_child(TestMap)
	self.add_child(Hero)


func _physics_process(delta: float) -> void:
	for i in get_children():
		if i.is_in_group("Chr"):
			i.velocity.y += gravity*delta
			i.move_and_slide()
