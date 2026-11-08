extends Node
## 仓库合成入口；不持有库存、不扫描背包，只接受一个明确的仓库 ID。

const WAREHOUSE_SERVICE = preload("res://Script/Gameplay/Inventory/Services/WarehouseService.gd")
const DEFAULT_CATALOG = preload("res://Rescource/Data/Crafting/catalog.tres")
@export var inventory_manager: Node
var _recipes: Dictionary = {}
var _service: CraftingService
var _lookup: Callable

func _ready() -> void:
	if inventory_manager == null:
		inventory_manager = InventoryManager
	var result := configure(DEFAULT_CATALOG, ResourceManager.get_item_config)
	if not result.is_ok():
		push_error(result.message)

## 校验完整目录后替换，失败保留旧目录；复制资源，防止调用方修改共享配方。
func configure(catalog: CraftingCatalog, lookup: Callable) -> InventoryResult:
	if catalog == null:
		return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "未提供配方目录")
	var result := catalog.validate(lookup)
	if not result.is_ok():
		return result
	var indexed: Dictionary = {}
	for recipe in catalog.recipes:
		indexed[recipe.recipe_id] = recipe.duplicate(true)
	_recipes = indexed
	_lookup = lookup
	_service = CraftingService.new(lookup)
	return InventoryResult.success()

func list_recipes(type: ENUM.ItemType = ENUM.ItemType.None) -> Array[CraftingRecipe]:
	var result: Array[CraftingRecipe] = []
	for recipe: CraftingRecipe in _recipes.values():
		if type != ENUM.ItemType.None:
			var matches := false
			for id: int in recipe.outputs:
				var config: ItemConfig = _lookup.call(id)
				matches = matches or config.MainItemType == type
			if not matches:
				continue
		result.append(recipe.duplicate(true))
	return result

func preview(warehouse_id: String, recipe_id: StringName, times: int = 1) -> InventoryResult:
	if not _recipes.has(recipe_id):
		return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "配方不存在")
	return inventory_manager.query_container_service(warehouse_id, WAREHOUSE_SERVICE,
		func(warehouse: WarehouseService) -> InventoryResult:
			var result := _service.plan(warehouse, _recipes[recipe_id], times)
			if result.is_ok():
				result.payload.erase("plan")
			return result)

func craft(warehouse_id: String, recipe_id: StringName, times: int = 1) -> InventoryResult:
	if not _recipes.has(recipe_id):
		return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "配方不存在")
	return inventory_manager.execute_container_operation(warehouse_id, WAREHOUSE_SERVICE,
		func(warehouse: WarehouseService) -> InventoryResult:
			return _service.craft(warehouse, _recipes[recipe_id], times))
