class_name WeaponContext
extends RefCounted

# 当前武器的数据配置
var weapon_data: WeaponPorperty

# 攻击者
var attacker: CharacterBody2D

# 武器节点
var weapon_node: Node2D

#检测箱
var hitbox: Area2D

#连击数
var combo_count:int

func _init(
	data: WeaponPorperty,
	owner_node: CharacterBody2D,
	weapon: Node2D,
	box: Area2D,
	ccount:int
):
	weapon_data = data
	attacker = owner_node
	weapon_node = weapon
	hitbox = box
	combo_count = ccount
