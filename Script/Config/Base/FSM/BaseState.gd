class_name BaseState
extends Node

@export var Entity:BaseCharacter
@export var AniPlayer:AnimationPlayer
@export var _InputController:InputController
@export var NextStates:Dictionary[String,Node]
@export var BufferedStates:Array[Node]

func enter():
	pass
	
func do(_delta: float):
	pass
	
func exit():
	pass
