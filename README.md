# Dodot Demo

# Dodot Demo
基于 **Godot 4 与 GDScript** 独立开发的 2D 动作冒险游戏原型，围绕关卡探索、角色战斗、资源收集与合成制作实现核心玩法。项目用于实践游戏系统设计与工具开发，使用 Codex 辅助功能开发，目前仍在持续迭代。

## 主要功能

- **角色与敌人行为**：通过有限状态机和信号机制组织角色行为，支持移动、跳跃、冲刺、连击、受击，以及敌人的追击与攻击。
- **武器与弹幕**：使用资源配置与动作组合描述攻击行为，支持不同武器和弹幕形态，并通过对象池复用弹幕节点。
- **关卡生成**：根据模板、房间类型与出入口匹配场景并进行拼接，支持房间重叠检测、走廊补接和可视化模板编辑。
- **物品与装备**：实现网格背包、装备栏和仓库，支持物品拾取、拖拽旋转、堆叠拆分、跨容器转移与装备穿脱。
- **采集与合成**：支持采集物交互及仓库材料合成，校验材料数量与产物容量，操作失败时恢复原有库存。
- **界面与反馈**：包含主菜单、设置、地图、小地图、技能冷却、死亡与关卡结算界面，以及调试控制台。

## 运行方式

项目配置使用 **Godot 4.7**，渲染模式为 **Forward Plus**。

1. 在 Godot 项目管理器中导入根目录的 `project.godot`。
2. 打开项目，等待首次资源导入完成。
3. 按 **F5** 运行项目，在主菜单中开始游戏。

也可打开下列场景，按 **F6** 单独运行：

- [背包交互测试场景](Scene/Inventory/InventoryGameplayLab.tscn)：体验真实角色拾取、背包与装备交互。
- [仓库交互测试场景](Scene/Inventory/WarehouseGameplayLab.tscn)：体验玩家与世界仓库之间的物品操作。
- [关卡模板编辑器](Scene/Util/TemplateEditor.tscn)：绘制、编辑和保存关卡模板。

## 基本操作

| 按键 | 操作 |
| --- | --- |
| A / D | 左右移动 |
| W / S | 攀爬时上下移动 |
| 空格 | 跳跃 |
| Shift | 冲刺 |
| 鼠标左键 | 攻击，需先装备武器 |
| Q | 切换当前使用的武器 |
| E | 拾取物品、采集或与仓库等对象交互 |
| Tab | 打开 / 关闭背包与装备栏 |
| K | 打开 / 关闭仓库合成界面 |
| M | 打开 / 关闭地图 |
| Esc | 关闭当前界面或切换暂停菜单 |

在背包界面中，左键拖动物品，拖动时按 **R** 旋转允许旋转的物品；中键拖出半栈，拖到同类物品上默认堆叠，按住 **Shift** 拖放可执行交换。

## 核心系统说明

- **人物状态机**：在 [Hero.tscn](Scene/Hero/Hero.tscn) 中通过各状态的 `NextStates` 属性配置事件与目标状态的映射，由 `StateManager` 统一接收事件并执行状态切换。
- **弹幕系统**：在 [BulletCatalog.tres](Rescource/Data/Catalog/BulletCatalog.tres) 中配置弹幕。`Spawned`、`Moving`、`Death`、`Hit` 数组分别保存对应生命周期的动作序列，扩展动作需继承 `BulletAction`。弹幕实例由 `BulletPoolManager` 统一复用与回收。
- **武器系统**：在 [WeaponPorpertyCatalog.tres](Rescource/Data/Catalog/WeaponPorpertyCatalog.tres) 中配置武器，使用 `BeforeAttack`、`DuringAttack`、`AfterAttack` 动作序列组织攻击过程，扩展动作需继承 `WeaponAction`。
- **关卡生成器**：实现位于 `Script/Gameplay/Map/`，从 `Rescource/Data/Level/LevelTemplate/` 读取模板并选择匹配的房间进行拼接。模板通过 `TemplateEditor.tscn` 编辑，可在检查器中配置房间类型。
- **背包与合成**：通过 `InventoryManager` 统一管理物品状态，由不同 Service 执行容器规则；跨容器操作与合成使用暂存、校验、提交和失败回滚流程维护数据一致性。

## 目录结构

```text
Script/       游戏逻辑、配置模型与界面脚本
Scene/        角色、敌人、关卡、交互物与工具场景
UI/           界面场景与主题
Rescource/    玩法配置、贴图及其他资源
Shader/       着色器
addons/       编辑器插件
tests/        功能与界面回归测试
docs/         系统设计文档与调试说明
```
