# 仓库 UI 使用与布局

## 直接运行

在 Godot 中打开 `Scene/Inventory/WarehouseLab.tscn`，运行当前场景。界面包含操作台、随身背包、仓库和物品详情面板。

- 左侧选择新增目标、物品与数量，点击“添加到空位”。数量上限来自物品配置。
- 左键选择一个物品，右侧显示图标、数量、占格、当前锚点、实例 ID 和描述。
- 可以直接拖动物品在背包与仓库之间移动、堆叠或交换；拖动时按 R 旋转预览，中键取出半栈。
- 也可以填写目标容器坐标后点击“存入仓库”或“取回背包”。坐标从 0 开始，目标必须能容纳完整物品。失败会显示服务返回的原因，不会预扣物品。
- 仓库标题上的“整理”会原子重排仓库。选择通过实例 ID 保留，详情和按钮使用新的锚点。
- “隐藏仓库”只解绑并隐藏窗口；“打开仓库”重新绑定原容器。物品不会清空，隐藏期间禁止仓库存取和向仓库新增。
- “重置演示物品”明确清空两个演示容器，再生成散放物品以便重复测试。

演示背包为 5 × 6，仓库使用 `home_warehouse.tres` 的 10 × 12 容量。专用仓库窗口一次完整显示 10 列、10 行，当前仓库不需要横向滚动，底部两行可用滚轮纵向浏览。窗口标题与边框仍支持按住左键移动。实验室窗口为 1700 × 900，为加宽后的仓库和详情面板保留空间。

## 场景与脚本

| 文件 | 用途 |
|---|---|
| `UI/Inventory/warehouse_window.tscn` | 正式仓库窗口，继承通用网格窗口，配置独立标题外观 |
| `Scene/Inventory/WarehouseLab.tscn` | 完整可运行界面，所有按钮、输入框、面板和窗口均在场景中声明 |
| `Scene/Inventory/Warehouse.tscn` | 家园仓库交互场景，外观与检测区域均由场景声明 |
| `Scene/Inventory/WarehouseGameplayLab.tscn` | 真实角色、掉落物与 E 交互的接入测试场景 |
| `Script/Gameplay/Interactable/WarehouseInteractable.gd` | 会话仓库创建或复用、打开正式工作区与界面生命周期 |
| `Scene/Inventory/WarehouseManager.tscn` | 全局仓库管理器场景，也供独立测试场景实例化 |
| `Script/Gameplay/Inventory/WarehouseManager.gd` | 仓库识别与整理入口，复用统一物品注册表和事务 |
| `Script/UI_Script/Inventory/warehouse_lab.gd` | 数据绑定、选择和详情展示、表单命令与窗口开关 |
| `Rescource/Data/Inventory/warehouse_demo_backpack.tres` | 演示背包定义，与正式玩家容器分开 |
| `Rescource/Data/Inventory/home_warehouse.tres` | 仓库标识、容量与服务类型 |
| `Rescource/Data/Inventory/inventory_demo_catalog.tres` | 复用现有演示物品和图标 |

脚本不使用 `Control.new()` 等方式创建 UI。网格单元、物品和拖拽预览沿用既有 PackedScene 组件。服务负责物品规则和原子提交，UI 不维护第二份可写物品状态。

网格坐标标签在 `inventory_cell.tscn` 中默认隐藏。物品数量位于共用 `inventory_item.tscn` 的 `Margin/Icon/Quantity`，通过场景锚点与对齐属性固定在图标右下角；背包、仓库、装备槽和拖拽预览共用此组件。可堆叠物品显示当前数量，不可堆叠物品隐藏数量文字。

仓库标题的整理按钮现在调用 `WarehouseManager.organize_warehouse()`，仓库识别使用 `WarehouseManager.is_warehouse()`。物品创建、查询、存取、交换、堆叠和分割继续由 `InventoryManager` 的通用接口处理。

业务需要物品总数量时，可调用 `WarehouseManager.get_total_item_count(id)`；指定配置数量使用 `get_item_count(id, config_id)`，全部配置汇总使用 `get_item_counts(id)`。统计按各堆的实际数量合计，区别于窗口现有的实例数和占格数；结果从成功的 `InventoryResult.payload` 读取。接口、返回值和测试口径见 [warehouse-service.md](warehouse-service.md)。

正式窗口默认使用全局 `WarehouseManager`。独立实验室在场景中配置了 `WarehouseManager.inventory_manager → Manager`，以及 `Workspace/Warehouse.warehouse_manager → WarehouseManager`；两个引用都在检查器中设置，不通过代码创建管理器节点。绑定到不同物品会话的管理器会被拒绝。

## 修改布局

在 `WarehouseLab.tscn` 中调整 `Tools`、`Details` 与 `Workspace` 的位置、尺寸。测试台的两个窗口位置直接由 `Workspace/Bag` 和 `Workspace/Warehouse` 的场景变换决定；修改它们即可改变演示的初始布局。

