# EquipmentSlotService 使用与测试

## 范围

`EquipmentSlotService` 直接继承抽象类 `InventoryService`，实现装备槽存储、规则检查和事务接口。装备 UI 已通过独立场景接入，布局方法见 [equipment-ui.md](equipment-ui.md)；正式玩家、武器与 HUD 的接入见 [equipment-gameplay.md](equipment-gameplay.md)。服务本身不处理角色属性、等级职业条件、武器场景或外观，也不自动卸下冲突装备。

`InventoryManager.ServiceType` 已增加 `EQUIPMENT_SLOT`，原 `SLOT = 0`、`GRID = 1` 保持不变。通过统一 `create_container()` 工厂传入槽位配置即可创建装备栏，已有 `register_container()` 手动注册方式也保留。命令路由与 `InventoryTransaction` 沿用现有抽象契约。

## 配置

- `EquipmentSlotDefinition`：`slot_id` 是唯一槽位标识，`accepted_types: Array[ENUM.EquipmentType]` 是可接收的装备类型，`auto_equip_priority` 越小越优先；同优先级按配置数组顺序选择。
- `EquipmentItemConfig`：`equipment_type: ENUM.EquipmentType` 是装备类型，检查器中使用枚举下拉选择；`blocked_slot_ids` 声明穿戴后必须留空的槽位。
- `ItemConfig.Equipment`：可选的装备配置。未填写时仍可进入普通背包，但不能进入装备栏。装备栏要求配置 `MaxStack = 1`、实例数量为 `1`。

槽位数组映射为 N × 1 的内部矩阵，数组第 i 项对应 `(i, 0)`。业务使用 `InventoryManager.get_slot_position(container_id, slot_id)` 或 `get_slot_id(container_id, pos)` 转换标识与坐标，两者返回 `InventoryResult`，映射值在成功结果的 `payload` 中。未知容器返回 `CONTAINER_NOT_FOUND`，非装备容器返回 `UNSUPPORTED`。装备 UI 按槽位标识绑定，可以独立布局，不需要按照矩阵排列。

槽位配置在构造时深复制，外部修改资源不会改变已创建服务的槽位规则。物品配置查询仍遵循现有服务的 Callable 注入方式。

枚举集中定义在 `Script/Gameplay/System/Enum.gd`。以下编号会写入 `.tres`，后续新增类型应追加编号，不能重新排序已有编号。

| `ENUM.EquipmentType` | 编号 | 含义 |
|---|---|---|
| `NONE` | 0 | 未配置，禁止穿戴，也不能作为槽位允许类型 |
| `ONE_HAND` | 1 | 单手武器 |
| `TWO_HAND` | 2 | 双手武器 |
| `SHIELD` | 3 | 盾牌 |
| `HELMET` | 4 | 头盔 |
| `BODY_ARMOR` | 5 | 身体防具 |
| `RING` | 6 | 戒指 |
| `RELIC` | 7 | 饰品 |

物品与槽位共享同一枚举，例如：

```gdscript
var rule := EquipmentItemConfig.new()
rule.equipment_type = ENUM.EquipmentType.ONE_HAND
var slot := EquipmentSlotDefinition.new()
slot.slot_id = &"main_hand"
slot.accepted_types = [ENUM.EquipmentType.ONE_HAND, ENUM.EquipmentType.TWO_HAND]
```

`slot_id` 与 `blocked_slot_ids` 继续使用 `StringName`，用于区分主手、副手及多个同类槽位。演示物品目录、正式和演示槽位定义及测试资源均已从字符串迁移到枚举编号；自定义旧资源也需要重新选择枚举类型。`ItemConfig.Equipment` 为空仍表示普通物品，类型转换不会自动为其创建装备规则。

例如双手武器类型设为 `ENUM.EquipmentType.TWO_HAND`，主手槽接受此类型，物品的 `blocked_slot_ids` 包含副手槽标识。副手已有装备时不能穿戴双手武器，双手武器已穿戴时也不能再添加副手；冲突不会隐式卸下物品。阻塞当前自身槽位会失败；当前布局没有的阻塞槽位标识忽略。

## 初始化与调用

槽位和物品配置可保存为 `.tres`。以下代码只创建数据服务，不创建任何场景节点或 UI 控件：

```gdscript
## 用已加载的槽位资源通过统一工厂创建装备栏，返回初始化或注册结果。
func register_equipment(slots: Array[EquipmentSlotDefinition]) -> InventoryResult:
    return InventoryManager.create_container(
        "player_equipment", Vector2i(slots.size(), 1),
        InventoryManager.ServiceType.EQUIPMENT_SLOT, slots)
```

