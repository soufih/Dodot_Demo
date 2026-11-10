class_name CraftingService
extends RefCounted
## 无库存副本；仅规划指定仓库，扣料与产出写入同一暂存状态。

const MAX_BATCH: int = 999
const MAX_INT: int = 9223372036854775807
var _lookup: Callable

func _init(lookup: Callable) -> void:
	_lookup = lookup

## preview=true 时仅使用临时 ID，连真实实例 ID 分配器也不改变。
func plan(service: WarehouseService, recipe: CraftingRecipe, times: int, preview: bool = true) -> InventoryResult:
	if times <= 0 or times > MAX_BATCH:
		return InventoryResult.failure(InventoryResult.Code.INVALID_QUANTITY, "合成次数必须为 1～%d" % MAX_BATCH)
	var checked := recipe.validate(_lookup)
	if not checked.is_ok():
		return checked
	for amounts: Dictionary in [recipe.inputs, recipe.outputs]:
		for quantity: int in amounts.values():
			if quantity > MAX_INT / times:
				return InventoryResult.failure(InventoryResult.Code.INVALID_QUANTITY, "合成数量超出范围")
	var staged := service.stage_snapshot()
	checked = service.validate_plan(staged)
	if not checked.is_ok():
		return checked
	var counts: Dictionary = service.get_item_counts().payload
	var materials: Array[Dictionary] = []
	var limit := MAX_BATCH
	var missing := false
	for id: int in recipe.inputs:
		var owned: int = counts.get(id, 0)
		var required: int = recipe.inputs[id] * times
		limit = mini(limit, owned / recipe.inputs[id])
		missing = missing or owned < required
		materials.append({"config_id": id, "owned": owned, "required": required, "missing": maxi(0, required - owned)})
	var products: Dictionary[int, int] = {}
	for id: int in recipe.outputs:
		products[id] = recipe.outputs[id] * times
	var details := {"recipe_id": recipe.recipe_id, "times": times, "warehouse_id": staged.container_id,
		"revision": staged.revision, "materials": materials, "outputs": products,
		"material_limit": limit, "can_craft": false, "blocking_code": InventoryResult.Code.OK, "reason": ""}
	if missing:
		return _blocked(details, InventoryResult.Code.MATERIALS_MISSING, "仓库材料不足")
	# 按实例 ID 稳定扣除，部分消耗保留原身份，耗尽才释放占位。
	var ids: Array = staged.items.keys()
	ids.sort()
	for config_id: int in recipe.inputs:
		var remaining: int = recipe.inputs[config_id] * times
		for id: int in ids:
			if remaining == 0:
				break
			if not staged.items.has(id):
				continue
			var item: ItemInstance = staged.items[id].instance
			if item.config_id != config_id:
				continue
			var consumed := mini(remaining, item.quantity)
			remaining -= consumed
			if consumed == item.quantity:
				service.stage_remove(staged, id)
			else:
				item.quantity -= consumed
	var output_ids: Array = products.keys()
	output_ids.sort()
	for config_id: int in output_ids:
		checked = _place_output(service, staged, config_id, products[config_id], preview)
		if not checked.is_ok():
			return _blocked(details, checked.code, checked.message)
	checked = service.validate_plan(staged)
	if not checked.is_ok():
		return checked
	details.can_craft = true
	details["plan"] = staged
	return InventoryResult.success(details)

## 由 InventoryManager 在事务锁内调用；提交故障恢复快照，版本冲突保留外部新状态。
func craft(service: WarehouseService, recipe: CraftingRecipe, times: int) -> InventoryResult:
	var before := service.stage_snapshot()
	var planned := plan(service, recipe, times, false)
	if not planned.is_ok():
		return planned
	var details: Dictionary = planned.payload
	if not details.can_craft:
		return InventoryResult.failure(details.blocking_code, details.reason)
	var committed := service.commit(details.plan)
	if not committed.is_ok():
		if committed.code != InventoryResult.Code.STALE_STATE:
			service.restore(before)
		return committed
	details.erase("plan")
	details.revision = service.container.revision
	committed.payload = details
	return committed

func _blocked(details: Dictionary, code: InventoryResult.Code, reason: String) -> InventoryResult:
	details.blocking_code = code
	details.reason = reason
	return InventoryResult.success(details)

func _temporary_item(staged: Dictionary, config_id: int, quantity: int) -> ItemInstance:
	var id := 1
	for existing: int in staged.items:
		id = maxi(id, existing + 1)
	return ItemInstance.new(config_id, quantity, false, id, false)

func _place_output(service: WarehouseService, staged: Dictionary, config_id: int, quantity: int, preview: bool) -> InventoryResult:
	var config: ItemConfig = _lookup.call(config_id)
	var remaining := quantity
	var ids: Array = staged.items.keys()
	ids.sort()
	for id: int in ids:
		if remaining == 0:
			break
		var record: Dictionary = staged.items[id]
		var target: ItemInstance = record.instance
		if target.config_id != config_id or target.quantity >= config.MaxStack:
			continue
		var donor := _temporary_item(staged, config_id, mini(remaining, config.MaxStack))
		var stacked := service.stage_stack(staged, donor, record.anchor)
		if not stacked.is_ok():
			return stacked
		remaining -= stacked.payload
	while remaining > 0:
		var amount := mini(remaining, config.MaxStack)
		var item := _temporary_item(staged, config_id, amount) if preview else ItemInstance.new(config_id, amount)
		var placed := service.stage_quick_add(staged, item)
		if not placed.is_ok():
			return placed
		remaining -= amount
	return InventoryResult.success()
