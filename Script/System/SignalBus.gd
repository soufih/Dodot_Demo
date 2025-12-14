extends Node

#角色属性信号
signal health_changed
signal state_changed
signal mana_changed
signal toughness_changed
signal god_mode

#背包信号
signal backpack_changed#释放信号后更新UI
signal quick_add#快速添加物品后触发

#装备栏信号
signal equipment_slot_changed
