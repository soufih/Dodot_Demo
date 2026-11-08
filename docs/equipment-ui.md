# 装备栏 UI 与手工布局

## 运行演示

打开 `Scene/Inventory/EquipmentLab.tscn` 并运行当前场景。测试台有独立 Manager、背包、装备栏，以及添加物品和重置按钮。不会写入正式物品目录或正式玩家的背包。

将长剑、短剑分别拖入同一武器分组中的主武器与副武器槽；拖到已占用的兼容槽位交换，拖回背包空位置卸下。普通草药不能穿戴，双手武器要求副武器槽为空。古代胸甲可放入新增的身体槽；四枚戒指可以分别放入同一个饰品分组的四个独立槽位。默认装备窗口高度为 744 像素，当前所有分组与槽位一次完整显示，无需滚动。

当前演示定义包含八个槽位：`main_hand`、`off_hand`、`head`、`body`、`relic1`～`relic4`，矩阵尺寸为 `8 × 1`。身体槽接受 `ENUM.EquipmentType.BODY_ARMOR`，四个饰品槽接受 `RING` 或 `RELIC`。这些规则来自定义资源，不从 UI 标签推断。

装备来源的拖拽预览保持原物品的完整网格尺寸，槽位静态图标适应场景设置的显示区域。装备来源不支持 R 旋转、中键分割；规则由 Manager 与 Service 再次校验。

## 场景结构

| 场景 | 用途 |
|---|---|
| `UI/Inventory/equipment_window.tscn` | 装备窗口、标题与四边拖动区、滚动区域 |
| `UI/Inventory/equipment_layout.tscn` | 自由布局画布，包含武器、防具、饰品分组 |
| `UI/Inventory/equipment_group.tscn` | 分组背景、标题和普通 Control 类型的 Slots 容器 |
| `UI/Inventory/equipment_slot.tscn` | 单个槽位、标题、空槽提示及已有物品视图 |
| `tests/inventory/equipment_custom_window.tscn` | 继承窗口并手工交换分组与槽位位置的可运行示例 |

所有 UI 控件由 `.tscn` 声明。运行时代码只绑定、刷新既有组件及实例化预制拖拽预览，不使用 `Control.new()` 等方式创建控件。

## 在 Godot 编辑器中调整布局

1. 打开 `equipment_layout.tscn`，或创建一个继承自装备窗口的自定义场景。
2. 移动、缩放 `Weapons`、`Armor`、`Rings` 分组。分组均为普通 `Control`，没有自动排列布局容器覆盖你的设置。
3. 展开某个分组的 `Slots`，分别调整 `MainWeapon`、`SecondaryWeapon` 等槽位的位置、尺寸与锚点。实例子节点可通过“可编辑子节点”展开；默认布局已开启相应节点的编辑。
4. 修改分组 `Title` 和槽位 `Caption` 标签的文本。标签是显示名称，不参与业务定位。
5. 保持每个 `EquipmentSlotView.slot_id` 与服务配置中的 `EquipmentSlotDefinition.slot_id` 对应。修改节点名称、显示名称或排列顺序不会改变它绑定的槽位。
6. 扩大布局时同步调整画布根节点的 `custom_minimum_size`，让 ScrollContainer 知道完整内容尺寸；装备窗口尺寸由根节点的场景设置决定，不会按业务矩阵自动缩放。

布局中的分组仅用于组织显示；是否允许武器、头盔等物品，仍由服务的 `accepted_types` 配置决定。该数组与物品的 `Equipment.equipment_type` 统一使用 `ENUM.EquipmentType`，检查器中可以通过下拉选项配置。没有把槽位数量、分组名称或屏幕位置硬编码到业务规则中。

## 为同一分组增加槽位

以武器分组增加“备用武器”为例：

