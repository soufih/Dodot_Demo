# UI 管理改造接入说明

本次实现将菜单、设置、地图、强化、背包工作区、死亡、结算、加载和调试控制台统一接入 `UIManager`。界面的场景路径和标志集中登记在 `_register_defaults`，注册类型为 `UIConfig`，标识为 `UIId`。现有场景资源位置保留，新增公共类型放在 `Script/UI_Script/Core`，共享主题放在 `UI/Themes`。

## 窗口入口

```gdscript
UIManager.open(UIId.SETTINGS)
UIManager.toggle(UIId.MAP)
UIManager.close(UIId.SETTINGS)
UIManager.close_top()
```

`open(id, payload = {}, owner = null, instance_key = "")` 同步完成实例挂载和 `ready`，失败返回 `null`。重复打开正在显示的实例只置顶，不重复绑定业务数据，也不自动选择控件。关闭后缓存的窗口再次打开会重新执行 `on_open`。

SCENE 窗口默认归 `current_scene` 所有，`keep_alive` 只决定关闭后是否缓存，不改变所属场景。管理器通过 `tree_exiting` 自动清理活动窗口、隐藏缓存、订阅和状态请求。嵌套窗口调用时可用 `UIManager.scene_owner(self)` 取得原所属场景，不能将常驻管理器当作关卡 owner。

场景在 `_ready` 中调用 `configure_scene(self, allowed_ids)` 声明可用窗口。主菜单只启用设置，家园启用地图和强化，关卡启用暂停、设置、背包及结果界面。运行期间需要提前创建隐藏实例时可以调用 `prepare`。

## 配置和生命周期

| 类别 | 层值 | 暂停游戏 | 阻止角色输入 | 普通快捷键 |
| --- | --- | --- | --- | --- |
| HUD | 10 | 否 | 否 | 不参与返回栈 |
| 地图 强化 背包 | 20 | 否 | 是 | 保留开关和返回 |
| 暂停 设置 | 30 | 是 | 是 | 返回关闭顶部 |
| 死亡 结算 | 40 | 是 | 是 | 禁止普通快捷键 |
| 加载 | 50 | 不额外申请 | 是 | 仅加载流程接收继续或失败返回 |
| 调试控制台 | 60 | 不额外申请 | 是 | 仅控制台输入框接收操作 |

注册配置还支持 `allow_multiple`、`instance_key`、`keep_alive`、`scope`、`modal`、`participates_in_back`、`close_on_cancel`。HUD、物品格、内部关卡说明等未注册组件不因继承 `BaseUI` 而自动入栈。地图仍使用跟随世界坐标的 CanvasLayer，保留原地图相机，关闭时取消延迟动画并复位。

新增窗口根节点继承 `BaseUI`，按需实现：

```gdscript
func on_open(payload: Dictionary) -> bool:
    # 绑定数据、读取快照；失败返回 false，由管理器回滚。
    return true

func on_close(reason: StringName) -> void:
    # 解除订阅、取消临时交互；不删除业务数据。
    pass

func cancel_local_interaction() -> bool:
    # 先取消拖动或局部编辑；消费返回操作时返回 true。
    return false
```

关闭按钮连接 `request_close`。界面打开、置顶、关闭和加载失败返回时均不自动设置或恢复控件焦点，用户可以点击控件或使用键盘导航选择。模态界面会清除被遮挡控件的焦点，低层界面停止处理、失去鼠标及焦点能力，透明遮罩阻止向场景穿透。返回顺序按层级和最近激活顺序计算，关闭设置后暂停菜单继续保持暂停。隐藏缓存不持续处理输入。旧 `show/hide` 只作为过渡兼容入口，新调用统一使用管理器。控制台输入框同样由用户手动选择，未选择输入框时也可按 Esc 关闭控制台。

## 暂停和输入请求

```gdscript
var token = UIManager.acquire_request(self, true, true, true)
# 参数依次为 owner、pause_game、block_gameplay、block_ui_shortcuts。
UIManager.release_request(token)
```

请求按 token 汇总，同一持有者可以同时申请多个请求；只释放自己的 token，离树时自动释放全部剩余请求。外部剧情或系统暂停也应通过该入口申请。`SceneTree.paused` 只有管理器负责写入；`is_paused`、`is_banned`、`gameplay_blocked` 是只读查询。

角色轮询和事件输入均通过 `InputController.is_banned` 判断，UI 禁用不会覆盖角色自身的 `ban_input` 状态。新锁生效时清空缓冲与残留方向。调试 `game.pause` 使用独立请求，关闭控制台不会撤销调试暂停。加载、死亡或结算状态下禁止新开控制台。

## 加载和失败恢复

保留 `SceneLoader.load_next_scene(path, wait_for_input)` 业务入口。加载窗口由常驻管理器持有，重复加载返回 `ERR_BUSY`；目标场景 `scene_changed` 后才关闭加载窗口并释放其输入请求。

死亡和结算窗口监听加载窗口的 `loading_failed`，失败时关闭本次加载、恢复按钮可用状态，保留结果界面的暂停请求，不自动聚焦按钮。普通入口加载失败后显示错误提示，按键返回原界面。错误日志是失败场景的正常输出。结果界面不再通过改写父 CanvasLayer 的层值切换显示优先级。

## 背包工作区

```gdscript
# 容器由业务系统事先创建；这里只绑定和显示。
UIManager.open(UIId.INVENTORY, {"container_id": "bag"})

# 显示多种服务类型的多个容器。
UIManager.open(UIId.INVENTORY, {"containers": [
    {"id": "bag", "service_type": InventoryManager.ServiceType.GRID},
    {"id": "chest", "service_type": InventoryManager.ServiceType.SLOT},
]})
```

工作区作为一个全局窗口参与返回栈，内部容器窗口自行拖动和置顶。关闭时取消拖动、解绑并释放局部视图，业务容器与物品不受影响。空 payload 显示空状态，不创建演示物品或新容器。现有 InventoryLab 仍可独立运行；本次没有新增游戏背包快捷键或背包业务创建规则。

## 兼容处理

项目原有武器控制器、武器 HUD、切换武器和死亡脚本引用 `EquipmentSlotSystem`，但当前仓库没有该 Autoload。相关调用改为可选节点查询：存在时沿用原业务接口，缺失时显示空装备并跳过对应操作。未另建装备系统。暂停菜单的存档按钮原本引用空实例，目前禁用，待存档模块接入后再启用。

## 验证

首次使用新检出目录时，先在 Godot 中完成资源导入。自动回归入口如下，均输出 `assertions` 与 `failures`：

- `tests/ui/runner.tscn`：真实场景、Esc 和点击事件、嵌套暂停、焦点、输入请求叠加、所属场景释放、地图取消、背包订阅、结果互斥、加载失败与跨场景成功。
- `tests/inventory/runner.tscn`：原有背包业务与不变量回归。
- `tests/inventory/ui_runner.tscn`：原有背包拖放、滚动、旋转、堆叠与分割回归。

Windows 可运行 `tests/ui/run_tests.ps1 -GodotPath "实际 Godot 可执行文件路径"`，脚本等待引擎完成、核对结果标记并拒绝预期失败区间以外的错误。渲染检查可通过 UI 测试入口附加 `-- --ui-capture=绝对图片路径`，使用真实渲染器生成暂停与设置叠加截图。

UI 管理回归包含不自动聚焦、保留手动选择、关闭后不恢复焦点，以及控制台无焦点时的 Esc 操作。各套件最新断言数与结果见对应测试日志。设置界面另以两种窗口尺寸进行实际渲染检查。
