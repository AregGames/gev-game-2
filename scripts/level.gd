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
const SWORD_RANGE := 72.0
const SWORD_SPREAD := PI / 3.0
const SWORD_DURATION := 0.18
const SWORD_COOLDOWN := 0.45
const SWORD_HANDLE_LENGTH := 16.0
const SWORD_BLADE_LENGTH := 42.0
const ARROW_SPEED := 520.0
const ARROW_RANGE := 460.0
const ARROW_SIZE := 18.0
const BOW_COOLDOWN := 0.38
const BOW_DRAW_DURATION := 0.16
const BOW_RELEASE_DURATION := 0.10
const FIREBALL_SPEED := 360.0
const FIREBALL_RANGE := 380.0
const FIREBALL_SIZE := 24.0
const FIREBALL_BLAST_RADIUS := 58.0
const FIREBALL_COOLDOWN := 0.85
const FIREBALL_CHARGE_DURATION := 0.22
const FIREBALL_RELEASE_DURATION := 0.12
const FIRST_PERSON_FOV := PI / 3.0
const FIRST_PERSON_RAYS := 160
const FIRST_PERSON_VIEW_DISTANCE := 700.0
const FIRST_PERSON_RAY_STEP := 5.0
const FIRST_PERSON_MOUSE_SENSITIVITY := 0.005
const TOP_DOWN_MOUSE_AIM_SPEED := 1.15
const FIRST_PERSON_WEAPON_SWAY := 0.18
const FIRST_PERSON_WEAPON_SWAY_RETURN := 9.0
const FIRST_PERSON_WEAPON_BOB_SPEED := 9.0
const FIRST_PERSON_WEAPON_BOB_AMOUNT := 10.0
const FIRST_PERSON_BRICK_WIDTH := 44.0
const FIRST_PERSON_BRICK_HEIGHT := 28.0
const FIRST_PERSON_MORTAR_THICKNESS := 2.0
const TORCH_SIZE := 12.0
const TRAP_SIZE := 34.0
const TRAP_TRIGGER_RADIUS := 24.0
const SPIKE_CYCLE_DURATION := 1.35
const SPIKE_ACTIVE_TIME := 0.72

var tiles: Array = []
var player_pos := Vector2.ZERO
var player_cell := Vector2i(1, 1)
var player_health := 3
var player_alive := true
var enemies: Array = []
var pickups: Array = []
var traps: Array = []
var decorations: Array = []
var arrows: Array = []
var fireballs: Array = []
var exit_cell := Vector2i(MAP_COLS - 2, MAP_ROWS - 2)
var score := 0
var current_level := 1
var elapsed_time := 0.0
var game_state := "playing"
var restart_timer := 0.0
var damage_cooldown := 0.0
var sword_timer := 0.0
var sword_cooldown := 0.0
var sword_angle := 0.0
var sword_requested := false
var bow_cooldown := 0.0
var arrow_requested := false
var bow_release_requested := false
var bow_draw_timer := 0.0
var bow_release_timer := 0.0
var bow_release_amount := 0.0
var bow_pending_arrow := false
var fireball_cooldown := 0.0
var fireball_requested := false
var fireball_release_requested := false
var fireball_charge_timer := 0.0
var fireball_release_timer := 0.0
var fireball_release_amount := 0.0
var fireball_pending := false
var active_weapon := "sword"
var first_person_mode := false
var first_person_angle := 0.0
var virtual_aim_pos := Vector2.ZERO
var first_person_weapon_sway := Vector2.ZERO
var active_buffs := {
	"speed": 0.0,
	"light": 0.0,
	"shield": 0.0,
}

func _ready() -> void:
	randomize()
	reset_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if first_person_mode:
			first_person_angle += motion_event.relative.x * FIRST_PERSON_MOUSE_SENSITIVITY
			first_person_weapon_sway += motion_event.relative * FIRST_PERSON_WEAPON_SWAY
			first_person_weapon_sway.x = clamp(first_person_weapon_sway.x, -28.0, 28.0)
			first_person_weapon_sway.y = clamp(first_person_weapon_sway.y, -18.0, 18.0)
		else:
			virtual_aim_pos += motion_event.relative * TOP_DOWN_MOUSE_AIM_SPEED
			virtual_aim_pos.x = clamp(virtual_aim_pos.x, MAP_ORIGIN.x, MAP_ORIGIN.x + MAP_COLS * TILE_SIZE)
			virtual_aim_pos.y = clamp(virtual_aim_pos.y, MAP_ORIGIN.y, MAP_ORIGIN.y + MAP_ROWS * TILE_SIZE)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if game_state == "game_over" and mouse_event.pressed:
				handle_game_over_click(mouse_event.position)
				return
			if active_weapon == "bow":
				if mouse_event.pressed:
					arrow_requested = true
				else:
					bow_release_requested = true
			elif mouse_event.pressed:
				sword_requested = true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_Q:
			if key_event.pressed and not key_event.echo:
				fireball_requested = true
			elif not key_event.pressed:
				fireball_release_requested = true
		elif key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_1:
				active_weapon = "sword"
			elif key_event.keycode == KEY_2:
				active_weapon = "bow"
			elif key_event.keycode == KEY_C:
				if first_person_mode:
					first_person_mode = false
					reset_virtual_aim(first_person_angle)
				else:
					first_person_angle = get_mouse_aim_angle()
					first_person_mode = true

func reset_game() -> void:
	current_level = 1
	score = 0
	elapsed_time = 0.0
	restart_timer = 0.0
	damage_cooldown = 0.0
	sword_timer = 0.0
	sword_cooldown = 0.0
	sword_requested = false
	bow_cooldown = 0.0
	arrow_requested = false
	bow_release_requested = false
	bow_draw_timer = 0.0
	bow_release_timer = 0.0
	bow_release_amount = 0.0
	bow_pending_arrow = false
	fireball_cooldown = 0.0
	fireball_requested = false
	fireball_release_requested = false
	fireball_charge_timer = 0.0
	fireball_release_timer = 0.0
	fireball_release_amount = 0.0
	fireball_pending = false
	active_weapon = "sword"
	first_person_mode = false
	first_person_angle = 0.0
	virtual_aim_pos = Vector2.ZERO
	first_person_weapon_sway = Vector2.ZERO
	arrows = []
	fireballs = []
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
	arrows = []
	fireballs = []
	bow_draw_timer = 0.0
	bow_release_timer = 0.0
	bow_release_amount = 0.0
	bow_pending_arrow = false
	fireball_charge_timer = 0.0
	fireball_release_timer = 0.0
	fireball_release_amount = 0.0
	fireball_pending = false
	generate_maze()
	player_pos = cell_to_world(player_cell)
	reset_virtual_aim()
	capture_mouse()
	spawn_decorations()
	spawn_traps()
	spawn_enemies()
	spawn_pickups()
	queue_redraw()

