class_name SlotService
extends InventoryService
## 普通背包的具体实现：每实例占一格，负责自身查询、操作及栏位规则。

const StateOps = preload("res://Script/Gameplay/Inventory/InventoryStateOps.gd")

## 注入 config_lookup(config_id) -> ItemConfig，只保存配置查询依赖，不创建容器。
func _init(config_lookup: Callable = Callable()) -> void:
	_config_lookup = config_lookup

## 以 id 和正数宽高 size 创建并独占绑定空容器。
## 成功返回 OK；重复初始化或参数非法时返回错误，已有绑定不变。
func initialize(id: String, size: Vector2i) -> InventoryResult:
	if container != null:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "容器已经初始化")
	if id.strip_edges().is_empty():
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "容器 ID 不能为空")
	if size.x <= 0 or size.y <= 0:
		return InventoryResult.failure(InventoryResult.Code.INVALID_POSITION, "容器尺寸必须为正数")
	container = InventoryContainer.new(id, size)
	return InventoryResult.success()

## 查询 pos 的实例及锚点，成功时 payload 为 {instance, anchor} 隔离副本。
## 空格返回 ITEM_NOT_FOUND，非法坐标或未初始化返回对应错误。
func query(pos: Vector2i) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var result := StateOps.validate_position(pos, container.size)
	if not result.is_ok():
		return result
	var id: Variant = container.get_cell(pos)
	if id == null:
		return InventoryResult.failure(InventoryResult.Code.ITEM_NOT_FOUND, "该位置没有物品")
	var record: Dictionary = container.get_item(id)
	return InventoryResult.success({"instance": record.instance.copy(), "anchor": record.anchor})

## 只读校验 item 能否以 pos 为锚点添加，返回规则校验结果，不提交任何状态。
func validate_add(item: ItemInstance, pos: Vector2i) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	return _validate_placement(stage_snapshot(), item, pos)

## 在暂存副本中添加完整 item，通过全部校验后提交；成功只增加一次版本。
## 保存输入实例的副本，失败时不改变真实容器。
func add(item: ItemInstance, pos: Vector2i) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var staged := stage_snapshot()
	var result := stage_add(staged, item, pos)
	return _commit_local(staged) if result.is_ok() else result

## 优先补满同类物品堆，余量放入首个空格；完整接收后一次提交，失败不保留部分堆叠。
## 返回余量新堆的锚点，完全合并时返回首个补堆锚点，输入实例保持不变。
func quick_add(item: ItemInstance) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var staged := stage_snapshot()
	var placed := stage_quick_add(staged, item)
	if not placed.is_ok():
		return placed
	var result := _commit_local(staged)
	if result.is_ok():
		result.payload = placed.payload
	return result

## 在暂存状态中完整规划补堆和余量位置；失败不修改传入计划，不提交或分配实例 ID。
func stage_quick_add(staged: Dictionary, item: ItemInstance) -> InventoryResult:
	var checked := StateOps.validate_item(item, _config_lookup)
	if not checked.is_ok():
		return checked
	if staged.items.has(item.instance_id):
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "实例已经属于此容器")
	var config: ItemConfig = _config_lookup.call(item.config_id)
	var plan := StateOps.plan_stack_fill(staged, item, config.MaxStack)
	var remaining: ItemInstance = plan.remaining
	var placed := InventoryResult.success(plan.anchor)
	if remaining.quantity > 0:
		placed = _stage_first_fit(staged, remaining)
	if placed.is_ok():
		StateOps.apply_stack_fill(staged, plan)
	return placed

## 按行寻找并写入第一个空格；失败候选不改变暂存状态。
func _stage_first_fit(staged: Dictionary, item: ItemInstance) -> InventoryResult:
	for y in range(staged.size.y):
		for x in range(staged.size.x):
			var pos := Vector2i(x, y)
			var result := stage_add(staged, item, pos)
			if result.is_ok():
				result.payload = pos
				return result
			if result.code != InventoryResult.Code.OCCUPIED and result.code != InventoryResult.Code.OUT_OF_BOUNDS:
				return result
	return InventoryResult.failure(InventoryResult.Code.NO_SPACE, "背包中没有可容纳完整物品的位置")

## 移除 pos 对应实例的记录及全部占位，提交成功后通过 payload 返回脱离的实例。
func remove(pos: Vector2i) -> InventoryResult:
	var found := query(pos)
	if not found.is_ok():
		return found
	var staged := stage_snapshot()
	var item: ItemInstance = stage_remove(staged, found.payload.instance.instance_id)
	var result := _commit_local(staged)
	if result.is_ok():
		result.payload = item
	return result

