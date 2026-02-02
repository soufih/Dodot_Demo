extends Node

var StatusTimer: Dictionary[String, Timer]

##设置状态计时器
func set_status_timer(index: String):
	if !StatusTimer.has(index):
		StatusTimer[index] = Timer.new()
		StatusTimer[index].one_shot = true
		add_child(StatusTimer[index])

##增加最大生命值
func enhance_max_health(Target:BaseCharacter, Duration:float, DeltaMaxHealth:float):
	#检测非法情况
	if !Target || Duration <= 0:
		return

	#在目标状态栏中添加状态
	Target.add_new_status(ENUM.STATUS.EnhanceHealth, Duration, 1)
	
	var index:String = Target.name+"status"+str(ENUM.STATUS.EnhanceHealth)
	set_status_timer(index)
	
	#施加效果
	var current:float
	if StatusTimer[index].is_stopped():
		current = Target.get_character_max_health()
		Target.set_character_max_health(current+DeltaMaxHealth)
	
	StatusTimer[index].start(Duration)
	
	#持续时间结束后移除计时器和效果
	await StatusTimer[index].timeout
	StatusTimer.erase(index)
	current = Target.get_character_max_health()
	Target.set_character_max_health(current-DeltaMaxHealth)
