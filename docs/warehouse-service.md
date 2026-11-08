# WarehouseService 使用与测试

## 范围与职责

`WarehouseService` 继承 `GridService`，直接复用矩形占位、旋转、移动、交换、堆叠、分割、自动寻找空位，以及暂存、版本校验、提交和快照恢复。仓库增加手动整理与物品数量统计，不另存一份物品列表，也不引用玩家、场景节点或 UI。

固定容量来自资源配置，不实现扩容、分页、一键批量存取或磁盘存档。世界交互由独立的 `WarehouseInteractable` 负责，正式家园已摆放仓库，服务自身不依赖交互组件。

## 两个全局管理器的职责

新增全局单例 `WarehouseManager`，场景为 `Scene/Inventory/WarehouseManager.tscn`，脚本为 `Script/Gameplay/Inventory/WarehouseManager.gd`。它在 `InventoryManager` 之后自动加载。

| 组件 | 职责 |
|---|---|
| `InventoryManager` | 统一容器工厂与注册表、物品查询、通用增删移动、跨容器事务、事务锁与通知 |
| `WarehouseManager` | 仓库类型识别、整理和物品数量统计的公开入口 |
| `WarehouseService` | 网格规则、数量汇总、整理算法、提交校验和失败恢复 |

`is_warehouse` 与 `organize_warehouse` 已从 `InventoryManager` 移除，调用方应改用 `WarehouseManager`。通用工厂仍支持 `ServiceType.WAREHOUSE`，背包与仓库继续注册在同一处，物品不会复制到第二份注册表。

```gdscript
WarehouseManager.is_warehouse("warehouse_home")
WarehouseManager.organize_warehouse("warehouse_home")
```

仓库管理器通过通用只读接口 `InventoryManager.is_container_service()` 判断实际服务类型，能识别手动注册的仓库子类；注销后判断立即失效，同名 ID 后来注册为普通背包时也不会误判。

整理通过 `InventoryManager.execute_container_operation()` 执行同步服务回调，先验证目标类型，再进入统一事务锁。回调按服务契约返回 `InventoryResult`；成功且发生变化时才发送一次既有的 `InventoryManager.container_changed`，失败沿用 `InventoryManager.operation_failed`。仓库管理器不转发第二套信号，不读取私有注册表，也不绕过事务锁直接调用已注册服务。

## Manager 创建入口

`InventoryManager.ServiceType.WAREHOUSE = 3`，已有 SLOT、GRID、EQUIPMENT_SLOT 的枚举值保持不变。仓库使用既有三参数创建入口，不接受装备槽配置。

提供的 `Rescource/Data/Inventory/home_warehouse.tres` 定义：

- 稳定容器标识：`warehouse_home`。
- 容量：`10 × 12`。
- 服务类型：`WAREHOUSE`。

```gdscript
## 打开前确保创建一次；已存在的仓库不重建，以保留会话内物品。
func ensure_warehouse() -> InventoryResult:
    var definition: InventoryDefinition = preload("res://Rescource/Data/Inventory/home_warehouse.tres")
    if WarehouseManager.is_warehouse(definition.container_id):
        return InventoryResult.success()
    return InventoryManager.create_container(
        definition.container_id, definition.size, definition.service_type)
```

关闭窗口、删除交互物和切换场景均不注销或清空容器，重新打开继续绑定同一 ID。每个独立仓库应配置稳定且唯一的 ID；多个交互物绑定同一 ID 表示共享同一个仓库。交互组件会拒绝已被普通背包占用的同名 ID。

主菜单“开始游戏”会明确重建背包、装备与家园仓库。角色组件单独重置玩家容器时不遍历清空其他仓库；新增仓库需要加入自己的新游戏重置清单。当前数据只保留在运行会话内，退出程序后不会写入磁盘。

## 存入与取出

存入和取出继续使用 `switch_to_container()`，交换、堆叠和分割分别使用原有跨容器接口。不要先删除源物品再添加到目标，否则无法保证失败时保持双方完整状态。

```gdscript
# 背包物品原子存入仓库指定位置。
InventoryManager.switch_to_container(
    "player_backpack", "warehouse_home", source_position, destination_position)

# 仓库物品原子取回背包。
InventoryManager.switch_to_container(
    "warehouse_home", "player_backpack", source_position, destination_position)
```

`quick_add_to_container()` 会创建一个新实例并寻找空位；它用于新增物品，不能代替已有实例的转移，也不会自动合并已有物品栈。

## 物品数量统计

统计按 `ItemInstance.quantity` 累加，同一配置的不同堆、不同旋转方向均合计到同一个配置 ID。多格物品只按一个实例的实际数量计入；数量与堆数、占格数是不同概念。例如同一草药分为 4 份和 3 份两堆，则该草药统计为 7，而不是 2。

