extends PanelContainer

@onready var VBox_Container = $VBoxContainer/MarginContainer/ScrollContainer/slot_VB

func _ready() -> void:
	var max_container = 10   #测试
	var warehouse_slot :PackedScene = load("uid://bmtyh6pxk6pjt")
	#print(typeof(warehouse_slot)
	for i in max_container:
		var warehouse_slot_instance = warehouse_slot.instantiate()
		VBox_Container.add_child(warehouse_slot_instance)
		

#func _init() -> void:
	#var max_container = 10   #测试
	#for i in max_container:
		#var item = WarehouseSystem.get_warehouse()
		#var item_id = WarehouseSystem.
		#var item_count = WarehouseSystem.get_item_count(item_id)
		#WarehouseSystem.add_item_to_warehouse(item_id,item_count)
		

func add_item_to_warehouse(warehouse: Dictionary[int,int] , position: int):
	pass
	

func remove_item_from_warehouse(warehouse: Dictionary[int,int] , position: int):
	pass
