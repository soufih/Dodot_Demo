extends RefCounted
class_name CompondSystem

##查询产物
func query_product(id: int) ->Array[int]:
	var products:Array[int] = ResourceManager.get_item_products(id)
	return products

##查询配方
func query_recipe(id: int) ->Array[int]:
	var recipe:Array[int] = ResourceManager.get_item_recipe(id)
	return recipe

##合成物品
func compound(id: int) ->bool:
	#获取配方
	var recipe:Array[int] = query_recipe(id)

	if recipe.size() == 0:  #没有配方
		return false

	#检查材料是否足够
	for item_id in recipe:
		if WarehouseSystem.get_item_count(item_id) <= 0:
			return false

	#扣除材料
	for item_id in recipe:
		WarehouseSystem.modify_item_count(item_id, -1)

	return true