以下接口均返回 `InventoryResult`，统计值位于成功结果的 `payload`：

| 仓库管理器接口 | 成功结果 |
|---|---|
| `WarehouseManager.get_item_counts(id)` | `Dictionary[int, int]`，保存 `{配置 ID: 数量合计}`，不包含数量为零的配置 |
| `WarehouseManager.get_item_count(id, config_id)` | 指定物品在该仓库中的数量合计，未存放时为 `0` |
| `WarehouseManager.get_total_item_count(id)` | 该仓库全部物品的数量总和，空仓库为 `0` |

```gdscript
## 在调用方处理查询失败后再使用数量；不存在的仓库与空仓库有不同结果。
func print_warehouse_quantity() -> void:
    var result := WarehouseManager.get_item_count("warehouse_home", 11)
    if result.is_ok():
        print("物品 11 的数量：", result.payload)
    else:
        print(result.message)
```

不存在的仓库返回 `CONTAINER_NOT_FOUND`，对普通背包等非仓库容器查询返回 `UNSUPPORTED`，错误沿用 `InventoryManager.operation_failed`。指定配置未存放则成功返回 `0`，无需该配置先存在于物品目录。

数量计算位于 `WarehouseService`，直接遍历当前实例记录，每次返回新的汇总字典。移动、旋转、整理、同仓库拆分和合并不改变总数量；添加、移除、跨容器存取、交换及部分转移之后按实际结果重新统计，不维护容易失效的第二份数量缓存。调用方修改返回字典不会修改仓库。

仓库管理器通过 `InventoryManager.query_container_service()` 路由只读查询；查询不获取写事务锁，不修改物品、布局和版本，也不发出 `container_changed`。该通用接口只负责容器存在性、类型检查与错误报告，仓库数量规则不放回 InventoryManager。

## 手动整理

```gdscript
WarehouseManager.organize_warehouse("warehouse_home")
```

算法先验证原状态，然后按以下顺序稳定排序：占格面积降序、主类型升序、配置 ID 升序、实例 ID 升序。随后在隔离的暂存状态中按行寻找每件物品的第一个适配位置。

- 保留所有实例 ID、配置、数量和原方向；不合并或分割物品，也不自动旋转。
- 全部摆放成功后一次提交，实际变化只递增一次版本，并由 Manager 通知仓库一次。
- 已经处于整理结果时返回无变化成功，不递增版本、不发送内容变化通知。
- 首适配算法不保证找到所有可能的合法布局。即使原布局合法，重新装箱也可能失败；此时返回 `NO_SPACE` 并保留全部原状态。
- 提交故障恢复整理前快照；版本冲突保留外部的新版本，不覆盖它。
- 普通背包和装备栏调用仓库整理接口返回 `UNSUPPORTED`。

整理只影响本仓库，不会重排玩家背包。算法写在服务中，仓库管理器负责专用入口，物品管理器负责通用类型校验、事务锁和提交后通知。

## UI 接入

仓库使用继承自 `inventory_window.tscn` 的独立外观场景 `warehouse_window.tscn`，复用网格画板，多格显示包含旋转方向，拖拽预览保持完整网格尺寸。专用场景的可见范围为 10 列、10 行，当前 10 × 12 仓库完整显示一行，仅需纵向滚动；超过该可见宽度的自定义仓库仍支持 Shift 横向滚动。正式工作区会按 WAREHOUSE 类型自动选择此场景。

窗口标题中的“整理”按钮已在 `.tscn` 中声明，仅仓库类型显示；普通背包和装备栏隐藏此按钮。实际点击调用 WarehouseManager 整理，并按实例 ID 更新选择记录的锚点，避免整理后仍使用旧坐标操作物品。窗口解绑后禁用按钮并清理运行期仓库管理器引用。

通过正式工作区同时显示背包和仓库：

```gdscript
UIManager.open(UIId.INVENTORY, {"containers": [
    {"id": "player_backpack", "service_type": InventoryManager.ServiceType.GRID},
    {"id": "warehouse_home", "service_type": InventoryManager.ServiceType.WAREHOUSE},
]})
```

调用前确保两个容器已经创建，并使用当前场景允许的 UIManager 归属。窗口初始位置沿用工作区导出的定位节点数组，不在仓库服务中定义布局。

## 完整仓库 UI 测试台

运行 `Scene/Inventory/WarehouseLab.tscn` 可直接体验完整界面，详见 [warehouse-ui.md](warehouse-ui.md)。新增物品、选中后按坐标存取、物品详情、标题整理、隐藏和重新打开仓库均由场景控件提供。该测试台使用独立 Manager 和演示目录，不修改正式玩家的数据。

测试台同时在场景中实例化独立的 `WarehouseManager`，其导出字段 `inventory_manager` 引用同场景的 `Manager`，仓库窗口导出字段 `warehouse_manager` 引用该仓库管理器。正式工作区未显式注入时使用全局单例。窗口绑定会检查两个管理器属于同一会话，错误组合直接拒绝，避免把测试整理命令发送到正式会话。