正式游戏工作区在 `inventory_workspace.tscn` 的 `Workspace/WindowPositions` 下准备了两组定位节点，与独立 UI 测试台布局互相独立：

- `WithoutWarehouse/BackpackPosition`、`WithoutWarehouse/EquipmentPosition`：不含仓库时使用，绑定根节点的 `window_positions` 数组。
- `WithWarehouse/BackpackPosition`、`WithWarehouse/EquipmentPosition`、`WithWarehouse/WarehousePosition`：包含仓库时整套使用，绑定根节点的 `warehouse_window_positions` 数组。

世界仓库默认按背包、装备、仓库顺序读取第二组；普通 Tab 打开背包和装备则读取第一组。在编辑器移动各自的 Marker2D 或分组父节点，就能分别调整两种情况的布局。选择依据为是否包含 WAREHOUSE 类型，不依赖容器数量；数组项仍按传入容器顺序对应。定位点缺失或数组为空时沿用自动排列。

`warehouse_window.tscn` 是通用窗口的继承场景，可通过可编辑子节点调整外观；在根节点检查器中设置 `Window Title` 修改显示标题，留空时显示容器 ID。根节点 `Max Grid View Size` 已设为 `(520, 520)`，对应 10 × 10 个 52 像素网格，绑定时再为边框和纵向滚动条预留宽度。以后增大仓库列数时，可同步增大该属性的 X 值；普通背包仍默认显示五列。

## 接入正式工作区

Manager 创建 WAREHOUSE 类型的容器后，UIManager 按类型自动选择 `warehouse_window.tscn`，不需要业务另外判断外观场景：

```gdscript
UIManager.open(UIId.INVENTORY, {"containers": [
    {"id": "player_backpack", "service_type": InventoryManager.ServiceType.GRID},
    {"id": "warehouse_home", "service_type": InventoryManager.ServiceType.WAREHOUSE},
]})
```

该调用绑定的是已存在的正式容器。运行独立测试台不会创建或覆盖正式玩家仓库。

正式家园已经接入 `HomeWarehouse`，位于出生点右侧。靠近宝箱后按 E 会同时打开背包、装备栏和仓库；用鼠标拖放存取物品，点击仓库标题“整理”重排，Tab / Esc 关闭。关闭后重开、切换场景或重建交互物均保留仓库物品。主菜单开始新游戏会清空这三个容器；退出程序不会保存到磁盘。

运行 `Scene/Inventory/WarehouseGameplayLab.tscn` 可以测试真实交互。左侧按钮生成材料和武器，先按 E 拾取，再向右靠近仓库按 E 打开。重置按钮明确清空背包、装备与仓库。该测试场景共用正式全局会话。

在其他关卡中添加仓库时，实例化 `Scene/Inventory/Warehouse.tscn` 并调整位置即可。不同仓库复制并配置独立的 `InventoryDefinition` 资源，设置唯一 `container_id`、容量和 WAREHOUSE 类型；同一 ID 则共享内容。所有窗口和交互节点仍由 `.tscn` 声明。

## 测试

```powershell
.\tests\inventory\run-tests.ps1 -WarehouseOnly -IncludeWarehouseUI -IncludeWarehouseGameplay
```

包含仓库服务 **169 条**、共用网格交互 **47 条**、完整仓库界面 **43 条**、世界接入 **80 条**断言，共 **339 条**，均为 0 失败。覆盖新单例、数量统计、独立会话、共享事务锁、单次通知及错误管理器绑定拒绝。

完整界面测试通过实际 GUI 输入覆盖添加数量、坐标存取、占用失败后双方状态不变、整理后的选择与详情更新、隐藏重开、原生三格物品拖放，以及正式工作区的专用场景选择。同时检查实验室与正式工作区均完整显示十列、保留纵向滚动，并且实验室仓库不遮挡详情。另使用 Godot OpenGL 渲染并检查了完整界面截图。

世界接入测试使用真实 Hero、键盘移动和 E 交互，覆盖实际家园摆放、三窗口存取、窗口归属、场景重载保留数据、新会话重置，以及主菜单开始游戏经过加载屏进入家园的完整流程。为隔离项目中可手动编辑的窗口布局，自动拖放测试仅在运行时清空两套定位数组，使用工作区已有的自动排列；不会修改场景中的 Marker2D。两套数组的实际选择与切换由装备 UI 中的工作区定位测试单独覆盖。

原生 OpenGL 截图已检查正式家园中的三窗口显示。项目默认启动检查通过；编辑器导入仍会触发 `resources_spreadsheet_view` 插件读取非物品资源的 `Item` 属性错误，堆栈位于插件的 `edit_tres.gd:133`，不属于上述运行测试结果。

本次数量位置调整还运行了旧背包 UI 套件，结果为 381 条断言、3 条失败，失败项与调整前一致，均为演示资源的旋转配置与测试预期不一致。堆叠、半栈预览和旋转后数量读取没有新增失败；仓库与装备原生截图已确认坐标隐藏及图标右下角数量显示。
