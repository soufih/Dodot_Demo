extends Node

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")*1.5
var HERO

var Blackboard:Dictionary

func _ready() -> void:
	ResourceManager.load_item_catalog()
	WeaponManager.load_weapon()
	EnemyManager.load_enemy()
	# LevelGenerator.prepare_generating()


func set_hero(hero:BaseCharacter):
	HERO = hero

func get_hero():
	if HERO:
		return HERO
	return null
