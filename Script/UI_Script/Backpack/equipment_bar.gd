extends Control
class_name equipment_bar

@onready var weapon_container: VBoxContainer = $VBoxContainer/WeaponSlot
@onready var relic_container: VBoxContainer = $VBoxContainer/RelicSlot


func _ready() -> void:
	#加载装备格子
	var max_weapon_contianer = EquipmentSlotSystem.get_weapon_max_contianer()
	var equipment_slot = load("uid://5fpsr5w83lwa")
	
	for i in range(0, max_weapon_contianer):
		weapon_container.add_child(equipment_slot.instantiate())
		
	var max_relic_contianer = EquipmentSlotSystem.get_relic_max_contianer()
	for i in range(0, max_relic_contianer):
		relic_container.add_child(equipment_slot.instantiate())
