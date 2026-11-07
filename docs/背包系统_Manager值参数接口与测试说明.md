# Manager 值参数接口与测试说明

## ID 与创建职责

`config_id` 表示物品配置，`instance_id` 表示具体物品栈的运行期身份。
Manager 的新增接口根据配置 ID、数量和方向创建实例。
`can_place`、`can_stack` 继续接收 `ItemInstance`，按调用方传入的实例副本进行只读预览。
Service 继续接收实例并负责配置、数量、占位、旋转、堆叠及提交规则，基类保持抽象契约。

## 新签名

```gdscript
add_to_container(id: String, config_id: int, quantity: int,
    pos: Vector2i, rotated: bool = false) -> InventoryResult

quick_add_to_container(id: String, config_id: int,
    quantity: int = 1, rotated: bool = false) -> InventoryResult

can_place(id: String, item: ItemInstance,
    pos: Vector2i, rotated: bool) -> InventoryResult

can_stack(id: String, item: ItemInstance, pos: Vector2i) -> InventoryResult
```

`add_to_container` 成功后的 payload 为新实例的隔离副本，可以从中取得实际 instance_id。
`quick_add_to_container` 继续以实际锚点 Vector2i 作为成功 payload，可通过该坐标查询新实例。
两个入口每次新增均生成独立身份，调用方不能指定运行期 ID。

预览使用传入实例的配置、身份和数量，数量合法性由 Service 校验。
未知目标容器返回 CONTAINER_NOT_FOUND，空实例或非法数量返回 INVALID_ITEM。
预览调用本身不修改输入实例、真实容器或 ID 分配器；正式提交时仍会重新读取和校验真实状态。

同容器整栈移动预览保留原实例 ID，因此可在暂存副本中释放自身旧占位。
半栈使用独立临时实例 ID，原栈占位保留，不能覆盖原栈。
Service 的 `can_place(item, pos, rotated)` 保持原签名，正式添加和提交继续执行身份唯一性校验。

## 调用示例

```gdscript
# 新增物品，调用方无需构造 ItemInstance。
var created := InventoryManager.add_to_container(
    "背包", 1004, 6, Vector2i.ZERO)
if created.is_ok():
    var item: ItemInstance = created.payload
    # 传入实例副本，预览整栈以旋转方向移入目标。
    var placement := InventoryManager.can_place(
        "储物箱", item, Vector2i(1, 0), true)
    # 独立半栈预览使用自己的临时身份，保留原栈占位。
    var half := ItemInstance.new(item.config_id, 3, item.rotated)
    var stacking := InventoryManager.can_stack(
        "储物箱", half, Vector2i.ZERO)

var added := InventoryManager.quick_add_to_container("背包", 1002, 5)
```

已有栈保留身份的转移仍使用 `switch_to_container`、`move_in_container`、交换或分割接口。
`remove_from_container` 后再按配置调用新增接口，表示创建新栈，会获得新 ID；
需要保留已有身份时应直接转移，不能把配置 ID 当作实例 ID 回填。
移除仍返回脱离实例副本，供调用方读取其配置、数量和方向。

## UI 接入

Lab 表单与默认演示物品只传配置 ID、数量及方向。
普通拖拽预览复制查询结果并保留原身份，中键半栈预览创建独立临时实例。
悬停校验将预览实例传给 Manager，Manager 路由到目标 Service 进行只读检查。
实际分割的新实例仍在 Service 暂存事务内生成，保证放置失败时源数量不变。
场景控件继续由 `.tscn` 声明，R 旋转、堆叠、交换、分割及滚动行为保持原有规则。

## 测试内容与方法

新增 `tests/inventory/manager_boundary_spec.gd`：

- 按相同配置创建多个独立栈，检查实际 ID、数量、方向和返回副本隔离。
- 通过新快速添加入口验证默认数量、普通栏位方向及非法参数失败原子性。
- 验证整栈原身份的重叠移动与独立半栈保留源占位的区别，覆盖旋转后的预览。
- 验证整栈/半栈堆叠预览、自身堆叠拒绝、未知目标容器及非法实例等错误。
- 在预览接口调用前后创建 ID 标记实例，断言接口本身不分配新 ID。
- 对比预览前后完整状态与通知次数；正式转移后验证原实例身份保留。

既有领域与 UI 夹具均已迁移到新签名，实例 ID 取自实际 Manager 返回结果或查询。
Service 直接调用的独立测试仍验证其原有实例契约。

```powershell
.\tests\inventory\run-tests.ps1 -IncludeUI
```

Godot 4.7.2：领域测试 16,814 条断言、UI 测试 372 条断言，失败均为 0。