1. 在装备定义资源的 `equipment_slots` 中新增 `EquipmentSlotDefinition`，将 `slot_id` 设为唯一标识（例如 `reserve_hand`），设置允许的装备类型，并将定义尺寸更新为 `N × 1`。
2. 在场景的 `Weapons/Slots` 下实例化 `equipment_slot.tscn`，将该组件的 `slot_id` 设为相同标识，修改 `Caption` 文本。
3. 在场景编辑器中将新槽位放到需要的位置；根据需要增大分组、画布和窗口尺寸。

分组下可放任意多个槽位，代码会从任意层级发现这些组件。每个可见槽位必须拥有不同的业务标识；未知或重复标识会使窗口绑定失败，不会把多个组件意外绑定到同一件装备。布局可以只显示服务中的部分槽位。

只增加场景节点不会自动扩展业务容器。务必同步定义资源的 `equipment_slots` 数组及 `size`；修改静态配置后需要重新创建会话容器或重启测试场景，已有会话不会被隐式扩容。

如果定义和场景不一致，测试台会显示具体槽位标识和节点路径，停止演示初始化并禁用添加、重置按钮。未绑定槽位关闭鼠标输入并拒绝拖放预览，错误不会再表现为调用空 Manager；修正配置后重新运行场景即可恢复。

## 正式工作区接入

### 调整背包和装备窗口的初始位置

打开 `UI/Inventory/inventory_workspace.tscn`，场景中已提供两组独立的 `Marker2D` 定位点：

```text
InventoryWorkspace
└─ Workspace
   └─ WindowPositions
      ├─ WithoutWarehouse
      │  ├─ BackpackPosition
      │  └─ EquipmentPosition
      └─ WithWarehouse
         ├─ BackpackPosition
         ├─ EquipmentPosition
         └─ WarehousePosition
```

选中并移动定位点，或在检查器的 Transform → Position 中填写坐标。两组背包、装备定位点是不同节点，可以分别调整；也可以移动各组父节点统一偏移整套布局。现有背包和装备坐标保留，新增仓库布局初始沿用原位置。

根节点导出两个 `Array[Marker2D]` 数组：

| 检查器属性 | 脚本字段 | 使用情况 |
|---|---|---|
| Window Positions | `window_positions` | 不含仓库时，默认绑定 `WithoutWarehouse` 下的背包、装备定位点 |
| Warehouse Window Positions | `warehouse_window_positions` | 包含仓库时，默认绑定 `WithWarehouse` 下的背包、装备、仓库定位点 |

每次打开时检查容器列表的 `service_type`，只要存在 WAREHOUSE 就为所有窗口使用仓库布局，否则使用常规布局。选择依据为容器类型，不依赖窗口数量或仓库所在索引；关闭仓库后再按 Tab 打开背包装备会恢复常规布局。

- 数组第 0 项对应第一个打开的容器，第 1 项对应第二个，依此类推；正式玩家默认先背包、后装备。节点名称不参与匹配。
- 新增定位点时，在对应分组中添加 `Marker2D`，再把它拖入根节点对应的数组。调整数组顺序即可更换窗口与定位点的对应关系。
- 可以在定位点的父节点上设置偏移或缩放，脚本会将定位点转换到 Workspace 坐标。
- 当前选中的数组数量不足、数组项未赋值时，相应窗口从前一个窗口的位置向右补位，间距使用 `window_gap`。数组为空时使用默认自动排列，不会混用另一套布局的定位点。
- 已有定位点直接决定初始位置，`window_gap` 仅影响自动补位。
- 定位点在每次打开界面时读取；打开后仍可拖动窗口，边界检查不会把它拉回定位点。重新打开会恢复场景定位。
- 超出工作区的初始位置仍会被限制到边界，小分辨率下仍会执行整体缩放。

这些定位点控制正式工作区中的浮动窗口位置，与 `equipment_layout.tscn` 中的装备分组和槽位布局互相独立。独立 `EquipmentLab.tscn` 的既有窗口仍直接使用其场景节点位置。

