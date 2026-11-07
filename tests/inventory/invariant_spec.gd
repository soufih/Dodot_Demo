extends RefCounted
## 固定随机种子的操作序列，用独立矩形重建验证全局不变量和失败原子性。

## 对两种服务各执行 250 步固定种子随机操作，检查失败原子性、版本增量和状态不变量。
func run(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	for grid in [false, true]:
		var service: InventoryService = t.service(grid, Vector2i(6, 5))
		for step in range(250):
			var before: Dictionary = t.value(service.stage_snapshot())
			var pos := Vector2i(rng.randi_range(-1, 6), rng.randi_range(-1, 5))
			var target := Vector2i(rng.randi_range(-1, 6), rng.randi_range(-1, 5))
			var result: InventoryResult
			match rng.randi_range(0, 4):
				0:
					result = service.add(ItemInstance.new(rng.randi_range(1, 4)), pos)
				1:
					result = service.move(pos, target)
				2:
					result = service.remove(pos)
				3:
					result = service.swap(pos, target)
				4:
					result = service.rotate(pos, rng.randi_range(0, 1) == 1)
			var after := service.stage_snapshot()
			if not result.is_ok() or not result.changed:
				t.equal(t.value(after), before, "随机操作失败/无变化时状态不变 %s/%d" % [grid, step])
			else:
				t.equal(after.revision, before.revision + 1, "随机成功操作仅加一个版本")
			_check_state(t, after, grid)

## 按记录与配置独立重建期望矩阵，检查栈数量、矩形边界、占位互斥及矩阵覆盖一致性。
## grid 决定使用配置矩形还是单格规则，断言结果累计到 t。
func _check_state(t, state: Dictionary, grid: bool) -> void:
	var expected: Array = []
	for y in range(state.size.y):
		var row: Array = []
		row.resize(state.size.x)
		expected.append(row)
	for id in state.items:
		var record: Dictionary = state.items[id]
		var item: ItemInstance = record.instance
		var config: ItemConfig = t.lookup(item.config_id)
		t.expect(item.quantity >= 1 and item.quantity <= config.MaxStack, "随机序列栈数量合法")
		var extent := config.GridSize if grid else Vector2i.ONE
		if grid and item.rotated:
			extent = Vector2i(extent.y, extent.x)
		for y in range(record.anchor.y, record.anchor.y + extent.y):
			for x in range(record.anchor.x, record.anchor.x + extent.x):
				t.expect(x >= 0 and y >= 0 and x < state.size.x and y < state.size.y, "随机序列占位不越界")
				if x >= 0 and y >= 0 and x < state.size.x and y < state.size.y:
					t.expect(expected[y][x] == null, "随机序列占位不重叠")
					expected[y][x] = id
	t.equal(state.cells, expected, "随机序列矩阵恰好对应记录中的形状")
