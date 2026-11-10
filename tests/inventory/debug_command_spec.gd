extends RefCounted
## 从真实控制台命令入口验证路由、参数校验、通知与失败原子性。

func run(t, manager) -> void:
	var previous := DebugTool.get_service(&"inventory")
	DebugTool.register_service(&"inventory", manager)
	manager.create_container("debug target", Vector2i(2, 1), InventoryManager.ServiceType.SLOT)
	var notifications: Array = []
	var on_changed := func(id: String, _revision: int, _ids: Array[int]) -> void:
		if id == "debug target":
			notifications.append(id)
	manager.container_changed.connect(on_changed)
	var listing := DebugTool.execute_command("inventory.containers", false)
	t.expect(listing.success and listing.value.has("debug target"), "控制台列出容器 ID")
	t.expect(DebugTool.execute_command('inventory.add "debug target" 1 3', false).success, "带空格的容器 ID 和指定数量")
	t.equal(manager.get_item_at("debug target", Vector2i.ZERO).instance.quantity, 3, "命令传递数量")
	t.expect(DebugTool.execute_command('inventory.add "debug target" 1', false).success, "省略数量默认添加一个")
	t.equal(manager.get_item_at("debug target", Vector2i.ZERO).instance.quantity, 4, "控制台快速添加优先补同类物品堆")
	t.equal(notifications.size(), 2, "成功添加通知 UI 刷新")
	t.expect(DebugTool.execute_command('inventory.add "debug target" 1 6', false).success, "将已有物品堆补满")
	t.expect(DebugTool.execute_command('inventory.add "debug target" 3', false).success, "填满剩余栏位以验证无空间失败")
	var before: Dictionary = t.value(manager.get_snapshot("debug target"))
	for command in [
		'inventory.add "debug target" 1',
		'inventory.add missing 1',
		'inventory.add "debug target" 999999',
		'inventory.add "debug target" 1 11',
		'inventory.add "debug target" 1 0',
		'inventory.add "debug target" 1 -1',
		'inventory.add "debug target" 1 nope',
		'inventory.add "debug target" nope',
		'inventory.add "debug target" -1',
		'inventory.add "debug target" 1 1 extra',
		'inventory.add',
	]:
		t.expect(not DebugTool.execute_command(command, false).success, "命令失败：%s" % command)
	t.equal(t.value(manager.get_snapshot("debug target")), before, "失败不修改已有容器")
	t.equal(notifications.size(), 4, "失败不发出变更通知")
	manager.container_changed.disconnect(on_changed)
	manager.unregister_container("debug target")
	DebugTool.unregister_service(&"inventory")
	t.expect(not DebugTool.execute_command("inventory.add missing 1", false).success, "服务缺失时明确失败")
	if previous != null:
		DebugTool.register_service(&"inventory", previous)
