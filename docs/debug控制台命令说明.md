# Debug 控制台命令说明

本文记录当前 `Script/Gameplay/Debug/DebugTool.gd` 注册的 15 个内建命令，以及它们的参数、默认行为与使用示例。运行时输入 `help` 可查看当前注册的命令。

## 1. 打开控制台与输入规则

- 在调试构建中运行游戏，按反引号键（键盘左上角、数字 1 左侧的键）切换控制台。
- 打开后点击输入框，输入命令并按 Enter 执行；按 Esc 关闭控制台。
- 每次提交执行一条命令，参数之间用空格分隔；不支持用分号串联多条命令。
- 下文的 `<参数>` 表示必填，`[参数]` 表示可选，输入时不包含尖括号或方括号。
- 命令名不区分大小写；容器 ID、资源路径等参数应按实际配置填写。
- 参数包含空格时，可使用双引号或单引号包裹，例如 `inventory.add "旅行 背包" 21 5`。
- 反斜杠用于转义下一个字符；场景路径建议使用 `res://` 和正斜杠。

## 2. 命令速查

| 命令语法 | 功能 | 示例 |
| --- | --- | --- |
| `help [command]` | 列出全部命令，或查看某个命令的帮助；别名为 `?` | `help inventory.add` |
| `clear` | 清空控制台输出，保留输入历史 | `clear` |
| `echo <text>` | 回显输入文本 | `echo "debug ready"` |
| `services` | 列出当前有效的调试服务及其节点路径或对象类型 | `services` |
| `game.pause [on\|off\|toggle]` | 请求暂停、释放暂停请求或切换；默认 `toggle` | `game.pause on` |
| `scene.current` | 输出当前活动场景的资源路径 | `scene.current` |
| `scene.load <res://scene.tscn>` | 切换到指定场景 | `scene.load res://Scene/Inventory/InventoryGameplayLab.tscn` |
| `ui.toggle <equipment\|map\|pause>` | 切换强化、地图或暂停界面 | `ui.toggle map` |
| `item.drop <item_id> [amount]` | 在玩家位置生成掉落物；数量默认 `1` | `item.drop 21 10` |
| `inventory.containers` | 按 ID 排序列出当前背包服务已注册的容器 | `inventory.containers` |
| `inventory.add <container_id> <item_id> [amount]` | 自动寻找空位，向指定容器添加一栈物品；数量默认 `1` | `inventory.add player_backpack 21 10` |
| `player.info` | 显示玩家当前/最大生命值和法力值 | `player.info` |
| `player.hp <value>` | 设置玩家当前生命值 | `player.hp 50` |
| `player.heal [amount]` | 恢复指定生命值；省略数量时恢复到最大生命值 | `player.heal 20` |
| `player.god [duration]` | 触发临时无敌；可指定整数秒数 | `player.god 10` |

## 3. 向指定容器添加物品

先查询容器，再使用查询结果中的 ID：

```text
inventory.containers
inventory.add player_backpack 21 10
inventory.add player_backpack 10
```

以上示例分别查询已注册容器、添加物品 `21` 共 `10` 个、添加物品 `10` 共 `1` 个。物品 ID 来自物品配置的 `ItemID`，不是物品实例 ID，也不是物品名称。正式物品目录为 `Rescource/Data/Catalog/ItemCatalog.tres`。

### 容器 ID 与显示名称

命令使用 `InventoryDefinition.container_id`，窗口标题使用的 `display_name` 不参与容器定位。当前正式配置如下；是否可用以运行时查询结果为准。

| 容器 ID | 显示名称 | 配置资源 |
| --- | --- | --- |
| `player_backpack` | 玩家背包 | `Rescource/Data/Inventory/player_backpack.tres` |
| `player_equipment` | 装备栏 | `Rescource/Data/Inventory/player_equipment.tres` |
| `warehouse_home` | 仓库 | `Rescource/Data/Inventory/home_warehouse.tres` |

```text
inventory.add player_backpack 21 10
inventory.add warehouse_home 21 10
```

容器须已由对应角色组件、仓库交互物或其他业务模块创建。`inventory.add` 不会创建容器，也不会打开其界面。

### 添加规则

