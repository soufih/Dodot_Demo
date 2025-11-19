extends Control

class_name Bag


@onready var grid_container = $PanelContainer/VBoxContainer/HBoxContainer/Item_Bag/ScrollContainer/GridContainer
@onready var weapon_container: HBoxContainer = $PanelContainer/VBoxContainer/HBoxContainer/Equipment_Bag/VBoxContainer/Weapon_Container
@onready var relic_container: HBoxContainer = $PanelContainer/VBoxContainer/HBoxContainer/Equipment_Bag/VBoxContainer/Relic_Container


func _ready() -> void:
	#加载物品格子
	var max_contianer = BackpackSystem.get_max_contianer()
	var slot = load("uid://6oby8ergpaw7")
	for i in range(0, max_contianer):
		grid_container.add_child(slot.instantiate())
	var max_weapon_contianer = EquipmentSlotSystem.get_weapon_current_contianer()
	for i in range(0, max_weapon_contianer):
		weapon_container.add_child(slot.instantiate())
	var max_relic_contianer = EquipmentSlotSystem.get_weapon_max_contianer()
	for i in range(0, max_relic_contianer):
		relic_container.add_child(slot.instantiate())
