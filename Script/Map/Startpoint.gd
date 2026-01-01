extends Node2D

func _ready() -> void:
	var hero = load("res://Scene/Hero/Hero.tscn").instantiate()
	DataLoader.set_hero(hero)
	add_child(hero)