func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func reset_virtual_aim(angle := 0.0) -> void:
	virtual_aim_pos = player_pos + Vector2(cos(angle), sin(angle)) * 180.0
	virtual_aim_pos.x = clamp(virtual_aim_pos.x, MAP_ORIGIN.x, MAP_ORIGIN.x + MAP_COLS * TILE_SIZE)
	virtual_aim_pos.y = clamp(virtual_aim_pos.y, MAP_ORIGIN.y, MAP_ORIGIN.y + MAP_ROWS * TILE_SIZE)

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
	
	player_cell = get_random_player_cell()
	exit_cell = get_random_exit_cell()
	carve_path(player_cell, exit_cell)
	clear_area(player_cell, 2)
	clear_area(exit_cell, 2)

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

func spawn_traps() -> void:
	traps = []
	var types = ["lava", "spikes", "shock"]
	var trap_count = min(3 + current_level, 14)
	for i in range(trap_count):
		var cell = get_trap_spawn_cell()
		if cell == Vector2i(-1, -1):
			continue
		traps.append({
			"type": types[i % types.size()],
			"cell": cell,
			"position": cell_to_world(cell),
			"phase": randf() * SPIKE_CYCLE_DURATION,
		})

func spawn_decorations() -> void:
	decorations = []
	var torch_count = min(8 + current_level * 2, 26)
	for i in range(torch_count):
		var decoration = get_torch_decoration()
		if decoration.is_empty():
			continue
		decorations.append(decoration)

func get_torch_decoration() -> Dictionary:
	for attempt in range(350):
		var cell = Vector2i(randi_range(1, MAP_COLS - 2), randi_range(1, MAP_ROWS - 2))
		if tiles[cell.y][cell.x] != 1:
			continue
		var normal = get_wall_torch_normal(cell)
		if normal == Vector2.ZERO:
			continue
		var pos = cell_to_world(cell) + normal * (TILE_SIZE * 0.36)
		if is_near_decoration(pos, TILE_SIZE * 1.65):
			continue
		return {
			"type": "torch",
			"cell": cell,
			"position": pos,
			"normal": normal,
			"phase": randf() * TAU,
		}
	return {}

func get_wall_torch_normal(cell: Vector2i) -> Vector2:
	var options := []
	if tiles[cell.y][cell.x - 1] == 0:
		options.append(Vector2.LEFT)
	if tiles[cell.y][cell.x + 1] == 0:
		options.append(Vector2.RIGHT)
	if tiles[cell.y - 1][cell.x] == 0:
		options.append(Vector2.UP)
	if tiles[cell.y + 1][cell.x] == 0:
		options.append(Vector2.DOWN)
	if options.is_empty():
		return Vector2.ZERO
	return options[randi_range(0, options.size() - 1)]

func is_near_decoration(pos: Vector2, distance: float) -> bool:
	for decoration in decorations:
		if decoration["position"].distance_to(pos) < distance:
			return true
	return false

func get_trap_spawn_cell() -> Vector2i:
	for attempt in range(300):
		var cell = Vector2i(randi_range(1, MAP_COLS - 2), randi_range(1, MAP_ROWS - 2))
		if not can_place_trap(cell):
			continue
		return cell
	for row in range(1, MAP_ROWS - 1):
		for col in range(1, MAP_COLS - 1):
			var cell = Vector2i(col, row)
			if can_place_trap(cell):
				return cell
	return Vector2i(-1, -1)

func can_place_trap(cell: Vector2i) -> bool:
	if tiles[cell.y][cell.x] != 0:
		return false
	if cell.distance_to(player_cell) < 3.0 or cell.distance_to(exit_cell) < 2.0:
		return false
	for trap in traps:
		if trap["cell"] == cell or trap["position"].distance_to(cell_to_world(cell)) < TILE_SIZE * 1.45:
			return false
	return true

func get_pickup_spawn_position() -> Vector2:
	var exit_pos = get_exit_position()
	for attempt in range(60):
		var spawn = get_random_walkable_position(160.0)
		var too_close_to_exit = spawn.distance_to(exit_pos) < 80.0
		var overlaps_trap = is_near_trap(spawn, 40.0)
		var overlaps_pickup = false
		for pickup in pickups:
			if spawn.distance_to(pickup["position"]) < 55.0:
				overlaps_pickup = true
				break
		if not too_close_to_exit and not overlaps_trap and not overlaps_pickup:
			return spawn
	return get_random_walkable_position(160.0)

func is_near_trap(pos: Vector2, distance: float) -> bool:
	for trap in traps:
		if trap["position"].distance_to(pos) < distance:
			return true
	return false

func get_random_walkable_position(min_distance_from_start: float) -> Vector2:
	var start_pos = player_pos
	for attempt in range(300):
		var col = randi_range(1, MAP_COLS - 2)
		var row = randi_range(1, MAP_ROWS - 2)
		if tiles[row][col] == 0:
			var pos = cell_to_world(Vector2i(col, row))
			if pos.distance_to(start_pos) >= min_distance_from_start and not is_near_trap(pos, 35.0):
				return pos
	return get_exit_position()

func get_random_player_cell() -> Vector2i:
	return Vector2i(randi_range(2, MAP_COLS - 3), randi_range(2, MAP_ROWS - 3))

func get_random_exit_cell() -> Vector2i:
	var start_pos = cell_to_world(player_cell)
	var best_cell = Vector2i(MAP_COLS - 2, MAP_ROWS - 2)
	var best_distance = 0.0
	
	for attempt in range(250):
		var col = randi_range(2, MAP_COLS - 3)
		var row = randi_range(2, MAP_ROWS - 3)
		var cell = Vector2i(col, row)
		if cell == player_cell:
			continue
		var pos = cell_to_world(cell)
		var distance = pos.distance_to(start_pos)
		
		if distance > best_distance:
			best_distance = distance
			best_cell = cell
		
		if distance >= 520.0:
			return cell
	
	return best_cell

func _process(delta: float) -> void:
	if game_state == "game_over":
		queue_redraw()
		return
	
	if game_state != "playing":
		return
	
	update_buffs(delta)
	damage_cooldown = max(0.0, damage_cooldown - delta)
	update_first_person_weapon_motion(delta)
	update_sword(delta)
	update_bow(delta)
	update_arrows(delta)
	update_fireballs(delta)
	update_player(delta)
	update_traps()
	update_pickups()
	update_enemies(delta)
	check_exit()
	elapsed_time += delta
	queue_redraw()

func update_first_person_weapon_motion(delta: float) -> void:
	first_person_weapon_sway = first_person_weapon_sway.lerp(Vector2.ZERO, min(1.0, FIRST_PERSON_WEAPON_SWAY_RETURN * delta))

func update_player(delta: float) -> void:
	var direction = get_first_person_move_direction() if first_person_mode else get_top_down_move_direction()
	
	if direction == Vector2.ZERO:
		return
	
	direction = direction.normalized()
	var speed_multiplier = 1.55 if active_buffs["speed"] > 0.0 else 1.0
	speed_multiplier *= get_trap_speed_multiplier()
	var velocity = direction * PLAYER_BASE_SPEED * speed_multiplier * delta
	try_move_player(velocity)

func get_top_down_move_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	return direction

