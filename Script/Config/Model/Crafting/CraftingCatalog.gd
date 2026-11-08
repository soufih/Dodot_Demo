class_name CraftingCatalog
extends Resource

@export var recipes: Array[CraftingRecipe] = []

func validate(lookup: Callable) -> InventoryResult:
	if not lookup.is_valid():
		return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "物品配置查询无效")
	var ids: Dictionary = {}
	for recipe in recipes:
		if recipe == null:
			return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "配方目录包含空资源")
		var result := recipe.validate(lookup)
		if not result.is_ok():
			return result
		if ids.has(recipe.recipe_id):
			return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "配方标识重复：%s" % recipe.recipe_id)
		ids[recipe.recipe_id] = true
	return InventoryResult.success()
