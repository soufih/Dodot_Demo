class_name Interactable
extends Area2D


@export var interaction_name := "交互"


func can_interact(actor: Node) -> bool:
	return true


func interact(actor: Node) -> void:
	pass


func get_interaction_text() -> String:
	return interaction_name