- `item_id` 必须是非负整数且存在有效配置，`amount` 必须是正整数。
- 一次命令添加一整栈，数量须符合物品配置的 `MaxStack`；不会自动拆成多栈，也不会自动合并到已有栈。
- 普通背包按行寻找空格；网格背包和仓库按物品完整占格尺寸寻找位置，可旋转物品必要时尝试另一方向。
- 装备栏还会校验装备类型、槽位适配及互斥规则，并寻找可用的适配槽。
- 成功后通过正常容器变更通知刷新界面，输出实际放置位置；无空间、配置不合法或槽位不适配时返回失败原因，不提交添加。
- 默认 `inventory` 服务连接全局 `InventoryManager`。独立测试台可能使用自己的 Manager，其容器不一定出现在控制台列表中。

## 4. 掉落物与玩家状态

### `item.drop`

```text
item.drop 10
item.drop 21 10
```

在 `Hero` 分组中第一个玩家的位置生成世界掉落物，不直接放入背包。数量默认 `1`，必须为正整数；物品须能通过资源服务查到。

此命令需要 `resources` 与 `dropped_items` 服务。掉落组件的 `register_debug_drop_service` 选项控制是否注册掉落服务，正式 Hero 场景已启用该选项。

### 玩家命令

```text
player.info
player.hp 50
player.heal 20
player.heal
player.god 10
```

这些命令均查找 `Hero` 分组中的第一个玩家，并要求目标支持对应属性接口或信号。

| 命令 | 参数与实际行为 |
| --- | --- |
| `player.hp <value>` | 接受浮点数，直接交给玩家生命值设置接口；命令层不额外校验生命值范围。 |
| `player.heal [amount]` | 接受浮点数，按“当前生命 + 数量”计算并限制不超过最大生命；省略参数时补满。命令层不拒绝负数，正常治疗请使用正数。 |
| `player.god [duration]` | 可选时长为整数，单位为秒。传入时会修改玩家的 `GodModeTimer`，再触发 `god_mode` 信号；省略时使用该属性的当前值。建议传入正整数。无敌到时自动结束，并非永久开关。 |

## 5. 场景、界面与暂停

### 场景切换

```text
scene.current
scene.load res://Scene/Inventory/InventoryGameplayLab.tscn
```

`scene.load` 仅接受一个已存在的 `PackedScene` 资源路径。切换使用场景树的 `change_scene_to_file`，不经过业务层 `SceneLoader` 的完整加载流程，适合直接进入测试场景。

### 界面开关

| 输入 | 对应界面 |
| --- | --- |
| `ui.toggle equipment` | 装备强化界面，不是玩家背包或装备槽窗口 |
| `ui.toggle map` | 地图界面 |
| `ui.toggle pause` | 暂停菜单 |

实际能否打开仍受 `UIManager` 的场景配置和界面规则控制。当前没有通过此命令打开背包或仓库的参数。

### 暂停请求

```text
game.pause on
game.pause off
game.pause toggle
```

省略参数等同于 `toggle`。`off` 仅释放调试工具自己持有的暂停请求；若暂停菜单等其他界面仍要求暂停，场景树可能继续暂停。控制台可在暂停期间处理输入。

## 6. 常见问题

| 输出或现象 | 检查方法 |
| --- | --- |
| 未知命令 | 输入 `help` 查看实际命令名，或输入 `help inventory.add` 查看用法。 |
| 命令包含未闭合的引号 | 补齐参数两侧的单引号或双引号。 |
| 调试服务未连接 | 输入 `services`；确认对应 Autoload 或场景组件已初始化并注册服务。 |
| 找不到玩家节点 | 确认当前场景有属于 `Hero` 分组的玩家。 |
| 当前没有已注册的容器 | 进入带背包组件的角色场景或带仓库交互物的场景，再查询。 |
| 容器不存在或添加失败 | 使用 `inventory.containers` 返回的 ID，检查物品 ID、堆叠上限、空间及槽位规则。不要把窗口显示名称当作容器 ID。 |
| 发布后没有控制台界面 | 控制台 UI 仅在 `OS.is_debug_build()` 为真时创建。 |

## 7. 维护入口

| 文件 | 职责 |
| --- | --- |
| `Script/Gameplay/Debug/DebugTool.gd` | 内建命令注册、参数解析、服务路由与结果输出 |
| `Script/UI_Script/Debug_UI/debug_console_ui.gd` | 命令输入、历史记录与输出展示 |
| `Script/UI_Script/Debug_UI/console_container.gd` | 控制台显示与关闭 |
| `Script/Gameplay/Inventory/InventoryManager.gd` | 容器查询和快速添加接口 |

新增或调整命令时，同步更新本说明中的速查表、参数默认值和示例。模块动态注册的命令以运行时 `help` 列表为准。
