@tool
class_name OpenDouGranularGraphNode
extends OpenDouBaseGraphNode

## Graph node for Granular Synthesis featuring an animated grain cloud scatter canvas and micro-grain parameter controls.

var grain_cloud_canvas: Control
var grain_size_spinbox: SpinBox
var grain_density_spinbox: SpinBox
var pitch_scatter_spinbox: SpinBox

var grain_anim_offset: float = 0.0

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_GRANULAR
	title = "✨ Granular Synthesizer"
	custom_minimum_size = Vector2(260, 210)
	
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, true, 0, COLOR_AUDIO_SIGNAL)
	_build_ui()

func _build_ui() -> void:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	add_child(container)
	
	# Grain Cloud Mini-Canvas
	grain_cloud_canvas = Control.new()
	grain_cloud_canvas.custom_minimum_size = Vector2(0, 48)
	grain_cloud_canvas.draw.connect(_on_draw_grain_cloud)
	container.add_child(grain_cloud_canvas)
	
	# Controls
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	
	# Grain Size
	var size_lbl = Label.new()
	size_lbl.text = "Grain Size (ms):"
	size_lbl.add_theme_font_size_override("font_size", 10)
	grid.add_child(size_lbl)
	
	grain_size_spinbox = SpinBox.new()
	grain_size_spinbox.min_value = 5.0
	grain_size_spinbox.max_value = 200.0
	grain_size_spinbox.value = 40.0
	grid.add_child(grain_size_spinbox)
	
	# Grain Rate / Density
	var dens_lbl = Label.new()
	dens_lbl.text = "Density (Hz):"
	dens_lbl.add_theme_font_size_override("font_size", 10)
	grid.add_child(dens_lbl)
	
	grain_density_spinbox = SpinBox.new()
	grain_density_spinbox.min_value = 10.0
	grain_density_spinbox.max_value = 200.0
	grain_density_spinbox.value = 45.0
	grid.add_child(grain_density_spinbox)
	
	# Pitch Scatter
	var pitch_lbl = Label.new()
	pitch_lbl.text = "Pitch Scatter (st):"
	pitch_lbl.add_theme_font_size_override("font_size", 10)
	grid.add_child(pitch_lbl)
	
	pitch_scatter_spinbox = SpinBox.new()
	pitch_scatter_spinbox.min_value = 0.0
	pitch_scatter_spinbox.max_value = 24.0
	pitch_scatter_spinbox.value = 2.5
	pitch_scatter_spinbox.step = 0.5
	grid.add_child(pitch_scatter_spinbox)
	
	container.add_child(grid)

func _process(delta: float) -> void:
	grain_anim_offset += delta * 2.0
	if grain_cloud_canvas:
		grain_cloud_canvas.queue_redraw()

func _on_draw_grain_cloud() -> void:
	if not grain_cloud_canvas:
		return
	var size = grain_cloud_canvas.size
	if size.x <= 10.0 or size.y <= 10.0:
		return
		
	# Dark canvas background
	grain_cloud_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.15, 1.0))
	grain_cloud_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.98, 0.55, 0.22, 0.4), false, 1.0)
	
	# Render micro-grains scatter
	var num_dots = 24
	for i in range(num_dots):
		var t = float(i) / float(num_dots)
		var dot_x = fposmod((t + grain_anim_offset * 0.2) * size.x, size.x)
		var dot_y = (0.5 + sin(float(i) * 1.7 + grain_anim_offset) * 0.35) * size.y
		var radius = 2.0 + sin(float(i)) * 1.2
		var alpha = 0.5 + sin(float(i) * 2.0 + grain_anim_offset) * 0.4
		grain_cloud_canvas.draw_circle(Vector2(dot_x, dot_y), radius, Color(0.98, 0.65, 0.3, alpha))
