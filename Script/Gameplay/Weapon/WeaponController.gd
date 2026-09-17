extends Node2D

@onready var InputControlller = $"../InputController"
@onready var Ani = $WeaponAnimations


func _on_hero_on_attack() -> void:
	Ani.play("AttackSword")
