extends Node2D


@export var Ani: AnimationPlayer
@export var PlayerAni: AnimationPlayer
@export var Owner:CharacterBody2D
@export var WeaponNode:Node2D
@export var Hitbox:Area2D
@export var WeaponTexture:Sprite2D
@export var ComboAnimations: Array[StringName] = [&"Attack", &"Attack2", &"Attack3", &"Attack4"]

var Weapon: WeaponPorperty
var Context:WeaponContext
var ComboCount:int
const Type:Dictionary[int, String] = {
	ENUM.WeaponType.Sword : "Sword",
	ENUM.WeaponType.Blade : 'Blade',
	ENUM.WeaponType.Staff : 'Staff',
	ENUM.WeaponType.Bow : 'Bow'
}


func _ready() -> void:
	if !EquipmentSlotSystem.current_weapon_changed.is_connected(_on_current_weapon_changed):
		EquipmentSlotSystem.current_weapon_changed.connect(_on_current_weapon_changed)
	var WeaponName = ResourceManager.get_item_name(EquipmentSlotSystem.CurrentWeapon)

	Weapon = WeaponManager.get_weapon_porperty(WeaponName)
	Ani.play("Reset")


func _exit_tree() -> void:
	EquipmentSlotSystem.current_weapon_changed.disconnect(_on_current_weapon_changed)


func _on_current_weapon_changed():
	get_weapon()

func get_weapon()->bool:
	var WeaponName = ResourceManager.get_item_name(EquipmentSlotSystem.get_current_weapon())
	Weapon = WeaponManager.get_weapon_porperty(WeaponName)
	if Weapon == null:
		return false
	var WeaponId = EquipmentSlotSystem.get_current_weapon()
	WeaponTexture.texture = ResourceManager.get_item_icon(WeaponId)
	return true

func _on_hero_on_attack(CCount:int) -> void:
	if Weapon == null && !get_weapon():
		return
	ComboCount = CCount % Weapon.MaxCombo
	Context = create_context()
	before_attack()

##结束攻击后复位
func _on_hero_end_attack() -> void:
	if Weapon == null:
		return
	Ani.play("Reset")


func _on_hero_breaked() -> void:
	Ani.play("Reset")


func before_attack():
	if Weapon == null:
		return
	for action:WeaponAction in Weapon.BeforeAttack:
		await action.execute(Context)
	
	PlayerAni.speed_scale = Weapon.AttackSpeed
	Ani.speed_scale = Weapon.AttackSpeed
	
	var AniName:String = Type[Weapon.Type]+ComboAnimations[ComboCount]
	if PlayerAni && PlayerAni.has_animation(AniName):
		PlayerAni.play(AniName)
	if Ani && Ani.has_animation(AniName):
		Ani.play(AniName)


func during_attack():
	if Weapon == null:
		return
	for action:WeaponAction in Weapon.DuringAttack:
		await action.execute(Context)


func after_attack():
	if Weapon == null:
		return
	for action:WeaponAction in Weapon.AfterAttack:
		await action.execute(Context)


##创建上下文供每个攻击动作使用
func create_context():
	return WeaponContext.new(
		Weapon,
		Owner,
		WeaponNode,
		Hitbox,
		ComboCount
	)