func get_first_person_move_direction() -> Vector2:
	var forward = Vector2(cos(get_light_angle()), sin(get_light_angle()))
	var right = forward.rotated(PI / 2.0)
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP):
		direction += forward
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN):
		direction -= forward
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		direction -= right
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		direction += right
	return direction

func get_trap_speed_multiplier() -> float:
	for trap in traps:
		if trap["type"] == "lava" and trap["position"].distance_to(player_pos) < TRAP_TRIGGER_RADIUS:
			return 0.55
	return 1.0

func update_sword(delta: float) -> void:
	sword_timer = max(0.0, sword_timer - delta)
	sword_cooldown = max(0.0, sword_cooldown - delta)
	if (sword_requested or Input.is_action_just_pressed("sword_attack")) and sword_cooldown <= 0.0:
		active_weapon = "sword"
		start_sword_attack()
	sword_requested = false

func start_sword_attack() -> void:
	sword_angle = get_light_angle()
	sword_timer = SWORD_DURATION
	sword_cooldown = SWORD_COOLDOWN
	for i in range(enemies.size() - 1, -1, -1):
		if is_enemy_in_sword_arc(enemies[i]["position"]):
			drop_enemy_loot(enemies[i]["position"])
			enemies.remove_at(i)

func is_enemy_in_sword_arc(enemy_pos: Vector2) -> bool:
	var to_enemy = enemy_pos - player_pos
	if to_enemy.length() > SWORD_RANGE:
		return false
	var angle_diff = abs(angle_difference(sword_angle, to_enemy.angle()))
	return angle_diff <= SWORD_SPREAD / 2.0

func update_bow(delta: float) -> void:
	bow_cooldown = max(0.0, bow_cooldown - delta)
	bow_release_timer = max(0.0, bow_release_timer - delta)
	if bow_pending_arrow:
		bow_draw_timer = min(BOW_DRAW_DURATION, bow_draw_timer + delta)
		if bow_release_requested:
			release_bow_arrow()
	if arrow_requested and bow_cooldown <= 0.0 and not bow_pending_arrow:
		start_bow_shot()
		if bow_release_requested:
			release_bow_arrow()
	arrow_requested = false
	bow_release_requested = false

func start_bow_shot() -> void:
	active_weapon = "bow"
	bow_draw_timer = 0.0
	bow_release_timer = 0.0
	bow_release_amount = 0.0
	bow_pending_arrow = true

func release_bow_arrow() -> void:
	bow_release_amount = get_bow_draw_amount()
	bow_pending_arrow = false
	bow_release_timer = BOW_RELEASE_DURATION
	bow_cooldown = BOW_COOLDOWN
	var angle = get_light_angle()
	var direction = Vector2(cos(angle), sin(angle)).normalized()
	arrows.append({
		"position": player_pos + direction * (PLAYER_SIZE + 8.0),
		"direction": direction,
		"distance": 0.0,
	})

func get_bow_draw_amount() -> float:
	if bow_pending_arrow:
		var progress = clamp(bow_draw_timer / BOW_DRAW_DURATION, 0.0, 1.0)
		return sin(progress * PI * 0.5)
	if bow_release_timer > 0.0:
		var progress = clamp(bow_release_timer / BOW_RELEASE_DURATION, 0.0, 1.0)
		return bow_release_amount * progress * progress
	return 0.0

func update_arrows(delta: float) -> void:
	for i in range(arrows.size() - 1, -1, -1):
		var arrow = arrows[i]
		var travel = ARROW_SPEED * delta
		var next_pos: Vector2 = arrow["position"] + arrow["direction"] * travel
		arrow["position"] = next_pos
		arrow["distance"] += travel
		
		if arrow["distance"] > ARROW_RANGE or not is_walkable_world(next_pos):
			arrows.remove_at(i)
			continue
		
		var hit_enemy = get_arrow_hit_enemy(next_pos)
		if hit_enemy != -1:
			drop_enemy_loot(enemies[hit_enemy]["position"])
			enemies.remove_at(hit_enemy)
			arrows.remove_at(i)
			continue
		
		arrows[i] = arrow

func get_arrow_hit_enemy(arrow_pos: Vector2) -> int:
	for i in range(enemies.size()):
		if enemies[i]["position"].distance_to(arrow_pos) < (ENEMY_SIZE + ARROW_SIZE) / 2.0:
			return i
	return -1

func update_fireballs(delta: float) -> void:
	fireball_cooldown = max(0.0, fireball_cooldown - delta)
	fireball_release_timer = max(0.0, fireball_release_timer - delta)
	if fireball_pending:
		fireball_charge_timer = min(FIREBALL_CHARGE_DURATION, fireball_charge_timer + delta)
		if fireball_release_requested:
			throw_fireball()
	if fireball_requested and fireball_cooldown <= 0.0 and not fireball_pending:
		start_fireball_charge()
		if fireball_release_requested:
			throw_fireball()
	fireball_requested = false
	fireball_release_requested = false
	
	for i in range(fireballs.size() - 1, -1, -1):
		var fireball = fireballs[i]
		var travel = FIREBALL_SPEED * delta
		var next_pos: Vector2 = fireball["position"] + fireball["direction"] * travel
		fireball["position"] = next_pos
		fireball["distance"] += travel
		fireball["spin"] += delta * 8.0
		
		if fireball["distance"] > FIREBALL_RANGE or not is_walkable_world(next_pos):
			explode_fireball(next_pos)
			fireballs.remove_at(i)
			continue
		
		if get_fireball_hit_enemy(next_pos) != -1:
			explode_fireball(next_pos)
			fireballs.remove_at(i)
			continue
		
		fireballs[i] = fireball

func start_fireball_charge() -> void:
	fireball_charge_timer = 0.0
	fireball_release_timer = 0.0
	fireball_release_amount = 0.0
	fireball_pending = true

func throw_fireball() -> void:
	fireball_release_amount = get_fireball_charge_amount()
	fireball_pending = false
	fireball_release_timer = FIREBALL_RELEASE_DURATION
	var angle = get_light_angle()
	var direction = Vector2(cos(angle), sin(angle)).normalized()
	fireball_cooldown = FIREBALL_COOLDOWN
	fireballs.append({
		"position": player_pos + direction * (PLAYER_SIZE + 12.0),
		"direction": direction,
		"distance": 0.0,
		"spin": randf() * TAU,
	})

func get_fireball_charge_amount() -> float:
	if fireball_pending:
		var progress = clamp(fireball_charge_timer / FIREBALL_CHARGE_DURATION, 0.0, 1.0)
		return sin(progress * PI * 0.5)
	if fireball_release_timer > 0.0:
		var progress = clamp(fireball_release_timer / FIREBALL_RELEASE_DURATION, 0.0, 1.0)
		return fireball_release_amount * progress * progress
	return 0.0

func get_fireball_hit_enemy(fireball_pos: Vector2) -> int:
	for i in range(enemies.size()):
		if enemies[i]["position"].distance_to(fireball_pos) < (ENEMY_SIZE + FIREBALL_SIZE) / 2.0:
			return i
	return -1

func explode_fireball(center: Vector2) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i]["position"].distance_to(center) <= FIREBALL_BLAST_RADIUS:
			drop_enemy_loot(enemies[i]["position"])
			enemies.remove_at(i)

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

