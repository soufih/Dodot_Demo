extends Node

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var WeaponPorpertyLog:WeaponPorperty
var EnemyPorpertyLog:EnemyPorperty

func _ready() -> void:
	WeaponPorpertyLog = preload("uid://cpjcvujytunnw")
	EnemyPorpertyLog = preload("uid://2srf8bdj186")
	
	var TestMap = preload("res://Scene/Map/Home/Home.tscn").instantiate()
	var Hero = preload("res://Scene/Hero/Hero.tscn").instantiate()
	var Enemy1 = preload("res://Scene/Enemy/Enemy1.tscn").instantiate()
	var Enemy2 = preload("res://Scene/Enemy/Enemy2.tscn").instantiate()
	add_child(TestMap)
	add_child(Hero)
	self.add_child(Enemy1)
	self.add_child(Enemy2)
	
	LevelGenerator.prepare_generating()


#func _physics_process(delta: float) -> void:
	#for i in get_children(): #对在“Chr”组中的对象施加重力
		#if i.is_in_group("Chr"):
			#i.velocity.y += gravity*delta
			#i.move_and_slide()


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
