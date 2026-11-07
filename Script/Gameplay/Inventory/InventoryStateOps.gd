extends RefCounted
## 无状态辅助函数：有效性、堆叠与分割数量校验、计划一致性、版本提交与快照恢复。
## 不持有容器，不执行容器操作，不决定单格或网格规则。

## 通过 config_lookup 读取配置，校验实例 ID、配置有效性及栈数量。
## 只返回 OK 或 INVALID_ITEM，不检查具体容器的占位和旋转规则。
static func validate_item(item: ItemInstance, config_lookup: Callable) -> InventoryResult:
	if item == null or item.instance_id <= 0 or not config_lookup.is_valid():
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "实例或配置查询无效")
	var config: ItemConfig = config_lookup.call(item.config_id)
	if config == null or config.ItemID != item.config_id or not config.validate():
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "物品配置缺失或非法")
	if item.quantity <= 0 or item.quantity > config.MaxStack:
		return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "物品数量超出堆叠限制")
	return InventoryResult.success()

## 校验两个独立栈的配置与数量，返回目标可接收的数量，不修改任何实例。
## 方向属于占位元数据，不影响同配置栈的兼容性；目标身份和方向由服务保留。
static func validate_stack(item: ItemInstance, target: ItemInstance, config_lookup: Callable) -> InventoryResult:
	for instance in [item, target]:
		var result := validate_item(instance, config_lookup)
		if not result.is_ok():
			return result
	if item.instance_id == target.instance_id:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "不能向同一物品栈堆叠")
	if item.config_id != target.config_id:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "只有相同配置的物品可以堆叠")
	var config: ItemConfig = config_lookup.call(target.config_id)
	if config.MaxStack == 1:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "此物品不能堆叠")
	var amount := mini(item.quantity, config.MaxStack - target.quantity)
	if amount <= 0:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "目标物品栈已满")
	return InventoryResult.success(amount)

## 只读校验分割数量，quantity=0 时取一半向下取整，禁止取空源栈。
static func validate_split(item: ItemInstance, quantity: int, config_lookup: Callable) -> InventoryResult:
	var result := validate_item(item, config_lookup)
	if not result.is_ok():
		return result
	var amount: int = item.quantity / 2 if quantity == 0 else quantity
	if amount <= 0 or amount >= item.quantity:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "分割数量必须大于零且少于原栈数量")
	return InventoryResult.success(amount)

## 检查 pos 是否位于 size 定义的矩阵内；负坐标与越界分别返回对应错误。
static func validate_position(pos: Vector2i, size: Vector2i) -> InventoryResult:
	if pos.x < 0 or pos.y < 0:
		return InventoryResult.failure(InventoryResult.Code.INVALID_POSITION, "坐标不能为负数")
	if pos.x >= size.x or pos.y >= size.y:
		return InventoryResult.failure(InventoryResult.Code.OUT_OF_BOUNDS, "坐标超出容器边界")
	return InventoryResult.success()

## 从 staged 清除 id 的全部占位和记录，并返回被移出的暂存实例。
## 调用方须保证 id 存在；仅修改传入副本，不递增版本。
static func remove(staged: Dictionary, id: int) -> ItemInstance:
	var item: ItemInstance = staged.items[id].instance
	for row in staged.cells:
		for x in range(row.size()):
			if row[x] == id:
				row[x] = null
	staged.items.erase(id)
	return item

## 以 add_to_plan(staged, item, anchor) 提供的具体规则重建期望矩阵。
## 验证身份、尺寸、记录索引及覆盖一致性；不修改真实容器或传入计划。
static func validate_plan(container: InventoryContainer, staged: Dictionary, add_to_plan: Callable) -> InventoryResult:
	if container == null:
		return not_initialized()
	if staged.container_id != container.container_id or staged.size != container.size:
		return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "提交不能改变容器身份或尺寸")
	var expected := InventoryContainer.new(staged.container_id, staged.size).snapshot()
	for id in staged.items:
		var record: Dictionary = staged.items[id]
		if not record.instance is ItemInstance or record.instance.instance_id != id:
			return InventoryResult.failure(InventoryResult.Code.INVALID_ITEM, "实例索引与实例 ID 不一致")
		var result: InventoryResult = add_to_plan.call(expected, record.instance, record.anchor)
		if not result.is_ok():
			return result
	if expected.cells != staged.cells:
		return InventoryResult.failure(InventoryResult.Code.INTERNAL_ERROR, "占位矩阵与物品记录不一致")
	return InventoryResult.success()

## 先校验 staged 的基准版本，再调用 validator 校验规则，并在写入前复查版本。
## 有变化时复制应用状态、revision 加一并返回受影响 ID；无变化时返回 changed=false。
## 整个过程同步执行，不发送信号；版本冲突返回 STALE_STATE。
static func commit(container: InventoryContainer, staged: Dictionary, validator: Callable) -> InventoryResult:
	if container == null:
		return not_initialized()
	if container.revision != staged.revision:
		return InventoryResult.failure(InventoryResult.Code.STALE_STATE, "容器版本已经变化")
	var result: InventoryResult = validator.call(staged)
	if not result.is_ok():
		return result
	# 规则校验与写入之间再次确认版本，避免校验扩展引入的状态变化被覆盖。
	if container.revision != staged.revision:
		return InventoryResult.failure(InventoryResult.Code.STALE_STATE, "校验期间容器版本已经变化")
	var ids := changed_ids(container, staged)
	if ids.is_empty():
		return InventoryResult.success()
	apply_state(container, staged)
	container.revision += 1
	return InventoryResult.success(null, ids, true)

## 复制 state 的矩阵和实例记录到 container，并将 revision 恢复为快照值。
## 内部提交/恢复工具，不执行规则校验，不额外递增版本，也不改变容器身份和尺寸。
static func apply_state(container: InventoryContainer, state: Dictionary) -> void:
	var owned := InventoryContainer.copy_state(state)
	container.cells = owned.cells
	container.items = owned.items
	container.revision = owned.revision

## 比较 container 与 staged，返回新增、移除、锚点或实例字段变化的 ID 列表。
static func changed_ids(container: InventoryContainer, staged: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for id in container.items:
		if not staged.items.has(id) or not same_record(container.items[id], staged.items[id]):
			ids.append(id)
	for id in staged.items:
		if not container.items.has(id):
			ids.append(id)
	return ids

## 按锚点、配置 ID、数量和方向比较两条同 ID 记录，不比较对象引用。
static func same_record(a: Dictionary, b: Dictionary) -> bool:
	return a.anchor == b.anchor and a.instance.config_id == b.instance.config_id \
		and a.instance.quantity == b.instance.quantity and a.instance.rotated == b.instance.rotated

## 构造容器尚未初始化的 RULE_REJECTED 结果，统一服务初始化前的失败反馈。
static func not_initialized() -> InventoryResult:
	return InventoryResult.failure(InventoryResult.Code.RULE_REJECTED, "容器尚未初始化")