func update_traps() -> void:
	for trap in traps:
		if trap["position"].distance_to(player_pos) > TRAP_TRIGGER_RADIUS:
			continue
		match trap["type"]:
			"lava":
				damage_player()
			"spikes":
				if is_spike_trap_active(trap):
					damage_player()
			"shock":
				if is_shock_trap_active(trap):
					damage_player()

func is_spike_trap_active(trap: Dictionary) -> bool:
	return fmod(elapsed_time + trap["phase"], SPIKE_CYCLE_DURATION) < SPIKE_ACTIVE_TIME

func is_shock_trap_active(trap: Dictionary) -> bool:
	return fmod(elapsed_time + trap["phase"], 2.2) < 0.45

func apply_pickup(type: String) -> void:
	match type:
		"coin":
			score += 10
		"heal":
			player_health = min(3, player_health + 1)
		"speed":
			active_buffs["speed"] = 7.0
		"light":
			active_buffs["light"] = 9.0
		"shield":
			active_buffs["shield"] = 6.0

func drop_enemy_loot(drop_position: Vector2) -> void:
	var drop_count = get_random_loot_count()
	for i in range(drop_count):
		var offset = Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		var loot_position = drop_position + offset
		if not is_walkable_world(loot_position):
			loot_position = drop_position
		pickups.append({
			"type": get_random_loot_type(),
			"position": loot_position,
		})

func get_random_loot_count() -> int:
	var roll = randf()
	if roll < 0.35:
		return 0
	if roll < 0.78:
		return 1
	if roll < 0.95:
		return 2
	return 3

func get_random_loot_type() -> String:
	var roll = randf()
	if roll < 0.52:
		return "coin"
	if roll < 0.68:
		return "heal"
	if roll < 0.81:
		return "speed"
	if roll < 0.92:
		return "light"
	return "shield"

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
		release_mouse()

func handle_game_over_click(pos: Vector2) -> void:
	if get_restart_button_rect().has_point(pos):
		reset_game()
	elif get_quit_button_rect().has_point(pos):
		get_tree().quit()

func get_restart_button_rect() -> Rect2:
	return Rect2(MAP_ORIGIN + Vector2(335, 330), Vector2(330, 58))

func get_quit_button_rect() -> Rect2:
	return Rect2(MAP_ORIGIN + Vector2(335, 405), Vector2(330, 58))

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
	return cell_to_world(exit_cell)

func get_light_range() -> float:
	return LIGHT_RANGE * 1.45 if active_buffs["light"] > 0.0 else LIGHT_RANGE

func get_light_angle() -> float:
	if first_person_mode:
		return first_person_angle
	return get_mouse_aim_angle()

func get_mouse_aim_angle() -> float:
	if virtual_aim_pos != Vector2.ZERO:
		return (virtual_aim_pos - player_pos).angle()
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
	if first_person_mode:
		draw_first_person_view()
	else:
		draw_title_ui()
		draw_map(false)
		draw_decorations(false)
		draw_traps(false)
		draw_arrows(false)
		draw_fireballs(false)
		draw_pickups(false)
		draw_enemies(false)
		draw_player(false)
		draw_fog()
		draw_map(true)
		draw_decorations(true)
		draw_traps(true)
		draw_arrows(true)
		draw_fireballs(true)
		draw_pickups(true)
		draw_enemies(true)
		draw_light_overlay()
		draw_top_down_aim_marker()
		draw_held_weapon()
		draw_held_fireball_charge()
		draw_sword()
		draw_player(true)
	draw_hud()
	
	if game_state == "game_over":
		draw_game_over()

func get_font() -> Font:
	return ThemeDB.get_fallback_font()

func draw_title_ui() -> void:
	var font = get_font()
	draw_string(font, Vector2(452, 55), "Sound Labyrinth", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("#00ff88"))

func draw_first_person_view() -> void:
	var horizon = VIEWPORT_SIZE.y * 0.47
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE.x, horizon)), Color("#060b10"))
	draw_rect(Rect2(Vector2(0, horizon), Vector2(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y - horizon)), Color("#11100d"))
	draw_first_person_walls(horizon)
	draw_first_person_objects(horizon)
	draw_first_person_weapon()
	draw_first_person_crosshair()

func draw_first_person_walls(horizon: float) -> void:
	var angle = get_light_angle()
	var column_width = VIEWPORT_SIZE.x / float(FIRST_PERSON_RAYS)
	for ray_index in range(FIRST_PERSON_RAYS):
		var t = float(ray_index) / float(FIRST_PERSON_RAYS - 1)
		var ray_angle = angle - FIRST_PERSON_FOV / 2.0 + FIRST_PERSON_FOV * t
		var hit = cast_first_person_ray(ray_angle)
		var corrected_distance = max(1.0, hit["distance"] * cos(ray_angle - angle))
		var wall_height = clamp((TILE_SIZE * 720.0) / corrected_distance, 24.0, VIEWPORT_SIZE.y * 1.35)
		var shade = clamp(1.0 - corrected_distance / FIRST_PERSON_VIEW_DISTANCE, 0.08, 1.0)
		var x = ray_index * column_width
		var wall_top = horizon - wall_height * 0.5
		var wall_rect = Rect2(Vector2(x, wall_top), Vector2(column_width + 1.0, wall_height))
		draw_first_person_brick_column(wall_rect, hit["position"], shade, corrected_distance)

func draw_first_person_brick_column(wall_rect: Rect2, hit_position: Vector2, shade: float, distance: float) -> void:
	var texture_u = fposmod(hit_position.x + hit_position.y, FIRST_PERSON_BRICK_WIDTH)
	var brick_row_height = max(4.0, FIRST_PERSON_BRICK_HEIGHT * wall_rect.size.y / TILE_SIZE)
	var row_index = floori((wall_rect.position.y - VIEWPORT_SIZE.y * 0.47) / brick_row_height)
	var row_offset = FIRST_PERSON_BRICK_WIDTH * 0.5 if row_index % 2 == 0 else 0.0
	var staggered_u = fposmod(texture_u + row_offset, FIRST_PERSON_BRICK_WIDTH)
	var mortar = Color("#07251a").darkened(0.28 * (1.0 - shade))
	var base_green = Color("#174f2f").lerp(Color("#45b861"), shade * 0.68)
	var moss_green = Color("#0d3425").lerp(Color("#1e7a45"), shade * 0.5)
	var column_tint = 0.04 * sin(hit_position.x * 0.09 + hit_position.y * 0.05)
	var brick_color = base_green.lightened(max(column_tint, 0.0)).darkened(max(-column_tint, 0.0))
	draw_rect(wall_rect, brick_color)
	var y = wall_rect.position.y
	while y < wall_rect.position.y + wall_rect.size.y:
		var row_rect = Rect2(Vector2(wall_rect.position.x, y), Vector2(wall_rect.size.x, min(FIRST_PERSON_MORTAR_THICKNESS, wall_rect.end.y - y)))
		draw_rect(row_rect, mortar)
		var row_mid = y + brick_row_height * 0.5
		var row_moss = Rect2(Vector2(wall_rect.position.x, row_mid), Vector2(wall_rect.size.x, min(2.0, wall_rect.end.y - row_mid)))
		draw_rect(row_moss, moss_green.darkened(0.22), false, 1.0)
		y += brick_row_height
	if staggered_u < FIRST_PERSON_MORTAR_THICKNESS or staggered_u > FIRST_PERSON_BRICK_WIDTH - FIRST_PERSON_MORTAR_THICKNESS:
		draw_rect(wall_rect, mortar)
	var edge_shadow = clamp(distance / FIRST_PERSON_VIEW_DISTANCE, 0.0, 1.0)
	draw_rect(Rect2(wall_rect.position, Vector2(wall_rect.size.x, 3.0)), brick_color.lightened(0.16 * shade))
	draw_rect(Rect2(Vector2(wall_rect.position.x, wall_rect.end.y - 3.0), Vector2(wall_rect.size.x, 3.0)), brick_color.darkened(0.3 + edge_shadow * 0.2))

