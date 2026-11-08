class_name CraftingRecipe
extends Resource
## 配方独立于物品；同一产物可拥有多份配方，数量均表示执行一次的数量。

@export var recipe_id: StringName
@export var inputs: Dictionary[int, int] = {}
@export var outputs: Dictionary[int, int] = {}

func validate(lookup: Callable) -> InventoryResult:
	if recipe_id.is_empty() or inputs.is_empty() or outputs.is_empty() or not lookup.is_valid():
		return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "配方标识、材料和产物不能为空")
	for amounts: Dictionary in [inputs, outputs]:
		for id: int in amounts:
			var config: ItemConfig = lookup.call(id)
			if amounts[id] <= 0 or config == null or config.ItemID != id or not config.validate():
				return InventoryResult.failure(InventoryResult.Code.INVALID_RECIPE, "配方 %s 的物品或数量无效：%d" % [recipe_id, id])
	return InventoryResult.success()
