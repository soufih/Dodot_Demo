# 玩家初始物品与合成演示

## 默认内容

新游戏的主武器槽 `main_hand` 装备物品 **10（Sword）**，副武器槽 `off_hand` 装备物品 **11（Sword2）**。当前使用主武器，按 **Q** 切换到副武器。

家园仓库提供以下十种材料，每种 **20 个**，合计 **200 个、10 栈**；玩家背包初始为空：

| 物品 ID | 配置名称 | 数量 |
| --- | --- | --- |
| 20 | Material | 20 |
| 21 | Material1 | 20 |
| 22 | Material2 | 20 |
| 23 | Material3 | 20 |
| 24 | Material4 | 20 |
| 26 | Material6 | 20 |
| 28 | Material8 | 20 |
| 29 | Material9 | 20 |
| 210 | Material10 | 20 |
| 211 | Material11 | 20 |

这批材料足以将当前目录中的五份配方各执行一次，包括材料 21、23 与武器 10、11、12。

## 演示步骤

1. F5 运行项目，从主菜单开始新游戏；也可以 F6 直接运行正式家园或仓库接入测试场景。
2. 按 Tab 查看背包和装备栏，确认主、副武器已装备；关闭界面后可攻击，按 Q 切换武器。
3. 按 K 打开合成界面，直接选择配方并执行合成，无需先转移材料。当前合成系统读取家园仓库 `warehouse_home`，产物也放入该仓库。
4. 在家园靠近仓库按 E，可查看剩余材料和合成产物。

仅关闭窗口或切换场景会保留原库存，即使仓库被清空，也不会再次发放。主菜单“开始游戏”会重建会话，恢复初始装备与仓库材料。仓库接入测试台的“重置”按钮同样恢复装备、空背包和仓库材料；普通玩家接入测试台没有仓库，其重置按钮只重置背包和装备。

## 配置位置与职责

- [player_equipment.tres](../Rescource/Data/Inventory/player_equipment.tres)：装备槽及两把初始武器。
- [home_warehouse.tres](../Rescource/Data/Inventory/home_warehouse.tres)：十种初始材料及数量。
- [player_backpack.tres](../Rescource/Data/Inventory/player_backpack.tres)：保留空背包，不配置演示材料。
- [InventoryInitialItem.gd](../Script/Config/Model/ResourceManager/InventoryInitialItem.gd)：单项配置，包含 `config_id`、`quantity`、`rotated` 和可选的 `slot_id`。
- [InventoryDefinition.gd](../Script/Config/Model/ResourceManager/InventoryDefinition.gd)：通过导出的 `initial_items` 数组保存配置；可在检查器的 **Initial Items** 中增删或修改。
- [PlayerInventorySession.gd](../Script/Gameplay/Inventory/PlayerInventorySession.gd)：只在创建新容器时读取配置，通过 Manager 添加物品。已有会话直接复用；若初始化失败，注销新建容器，避免保留半成品。
- [WarehouseInteractable.gd](../Script/Gameplay/Interactable/WarehouseInteractable.gd)：直接运行家园或仓库测试场景时，也通过相同会话入口创建仓库并发放初始材料。

装备项填写稳定槽位标识 `main_hand` / `off_hand`，无需依赖槽位数组索引。仓库材料项的 `slot_id` 留空，使用现有快速添加规则决定位置和堆叠。每一项数量应满足物品的单栈上限；需要更多时可以配置多项。初始内容均来自资源，没有新增或用脚本创建 UI 控件。

## 自动测试内容与方法

新增场景 [player_defaults_runner.tscn](../tests/inventory/player_defaults_runner.tscn)，测试脚本 [player_defaults_spec.gd](../tests/inventory/player_defaults_spec.gd)。分别直接运行家园及通过真实主菜单、加载屏进入家园，检查：

1. 两个命名装备槽分别为 10、11，当前与备用选择正确，攻击控制器和 HUD 同步。
2. 背包为空，仓库十种材料各 20 个；重复绑定不会修改实例、数量和容器版本。
3. 切换到副武器后显式重置装备，重新选择主武器。
4. 直接预览并执行全部五份正式配方，核对材料消耗及产物数量。
5. 合成后重载家园，装备和仓库完整快照保持不变；清空仓库后再次重载，也不会补发材料。
6. 再次从主菜单开始游戏，恢复初始装备和仓库材料，替换旧库存。
7. 非法数量或不存在的装备槽导致初始化失败时，不残留半成品容器；修正配置后能够重试。

在项目根目录运行 PowerShell（可通过 `-GodotPath` 指定引擎路径）：

```powershell
.\tests\inventory\run-tests.ps1 -EquipmentOnly -IncludePlayerDefaults
.\tests\inventory\run-tests.ps1 -WarehouseOnly -IncludeWarehouseGameplay
.\tests\crafting\run-tests.ps1 -IncludeUI
```

也可以直接用 Godot 无头运行 `res://tests/inventory/player_defaults_runner.tscn`。测试日志位于 `Log/`，新增完成标记为 `PLAYER_DEFAULTS_TEST_RESULT`。

2026-11-10，Godot 4.7.2 本次验证结果：

| 测试 | 断言数 | 失败数 |
| --- | ---: | ---: |
| 玩家初始物品及合成演示 | 87 | 0 |
| 背包完整领域测试 | 17438 | 0 |
| 装备服务 | 300 | 0 |
| 仓库服务 | 169 | 0 |
| 仓库 UI | 47 | 0 |
| 仓库测试台 UI | 44 | 0 |
| 仓库真实角色接入 | 80 | 0 |
| 玩家拾取测试台 | 11 | 0 |
| 合成服务 | 121 | 0 |
| 合成 UI | 41 | 0 |
| 装备真实角色接入 | 102 | 9 |

装备真实接入的九项失败集中在原有武器 **15（Bow）** 的双手穿戴与后续同步用例：正式物品目录未提供该物品的 `Equipment` 配置，导致无法穿戴并产生后续连带失败。本次默认武器 10、11 的初始化、切换、实际攻击及重置用例均通过；未修改武器 15 的物品定义。

合成 UI 测试的导航材料改用快速添加返回的实际锚点进行布置与清理，适应当前多格材料尺寸，避免固定边缘坐标使测试物品添加失败。