## 正式游戏交互

`Scene/Inventory/Warehouse.tscn` 声明仓库外观、名称和交互碰撞区域，根节点挂载 `WarehouseInteractable.gd`，导出 `definition` 资源。正式家园 `Scene/Map/Home/Home.tscn` 已实例化 `HomeWarehouse`，位置为 `(150, 0)`，在出生点右侧。

角色靠近后按 E，组件复用 `PlayerInventoryComponent.get_ui_containers()` 返回的背包和装备列表，再追加仓库，通过 UIManager 打开正式工作区。UI 只绑定 Manager 中已有的三个容器，存取仍调用原有跨容器事务。打开期间屏蔽游戏输入，Tab 或 Esc 关闭后恢复操作。

交互物仅在拥有当前仓库窗口时负责关闭它，正常关闭后解除归属。因此先关闭仓库、再用 Tab 打开的玩家窗口不会被旧交互物的销毁误关。销毁正在打开仓库的交互物会关闭界面，仓库内容始终保留在 Manager 中。

`Scene/Inventory/WarehouseGameplayLab.tscn` 复用真实 Hero、掉落按钮与正式交互，适合测试走近、拾取、E 打开、三窗口拖放、整理和重置。该场景使用全局正式会话，区别于独立数据的 `WarehouseLab.tscn`。

## 测试方法与结果

```powershell
.\tests\inventory\run-tests.ps1 -WarehouseOnly -IncludeWarehouseUI -IncludeWarehouseGameplay
```

首次新增脚本时可先刷新编辑器文件，或加 `-Import`。不加 `-WarehouseOnly` 时仓库领域测试也随原有领域套件运行。

领域测试 `tests/inventory/warehouse_spec.gd`：**169 条断言，0 失败**。覆盖继承规则、内容守恒、稳定排序、重复整理无变化、合法布局重新装箱失败、真实提交后故障恢复、旧版本冲突，以及 Manager 创建、存取、交换、分割、堆叠和通知。另覆盖专属 API 迁移、独立与全局会话隔离、仓库子类识别、实际回调执行期间禁止重入、注销及同名 ID 更换类型后的即时识别。

数量统计新增 72 条断言：未初始化与空仓库、未存放物品、同配置多堆、旋转和多格不重复计数、返回字典隔离、移动整理及拆分合并守恒、删除整堆、跨容器存取与交换后的实时更新、失败回滚、不混入其他仓库、错误类型和缺失容器、单次错误报告、无版本变化和无变更通知，以及写锁期间的只读查询。

UI 测试场景 `tests/inventory/warehouse_ui_runner.tscn`、脚本 `warehouse_ui_spec.gd`：**47 条断言，0 失败**。使用真实 GUI 输入检查仓库多格显示、双向滚轮、整理按钮、整理后的选择锚点、完整尺寸预览、背包存取、滚动后的末行放置，以及关闭重绑保留会话数据；也覆盖缩放窗口下的完整预览、旋转与半栈操作，以及拒绝跨会话管理器绑定后按钮保持禁用、物品不变。

完整界面测试 `tests/inventory/warehouse_lab_runner.tscn`、`warehouse_lab_spec.gd`：**43 条断言，0 失败**。包括实验室与正式工作区完整显示十列、纵向滚动仍可用、详情面板不被遮挡。同一个 `-IncludeWarehouseUI` 参数会同时运行两组 UI 测试。

世界接入测试 `tests/inventory/warehouse_gameplay_runner.tscn`、`warehouse_gameplay_spec.gd`：**80 条断言，0 失败**。通过真实按键移动到交互区，按 E 打开并进行原生 GUI 拖放，检查三窗口绑定、实例身份守恒、整理、关闭恢复输入、重载场景与交互物销毁后的数据保留、正式家园可达性、错误定义与同名容器保护，以及显式重置。数量统计增加全局单例的空仓库、真实存入与取回、重载保留及重置归零验证。最后实际触发主菜单开始游戏按钮，检查仓库清空、加载完成、按键继续进入家园，并确认背包和装备同步重置。取回目标按当前正式武器的完整尺寸寻找空位，兼容现有 4×1 长剑，不再固定使用越界落点。测试切换真实场景，驱动节点独立于当前场景，不依靠直接调用 `interact()` 代替交互流程。

本次装备服务 300 条、装备 UI 178 条断言均通过。另运行全量领域回归，仍为原有 4 项旋转默认值预期失败，没有新增失败；没有通过修改正式配置规避它们。

故障注入仅在 `warehouse_fault_service.gd` 测试子类中实现，生产服务不包含测试开关。所有测试 UI 节点来自 `.tscn`，没有通过代码创建控件。