## 将 from_pos 对应实例移动到以 to_pos 为锚点的位置，目标占用时失败。
## 原地且方向不变时返回 changed=false；rotated 指定新方向时与移动在同次提交中完成。
func move(from_pos: Vector2i, to_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	var found := query(from_pos)
	if not found.is_ok():
		return found
	if from_pos == to_pos or found.payload.anchor == to_pos:
		return rotate(from_pos, rotated) if rotated != null else InventoryResult.success()
	var staged := stage_snapshot()
	var item := stage_remove(staged, found.payload.instance.instance_id)
	if rotated != null:
		item.rotated = rotated
	var result := stage_add(staged, item, to_pos)
	return _commit_local(staged) if result.is_ok() else result

## 交换 a_pos、b_pos 对应实例的原锚点，两端都必须有物品。
## 同一实例且方向不变时无变化；rotated 只应用于 a，完整最终状态校验失败时不提交。
func swap(a_pos: Vector2i, b_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	var a := query(a_pos)
	if not a.is_ok():
		return a
	var b := query(b_pos)
	if not b.is_ok():
		return b
	if a.payload.instance.instance_id == b.payload.instance.instance_id:
		return rotate(a_pos, rotated) if rotated != null else InventoryResult.success()
	var staged := stage_snapshot()
	var a_item := stage_remove(staged, a.payload.instance.instance_id)
	var b_item := stage_remove(staged, b.payload.instance.instance_id)
	if rotated != null:
		a_item.rotated = rotated
	var result := stage_add(staged, a_item, b.payload.anchor)
	if result.is_ok():
		result = stage_add(staged, b_item, a.payload.anchor)
	return _commit_local(staged) if result.is_ok() else result

## 将 pos 对应实例的方向设为 rotated；普通背包只改变元数据，占用始终为单格。
## 方向不变时不提交，失败时保留原状态。
func rotate(pos: Vector2i, rotated: bool) -> InventoryResult:
	var found := query(pos)
	if not found.is_ok():
		return found
	if found.payload.instance.rotated == rotated:
		return InventoryResult.success()
	var staged := stage_snapshot()
	var item := stage_remove(staged, found.payload.instance.instance_id)
	item.rotated = rotated
	var result := stage_add(staged, item, found.payload.anchor)
	return _commit_local(staged) if result.is_ok() else result

## 按 rotated 方向只读预览 item 放在 pos 的结果；已有实例先在副本中释放旧占位。
## 不修改输入实例、真实占位或版本，返回放置规则的校验结果。
func can_place(item: ItemInstance, pos: Vector2i, rotated: bool) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	if item == null:
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "物品不能为空")
	var staged := stage_snapshot()
	if staged.items.has(item.instance_id):
		stage_remove(staged, item.instance_id)
	var preview := item.copy()
	preview.rotated = rotated
	return _validate_placement(staged, preview, pos)

## 将源栈尽量合并到目标同配置栈；剩余数量仍位于原锚点，耗尽时释放全部源占位。
## 单次提交同时更新两栈，payload 为合并数量；同一实例返回 0 且不增加版本。
func stack(from_pos: Vector2i, to_pos: Vector2i) -> InventoryResult:
	var source := query(from_pos)
	if not source.is_ok():
		return source
	var target := query(to_pos)
	if not target.is_ok():
		return target
	if source.payload.instance.instance_id == target.payload.instance.instance_id:
		return InventoryResult.success(0)
	var staged := stage_snapshot()
	var item := stage_remove(staged, source.payload.instance.instance_id)
	var merged := stage_stack(staged, item, target.payload.anchor)
	if not merged.is_ok():
		return merged
	item.quantity -= merged.payload
	if not item.is_empty():
		var added := stage_add(staged, item, source.payload.anchor)
		if not added.is_ok():
			return added
	var result := _commit_local(staged)
	if result.is_ok():
		result.payload = merged.payload
	return result

## 只读查询目标并计算 item 可合并的数量；不改变原实例、容器或版本。
func can_stack(item: ItemInstance, pos: Vector2i) -> InventoryResult:
	var target := query(pos)
	if not target.is_ok():
		return target
	return StateOps.validate_stack(item, target.payload.instance, _config_lookup)

## 只读预览源栈可分割的数量，默认对半取整，单件不可分割。
func can_split(pos: Vector2i, quantity: int = 0) -> InventoryResult:
	var source := query(pos)
	if not source.is_ok():
		return source
	return StateOps.validate_split(source.payload.instance, quantity, _config_lookup)

## 在同一暂存计划中扣减源数量并放置新栈，全部合法后一次提交。
## 目标为同类栈时必须完整接收分割数量；rotated 只应用于新栈，成功 payload 为目标实例副本。
func split(from_pos: Vector2i, to_pos: Vector2i, quantity: int = 0, rotated: Variant = null) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var staged := stage_snapshot()
	var detached := stage_split(staged, from_pos, quantity)
	if not detached.is_ok():
		return detached
	if rotated != null:
		detached.payload.rotated = rotated
	var placed := stage_place_split(staged, detached.payload, to_pos)
	if not placed.is_ok():
		return placed
	var result := _commit_local(staged)
	if result.is_ok():
		result.payload = placed.payload
	return result

## 返回完整深复制暂存状态，矩阵行和实例字段均隔离；调用前须已初始化。
func stage_snapshot() -> Dictionary:
	return container.snapshot()

## 校验后仅在 staged 中添加 item 的副本，以 pos 为锚点占一格。
## 同步更新物品记录与单格占位，不提交真实状态或递增版本。
func stage_add(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult:
	var result := _validate_placement(staged, item, pos)
	if not result.is_ok():
		return result
	var owned := item.copy()
	staged.items[owned.instance_id] = {"instance": owned, "anchor": pos}
	staged.cells[pos.y][pos.x] = owned.instance_id
	return InventoryResult.success()

## 仅从 staged 清除 id 的全部占位和记录，返回移出的暂存实例。
## 内部接口；调用方须保证 id 存在。
func stage_remove(staged: Dictionary, id: int) -> ItemInstance:
	return StateOps.remove(staged, id)

## 在暂存状态中向 pos 所属的目标栈增加数量，保留其身份、方向、锚点及全部占位。
## 输入 item 不变；返回接收数量，调用方负责从源计划扣除，不直接提交真实状态。
func stage_stack(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult:
	var position_result := StateOps.validate_position(pos, staged.size)
	if not position_result.is_ok():
		return position_result
	var id: Variant = staged.cells[pos.y][pos.x]
	if id == null:
		return InventoryResult.failure(InventoryResult.Code.ITEM_NOT_FOUND, "目标位置没有物品")
	var target: ItemInstance = staged.items[id].instance
	var result := StateOps.validate_stack(item, target, _config_lookup)
	if result.is_ok():
		target.quantity += result.payload
	return result

## 仅从暂存源栈分出数量，创建独立 ID；源占位、方向、锚点和原 ID 不变。
func stage_split(staged: Dictionary, pos: Vector2i, quantity: int = 0) -> InventoryResult:
	var checked := StateOps.validate_position(pos, staged.size)
	if not checked.is_ok():
		return checked
	var id: Variant = staged.cells[pos.y][pos.x]
	if id == null:
		return InventoryResult.failure(InventoryResult.Code.ITEM_NOT_FOUND, "源位置没有物品")
	var source: ItemInstance = staged.items[id].instance
	checked = StateOps.validate_split(source, quantity, _config_lookup)
	if not checked.is_ok():
		return checked
	var detached := ItemInstance.new(source.config_id, checked.payload, source.rotated)
	source.quantity -= checked.payload
	return InventoryResult.success(detached)

## 完整接收分割栈：空位遵守本服务占位规则，同类目标须有足够容量。
## 失败时不改暂存目标，成功返回实际目标的隔离实例，供 UI 更新选择。
func stage_place_split(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult:
	var checked := StateOps.validate_position(pos, staged.size)
	if not checked.is_ok():
		return checked
	var id: Variant = staged.cells[pos.y][pos.x]
	if id == null:
		checked = stage_add(staged, item, pos)
		if checked.is_ok():
			checked.payload = item.copy()
		return checked
	var target: ItemInstance = staged.items[id].instance
	checked = StateOps.validate_stack(item, target, _config_lookup)
	if not checked.is_ok():
		return checked
	if checked.payload != item.quantity:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "目标容量不足以接收完整分割数量")
	target.quantity += item.quantity
	return InventoryResult.success(target.copy())

## 使用本服务的添加规则重建占位，返回 staged 的完整一致性校验结果，不修改真实状态。
func validate_plan(staged: Dictionary) -> InventoryResult:
	return StateOps.validate_plan(container, staged, stage_add)

## 使用本服务的计划校验函数同步提交 staged，实际变化时仅增加一次版本。
## 过期计划返回 STALE_STATE；不 await、不发送外部通知。
func commit(staged: Dictionary) -> InventoryResult:
	return StateOps.commit(container, staged, validate_plan)

## 直接复制恢复本容器事务前的 snapshot，包含实例、占位及原版本，返回 OK。
## 仅供内部回滚，不再次执行普通添加规则。
func restore(snapshot: Dictionary) -> InventoryResult:
	StateOps.apply_state(container, snapshot)
	return InventoryResult.success()

## 保存提交前快照后调用可覆写的 commit，非版本冲突失败时直接恢复快照。
## STALE_STATE 保留外部已产生的新版本，避免回滚覆盖新状态。
func _commit_local(staged: Dictionary) -> InventoryResult:
	var before := stage_snapshot()
	var result := commit(staged)
	if not result.is_ok() and result.code != InventoryResult.Code.STALE_STATE:
		restore(before)
	return result

## 只读检查 staged 中的实例、坐标、重复 ID 和目标单格占用，忽略网格尺寸与方向。
func _validate_placement(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult:
	var result := StateOps.validate_item(item, _config_lookup)
	if not result.is_ok():
		return result
	result = StateOps.validate_position(pos, staged.size)
	if not result.is_ok():
		return result
	if staged.items.has(item.instance_id):
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "实例已经属于此容器")
	if staged.cells[pos.y][pos.x] != null:
		return InventoryResult.failure(InventoryResult.Code.OCCUPIED, "目标栏位已经被占用")
	return InventoryResult.success()