func cast_first_person_ray(angle: float) -> Dictionary:
	var direction = Vector2(cos(angle), sin(angle))
	var distance = 0.0
	while distance < FIRST_PERSON_VIEW_DISTANCE:
		var pos = player_pos + direction * distance
		if is_wall_world(pos):
			return {
				"position": pos,
				"distance": distance,
			}
		distance += FIRST_PERSON_RAY_STEP
	return {
		"position": player_pos + direction * FIRST_PERSON_VIEW_DISTANCE,
		"distance": FIRST_PERSON_VIEW_DISTANCE,
	}

func is_wall_world(world_pos: Vector2) -> bool:
	var local = world_pos - MAP_ORIGIN
	var col = floori(local.x / TILE_SIZE)
	var row = floori(local.y / TILE_SIZE)
	if row < 0 or row >= MAP_ROWS or col < 0 or col >= MAP_COLS:
		return true
	return tiles[row][col] == 1

func draw_first_person_objects(horizon: float) -> void:
	var objects := []
	objects.append({
		"type": "exit",
		"position": get_exit_position(),
		"color": Color("#00ff66"),
		"size": 64.0,
	})
	for decoration in decorations:
		if decoration["type"] == "torch":
			objects.append({
				"type": "torch",
				"position": decoration["position"],
				"color": Color("#ff9f1c"),
				"size": 36.0,
			})
	for trap in traps:
		objects.append({
			"type": trap["type"],
			"position": trap["position"],
			"color": get_first_person_trap_color(trap),
			"size": 40.0,
		})
	for pickup in pickups:
		objects.append({
			"type": pickup["type"],
			"position": pickup["position"],
			"color": get_pickup_color(pickup["type"]),
			"size": 32.0,
		})
	for enemy in enemies:
		objects.append({
			"type": "enemy",
			"position": enemy["position"],
			"color": Color("#ff0000") if enemy["alert"] else Color("#ff6600"),
			"size": 54.0,
		})
	for arrow in arrows:
		objects.append({
			"type": "arrow",
			"position": arrow["position"],
			"color": Color("#dbeafe"),
			"size": 18.0,
		})
	for fireball in fireballs:
		objects.append({
			"type": "fireball",
			"position": fireball["position"],
			"color": Color("#ff7a18"),
			"size": 34.0,
		})
	objects.sort_custom(func(a, b): return player_pos.distance_to(a["position"]) > player_pos.distance_to(b["position"]))
	for object in objects:
		draw_first_person_object(object, horizon)

func draw_first_person_object(object: Dictionary, horizon: float) -> void:
	var to_object: Vector2 = object["position"] - player_pos
	var distance = to_object.length()
	if distance < 8.0 or distance > FIRST_PERSON_VIEW_DISTANCE:
		return
	var view_angle = get_light_angle()
	var object_angle = angle_difference(view_angle, to_object.angle())
	if abs(object_angle) > FIRST_PERSON_FOV * 0.56:
		return
	var forward_hit = cast_first_person_ray(to_object.angle())
	if forward_hit["distance"] + 18.0 < distance:
		return
	var screen_x = VIEWPORT_SIZE.x * 0.5 + (object_angle / (FIRST_PERSON_FOV * 0.5)) * VIEWPORT_SIZE.x * 0.5
	var projected_size = clamp((object["size"] * 520.0) / distance, 12.0, 180.0)
	var base_y = horizon + projected_size * 0.78
	var color: Color = object["color"]
	var shade = clamp(1.0 - distance / FIRST_PERSON_VIEW_DISTANCE, 0.2, 1.0)
	color = color.darkened(1.0 - shade)
	match object["type"]:
		"enemy":
			draw_rect(Rect2(Vector2(screen_x - projected_size * 0.35, base_y - projected_size), Vector2(projected_size * 0.7, projected_size)), color)
			draw_circle(Vector2(screen_x, base_y - projected_size * 1.08), projected_size * 0.22, color.lightened(0.15))
		"exit":
			draw_rect(Rect2(Vector2(screen_x - projected_size * 0.5, base_y - projected_size * 1.1), Vector2(projected_size, projected_size * 1.1)), color)
			draw_rect(Rect2(Vector2(screen_x - projected_size * 0.5, base_y - projected_size * 1.1), Vector2(projected_size, projected_size * 1.1)), Color("#001800"), false, 2.0)
		"fireball":
			draw_circle(Vector2(screen_x, base_y - projected_size * 0.5), projected_size * 0.5, color)
			draw_circle(Vector2(screen_x, base_y - projected_size * 0.5), projected_size * 0.25, Color("#ffe066").darkened(1.0 - shade))
		"arrow":
			draw_line(Vector2(screen_x - projected_size * 0.8, base_y - projected_size * 0.5), Vector2(screen_x + projected_size * 0.8, base_y - projected_size * 0.5), color, 2.0)
		"torch":
			draw_first_person_torch(screen_x, base_y, projected_size, shade, color)
		_:
			draw_circle(Vector2(screen_x, base_y - projected_size * 0.5), projected_size * 0.45, color)

func draw_first_person_torch(screen_x: float, base_y: float, projected_size: float, shade: float, flame_color: Color) -> void:
	var flame_center = Vector2(screen_x, base_y - projected_size * 0.82)
	var sconce_top = Vector2(screen_x, base_y - projected_size * 0.5)
	var sconce_bottom = Vector2(screen_x, base_y - projected_size * 0.08)
	var metal_color = Color("#42301f").lerp(Color("#9b6a32"), shade)
	var wood_color = Color("#2a1608").lerp(Color("#704019"), shade)
	draw_circle(flame_center, projected_size * 0.78, Color(1.0, 0.47, 0.06, 0.14 * shade))
	draw_line(sconce_top + Vector2(-projected_size * 0.22, 0.0), sconce_top + Vector2(projected_size * 0.22, 0.0), metal_color, max(2.0, projected_size * 0.08))
	draw_line(sconce_top, sconce_bottom, wood_color, max(3.0, projected_size * 0.1))
	draw_line(sconce_top, sconce_bottom + Vector2(-projected_size * 0.18, projected_size * 0.08), metal_color.darkened(0.25), max(2.0, projected_size * 0.05))
	draw_line(sconce_top, sconce_bottom + Vector2(projected_size * 0.18, projected_size * 0.08), metal_color.darkened(0.25), max(2.0, projected_size * 0.05))
	var flicker = 0.9 + sin(elapsed_time * 10.0 + screen_x * 0.03) * 0.1
	draw_circle(flame_center, projected_size * 0.34 * flicker, flame_color)
	draw_circle(flame_center + Vector2(0.0, -projected_size * 0.03), projected_size * 0.16, Color("#ffe066").darkened(1.0 - shade))

