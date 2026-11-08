extends Node2D
## 生命周期测试中的真实场景作用域，角色组件在场景重建后绑定同一会话背包。

## 配置正式 UIManager 的场景归属，以验证切关自动关闭窗口但保留业务数据。
func _ready() -> void:
	UIManager.configure_scene(self, [UIId.INVENTORY, UIId.PAUSE, UIId.SETTINGS, UIId.DEATH, UIId.END])
