extends RefCounted
class_name ENUM

##伤害类型
enum DamageType {Physics, Fire, Ice}
enum AbnormalType {}

##房间属性
enum Type {Start, Corridor, Room, End}
enum Location {LEFT,RIGHT,TOP,BOTTOM}

##物品属性
enum ItemType {
	None,
	Weapon,
	Materials,
	Relic,
	Equipment
}

##状态类型
enum STATUS {
	EnhanceHealth,
	EnhanceStrength,
	ContinuousRecovery,
	Weakness,
}

##敌人级别
enum EnemyLevel{
	Normal,
	Elite,
	Boss,
}

## 武器类型
enum WeaponType{
	Sword,
	Blade,
	Staff,
	Bow,
}