func get_first_person_trap_color(trap: Dictionary) -> Color:
	match trap["type"]:
		"lava":
			return Color("#ff4d00")
		"spikes":
			return Color("#d1d5db") if is_spike_trap_active(trap) else Color("#777777")
		"shock":
			return Color("#67e8f9") if is_shock_trap_active(trap) else Color("#25636d")
	return Color.WHITE

func draw_first_person_weapon() -> void:
	var center = get_first_person_weapon_center()
	if active_weapon == "bow":
		draw_first_person_bow(center)
	else:
		draw_first_person_sword(center)
	draw_first_person_fireball_charge(center)

func get_first_person_weapon_center() -> Vector2:
	var moving = get_first_person_move_direction() != Vector2.ZERO
	var bob = Vector2.ZERO
	if moving:
		bob = Vector2(
			sin(elapsed_time * FIRST_PERSON_WEAPON_BOB_SPEED) * FIRST_PERSON_WEAPON_BOB_AMOUNT * 0.65,
			abs(cos(elapsed_time * FIRST_PERSON_WEAPON_BOB_SPEED)) * FIRST_PERSON_WEAPON_BOB_AMOUNT
		)
	return Vector2(VIEWPORT_SIZE.x * 0.5, VIEWPORT_SIZE.y - 88.0) + bob + first_person_weapon_sway

func draw_first_person_sword(center: Vector2) -> void:
	var swing = 0.0
	if sword_timer > 0.0:
		var progress = 1.0 - sword_timer / SWORD_DURATION
		swing = sin(progress * PI) * 68.0
	var guard = center + Vector2(82 + swing * 0.2, 20 - swing * 0.18)
	var handle_start = center + Vector2(48 + swing * 0.12, 48)
	var handle_end = center + Vector2(75 + swing * 0.18, 18 - swing * 0.12)
	var blade_end = center + Vector2(142 - swing * 0.55, -56 + swing * 0.85)
	var blade_normal = (blade_end - handle_end).normalized().rotated(PI / 2.0)
	var tip_left = blade_end - (blade_end - handle_end).normalized() * 12.0 + blade_normal * 6.0
	var tip_right = blade_end - (blade_end - handle_end).normalized() * 12.0 - blade_normal * 6.0
	
	draw_line(handle_start, handle_end, Color("#6b3f1d"), 8.0)
	draw_line(guard + Vector2(-18, -12), guard + Vector2(18, 12), Color("#d9b36c"), 6.0)
	draw_line(handle_end, blade_end, Color("#d9f8ff"), 9.0)
	draw_colored_polygon(PackedVector2Array([blade_end, tip_left, tip_right]), Color("#f5fdff"))
	draw_line(handle_end, blade_end, Color.WHITE, 2.5)

func draw_first_person_bow(center: Vector2) -> void:
	var draw_amount = get_bow_draw_amount()
	var recoil = (1.0 - draw_amount) * 10.0
	var bow_center = center + Vector2(92 - recoil, -4 + sin(elapsed_time * 6.0) * 2.0)
	var upper_string = bow_center + Vector2(-36.0, -54.0)
	var lower_string = bow_center + Vector2(-36.0, 50.0)
	var nock = center + Vector2(56.0 - draw_amount * 38.0, -4.0)
	var arrow_tip = center + Vector2(132.0 + draw_amount * 8.0, -4.0)
	var arrow_visible = bow_pending_arrow or bow_release_timer > 0.0 or bow_cooldown <= 0.0
	
	draw_arc(bow_center, 62.0, PI * 0.62, PI * 1.38, 24, Color("#b45309"), 7.0)
	draw_line(upper_string, nock, Color("#dbeafe"), 2.0)
	draw_line(nock, lower_string, Color("#dbeafe"), 2.0)
	draw_circle(nock, 3.0 + draw_amount * 1.5, Color("#f8fafc"))
	if arrow_visible:
		draw_line(nock, arrow_tip, Color("#f8fafc"), 3.0)
		draw_colored_polygon(PackedVector2Array([
			arrow_tip + Vector2(8.0, 0.0),
			arrow_tip + Vector2(-4.0, -6.0),
			arrow_tip + Vector2(-4.0, 6.0),
		]), Color("#f8fafc"))

func draw_first_person_fireball_charge(center: Vector2) -> void:
	var charge = get_fireball_charge_amount()
	if charge <= 0.0:
		return
	var palm = center + Vector2(-96.0 + charge * 18.0, 22.0 - charge * 18.0)
	var pulse = 0.5 + sin(elapsed_time * 18.0) * 0.5
	var radius = 12.0 + charge * 22.0 + pulse * charge * 3.0
	draw_circle(palm, radius + 12.0, Color(1.0, 0.22, 0.02, 0.16 + charge * 0.12))
	draw_circle(palm, radius, Color("#ff7a18"))
	draw_circle(palm + Vector2(4.0, -3.0), radius * 0.48, Color("#ffe066"))
	draw_arc(palm, radius + 6.0, elapsed_time * 9.0, elapsed_time * 9.0 + PI * 1.25, 14, Color("#ffd166"), 2.5)
	draw_arc(palm, radius + 12.0, -elapsed_time * 7.0, -elapsed_time * 7.0 + PI * 0.95, 14, Color("#ff2e00"), 2.0)

func draw_first_person_crosshair() -> void:
	var center = VIEWPORT_SIZE * 0.5
	draw_line(center + Vector2(-10, 0), center + Vector2(-3, 0), Color("#d9f8ff"), 1.5)
	draw_line(center + Vector2(3, 0), center + Vector2(10, 0), Color("#d9f8ff"), 1.5)
	draw_line(center + Vector2(0, -10), center + Vector2(0, -3), Color("#d9f8ff"), 1.5)
	draw_line(center + Vector2(0, 3), center + Vector2(0, 10), Color("#d9f8ff"), 1.5)

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

func draw_decorations(lit_only: bool) -> void:
	for decoration in decorations:
		var lit = is_in_light(decoration["position"])
		if lit_only != lit:
			continue
		if decoration["type"] == "torch":
			draw_torch(decoration, lit)

