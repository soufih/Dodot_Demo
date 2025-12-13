extends Node

var Warehouse:Dictionary[int,int] = {} #物品ID-数量


##获取仓库
func get_warehouse() ->Dictionary[int,int]:
	return Warehouse

##获取仓库中物品数量
func get_item_count(id: int) ->int:
	if Warehouse.has(id):
		return Warehouse[id]
	
	return 0

##修改仓库中物品数量
func modify_item_count(id: int, count: int) ->void:
	if Warehouse.has(id):
		Warehouse[id] += count
	else:
		Warehouse[id] = count

##添加物品到仓库
func add_item_to_warehouse(id: int, count: int) ->void:
	if Warehouse.has(id):
		Warehouse[id] += count
	else:
		Warehouse[id] = count

##移出物品从仓库
func remove_item_from_warehouse(id: int, count: int) ->void:
	if Warehouse.has(id):
		Warehouse[id] -= count
		if Warehouse[id] <= 0:
			Warehouse.erase(id)
