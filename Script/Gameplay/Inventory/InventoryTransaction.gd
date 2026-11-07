class_name InventoryTransaction
extends RefCounted
## 只负责两容器事务，不保存注册表或物品。所有矩阵写入仍委托 Service。

enum Operation { TRANSFER, SWAP, STACK, SPLIT }

## 同步协调服务 a、b 的跨容器转移、交换、堆叠或分割事务。
## 交换使用双方原锚点；still_registered() 在提交前确认参与者仍有效。
## quantity 仅用于分割，0 表示对半取整；成功 payload 包含通知、合并数量及分割目标实例。
## rotated=null 保留方向，否则仅设置将放入目标的实例方向，与位置和数量在同一事务中提交。
## 校验后复查版本并依次提交，提交失败恢复双方。
static func execute(a: InventoryService, b: InventoryService, a_pos: Vector2i,
		b_pos: Vector2i, operation: Operation, still_registered: Callable, quantity: int = 0, rotated: Variant = null) -> InventoryResult:
	var a_query := a.query(a_pos)
	if not a_query.is_ok():
		return a_query
	var b_query: InventoryResult
	if operation == Operation.SWAP or operation == Operation.STACK:
		b_query = b.query(b_pos)
		if not b_query.is_ok():
			return b_query
	var before_a := a.stage_snapshot()
	var before_b := b.stage_snapshot()
	var plan_a := InventoryContainer.copy_state(before_a)
	var plan_b := InventoryContainer.copy_state(before_b)
	var result: InventoryResult
	var moved_quantity: int = 0
	var split_item: ItemInstance = null
	var a_item: ItemInstance
	if operation == Operation.SPLIT:
		result = a.stage_split(plan_a, a_pos, quantity)
		if not result.is_ok():
			return result
		a_item = result.payload
	else:
		a_item = a.stage_remove(plan_a, a_query.payload.instance.instance_id)
	# 只改变将要放入目标的暂存实例；分割时源栈保留原方向。
	if rotated != null and operation != Operation.STACK:
		a_item.rotated = rotated
	if operation == Operation.SPLIT:
		result = b.stage_place_split(plan_b, a_item, b_pos)
		if result.is_ok():
			split_item = result.payload
	elif operation == Operation.STACK:
		result = b.stage_stack(plan_b, a_item, b_query.payload.anchor)
		if not result.is_ok():
			return result
		moved_quantity = result.payload
		a_item.quantity -= moved_quantity
		# 余量通过源服务重新放回原锚点；耗尽时保留已释放的源占位。
		if not a_item.is_empty():
			result = a.stage_add(plan_a, a_item, a_query.payload.anchor)
	elif operation == Operation.SWAP:
		var b_item := b.stage_remove(plan_b, b_query.payload.instance.instance_id)
		result = a.stage_add(plan_a, b_item, a_query.payload.anchor)
		if not result.is_ok():
			return result
		# 点击非锚点占位格也交换到原锚点。
		result = b.stage_add(plan_b, a_item, b_query.payload.anchor)
	else:
		result = b.stage_add(plan_b, a_item, b_pos)
	if not result.is_ok():
		return result
	for pair in [[a, plan_a], [b, plan_b]]:
		result = pair[0].validate_plan(pair[1])
		if not result.is_ok():
			return result
	if not still_registered.call() or a.container.revision != before_a.revision \
			or b.container.revision != before_b.revision:
		return InventoryResult.failure(InventoryResult.Code.STALE_STATE, "事务参与者或版本已经变化")
	# 同步提交期间没有 await 或通知，外部观察者只能看到全部成功后的状态。
	var a_commit := a.commit(plan_a)
	var b_commit: InventoryResult
	if a_commit.is_ok():
		b_commit = b.commit(plan_b)
	if not a_commit.is_ok() or b_commit == null or not b_commit.is_ok():
		# 直接恢复快照，不能通过普通 add 回滚（它可能再次触发规则失败）。
		a.restore(before_a)
		b.restore(before_b)
		return InventoryResult.failure(InventoryResult.Code.INTERNAL_ERROR, "跨容器提交失败，已恢复双方快照")
	var ids: Array[int] = a_commit.affected_ids.duplicate()
	for id in b_commit.affected_ids:
		if not ids.has(id):
			ids.append(id)
	return InventoryResult.success({"notifications": [
		{"id": a.container.container_id, "revision": a.container.revision, "ids": a_commit.affected_ids},
		{"id": b.container.container_id, "revision": b.container.revision, "ids": b_commit.affected_ids},
	], "moved_quantity": moved_quantity, "split_item": split_item}, ids, true)