func draw_torch(decoration: Dictionary, lit: bool) -> void:
	var pos: Vector2 = decoration["position"]
	var normal: Vector2 = decoration["normal"]
	var tangent = normal.rotated(PI / 2.0)
	var flicker = 0.75 + sin(elapsed_time * 8.0 + decoration["phase"]) * 0.25
	var bracket_color = Color("#6b3f1d") if lit else Color("#1f1209")
	var flame_color = Color("#ff9f1c") if lit else Color("#3a1703")
	var core_color = Color("#ffe066") if lit else Color("#5a2607")
	if lit:
		draw_circle(pos + normal * 2.0, 18.0 + flicker * 5.0, Color(1.0, 0.42, 0.08, 0.16))
	draw_line(pos - tangent * 6.0, pos + tangent * 6.0, bracket_color, 3.0)
	draw_line(pos - normal * 8.0, pos + normal * 2.0, bracket_color, 4.0)
	draw_circle(pos + normal * 8.0, TORCH_SIZE * 0.5 * flicker, flame_color)
	draw_circle(pos + normal * 8.0, TORCH_SIZE * 0.25, core_color)

func draw_traps(lit_only: bool) -> void:
	for trap in traps:
		var lit = is_in_light(trap["position"])
		if lit_only != lit:
			continue
		match trap["type"]:
			"lava":
				draw_lava_trap(trap, lit)
			"spikes":
				draw_spike_trap(trap, lit)
			"shock":
				draw_shock_trap(trap, lit)

func draw_lava_trap(trap: Dictionary, lit: bool) -> void:
	var pos: Vector2 = trap["position"]
	var rect = Rect2(pos - Vector2(TRAP_SIZE / 2.0, TRAP_SIZE / 2.0), Vector2(TRAP_SIZE, TRAP_SIZE))
	var base_color = Color("#ff4d00") if lit else Color("#351006")
	var hot_color = Color("#ffd166") if lit else Color("#5a2708")
	draw_rect(rect, base_color)
	draw_circle(pos + Vector2(-7, -4), 6.0, hot_color)
	draw_circle(pos + Vector2(8, 6), 5.0, hot_color.darkened(0.15))
	draw_rect(rect, Color("#ffb000") if lit else Color("#4a1904"), false, 2.0)

func draw_spike_trap(trap: Dictionary, lit: bool) -> void:
	var pos: Vector2 = trap["position"]
	var active = is_spike_trap_active(trap)
	var base_color = Color("#444444") if lit else Color("#111111")
	var spike_color = Color("#e5e7eb") if lit and active else Color("#777777")
	if not lit:
		spike_color = Color("#202020")
	var rect = Rect2(pos - Vector2(TRAP_SIZE / 2.0, TRAP_SIZE / 2.0), Vector2(TRAP_SIZE, TRAP_SIZE))
	draw_rect(rect, base_color)
	for i in range(3):
		var x = rect.position.x + 8.0 + i * 9.0
		var height = 18.0 if active else 9.0
		var y = pos.y + 10.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y),
			Vector2(x + 4.5, y - height),
			Vector2(x + 9.0, y),
		]), spike_color)
	draw_rect(rect, Color("#9ca3af") if lit else Color("#202020"), false, 1.5)

func draw_shock_trap(trap: Dictionary, lit: bool) -> void:
	var pos: Vector2 = trap["position"]
	var active = is_shock_trap_active(trap)
	var rect = Rect2(pos - Vector2(TRAP_SIZE / 2.0, TRAP_SIZE / 2.0), Vector2(TRAP_SIZE, TRAP_SIZE))
	var base_color = Color("#0f2d36") if lit else Color("#071014")
	var arc_color = Color("#67e8f9") if active and lit else Color("#25636d")
	draw_rect(rect, base_color)
	draw_circle(pos, 5.5, Color("#a7f3d0") if lit else Color("#12322e"))
	draw_line(pos + Vector2(-12, -8), pos + Vector2(-2, 2), arc_color, 2.0)
	draw_line(pos + Vector2(-2, 2), pos + Vector2(8, -6), arc_color, 2.0)
	draw_line(pos + Vector2(8, -6), pos + Vector2(13, 7), arc_color, 2.0)
	draw_rect(rect, Color("#22d3ee") if lit else Color("#12343c"), false, 1.5)

func get_pickup_color(type: String) -> Color:
	match type:
		"coin":
			return Color("#f59e0b")
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
		"coin":
			return "$"
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

func draw_arrows(lit_only: bool) -> void:
	for arrow in arrows:
		var pos: Vector2 = arrow["position"]
		var lit = is_in_light(pos)
		if lit_only != lit:
			continue
		var direction: Vector2 = arrow["direction"]
		var normal = direction.rotated(PI / 2.0)
		var tip = pos + direction * (ARROW_SIZE * 0.55)
		var tail = pos - direction * (ARROW_SIZE * 0.65)
		var color = Color("#f8fafc") if lit else Color("#2c343d")
		var feather = Color("#38bdf8") if lit else Color("#16323d")
		draw_line(tail, tip, color, 2.5)
		draw_colored_polygon(PackedVector2Array([
			tip,
			tip - direction * 6.0 + normal * 3.0,
			tip - direction * 6.0 - normal * 3.0,
		]), color)
		draw_line(tail, tail - direction * 5.0 + normal * 4.0, feather, 2.0)
		draw_line(tail, tail - direction * 5.0 - normal * 4.0, feather, 2.0)

func draw_fireballs(lit_only: bool) -> void:
	for fireball in fireballs:
		var pos: Vector2 = fireball["position"]
		var lit = is_in_light(pos)
		if lit_only != lit:
			continue
		var direction: Vector2 = fireball["direction"]
		var normal = direction.rotated(PI / 2.0)
		var flame = Color("#ff7a18") if lit else Color("#361107")
		var core = Color("#ffe066") if lit else Color("#5c2a0a")
		var ember = Color("#ff2e00") if lit else Color("#220705")
		var tail = pos - direction * 15.0
		draw_circle(pos, FIREBALL_SIZE / 2.0, flame)
		draw_circle(pos + direction * 3.0, FIREBALL_SIZE / 3.2, core)
		draw_colored_polygon(PackedVector2Array([
			tail - normal * 7.0,
			tail - direction * 18.0,
			tail + normal * 7.0,
			pos - direction * 5.0,
		]), ember)
		draw_arc(pos, FIREBALL_SIZE * 0.7, fireball["spin"], fireball["spin"] + PI * 1.35, 12, core, 2.0)

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

func draw_top_down_aim_marker() -> void:
	draw_line(virtual_aim_pos + Vector2(-8, 0), virtual_aim_pos + Vector2(-3, 0), Color("#d9f8ff"), 1.5)
	draw_line(virtual_aim_pos + Vector2(3, 0), virtual_aim_pos + Vector2(8, 0), Color("#d9f8ff"), 1.5)
	draw_line(virtual_aim_pos + Vector2(0, -8), virtual_aim_pos + Vector2(0, -3), Color("#d9f8ff"), 1.5)
	draw_line(virtual_aim_pos + Vector2(0, 3), virtual_aim_pos + Vector2(0, 8), Color("#d9f8ff"), 1.5)

func draw_held_weapon() -> void:
	if active_weapon == "bow":
		draw_held_bow()
	else:
		draw_held_sword()

