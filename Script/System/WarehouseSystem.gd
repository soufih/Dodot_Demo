extends Node

var Warehouse:Array[Dictionary] #物品ID-数量

func _ready() -> void:
	Warehouse.append({
		"id":1,
		"amount": 100
	})
	Warehouse.append({
		"id":2,
		"amount": 100
	})

##获取仓库
func get_warehouse() ->Array[Dictionary]:
	return Warehouse

##获取仓库中物品数量
func get_item_count(id: int) ->int:
	if !ResourceManager.get_item_config(id):
		return -1

	for item in Warehouse:
		if item.id == id:
			return item.amount
	
	return 0


##修改仓库中物品数量
func modify_item_count(id: int, count: int) ->bool:
	if !ResourceManager.get_item_config(id):
		return false

	for item in Warehouse:
		if item.id == id:
			item.amount += count
			return true

	return false

##添加物品到仓库
func add_item_to_warehouse(id: int, count: int) ->bool:
	if !ResourceManager.get_item_config(id):
		return false

	if !modify_item_count(id, count):
		Warehouse.append({
			"id": id,
			"amount": count
		})
	return true

##移出物品从仓库
func remove_item_from_warehouse(id: int, count: int) ->bool:
	if !ResourceManager.get_item_config(id):
		return false

	if modify_item_count(id, count):
		if get_item_count(id) <= 0:
			Warehouse.erase({
				"id": id,
				"amount": get_item_count(id)
			})
			return true
	
	return false
