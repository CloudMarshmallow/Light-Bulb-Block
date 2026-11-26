extends ColorRect
## 太阳光束层：固定放射条纹（不晃动），只随太阳位置/强度/颜色变化；
## 亮度做缓慢“呼吸”，参考 CHOICE 标题画面的阳光呼吸。

var sun
var _time: float = 0.0


func _ready() -> void:
	color = Color(1, 1, 1, 1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/sun_rays.gdshader") as Shader
	material = mat


func _process(delta: float) -> void:
	_time += delta
	if sun == null:
		return
	var mat: ShaderMaterial = material as ShaderMaterial
	if mat == null:
		return
	var breathe: float = 0.92 + 0.08 * sin(_time * 0.6)
	mat.set_shader_parameter("sun_uv", sun.sun_uv)
	mat.set_shader_parameter("intensity", float(sun.intensity) * breathe)
	mat.set_shader_parameter("ray_color", sun.ray_color)
