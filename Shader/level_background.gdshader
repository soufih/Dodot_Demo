shader_type canvas_item;
render_mode unshaded;

uniform sampler2D background_texture : filter_nearest, repeat_enable;
uniform float layer_depth = 0.70;
uniform bool effects_only = false;
uniform vec2 camera_position = vec2(0.0);
uniform vec2 camera_zoom = vec2(1.0);
uniform vec2 viewport_size = vec2(1152.0, 648.0);
uniform float texture_scale = 1.5;
uniform float perspective_strength = 0.08;
uniform float fog_strength = 0.035;
uniform float elapsed = 0.0;

vec2 layer_uv(vec2 screen_position, float depth) {
	vec2 tile_size = vec2(textureSize(background_texture, 0)) * max(texture_scale, 0.001);
	vec2 p = screen_position / max(camera_zoom, vec2(0.001));
	// 画面边缘比中心略快，形成轻微的透视展开；不变形玩法层。
	p.x *= 1.0 + perspective_strength * depth * abs(p.y / tile_size.y);
	vec2 uv = (p + camera_position * vec2(depth, depth * 0.65)) / tile_size + vec2(0.5);
	// 垂直镜像让洞顶/洞底在循环边界连续，支持上下拼接与任意窗口尺寸。
	uv.y = 1.0 - abs(mod(uv.y, 2.0) - 1.0);
	return uv;
}


void fragment() {
	vec2 p = (UV - vec2(0.5)) * viewport_size;
	vec2 fog_p = p / max(camera_zoom, vec2(0.001)) + camera_position * 0.25;
	float fog = 0.5 + 0.25 * sin(fog_p.x * 0.004 + elapsed * 0.12)
		+ 0.25 * sin(fog_p.y * 0.007 - elapsed * 0.08);

	// 稀疏的漂浮微粒，固定世界基准，不调用玩法随机数生成器。
	vec2 dust_p = (fog_p + vec2(elapsed * 3.0, elapsed * 5.0)) / 96.0;
	vec2 cell = floor(dust_p);
	float seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec2 point = vec2(seed, fract(seed * 17.13));
	float dust = (1.0 - smoothstep(0.008, 0.025, length(fract(dust_p) - point)))
		* step(0.82, seed) * (0.5 + 0.5 * sin(elapsed + seed * 6.283));
	if (effects_only) {
		float alpha = clamp(fog * fog_strength + dust * 0.2, 0.0, 1.0);
		COLOR = vec4(0.30, 0.43, 0.46, alpha);
	} else {
		COLOR = texture(background_texture, layer_uv(p, layer_depth));
	}
}
