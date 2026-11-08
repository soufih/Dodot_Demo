class_name EquipmentSlotService
extends InventoryService
## 装备栏的具体服务：每槽一件装备，管理类型适配、槽位互斥及事务状态。
## 槽位用 N × 1 矩阵兼容现有事务，UI 与角色效果不参与服务逻辑。

const StateOps = preload("res://Script/Gameplay/Inventory/InventoryStateOps.gd")

var _slots: Array[EquipmentSlotDefinition] = []
var _slot_indices: Dictionary[StringName, int] = {}
var _quick_positions: Array[Vector2i] = []

## 注入物品查询和槽位配置，复制配置以隔离调用方后续修改；不创建运行期容器。
func _init(config_lookup: Callable = Callable(), slots: Array[EquipmentSlotDefinition] = []) -> void:
	_config_lookup = config_lookup
	for slot in slots:
		_slots.append(slot.duplicate(true) if slot != null else null)

## 校验槽位标识与 N × 1 尺寸后初始化；失败不绑定容器，禁止重复初始化。
func initialize(id: String, size: Vector2i) -> InventoryResult:
	if container != null:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "容器已经初始化")
	if id.strip_edges().is_empty():
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "容器 ID 不能为空")
	if _slots.is_empty() or size != Vector2i(_slots.size(), 1):
		return InventoryResult.failure(InventoryResult.Code.INVALID_POSITION, "装备栏尺寸必须为槽位数量 × 1")
	var indices: Dictionary[StringName, int] = {}
	var positions: Array[Vector2i] = []
	for index in range(_slots.size()):
		var slot := _slots[index]
		if slot == null or not slot.validate() or indices.has(slot.slot_id):
			return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "装备槽配置无效或标识重复")
		indices[slot.slot_id] = index
		positions.append(Vector2i(index, 0))
	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var left := _slots[a.x].auto_equip_priority
		var right := _slots[b.x].auto_equip_priority
		return a.x < b.x if left == right else left < right)
	_slot_indices = indices
	_quick_positions = positions
	container = InventoryContainer.new(id, size)
	return InventoryResult.success()

## 将稳定的业务槽位标识转换为内部坐标；未知标识明确失败，避免误用第一个槽位。
func get_slot_position(slot_id: StringName) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	if not _slot_indices.has(slot_id):
		return InventoryResult.failure(InventoryResult.Code.INVALID_POSITION, "不存在此装备槽")
	return InventoryResult.success(Vector2i(_slot_indices[slot_id], 0))

## 返回坐标对应的槽位标识，供业务与 UI 使用，不暴露可变配置。
func get_slot_id(pos: Vector2i) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var result := StateOps.validate_position(pos, container.size)
	return InventoryResult.success(_slots[pos.x].slot_id) if result.is_ok() else result

## 查询单个槽位，返回包含实例副本及锚点的记录；空槽和越界明确失败。
func query(pos: Vector2i) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var result := StateOps.validate_position(pos, container.size)
	if not result.is_ok():
		return result
	var id: Variant = container.get_cell(pos)
	if id == null:
		return InventoryResult.failure(InventoryResult.Code.ITEM_NOT_FOUND, "装备槽为空")
	var record := container.get_item(id)
	return InventoryResult.success({"instance": record.instance.copy(), "anchor": record.anchor})

## 只读校验空槽添加规则，不修改实例、矩阵或版本。
func validate_add(item: ItemInstance, pos: Vector2i) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	return _validate_placement(stage_snapshot(), item, pos)

## 预览放置时允许释放自身旧槽，但不允许通过预览改变物品方向。
func can_place(item: ItemInstance, pos: Vector2i, rotated: bool) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	if item == null:
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "物品不能为空")
	if rotated != item.rotated:
		return _unsupported("旋转")
	var staged := stage_snapshot()
	if staged.items.has(item.instance_id):
		stage_remove(staged, item.instance_id)
	return _validate_placement(staged, item, pos)

## 添加一件适配装备；保存输入副本，仅在完整校验成功后提交一次。
func add(item: ItemInstance, pos: Vector2i) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var staged := stage_snapshot()
	var result := stage_add(staged, item, pos)
	return _commit_local(staged) if result.is_ok() else result

