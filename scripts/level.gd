extends Node2D

const VIEWPORT_SIZE := Vector2(1280, 720)
const MAP_ORIGIN := Vector2(140, 90)
const TILE_SIZE := 50
const MAP_COLS := 20
const MAP_ROWS := 12
const PLAYER_SIZE := 15.0
const ENEMY_SIZE := 15.0
const PICKUP_SIZE := 18.0
const PLAYER_BASE_SPEED := 180.0
const ENEMY_BASE_SPEED := 90.0
const LIGHT_RANGE := 430.0
const LIGHT_SPREAD := PI / 4.5
const PLAYER_GLOW_RADIUS := 70.0

var tiles: Array = []
var player_pos := Vector2.ZERO
var player_health := 3
var player_alive := true
var enemies: Array = []
var pickups: Array = []
var current_level := 1
var elapsed_time := 0.0
var game_state := "playing"
var restart_timer := 0.0
var damage_cooldown := 0.0
var active_buffs := {
	"speed": 0.0,
	"light": 0.0,
	"shield": 0.0,
}

func _ready() -> void:
	randomize()
	reset_game()

func reset_game() -> void:
	current_level = 1
	elapsed_time = 0.0
	restart_timer = 0.0
	damage_cooldown = 0.0
	active_buffs = {
		"speed": 0.0,
		"light": 0.0,
		"shield": 0.0,
	}
	load_level()

func load_level() -> void:
	game_state = "playing"
	player_alive = true
	player_health = 3
	player_pos = cell_to_world(Vector2i(1, 1))
	generate_maze()
	spawn_enemies()
	spawn_pickups()
	queue_redraw()

func next_level() -> void:
	current_level += 1
	load_level()

func generate_maze() -> void:
	var wall_chance = min(0.16 + current_level * 0.018, 0.34)
	tiles = []
	for row in range(MAP_ROWS):
		var tile_row := []
		for col in range(MAP_COLS):
			var is_border = row == 0 or row == MAP_ROWS - 1 or col == 0 or col == MAP_COLS - 1
			tile_row.append(1 if is_border or randf() < wall_chance else 0)
		tiles.append(tile_row)
	
	carve_path(Vector2i(1, 1), Vector2i(MAP_COLS - 2, MAP_ROWS - 2))
	clear_area(Vector2i(1, 1), 2)
	clear_area(Vector2i(MAP_COLS - 2, MAP_ROWS - 2), 2)

func carve_path(start_cell: Vector2i, end_cell: Vector2i) -> void:
	var cell := start_cell
	tiles[cell.y][cell.x] = 0
	while cell != end_cell:
		var move_horizontally = randf() < 0.5
		if (move_horizontally and cell.x != end_cell.x) or cell.y == end_cell.y:
			cell.x += signi(end_cell.x - cell.x)
		elif cell.y != end_cell.y:
			cell.y += signi(end_cell.y - cell.y)
		
		tiles[cell.y][cell.x] = 0
		if randf() < 0.35:
			clear_area(cell, 1)

