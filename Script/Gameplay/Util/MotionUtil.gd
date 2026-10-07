class_name MotionUtil
extends RefCounted

## 在 move_and_slide 后查询本次移动是否撞到墙壁。
static func hit_wall(body: CharacterBody2D) -> bool:
	return body.is_on_wall()
