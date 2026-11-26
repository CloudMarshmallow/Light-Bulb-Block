shader_type canvas_item;
// 太阳光束：固定从太阳位置（UV 坐标）放射，条纹不随时间/风晃动。
// 太阳位置、颜色、强度由太阳系统按本地时间驱动（每小时缓慢变化）。

uniform vec2 sun_uv = vec2(0.5, 0.03);
uniform float intensity : hint_range(0.0, 2.0) = 0.8;
uniform vec4 ray_color : source_color = vec4(1.0, 0.92, 0.72, 1.0);

void fragment() {
	vec2 d = UV - sun_uv;
	float r = length(d);
	float ang = atan(d.y, d.x);

	// 固定的角度条纹
	float bands = 0.5 + 0.5 * sin(ang * 32.0);
	bands = pow(max(bands, 0.0), 2.6);

	float near_sun = smoothstep(0.0, 0.30, r);
	float far_fade = smoothstep(1.15, 0.25, r);
	float mask = bands * near_sun * far_fade;
	float glow = smoothstep(0.18, 0.0, r) * 0.50;

	COLOR = vec4(ray_color.rgb, clamp(mask * intensity * 0.30 + glow * intensity, 0.0, 1.0));
}
