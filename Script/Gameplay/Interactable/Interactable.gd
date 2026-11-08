class_name Interactable
extends Area2D


@export var interaction_name := "交互"
## 一次性交互默认隐藏提示；可重试的拾取区域在场景中关闭此选项。
@export var dismiss_prompt_after_interact: bool = true


func can_interact(actor: Node) -> bool:
	return true


func interact(actor: Node) -> void:
	pass


func get_interaction_text() -> String:
	return interaction_name
