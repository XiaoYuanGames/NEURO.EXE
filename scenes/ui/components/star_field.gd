extends CPUParticles2D
## StarField — 紫蓝色背景星点粒子
##   缓慢漂移,颜色随生命周期在紫/青/品红之间变化

class_name StarField

func _ready() -> void:
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(640, 360)
	direction = Vector2(0.1, 0.05)
	spread = 180.0
	gravity = Vector2.ZERO
	initial_velocity_min = 8.0
	initial_velocity_max = 18.0
	scale_amount_min = 0.4
	scale_amount_max = 1.4
	color = Color(0.7, 0.5, 1.0, 0.9)
	color_ramp = _build_color_ramp()
	lifetime = 8.0
	preprocess = 4.0
	amount = 80
	speed_scale = 0.6
	# 应用粒子密度
	_apply_density()


func _build_color_ramp() -> Gradient:
	var g := Gradient.new()
	# 关键点:0 紫色, 0.5 青蓝, 1.0 品红
	g.add_point(0.0, Color(0.55, 0.20, 1.0, 0.0))
	g.add_point(0.2, Color(0.55, 0.20, 1.0, 0.9))
	g.add_point(0.6, Color(0.13, 0.82, 0.93, 0.9))
	g.add_point(1.0, Color(0.95, 0.10, 0.65, 0.0))
	return g


func _apply_density() -> void:
	var us := get_node_or_null("/root/UserSettings")
	if us:
		var d: int = int(us.get_value("particle_density", 1))
		match d:
			0: amount = 30
			1: amount = 80
			2: amount = 160
	else:
		amount = 80


func set_density(d: int) -> void:
	match d:
		0: amount = 30
		1: amount = 80
		2: amount = 160
		_: amount = 80
