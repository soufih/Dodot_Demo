extends Node2D

signal interact

func _ready() -> void:
	interact.connect(do)

func do():
	print(2)