## 按配置优先级寻找兼容空槽，不替换现有装备；成功 payload 为槽位坐标。
func quick_add(item: ItemInstance) -> InventoryResult:
	if container == null:
		return StateOps.not_initialized()
	var result := _validate_equipment(item)
	if not result.is_ok():
		return result
	if container.items.has(item.instance_id):
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "实例已经属于此容器")
	var staged := stage_snapshot()
	for pos in _quick_positions:
		result = stage_add(staged, item, pos)
		if result.is_ok():
			result = _commit_local(staged)
			if result.is_ok():
				result.payload = pos
			return result
	return InventoryResult.failure(InventoryResult.Code.NO_SPACE, "没有适配且可用的装备槽")

## 移除整个装备实例，成功 payload 为脱离容器的实例，不处理角色效果。
func remove(pos: Vector2i) -> InventoryResult:
	var found := query(pos)
	if not found.is_ok():
		return found
	var staged := stage_snapshot()
	var item := stage_remove(staged, found.payload.instance.instance_id)
	var result := _commit_local(staged)
	if result.is_ok():
		result.payload = item
	return result

## 在装备槽间移动，保留原方向；原地移动无变化，失败保持整个容器不变。
func move(from_pos: Vector2i, to_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	var found := query(from_pos)
	if not found.is_ok():
		return found
	if rotated != null and rotated != found.payload.instance.rotated:
		return _unsupported("旋转")
	if from_pos == to_pos:
		return InventoryResult.success()
	var staged := stage_snapshot()
	var item := stage_remove(staged, found.payload.instance.instance_id)
	var result := stage_add(staged, item, to_pos)
	return _commit_local(staged) if result.is_ok() else result

## 交换两槽装备，双方类型与组合规则都必须合法，任何失败均不提交。
func swap(a_pos: Vector2i, b_pos: Vector2i, rotated: Variant = null) -> InventoryResult:
	var a := query(a_pos)
	if not a.is_ok():
		return a
	var b := query(b_pos)
	if not b.is_ok():
		return b
	if rotated != null and rotated != a.payload.instance.rotated:
		return _unsupported("旋转")
	if a_pos == b_pos:
		return InventoryResult.success()
	var staged := stage_snapshot()
	var a_item := stage_remove(staged, a.payload.instance.instance_id)
	var b_item := stage_remove(staged, b.payload.instance.instance_id)
	var result := stage_add(staged, a_item, b_pos)
	if result.is_ok():
		result = stage_add(staged, b_item, a_pos)
	return _commit_local(staged) if result.is_ok() else result

## 装备方向仅作为原物品元数据保留；不变时成功，主动修改时拒绝。
func rotate(pos: Vector2i, rotated: bool) -> InventoryResult:
	var found := query(pos)
	if not found.is_ok():
		return found
	return InventoryResult.success() if rotated == found.payload.instance.rotated else _unsupported("旋转")

## 装备槽不支持堆叠，调用不会改变任何状态。
func stack(_from_pos: Vector2i, _to_pos: Vector2i) -> InventoryResult:
	return _unsupported("堆叠")

## 装备槽不提供堆叠预览。
func can_stack(_item: ItemInstance, _pos: Vector2i) -> InventoryResult:
	return _unsupported("堆叠")

## 装备槽不提供分割预览。
func can_split(_pos: Vector2i, _quantity: int = 0) -> InventoryResult:
	return _unsupported("分割")

## 装备槽每件数量固定为一，不支持分割。
func split(_from_pos: Vector2i, _to_pos: Vector2i, _quantity: int = 0, _rotated: Variant = null) -> InventoryResult:
	return _unsupported("分割")

## 复制运行期状态供事务使用；调用前必须已成功初始化。
func stage_snapshot() -> Dictionary:
	return container.snapshot()

## 校验后在暂存状态中写入单格装备副本；失败不改变传入计划。
func stage_add(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult:
	var result := _validate_placement(staged, item, pos)
	if not result.is_ok():
		return result
	var owned := item.copy()
	staged.items[owned.instance_id] = {"instance": owned, "anchor": pos}
	staged.cells[pos.y][pos.x] = owned.instance_id
	return InventoryResult.success()

## 从暂存状态移出已存在的实例；不提交版本，调用方负责确保 ID 存在。
func stage_remove(staged: Dictionary, id: int) -> ItemInstance:
	return StateOps.remove(staged, id)

## 事务也不能向装备槽堆叠，避免绕过公开操作的限制。
func stage_stack(_staged: Dictionary, _item: ItemInstance, _pos: Vector2i) -> InventoryResult:
	return _unsupported("堆叠")

## 事务不能从装备槽拆分实例。
func stage_split(_staged: Dictionary, _pos: Vector2i, _quantity: int = 0) -> InventoryResult:
	return _unsupported("分割")

## 第一版不接收分割操作，即使分割结果为一件也明确拒绝。
func stage_place_split(_staged: Dictionary, _item: ItemInstance, _pos: Vector2i) -> InventoryResult:
	return _unsupported("分割")

## 按本服务规则重建完整计划，校验矩阵、实例、槽位类型及双向互斥关系。
func validate_plan(staged: Dictionary) -> InventoryResult:
	return StateOps.validate_plan(container, staged, stage_add)

## 先校验版本和完整状态，再同步提交；不发通知，通知交给 Manager 统一处理。
func commit(staged: Dictionary) -> InventoryResult:
	return StateOps.commit(container, staged, validate_plan)

## 按事务前快照直接恢复数据与版本，不重新触发装备规则。
func restore(snapshot: Dictionary) -> InventoryResult:
	StateOps.apply_state(container, snapshot)
	return InventoryResult.success()

## 提交本地计划；非版本冲突的提交失败恢复原快照，避免覆盖外部的新版本。
func _commit_local(staged: Dictionary) -> InventoryResult:
	var before := stage_snapshot()
	var result := commit(staged)
	if not result.is_ok() and result.code != InventoryResult.Code.STALE_STATE:
		restore(before)
	return result

## 校验实例和装备配置；装备必须有有效类型，且配置与实例都只允许一件。
func _validate_equipment(item: ItemInstance) -> InventoryResult:
	var result := StateOps.validate_item(item, _config_lookup)
	if not result.is_ok():
		return result
	var config: ItemConfig = _config_lookup.call(item.config_id)
	if config.MaxStack != 1 or item.quantity != 1 or config.Equipment == null or not config.Equipment.validate():
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "需要数量为一且配置有效的不可堆叠装备")
	return InventoryResult.success()

## 校验空槽类型、重复实例和双向阻塞；既检查新装备的要求，也检查已有装备的要求。
func _validate_placement(staged: Dictionary, item: ItemInstance, pos: Vector2i) -> InventoryResult:
	var result := _validate_equipment(item)
	if not result.is_ok():
		return result
	result = StateOps.validate_position(pos, staged.size)
	if not result.is_ok():
		return result
	if staged.items.has(item.instance_id):
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "实例已经属于此容器")
	var slot := _slots[pos.x]
	var config: ItemConfig = _config_lookup.call(item.config_id)
	var equipment := config.Equipment
	if not slot.accepted_types.has(equipment.equipment_type):
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "装备类型不适配目标槽位")
	if staged.cells[pos.y][pos.x] != null:
		return InventoryResult.failure(InventoryResult.Code.OCCUPIED, "装备槽已经被占用")
	if equipment.blocked_slot_ids.has(slot.slot_id):
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "装备不能阻塞自身槽位")
	for blocked_id in equipment.blocked_slot_ids:
		if _slot_indices.has(blocked_id) and staged.cells[0][_slot_indices[blocked_id]] != null:
			return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "装备要求的空槽已被占用")
	for record: Dictionary in staged.items.values():
		var existing: ItemConfig = _config_lookup.call(record.instance.config_id)
		if existing.Equipment.blocked_slot_ids.has(slot.slot_id):
			return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "目标槽位被已有装备阻塞")
	return InventoryResult.success()

## 返回统一的不支持结果，不触发状态或版本变化。
func _unsupported(operation: String) -> InventoryResult:
	return InventoryResult.failure(InventoryResult.Code.UNSUPPORTED, "装备栏不支持" + operation)