func signi(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0

func clear_area(center: Vector2i, radius: int) -> void:
	for row in range(center.y - radius, center.y + radius + 1):
		for col in range(center.x - radius, center.x + radius + 1):
			if row > 0 and row < MAP_ROWS - 1 and col > 0 and col < MAP_COLS - 1:
				tiles[row][col] = 0

func spawn_enemies() -> void:
	enemies = []
	var enemy_count = min(3 + current_level, 12)
	for i in range(enemy_count):
		enemies.append({
			"position": get_random_walkable_position(220.0),
			"alert": false,
			"wander_angle": randf() * TAU,
		})

func spawn_pickups() -> void:
	pickups = []
	var types = ["heal", "speed", "light", "shield"]
	var pickup_count = min(3 + int(current_level / 2), 7)
	for i in range(pickup_count):
		pickups.append({
			"type": types[i % types.size()],
			"position": get_pickup_spawn_position(),
		})

func get_pickup_spawn_position() -> Vector2:
	var exit_pos = get_exit_position()
	for attempt in range(60):
		var spawn = get_random_walkable_position(160.0)
		var too_close_to_exit = spawn.distance_to(exit_pos) < 80.0
		var overlaps_pickup = false
		for pickup in pickups:
			if spawn.distance_to(pickup["position"]) < 55.0:
				overlaps_pickup = true
				break
		if not too_close_to_exit and not overlaps_pickup:
			return spawn
	return get_random_walkable_position(160.0)

func get_random_walkable_position(min_distance_from_start: float) -> Vector2:
	var start_pos = cell_to_world(Vector2i(1, 1))
	for attempt in range(300):
		var col = randi_range(1, MAP_COLS - 2)
		var row = randi_range(1, MAP_ROWS - 2)
		if tiles[row][col] == 0:
			var pos = cell_to_world(Vector2i(col, row))
			if pos.distance_to(start_pos) >= min_distance_from_start:
				return pos
	return get_exit_position()

func _process(delta: float) -> void:
	if game_state == "game_over":
		restart_timer -= delta
		if restart_timer <= 0.0:
			reset_game()
		queue_redraw()
		return
	
	if game_state != "playing":
		return
	
	update_buffs(delta)
	damage_cooldown = max(0.0, damage_cooldown - delta)
	update_player(delta)
	update_pickups()
	update_enemies(delta)
	check_exit()
	elapsed_time += delta
	queue_redraw()

func update_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	
	if direction == Vector2.ZERO:
		return
	
	direction = direction.normalized()
	var speed_multiplier = 1.55 if active_buffs["speed"] > 0.0 else 1.0
	var velocity = direction * PLAYER_BASE_SPEED * speed_multiplier * delta
	try_move_player(velocity)

func try_move_player(velocity: Vector2) -> void:
	var next_x = Vector2(player_pos.x + velocity.x, player_pos.y)
	if is_actor_walkable(next_x, PLAYER_SIZE):
		player_pos.x = next_x.x
	
	var next_y = Vector2(player_pos.x, player_pos.y + velocity.y)
	if is_actor_walkable(next_y, PLAYER_SIZE):
		player_pos.y = next_y.y
	
	player_pos.x = clamp(player_pos.x, MAP_ORIGIN.x + PLAYER_SIZE / 2.0, MAP_ORIGIN.x + MAP_COLS * TILE_SIZE - PLAYER_SIZE / 2.0)
	player_pos.y = clamp(player_pos.y, MAP_ORIGIN.y + PLAYER_SIZE / 2.0, MAP_ORIGIN.y + MAP_ROWS * TILE_SIZE - PLAYER_SIZE / 2.0)

func update_buffs(delta: float) -> void:
	for key in active_buffs.keys():
		active_buffs[key] = max(0.0, active_buffs[key] - delta)

func update_pickups() -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup = pickups[i]
		if pickup["position"].distance_to(player_pos) < (PICKUP_SIZE + PLAYER_SIZE) / 2.0:
			apply_pickup(pickup["type"])
			pickups.remove_at(i)

func apply_pickup(type: String) -> void:
	match type:
		"heal":
			player_health = min(3, player_health + 1)
		"speed":
			active_buffs["speed"] = 7.0
		"light":
			active_buffs["light"] = 9.0
		"shield":
			active_buffs["shield"] = 6.0

func update_enemies(delta: float) -> void:
	for enemy in enemies:
		var enemy_pos: Vector2 = enemy["position"]
		var distance = enemy_pos.distance_to(player_pos)
		var velocity := Vector2.ZERO
		
		if distance < 150.0:
			enemy["alert"] = true
			velocity = (player_pos - enemy_pos).normalized() * ENEMY_BASE_SPEED * delta
		else:
			enemy["alert"] = false
			if randf() < 3.0 * delta:
				enemy["wander_angle"] = randf() * TAU
			velocity = Vector2(cos(enemy["wander_angle"]), sin(enemy["wander_angle"])) * ENEMY_BASE_SPEED * 0.35 * delta
		
		var next_x = Vector2(enemy_pos.x + velocity.x, enemy_pos.y)
		if is_actor_walkable(next_x, ENEMY_SIZE):
			enemy_pos.x = next_x.x
		
		var next_y = Vector2(enemy_pos.x, enemy_pos.y + velocity.y)
		if is_actor_walkable(next_y, ENEMY_SIZE):
			enemy_pos.y = next_y.y
		
		enemy["position"] = enemy_pos
		if enemy_pos.distance_to(player_pos) < (ENEMY_SIZE + PLAYER_SIZE) / 2.0:
			damage_player()

func damage_player() -> void:
	if active_buffs["shield"] > 0.0 or damage_cooldown > 0.0:
		return
	
	player_health -= 1
	damage_cooldown = 0.8
	if player_health <= 0:
		player_alive = false
		game_state = "game_over"
		restart_timer = 1.5

func check_exit() -> void:
	if player_pos.distance_to(get_exit_position()) < 30.0:
		next_level()

func is_actor_walkable(pos: Vector2, size: float) -> bool:
	var half = size / 2.0
	return is_walkable_world(pos + Vector2(-half, -half)) \
		and is_walkable_world(pos + Vector2(half, -half)) \
		and is_walkable_world(pos + Vector2(-half, half)) \
		and is_walkable_world(pos + Vector2(half, half))

func is_walkable_world(world_pos: Vector2) -> bool:
	var local = world_pos - MAP_ORIGIN
	var col = floori(local.x / TILE_SIZE)
	var row = floori(local.y / TILE_SIZE)
	if row < 0 or row >= MAP_ROWS or col < 0 or col >= MAP_COLS:
		return false
	return tiles[row][col] == 0

func cell_to_world(cell: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func get_exit_position() -> Vector2:
	return cell_to_world(Vector2i(MAP_COLS - 2, MAP_ROWS - 2))

func get_light_range() -> float:
	return LIGHT_RANGE * 1.45 if active_buffs["light"] > 0.0 else LIGHT_RANGE

func get_light_angle() -> float:
	return (get_global_mouse_position() - player_pos).angle()

func is_in_light(pos: Vector2) -> bool:
	if pos.distance_to(player_pos) <= PLAYER_GLOW_RADIUS:
		return true
	
	var to_pos = pos - player_pos
	var distance = to_pos.length()
	if distance > get_light_range():
		return false
	
	var angle_diff = abs(angle_difference(get_light_angle(), to_pos.angle()))
	return angle_diff <= LIGHT_SPREAD

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color("#050505"))
	draw_title_ui()
	draw_map(false)
	draw_pickups(false)
	draw_enemies(false)
	draw_player(false)
	draw_fog()
	draw_map(true)
	draw_pickups(true)
	draw_enemies(true)
	draw_light_overlay()
	draw_player(true)
	draw_hud()
	
	if game_state == "game_over":
		draw_game_over()

func get_font() -> Font:
	return ThemeDB.get_fallback_font()

func draw_title_ui() -> void:
	var font = get_font()
	draw_string(font, Vector2(452, 55), "Sound Labyrinth", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("#00ff88"))

func draw_map(lit_only: bool) -> void:
	for row in range(MAP_ROWS):
		for col in range(MAP_COLS):
			var rect = Rect2(MAP_ORIGIN + Vector2(col * TILE_SIZE, row * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			var center = rect.position + rect.size / 2.0
			var lit = is_in_light(center)
			if lit_only and not lit:
				continue
			if not lit_only and lit:
				continue
			
			if tiles[row][col] == 1:
				draw_rect(rect, Color("#5f5f5f") if lit else Color("#171717"))
				draw_rect(rect, Color("#8f8f8f") if lit else Color("#222222"), false, 1.0)
			else:
				draw_rect(rect, Color("#202020") if lit else Color("#080808"))
	
	var exit_rect = Rect2(get_exit_position() - Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0), Vector2(TILE_SIZE, TILE_SIZE))
	var exit_lit = is_in_light(get_exit_position())
	if lit_only == exit_lit:
		draw_rect(exit_rect, Color("#00ff00") if exit_lit else Color("#003800"))
		draw_string(get_font(), exit_rect.position + Vector2(10, 31), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK if exit_lit else Color("#001800"))

func draw_pickups(lit_only: bool) -> void:
	for pickup in pickups:
		var lit = is_in_light(pickup["position"])
		if lit_only != lit:
			continue
		var color = get_pickup_color(pickup["type"])
		if not lit:
			color = color.darkened(0.7)
		draw_circle(pickup["position"], PICKUP_SIZE / 2.0, color)
		draw_string(get_font(), pickup["position"] + Vector2(-5, 5), get_pickup_label(pickup["type"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#08110d"))

func get_pickup_color(type: String) -> Color:
	match type:
		"heal":
			return Color("#ff4f7b")
		"speed":
			return Color("#38bdf8")
		"light":
			return Color("#facc15")
		"shield":
			return Color("#a78bfa")
	return Color.WHITE

func get_pickup_label(type: String) -> String:
	match type:
		"heal":
			return "+"
		"speed":
			return "S"
		"light":
			return "L"
		"shield":
			return "O"
	return "?"

func draw_enemies(lit_only: bool) -> void:
	for enemy in enemies:
		var lit = is_in_light(enemy["position"])
		if lit_only != lit:
			continue
		var color = Color("#ff0000") if enemy["alert"] else Color("#ff6600")
		if not lit:
			color = color.darkened(0.85)
		var rect = Rect2(enemy["position"] - Vector2(ENEMY_SIZE / 2.0, ENEMY_SIZE / 2.0), Vector2(ENEMY_SIZE, ENEMY_SIZE))
		draw_rect(rect, color)
		if lit:
			draw_rect(Rect2(enemy["position"] + Vector2(-4, -4), Vector2(3, 3)), Color.YELLOW)
			draw_rect(Rect2(enemy["position"] + Vector2(3, -4), Vector2(3, 3)), Color.YELLOW)

func draw_player(lit: bool) -> void:
	var rect = Rect2(player_pos - Vector2(PLAYER_SIZE / 2.0, PLAYER_SIZE / 2.0), Vector2(PLAYER_SIZE, PLAYER_SIZE))
	draw_rect(rect, Color("#00ff88"))
	draw_rect(Rect2(player_pos + Vector2(-4, -4), Vector2(3, 3)), Color.BLACK)
	draw_rect(Rect2(player_pos + Vector2(3, -4), Vector2(3, 3)), Color.BLACK)
	if lit and active_buffs["shield"] > 0.0:
		draw_arc(player_pos, PLAYER_SIZE * 1.25, 0, TAU, 32, Color("#a78bfa"), 3.0)

func draw_fog() -> void:
	draw_rect(Rect2(MAP_ORIGIN, Vector2(MAP_COLS * TILE_SIZE, MAP_ROWS * TILE_SIZE)), Color(0, 0, 0, 0.76))

func draw_light_overlay() -> void:
	var angle = get_light_angle()
	var left_angle = angle - LIGHT_SPREAD
	var right_angle = angle + LIGHT_SPREAD
	var points = PackedVector2Array([player_pos])
	for i in range(18):
		var t = float(i) / 17.0
		var beam_angle = lerp(left_angle, right_angle, t)
		points.append(player_pos + Vector2(cos(beam_angle), sin(beam_angle)) * get_light_range())
	draw_colored_polygon(points, Color(0.25, 1.0, 0.55, 0.12))
	draw_circle(player_pos, PLAYER_GLOW_RADIUS, Color(0.45, 1.0, 0.75, 0.18))
	draw_line(player_pos, player_pos + Vector2(cos(left_angle), sin(left_angle)) * get_light_range() * 0.75, Color(0, 1, 0.53, 0.22), 1.5)
	draw_line(player_pos, player_pos + Vector2(cos(right_angle), sin(right_angle)) * get_light_range() * 0.75, Color(0, 1, 0.53, 0.22), 1.5)

func draw_hud() -> void:
	var font = get_font()
	draw_rect(Rect2(MAP_ORIGIN.x, 20, MAP_COLS * TILE_SIZE, 52), Color("#191919"))
	draw_rect(Rect2(MAP_ORIGIN.x, 20, MAP_COLS * TILE_SIZE, 52), Color("#00ff88"), false, 2.0)
	draw_string(font, Vector2(MAP_ORIGIN.x + 120, 54), "Health: %d" % player_health, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(MAP_ORIGIN.x + 450, 54), "Level: %d" % current_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(MAP_ORIGIN.x + 780, 54), "Time: %ds" % int(elapsed_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	
	var buff_text := []
	for key in active_buffs.keys():
		if active_buffs[key] > 0.0:
			buff_text.append("%s %ds" % [String(key).to_upper(), ceili(active_buffs[key])])
	if not buff_text.is_empty():
		draw_string(font, MAP_ORIGIN + Vector2(16, 18), " | ".join(buff_text), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func draw_game_over() -> void:
	var font = get_font()
	draw_rect(Rect2(MAP_ORIGIN, Vector2(MAP_COLS * TILE_SIZE, MAP_ROWS * TILE_SIZE)), Color(0, 0, 0, 0.7))
	draw_string(font, MAP_ORIGIN + Vector2(360, 260), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.RED)
	draw_string(font, MAP_ORIGIN + Vector2(360, 330), "Restarting...", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
