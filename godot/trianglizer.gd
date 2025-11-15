@tool
# trianglizer.gd
extends Node2D

var _data_path : String = ""

@export_file("*.svg", "*.json") var data_path : String:
	get:
		return _data_path
	set(value):
		_data_path = value
		_data_loaded = false
		if Engine.is_editor_hint() and _data_path != "":
			_load_data()

@export_enum("top_left", "top_center", "top_right",
			 "center_left", "center", "center_right",
			 "bottom_left", "bottom_center", "bottom_right")
var origin : String = "center"
@export var tint_mul : Color = Color(1, 1, 1, 1)
@export var tint_add : Color = Color(0, 0, 0, 0)
@export_range(0.0, 1.0, 0.01) var opacity : float = 1.0
@export var playback_rate : float = 1.0
@export var ping_pong : bool = false
@export var hold_last_frame : bool = false

var tex_width : float = 0.0
var tex_height : float = 0.0

var frames : Array = []            # Array of Array[Dictionary]: per-frame polygons
var frame_durations : Array = []   # Array[int] in ms
var total_duration_ms : int = 0
var time_accum_ms : float = 0.0
var current_frame : int = 0
var _data_loaded : bool = false

func _ready() -> void:
	set_process(true)

	if data_path == "":
		if not Engine.is_editor_hint():
			push_warning("No data_path set on %s" % name)
	else:
		_load_data()


func _load_data() -> void:
	var text := FileAccess.get_file_as_string(_data_path)
	if text == "":
		push_error("Could not read file: %s" % _data_path)
		return

	var root : Dictionary
	var ext := _data_path.get_extension().to_lower()

	if ext == "json":
		var parsed_json = JSON.parse_string(text)
		if typeof(parsed_json) != TYPE_DICTIONARY:
			push_error("Invalid JSON in %s" % _data_path)
			return
		root = parsed_json
	else:
		# Assume SVG with embedded GODOT_TRI comment
		var marker := "GODOT_TRI"
		var idx := text.find(marker)
		if idx == -1:
			push_error("No GODOT_TRI comment found in %s" % _data_path)
			return

		var json_start := idx + marker.length()
		# Skip whitespace after marker
		while json_start < text.length():
			var ch := text[json_start]
			if ch != " " and ch != "\t" and ch != "\n" and ch != "\r":
				break
			json_start += 1

		var end_idx := text.find("-->", json_start)
		if end_idx == -1:
			push_error("Unterminated GODOT_TRI comment in %s" % _data_path)
			return

		var json_str := text.substr(json_start, end_idx - json_start).strip_edges()
		var parsed_svg_json = JSON.parse_string(json_str)
		if typeof(parsed_svg_json) != TYPE_DICTIONARY:
			push_error("Invalid GODOT_TRI JSON in %s" % _data_path)
			return
		root = parsed_svg_json

	tex_width = float(root.get("width", 0))
	tex_height = float(root.get("height", 0))

	var raw_frames : Array = root.get("frames", [])
	if raw_frames.is_empty():
		push_warning("No frames found in %s" % _data_path)
		return

	frames.clear()
	frame_durations.clear()
	total_duration_ms = 0

	# Build frames as array of polygon arrays
	for rf in raw_frames:
		var dur : int = int(rf.get("duration", 100))
		if dur <= 0:
			dur = 1
		frame_durations.append(dur)
		total_duration_ms += dur

		var poly_defs : Array = rf.get("polygons", [])
		var polys : Array = []

		for p in poly_defs:
			var pts_src : Array = p.get("points", [])
			var pts := PackedVector2Array()
			for v in pts_src:
				if v.size() >= 2:
					pts.append(Vector2(v[0], v[1]))

			var col_str : String = p.get("color", "#ffffff")
			var col := Color(col_str)

			polys.append({
				"points": pts,
				"color": col,
			})

		frames.append(polys)

	time_accum_ms = 0.0
	current_frame = 0
	_data_loaded = true
	queue_redraw()


func _update_frame_from_time(t_ms: float) -> void:
	var acc := 0
	var new_frame := current_frame
	for i in frame_durations.size():
		acc += frame_durations[i]
		if t_ms < float(acc):
			new_frame = i
			break

	if new_frame != current_frame:
		current_frame = new_frame
		queue_redraw()


func _process(delta: float) -> void:
	if not _data_loaded and _data_path != "":
		_load_data()

	if frames.is_empty() or total_duration_ms <= 0:
		return

	time_accum_ms += delta * 1000.0 * playback_rate

	# Handle hold-last-frame mode (one-shot in game; editor keeps processing so you can tweak preview)
	if hold_last_frame and time_accum_ms >= float(total_duration_ms):
		time_accum_ms = float(total_duration_ms)
		current_frame = frames.size() - 1
		if not Engine.is_editor_hint():
			set_process(false)
		queue_redraw()
		return

	var t_cycle := time_accum_ms

	if ping_pong:
		var cycle_len := float(total_duration_ms) * 2.0
		if cycle_len <= 0.0:
			return
		t_cycle = fmod(t_cycle, cycle_len)
		if t_cycle >= float(total_duration_ms):
			t_cycle = cycle_len - t_cycle
	else:
		if float(total_duration_ms) <= 0.0:
			return
		t_cycle = fmod(t_cycle, float(total_duration_ms))

	_update_frame_from_time(t_cycle)


func reset_animation() -> void:
	if frames.is_empty() or total_duration_ms <= 0:
		return
	time_accum_ms = 0.0
	current_frame = 0
	set_process(true)
	queue_redraw()


func set_loop_progress(p: float) -> void:
	if frames.is_empty() or total_duration_ms <= 0:
		return
	p = clamp(p, 0.0, 1.0)
	time_accum_ms = float(total_duration_ms) * p
	_update_frame_from_time(time_accum_ms)


func _draw() -> void:
	if frames.is_empty():
		return

	var polys : Array = frames[current_frame]

	# Compute origin offset based on tex_width/tex_height
	var ox := 0.0
	var oy := 0.0
	if tex_width > 0.0 and tex_height > 0.0:
		match origin:
			"top_left":
				pass
			"top_center":
				ox = -tex_width / 2.0
			"top_right":
				ox = -tex_width
			"center_left":
				oy = -tex_height / 2.0
			"center":
				ox = -tex_width / 2.0
				oy = -tex_height / 2.0
			"center_right":
				ox = -tex_width
				oy = -tex_height / 2.0
			"bottom_left":
				oy = -tex_height
			"bottom_center":
				ox = -tex_width / 2.0
				oy = -tex_height
			"bottom_right":
				ox = -tex_width
				oy = -tex_height

	for p in polys:
		var pts : PackedVector2Array = p["points"]
		var base_col : Color = p["color"]
		if pts.size() >= 3:
			# Apply origin offset without mutating original points
			var pts_local := PackedVector2Array()
			pts_local.resize(pts.size())
			for i in pts.size():
				var v := pts[i]
				pts_local[i] = Vector2(v.x + ox, v.y + oy)

			# Color pipeline: multiply, then add, then opacity
			var col := base_col * tint_mul
			col.r = clamp(col.r + tint_add.r, 0.0, 1.0)
			col.g = clamp(col.g + tint_add.g, 0.0, 1.0)
			col.b = clamp(col.b + tint_add.b, 0.0, 1.0)
			col.a = clamp(col.a + tint_add.a, 0.0, 1.0)
			col.a *= opacity

			draw_polygon(pts_local, PackedColorArray([col]))
