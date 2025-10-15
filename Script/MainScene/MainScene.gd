extends Node
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var TestMap = preload("res://Scene/Map/Home/Home.tscn").instantiate()
	var Hero = preload("res://Scene/Hero/Hero.tscn").instantiate()
	#var Enemy1 = preload("res://Scene/Enemy/Enemy1.tscn").instantiate()
	var Enemy2 = preload("res://Scene/Enemy/Enemy2.tscn").instantiate()
	self.add_child(TestMap)
	self.add_child(Hero)
	#self.add_child(Enemy1)
	self.add_child(Enemy2)


func _physics_process(delta: float) -> void:
	for i in get_children(): #对在“Chr”组中的对象施加重力
		if i.is_in_group("Chr"):
			i.velocity.y += gravity*delta
			i.move_and_slide()
