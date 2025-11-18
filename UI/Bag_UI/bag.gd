extends Control

class_name Bag


@onready var grid_container = $PanelContainer/VBoxContainer/HBoxContainer/Item_Bag/ScrollContainer/GridContainer


func _ready() -> void:
	#加载物品格子
	var max_contianer = BackpackSystem.get_max_contianer()
	var slot = load("uid://6oby8ergpaw7")
	for i in range(0, max_contianer):
		grid_container.add_child(slot.instantiate())
