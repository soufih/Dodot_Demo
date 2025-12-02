extends Node

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var WeaponPorpertyLog:WeaponPorperty
var EnemyPorpertyLog:EnemyPorperty
var HERO

func _ready() -> void:
	WeaponPorpertyLog = preload("uid://cpjcvujytunnw")
	EnemyPorpertyLog = preload("uid://2srf8bdj186")
	HERO = preload("res://Scene/Hero/Hero.tscn").instantiate()
	add_child(HERO)
	
	LevelGenerator.prepare_generating()
	LevelGenerator.generate_level(0)
	
	#var TestMap = preload("res://Scene/Map/Home/Home.tscn").instantiate()
	#add_child(TestMap)
	
	#var Enemy1 = preload("res://Scene/Enemy/Enemy1.tscn").instantiate()
	#add_child(Enemy1)
#
	#var Enemy2 = preload("res://Scene/Enemy/Enemy2.tscn").instantiate()
	#add_child(Enemy2)

	#var PlayerStateUI = preload("uid://bd2erf76jvubl").instantiate()
	#add_child(PlayerStateUI)
	

func get_weapon_porperty(Name:String)->DamagePorperty:
	if WeaponPorpertyLog:
		if WeaponPorpertyLog.Weapon[Name]:
			return WeaponPorpertyLog.Weapon[Name]
	return null


func get_enemy_porperty(Name:String)->DamagePorperty:
	if EnemyPorpertyLog:
		if EnemyPorpertyLog.Enemy[Name]:
			return EnemyPorpertyLog.Enemy[Name]
	return null
