shader_type canvas_item;
render_mode unshaded, blend_add;

// 柔和的暖白光晕，降低核心与光束的亮度。
uniform vec4 glow_color : source_color = vec4(1.0, 0.94, 0.84, 1.0);
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.8;
uniform float brightness : hint_range(0.0, 3.0) = 6;
uniform float ray_strength : hint_range(0.0, 2.0) = 0.55;
// 放射光芒周期性收缩；速度单位为每秒循环次数，幅度为最大缩短比例。
uniform float contraction_speed : hint_range(0.0, 3.0) = 0.33333333;
uniform float contraction_amount : hint_range(0.0, 0.9) = 0.5;
instance uniform float phase_offset = 0.0;

void fragment() {
	vec2 point = UV - vec2(0.5);
	float radius = length(point);
	float angle = atan(point.y, point.x + 0.00001);
	float pulse = 0.94 + 0.06 * sin(TIME * pulse_speed + phase_offset);

	// 饱满白色核心叠加两层柔光，形成参考图中的散射效果。
	float core = exp(-radius * radius * 200.0) * 0.65;
	float inner_glow = exp(-radius * radius * 55.0) * 0.38;
	float outer_glow = exp(-radius * radius * 15.0) * 0.12;

	// 长短不一的放射光芒，细光束与宽光束交错，避免规则十字形。
	float warped_angle = angle + 0.035 * sin(angle * 5.0 + phase_offset);
	float broad_rays = pow(abs(cos(warped_angle * 12.0)), 12.0);
	float fine_rays = pow(abs(cos(warped_angle * 19.0 + 0.7)), 36.0);
	float ray_length = 0.26 + 0.12 * (0.5 + 0.5 * sin(angle * 7.0 + 1.3));
	// 缩放光芒的径向坐标，使光束整体向核心收拢，核心和柔光保持稳定。
	float contraction = 0.5 - 0.5 * cos(TIME * contraction_speed * 6.2831853 + phase_offset);
	float ray_scale = 1.0 - contraction_amount * contraction;
	float ray_radius = radius / ray_scale;
	float ray_falloff = exp(-ray_radius * 7.0) * (1.0 - smoothstep(ray_length * 0.55, ray_length, ray_radius));
	float rays = (broad_rays * 0.65 + fine_rays * 0.25) * ray_falloff * ray_strength;

	// 在贴图边界之前平滑消失，避免出现方形轮廓。
	float edge = 1.0 - smoothstep(0.38, 0.49, radius);
	float intensity = (core + inner_glow + outer_glow + rays) * edge * pulse;
	float alpha = clamp(intensity, 0.0, 1.0) * glow_color.a;
	vec3 color = mix(glow_color.rgb, vec3(1.0), clamp(core + inner_glow, 0.0, 1.0));
	COLOR = vec4(color * brightness, alpha);
}
