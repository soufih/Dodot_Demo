class_name WarehouseService
extends GridService
## 仓库复用网格背包的全部规则，仅增加保留实例、数量和方向的手动整理。

## 按面积降序、主类型、配置 ID、实例 ID 排序并在暂存计划中重新摆放。
## 全部摆放成功才提交一次；装箱失败或提交失败时保留原布局，不合并或分割物品。
func organize() -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var staged := stage_snapshot()
	var result := validate_plan(staged)
	if not result.is_ok():
		return result
	var records: Array = staged.items.values()
	records.sort_custom(_comes_before)
	staged.items.clear()
	for row in staged.cells:
		row.fill(null)
	for record: Dictionary in records:
		result = _stage_first_fit(staged, record.instance)
		if not result.is_ok():
			if result.code == InventoryResult.Code.NO_SPACE:
				return InventoryResult.failure(result.code, "整理未能容纳全部物品，已保留原布局")
			return result
	return _commit_local(staged)

## 使用稳定的完整排序键，相同配置的多个实例也不会因字典遍历顺序反复换位。
func _comes_before(a: Dictionary, b: Dictionary) -> bool:
	var left: ItemInstance = a.instance
	var right: ItemInstance = b.instance
	var left_config: ItemConfig = _config_lookup.call(left.config_id)
	var right_config: ItemConfig = _config_lookup.call(right.config_id)
	var left_area := left_config.GridSize.x * left_config.GridSize.y
	var right_area := right_config.GridSize.x * right_config.GridSize.y
	if left_area != right_area:
		return left_area > right_area
	if left_config.MainItemType != right_config.MainItemType:
		return left_config.MainItemType < right_config.MainItemType
	if left.config_id != right.config_id:
		return left.config_id < right.config_id
	return left.instance_id < right.instance_id
