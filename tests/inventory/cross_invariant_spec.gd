extends RefCounted
## 跨容器随机操作验证唯一归属、数量守恒和双边失败原子性。

## 执行 200 步固定种子跨容器转移/交换，检查唯一归属、实例字段守恒与失败时双边状态不变。
func run(t, manager) -> void:
	manager.create_container("random_slot", Vector2i(5, 3), manager.ServiceType.SLOT)
	manager.create_container("random_grid", Vector2i(5, 4), manager.ServiceType.GRID)
	for index in range(6):
		manager.add_to_container("random_slot", 2, index + 1, Vector2i(index % 5, index / 5), index % 2 == 0)
	var original := _items(manager)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	for step in range(200):
		var source: String = "random_slot" if rng.randi_range(0, 1) == 0 else "random_grid"
		var target: String = "random_grid" if source == "random_slot" else "random_slot"
		var source_state: Dictionary = manager.get_snapshot(source)
		var target_state: Dictionary = manager.get_snapshot(target)
		var records: Array = source_state.items.values()
		var from_pos: Vector2i = records[rng.randi_range(0, records.size() - 1)].anchor if not records.is_empty() else Vector2i.ZERO
		var to_pos := Vector2i(rng.randi_range(-1, 5), rng.randi_range(-1, 4))
		var result: InventoryResult
		if rng.randi_range(0, 1) == 0:
			result = manager.switch_to_container(source, target, from_pos, to_pos)
		else:
			result = manager.swap_between_containers(source, target, from_pos, to_pos)
		if not result.is_ok():
			t.equal(t.value(manager.get_snapshot(source)), t.value(source_state), "随机跨容器失败源不变")
			t.equal(t.value(manager.get_snapshot(target)), t.value(target_state), "随机跨容器失败目标不变")
		else:
			t.equal(manager.get_snapshot(source).revision, source_state.revision + 1, "随机转移源版本递增一次")
			t.equal(manager.get_snapshot(target).revision, target_state.revision + 1, "随机转移目标版本递增一次")
		var seen: Dictionary = {}
		for id in [source, target]:
			var snapshot: Dictionary = manager.get_snapshot(id)
			for instance_id in snapshot.items:
				t.expect(not seen.has(instance_id), "随机跨容器实例唯一归属")
				seen[instance_id] = true
		t.equal(_items(manager), original, "随机跨容器数量、ID、配置和方向守恒 %d" % step)
	manager.unregister_container("random_slot")
	manager.unregister_container("random_grid")

## 按实例 ID 汇总两个随机测试容器的配置、数量和方向，用于忽略位置比较转移前后的守恒关系。
func _items(manager) -> Dictionary:
	var items: Dictionary = {}
	for id in ["random_slot", "random_grid"]:
		for instance_id in manager.get_snapshot(id).items:
			var item: ItemInstance = manager.get_snapshot(id).items[instance_id].instance
			items[instance_id] = [item.config_id, item.quantity, item.rotated]
	return items