func draw_held_sword() -> void:
	var angle = get_light_angle()
	var direction = Vector2(cos(angle), sin(angle))
	var normal = direction.rotated(PI / 2.0)
	var handle_start = player_pos + direction * 8.0 - normal * 3.0
	var handle_end = handle_start + direction * SWORD_HANDLE_LENGTH
	var blade_end = handle_end + direction * SWORD_BLADE_LENGTH
	var tip_left = blade_end - direction * 9.0 + normal * 4.0
	var tip_right = blade_end - direction * 9.0 - normal * 4.0
	
	draw_line(handle_start, handle_end, Color("#6b3f1d"), 5.0)
	draw_line(handle_end - normal * 8.0, handle_end + normal * 8.0, Color("#d9b36c"), 4.0)
	draw_line(handle_end, blade_end, Color("#d9f8ff"), 6.0)
	draw_colored_polygon(PackedVector2Array([blade_end, tip_left, tip_right]), Color("#f5fdff"))
	draw_line(handle_end, blade_end, Color.WHITE, 2.0)

func draw_held_bow() -> void:
	var angle = get_light_angle()
	var direction = Vector2(cos(angle), sin(angle))
	var normal = direction.rotated(PI / 2.0)
	var draw_amount = get_bow_draw_amount()
	var grip = player_pos + direction * 12.0
	var top = grip + normal * 17.0 + direction * 10.0
	var bottom = grip - normal * 17.0 + direction * 10.0
	var nock = grip - direction * (4.0 + draw_amount * 18.0)
	var arrow_tip = grip + direction * (29.0 + draw_amount * 5.0)
	var arrow_visible = bow_pending_arrow or bow_release_timer > 0.0 or bow_cooldown <= 0.0
	var string_color = Color("#dbeafe")
	var bow_color = Color("#b45309")
	draw_arc(grip + direction * 6.0, 20.0, angle - PI * 0.5, angle + PI * 0.5, 14, bow_color, 4.0)
	draw_line(top, nock, string_color, 1.6)
	draw_line(nock, bottom, string_color, 1.6)
	if arrow_visible:
		draw_line(nock, arrow_tip, Color("#f8fafc"), 2.0)
		draw_colored_polygon(PackedVector2Array([
			arrow_tip + direction * 3.0,
			arrow_tip - direction * 5.0 + normal * 3.0,
			arrow_tip - direction * 5.0 - normal * 3.0,
		]), Color("#f8fafc"))

func draw_held_fireball_charge() -> void:
	var charge = get_fireball_charge_amount()
	if charge <= 0.0:
		return
	var angle = get_light_angle()
	var direction = Vector2(cos(angle), sin(angle))
	var normal = direction.rotated(PI / 2.0)
	var palm = player_pos + direction * (18.0 + charge * 5.0) - normal * 13.0
	var pulse = 0.5 + sin(elapsed_time * 18.0) * 0.5
	var radius = 7.0 + charge * 12.0 + pulse * charge * 2.0
	draw_circle(palm, radius + 8.0, Color(1.0, 0.22, 0.02, 0.18 + charge * 0.14))
	draw_circle(palm, radius, Color("#ff7a18"))
	draw_circle(palm + direction * 2.0 - normal * 1.5, radius * 0.45, Color("#ffe066"))
	draw_arc(palm, radius + 4.0, elapsed_time * 9.0, elapsed_time * 9.0 + PI * 1.2, 12, Color("#ffd166"), 1.8)

func draw_sword() -> void:
	if sword_timer <= 0.0:
		return
	
	var progress = 1.0 - sword_timer / SWORD_DURATION
	var swing_center = sword_angle + lerp(-SWORD_SPREAD * 0.35, SWORD_SPREAD * 0.35, progress)
	var left_angle = swing_center - SWORD_SPREAD / 2.0
	var right_angle = swing_center + SWORD_SPREAD / 2.0
	var points = PackedVector2Array([player_pos])
	for i in range(14):
		var t = float(i) / 13.0
		var arc_angle = lerp(left_angle, right_angle, t)
		points.append(player_pos + Vector2(cos(arc_angle), sin(arc_angle)) * SWORD_RANGE)
	
	draw_colored_polygon(points, Color(0.85, 0.95, 1.0, 0.24))
	draw_arc(player_pos, SWORD_RANGE, left_angle, right_angle, 20, Color("#d9f8ff"), 4.0)
	draw_line(player_pos, player_pos + Vector2(cos(swing_center), sin(swing_center)) * (SWORD_RANGE + 8.0), Color.WHITE, 2.5)

func draw_hud() -> void:
	var font = get_font()
	draw_rect(Rect2(MAP_ORIGIN.x, 20, MAP_COLS * TILE_SIZE, 52), Color("#191919"))
	draw_rect(Rect2(MAP_ORIGIN.x, 20, MAP_COLS * TILE_SIZE, 52), Color("#00ff88"), false, 2.0)
	draw_string(font, Vector2(MAP_ORIGIN.x + 120, 54), "Health: %d" % player_health, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(MAP_ORIGIN.x + 340, 54), "Level: %d" % current_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(MAP_ORIGIN.x + 560, 54), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(MAP_ORIGIN.x + 780, 54), "Time: %ds" % int(elapsed_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(MAP_ORIGIN.x + 16, 54), "Weapon: %s" % get_weapon_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, get_weapon_color())
	draw_string(font, Vector2(MAP_ORIGIN.x + 16, 34), "View: %s" % get_view_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a7f3d0") if first_person_mode else Color("#8f8f8f"))
	
	var buff_text := []
	for key in active_buffs.keys():
		if active_buffs[key] > 0.0:
			buff_text.append("%s %ds" % [String(key).to_upper(), ceili(active_buffs[key])])
	if not buff_text.is_empty():
		draw_string(font, MAP_ORIGIN + Vector2(16, 18), " | ".join(buff_text), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func get_weapon_label() -> String:
	return "BOW" if active_weapon == "bow" else "SWORD"

func get_weapon_color() -> Color:
	return Color("#38bdf8") if active_weapon == "bow" else Color("#d9f8ff")

func get_view_label() -> String:
	return "FIRST PERSON" if first_person_mode else "TOP DOWN"

func draw_game_over() -> void:
	var font = get_font()
	draw_rect(Rect2(MAP_ORIGIN, Vector2(MAP_COLS * TILE_SIZE, MAP_ROWS * TILE_SIZE)), Color(0, 0, 0, 0.78))
	draw_string(font, MAP_ORIGIN + Vector2(356, 255), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.RED)
	draw_game_over_button(get_restart_button_rect(), "ПЕРЕЗАПУСТИТЬ")
	draw_game_over_button(get_quit_button_rect(), "ВЫЙТИ ИЗ ИГРЫ")

func draw_game_over_button(rect: Rect2, label: String) -> void:
	var mouse_pos = get_global_mouse_position()
	var hovered = rect.has_point(mouse_pos)
	var fill = Color("#00ff88") if hovered else Color("#191919")
	var border = Color("#d9f8ff") if hovered else Color("#00ff88")
	var text_color = Color("#06130c") if hovered else Color.WHITE
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 2.0)
	draw_string(get_font(), rect.position + Vector2(62, 38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, text_color)