正式装备数据先由 Manager 创建。通过现有 `UIManager` 打开时，声明 `EQUIPMENT_SLOT`，工作区会选择默认装备窗口：

真实玩家已通过 `PlayerEquipmentComponent` 接通此流程，Tab 默认同时显示背包与装备栏；武器切换、HUD 与会话行为见 [equipment-gameplay.md](equipment-gameplay.md)。以下接口用于其他业务自行打开容器。

```gdscript
UIManager.open(UIId.INVENTORY, {
    "container_id": "player_equipment",
    "service_type": InventoryManager.ServiceType.EQUIPMENT_SLOT,
})
```

需要自定义布局时增加 `window_scene`，值为已加载的 `PackedScene`：

```gdscript
UIManager.open(UIId.INVENTORY, {
    "container_id": "player_equipment",
    "service_type": InventoryManager.ServiceType.EQUIPMENT_SLOT,
    "window_scene": preload("res://tests/inventory/equipment_custom_window.tscn"),
})
```

实际项目应将示例路径替换为自己的装备窗口场景。自定义场景可继承 `equipment_window.tscn`，保留统一绑定、解绑、关闭和边框拖动功能。需要同时显示背包与装备栏时，使用既有 `containers` 数组传入多个条目，每个条目可独立设置 `service_type` 与 `window_scene`。

装备定义资源 `InventoryDefinition` 现在提供 `equipment_slots` 字段，`PlayerInventorySession` 会将其传给 Manager。正式物品还需配置 `ItemConfig.Equipment`；独立测试台的演示物品不会自动加入正式目录。

## 测试内容与方法

运行装备服务与装备 UI 的独立回归：

```powershell
.\tests\inventory\run-tests.ps1 -EquipmentOnly -IncludeEquipmentUI
```

结果：服务 **300 条断言，0 失败**；装备 UI **178 条断言，0 失败**。UI 回归包含枚举资源下的类型匹配与双手互斥、两套定位节点的独立性、有无仓库切换、仓库处于首项及仅两个窗口时的类型判断、关闭重开、空数组自动排列和订阅清理。

`tests/inventory/equipment_ui_runner.tscn` 使用完整演示场景和一个继承场景，`equipment_ui_spec.gd` 通过 `Input.parse_input_event()` 发送真实鼠标和键盘事件。覆盖：

- 同一武器分组的两个槽位、新增身体槽，以及同一饰品分组的四枚独立戒指。
- 表单添加和重置、穿戴、卸下、交换以及视图刷新。
- 普通物品拒绝、错误类型替换不修改双方、双手与副手互斥。
- 装备来源的完整网格拖拽预览、禁止旋转与分割、Esc 取消。
- 继承场景中调换槽位和分组位置，修改槽位尺寸后仍按标识正确绑定和接受拖放。
- 绑定、刷新、拖放和再次绑定均不重排布局，不影响另一布局实例。
- 窗口标题拖动保持内部布局和装备数据不变。
- 默认窗口没有横纵滚动条，全部八个槽位矩形均完整位于可见区域，窗口本身不超出屏幕，滚轮不产生偏移。
- 正式 UIManager 选择默认及自定义装备窗口；布局不匹配时清理已绑定窗口与订阅，保留业务数据。
- 使用缺少身体槽定义的独立失败场景复现绑定错误，检查具体错误提示、禁用按钮、全部槽位不接收输入，以及真实拖放不修改任何容器。
- 精确调用未绑定槽位的拖放预览与落地接口，确认安全拒绝；正确配置重新绑定后恢复交互，解绑后再次拒绝。
- 场景定位数组的顺序、父节点变换、数量不足、未赋值、空数组回退，以及窗口拖动和再次打开时的初始位置恢复。

另外使用 Godot OpenGL 实际渲染并检查了演示截图，确认武器分组、多个槽位、图标、标题和状态文字显示正常。
