# WarehouseService 使用与测试

## 范围与职责

`WarehouseService` 继承 `GridService`，直接复用矩形占位、旋转、移动、交换、堆叠、分割、自动寻找空位，以及暂存、版本校验、提交和快照恢复。仓库只增加手动整理，不另存一份物品列表，也不引用玩家、场景节点或 UI。

固定容量来自资源配置，不实现扩容、分页、一键批量存取或磁盘存档。世界交互由独立的 `WarehouseInteractable` 负责，正式家园已摆放仓库，服务自身不依赖交互组件。

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
    if InventoryManager.has_container(definition.container_id):
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

## 手动整理

```gdscript
InventoryManager.organize_warehouse("warehouse_home")
```

算法先验证原状态，然后按以下顺序稳定排序：占格面积降序、主类型升序、配置 ID 升序、实例 ID 升序。随后在隔离的暂存状态中按行寻找每件物品的第一个适配位置。

- 保留所有实例 ID、配置、数量和原方向；不合并或分割物品，也不自动旋转。
- 全部摆放成功后一次提交，实际变化只递增一次版本，并由 Manager 通知仓库一次。
- 已经处于整理结果时返回无变化成功，不递增版本、不发送内容变化通知。
- 首适配算法不保证找到所有可能的合法布局。即使原布局合法，重新装箱也可能失败；此时返回 `NO_SPACE` 并保留全部原状态。
- 提交故障恢复整理前快照；版本冲突保留外部的新版本，不覆盖它。
- 普通背包和装备栏调用仓库整理接口返回 `UNSUPPORTED`。

整理只影响本仓库，不会重排玩家背包。算法写在服务中，Manager 仅负责类型路由、事务锁和提交后通知。

## UI 接入

仓库使用继承自 `inventory_window.tscn` 的独立外观场景 `warehouse_window.tscn`，复用网格画板，多格显示包含旋转方向，拖拽预览保持完整网格尺寸。专用场景的可见范围为 10 列、10 行，当前 10 × 12 仓库完整显示一行，仅需纵向滚动；超过该可见宽度的自定义仓库仍支持 Shift 横向滚动。正式工作区会按 WAREHOUSE 类型自动选择此场景。

窗口标题中的“整理”按钮已在 `.tscn` 中声明，仅仓库类型显示；普通背包和装备栏隐藏此按钮。实际点击调用 Manager 整理，并按实例 ID 更新选择记录的锚点，避免整理后仍使用旧坐标操作物品。窗口解绑后禁用按钮并拒绝命令。

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

领域测试 `tests/inventory/warehouse_spec.gd`：**85 条断言，0 失败**。覆盖继承规则、内容守恒、稳定排序、重复整理无变化、合法布局重新装箱失败、真实提交后故障恢复、旧版本冲突，以及 Manager 创建、存取、交换、分割、堆叠和通知。

UI 测试场景 `tests/inventory/warehouse_ui_runner.tscn`、脚本 `warehouse_ui_spec.gd`：**43 条断言，0 失败**。使用真实 GUI 输入检查仓库多格显示、双向滚轮、整理按钮、整理后的选择锚点、完整尺寸预览、背包存取、滚动后的末行放置，以及关闭重绑保留会话数据；也覆盖缩放窗口下的完整预览、旋转与半栈操作。

完整界面测试 `tests/inventory/warehouse_lab_runner.tscn`、`warehouse_lab_spec.gd`：**43 条断言，0 失败**。包括实验室与正式工作区完整显示十列、纵向滚动仍可用、详情面板不被遮挡。同一个 `-IncludeWarehouseUI` 参数会同时运行两组 UI 测试。

世界接入测试 `tests/inventory/warehouse_gameplay_runner.tscn`、`warehouse_gameplay_spec.gd`：**73 条断言，0 失败**。通过真实按键移动到交互区，按 E 打开并进行原生 GUI 拖放，检查三窗口绑定、实例身份守恒、整理、关闭恢复输入、重载场景与交互物销毁后的数据保留、正式家园可达性、错误定义与同名容器保护，以及显式重置。最后实际触发主菜单开始游戏按钮，检查仓库清空、加载完成、按键继续进入家园，并确认背包和装备同步重置。测试切换真实场景，驱动节点独立于当前场景，不依靠直接调用 `interact()` 代替交互流程。

故障注入仅在 `warehouse_fault_service.gd` 测试子类中实现，生产服务不包含测试开关。所有测试 UI 节点来自 `.tscn`，没有通过代码创建控件。
