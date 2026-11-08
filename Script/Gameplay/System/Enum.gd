extends RefCounted
class_name ENUM


##伤害类型
enum DamageType {Physics, Fire, Ice, Null}
enum AbnormalType {}

##房间属性
enum Type {Start, Corridor, Room, End, Treasure, Event}
enum Location {LEFT,RIGHT,TOP,BOTTOM}

##物品属性
enum ItemType {
	None,
	Weapon,
	Materials,
	Relic,
	Equipment
}

## 装备适配类型；数值写入资源文件，新增类型时追加编号，避免改变已有资源含义。
enum EquipmentType {
	NONE = 0,
	ONE_HAND = 1,
	TWO_HAND = 2,
	SHIELD = 3,
	HELMET = 4,
	BODY_ARMOR = 5,
	RING = 6,
	RELIC = 7,
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
