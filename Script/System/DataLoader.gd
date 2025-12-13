extends Node

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var HERO
var tmp_slot:TmpSlot
var UILayer: CanvasLayer

func _ready() -> void:
	load_ui()

	HERO = preload("res://Scene/Hero/Hero.tscn").instantiate()

	LevelGenerator.prepare_generating()
	LevelGenerator.generate_level(0)

	#var TestMap = preload("res://Scene/Map/Home/Home.tscn").instantiate()
	#add_child(TestMap)

	#var Enemy1 = preload("res://Scene/Enemy/Enemy1.tscn").instantiate()
	#add_child(Enemy1)

	#var Enemy2 = preload("res://Scene/Enemy/Enemy2.tscn").instantiate()
	#add_child(Enemy2)

	#var PlayerStateUI = preload("uid://bd2erf76jvubl").instantiate()
	#add_child(PlayerStateUI)

	add_child(HERO)


func load_ui():
	var TmpSlotLayer = CanvasLayer.new()
	UILayer = CanvasLayer.new()
	
	add_child(TmpSlotLayer)
	add_child(UILayer)
	
	TmpSlotLayer.layer = 100
	UILayer.layer = 99

	tmp_slot = preload("uid://bb4quhyltqxmu").instantiate()
	TmpSlotLayer.add_child(tmp_slot)

	var Backpack:BaseUI = preload("uid://b12ujb2p2b4v").instantiate()
	Backpack.hide()
	UILayer.add_child(Backpack)