旧普通背包和网格背包的三参数创建调用保持兼容。第四参数 `equipment_slots` 仅供装备栏使用，向普通或网格容器传入非空槽位配置会返回 `RULE_REJECTED`。装备栏缺少配置、尺寸不符、槽位标识重复时创建失败，不在 Manager 注册表中留下容器。

注册成功后，通过 `InventoryManager` 执行正式写操作和获取变更通知。先获取并检查槽位映射结果，再将坐标传给统一接口：

| 操作 | 接口与行为 |
|---|---|
| 穿戴到空槽 | `switch_to_container`，从背包转移到装备栏 |
| 替换装备 | `swap_between_containers`，两件物品必须都能进入对方原位置 |
| 卸下 | `switch_to_container`，明确指定背包目标位置，放不下时双方不变 |
| 自动选择空装备槽 | `quick_add_to_container`，按配置优先级选择，不替换已有物品 |
| 已有背包物品自动穿戴 | 需要后续实现事务级自动选槽；不能先移除再调用 `quick_add_to_container`，后者会创建新实例 |

服务本身不会发信号，通知由 Manager 在提交成功后统一发送。直接持有服务可以进行只读预览；对已注册容器的正式操作应通过 Manager，避免绕过通知和事务协调。

## 操作语义

- 每个装备实例只占一格，忽略背包 `GridSize`；保留转入实例的方向元数据。
- `can_place()` 会在暂存副本中释放自身旧槽，再检查新槽是否适配。
- `move()`、`swap()`、`rotate()` 不主动改变装备方向；保持原方向为无变化成功，要求改变方向返回 `UNSUPPORTED`。
- 堆叠、分割及其预览、暂存接口均返回 `UNSUPPORTED`，不改真实或暂存状态。
- 所有添加路径检查装备类型、数量、目标占用、实例重复归属以及双向阻塞关系。
- `validate_plan()` 重建最终状态并校验类型、互斥与矩阵一致性，事务不能绕过公开添加规则。
- 过期计划返回 `STALE_STATE`；本地提交故障恢复原快照，跨容器故障由现有事务协调器恢复双方。

## 测试方法与结果

在项目根目录运行：

```powershell
.\tests\inventory\run-tests.ps1 -EquipmentOnly
```

首次新增脚本后，如需刷新 Godot 类缓存，可加 `-Import`。不带 `-EquipmentOnly` 时，装备测试也会随原有领域测试执行。

测试文件为 `tests/inventory/equipment_spec.gd`，故障注入服务为 `equipment_fault_service.gd`。测试使用独立物品资源夹具，不修改正式物品目录，不以代码创建场景节点。

覆盖内容：

1. 空、重复、非法槽位配置，N × 1 尺寸约束、名称映射及输入资源隔离。
2. 普通物品、可堆叠物品、错误数量、错误类型、越界和重复实例拒绝。
3. 单格占用、方向保留、只读预览、查询副本隔离及移动和交换原子性。
4. 自动装备优先级、稳定排序、跳过不兼容槽位及满槽不替换。
5. 双手与副手双向互斥；伪造最终计划、反转记录顺序也不能绕过校验。
6. 堆叠、分割和方向修改的所有服务入口明确拒绝，失败不修改计划或版本。
7. 旧版本拒绝、快照恢复、本地真实写入后故障回滚。
8. 真实 Manager 注册、网格背包穿戴、替换、卸下、双边故障恢复及成功/失败通知。
9. Manager 工厂创建、非法配置失败无残留、旧创建接口兼容、槽位映射查询和统一命令路由。
10. 枚举默认 NONE、非法枚举值拒绝、七种合法类型实际穿戴、物品及槽位数组的检查器枚举提示，以及迁移资源加载验证。

本次独立测试结果：**300 条断言，0 失败**。装备 UI 为 **178 条断言，0 失败**。

正式玩家接入测试在首次穿戴处失败：当前正式 `ItemCatalog.tres` 的武器缺少 `ItemConfig.Equipment`，服务按原有规则拒绝穿戴。这是迁移前已确认的物品配置缺失；本次保留空值，不自动猜测装备类型。补齐正式物品规则后，再运行 `-IncludeEquipmentGameplay` 验证完整战斗流程。

全量回归另外发现 4 条既有领域断言及 3 条 UI 断言失败，涉及当前 `CanRotate` 默认值、演示物品旋转配置与旧测试预期不一致。本次保留原有配置，没有将它们纳入装备服务修改。
