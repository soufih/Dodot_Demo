extends Node

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var HERO

func _ready() -> void:
	ResourceManager.load_item_catalog()
	WeaponManager.load_weapon()
	EnemyManager.load_enemy()
	# LevelGenerator.prepare_generating()


	# HERO = preload("res://Scene/Hero/Hero.tscn").instantiate()
	# HERO.hide()
	# add_child(HERO)
	

	# LevelGenerator.generate_level(0)

	# var TestMap = preload("res://Scene/Map/Home/Home.tscn").instantiate()
	# add_child(TestMap)

	# var Enemy1 = preload("res://Scene/Enemy/Enemy1.tscn").instantiate()
	# add_child(Enemy1)

	# var Enemy2 = preload("res://Scene/Enemy/Enemy2.tscn").instantiate()
	# add_child(Enemy2)


func set_hero(hero:BaseCharacter):
	HERO = hero

func get_hero():
	if HERO:
		return HERO
	return null
