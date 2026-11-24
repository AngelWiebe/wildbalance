extends Node3D

const SIMULATION_URL := "ws://127.0.0.1:8080/ws"
const Forest := preload("res://scripts/forest.gd")
const DeerModel := preload("res://materials/deer-animated.glb")
const ReworkedGrazeModel := preload("res://materials/deer-graze-rework.glb")
const WolfModel := preload("res://materials/dire-wolf-lite.glb")

@onready var status: Label = %SimulationStatus
@onready var meadow_status: Label = %MeadowStatus
@onready var season_report: Label = %SeasonReport
@onready var overlay: CanvasLayer = $Overlay
@onready var start_screen: Control = $Overlay/StartScreen
@onready var forest: Node3D = $Forest
@onready var atmosphere: WorldEnvironment = $Atmosphere
@onready var sun: DirectionalLight3D = $LateAfternoonSun

var socket := WebSocketPeer.new()
var retry_in := 0.0
var receiving := false
var reseed_cooldown_ticks := 0
var reseeds_remaining := 3
var wolf_call_cooldown_ticks := 0
var ecosystem_balance := 0.0
var balance_streak_ticks := 0
var current_season := "SPRING"
var displayed_season := ""
var seasons_balanced := 0
var stewardship_complete := false
var meadow_food: Array[float] = []
var season_event := "CALM WEATHER"
var season_hint := "conditions are stable"
var season_result := ""
var season_reason := ""
var season_report_ticks := 0
var director_status := "DIRECTOR  •  observing the ecosystem"
var meadows_tended := 0
var game_started := false

var animal_nodes: Dictionary = {}
var animal_targets: Dictionary = {}
var animal_activities: Dictionary = {}
var animal_species: Dictionary = {}
var animal_states: Dictionary = {}
var animal_animations: Dictionary = {}


func _ready() -> void:
	_apply_season_visuals(current_season)
	$Lookout.call("set_controls_enabled", false)


func _process(delta: float) -> void:
	socket.poll()

	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count() > 0:
				_read_snapshot(socket.get_packet().get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			receiving = false
			status.text = "FOREST PREVIEW  /  WAITING FOR GO"
			retry_in -= delta

			if retry_in <= 0.0:
				socket = WebSocketPeer.new()
				socket.connect_to_url(SIMULATION_URL)
				retry_in = 2.0

	for animal_id in animal_nodes:
		if animal_species[animal_id] == &"wolf":
			_update_wolf(animal_id, delta)
		else:
			_update_deer(animal_id, delta)


func _create_deer(deer_id: String, start_position: Vector2) -> void:
	var deer := Node3D.new()
	deer.name = deer_id

	match deer_id:
		"deer-2":
			deer.scale = Vector3.ONE * 0.92
		"deer-3":
			deer.scale = Vector3.ONE * 0.86
		"deer-4":
			deer.scale = Vector3.ONE * 1.04
		"deer-5":
			deer.scale = Vector3.ONE * 0.95
		"deer-6":
			deer.scale = Vector3.ONE * 0.89

	add_child(deer)

	var model := DeerModel.instantiate()
	deer.add_child(model)

	var animation := model.find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer

	var graze_source := ReworkedGrazeModel.instantiate()
	var graze_source_player := graze_source.find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer

	if animation and graze_source_player and not animation.has_animation(&"graze"):
		var graze_copy_source := graze_source_player.get_animation(&"graze")
		var animation_library := animation.get_animation_library(&"")

		if graze_copy_source and animation_library:
			var graze_copy := graze_copy_source.duplicate() as Animation

			if graze_copy:
				animation_library.add_animation(&"graze", graze_copy)

	graze_source.free()

	if animation:
		var walk := animation.get_animation(&"walk")
		if walk:
			walk.loop_mode = Animation.LOOP_LINEAR

		var graze := animation.get_animation(&"graze")
		if graze:
			graze.loop_mode = Animation.LOOP_NONE

		var rest := animation.get_animation(&"rest")
		if rest:
			rest.loop_mode = Animation.LOOP_LINEAR

		var laydown := animation.get_animation(&"laydown")
		if laydown:
			laydown.loop_mode = Animation.LOOP_NONE

		var get_up := animation.get_animation(&"get up")
		if get_up:
			get_up.loop_mode = Animation.LOOP_NONE

		animation.play(&"graze")
		animation.speed_scale = 0.30

	deer.position = Vector3(
		start_position.x,
		Forest.ground_height(start_position.x, start_position.y),
		start_position.y
	)

	animal_nodes[deer_id] = deer
	animal_targets[deer_id] = start_position
	animal_activities[deer_id] = &"grazing"
	animal_species[deer_id] = &"deer"
	animal_states[deer_id] = &"graze"
	animal_animations[deer_id] = animation


func _create_wolf(wolf_id: String, start_position: Vector2) -> void:
	var wolf := Node3D.new()
	wolf.name = wolf_id
	wolf.scale = Vector3.ONE * 0.60
	add_child(wolf)

	var model := WolfModel.instantiate()
	wolf.add_child(model)

	var animation := model.find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer

	if animation:
		var idle := animation.get_animation(&"idle")
		if idle:
			idle.loop_mode = Animation.LOOP_LINEAR

		var walk := animation.get_animation(&"walk")
		if walk:
			walk.loop_mode = Animation.LOOP_LINEAR
			
		var run := animation.get_animation(&"run")
		if run:
			run.loop_mode = Animation.LOOP_LINEAR

		animation.play(&"idle")
		animation.speed_scale = 0.75

	wolf.position = Vector3(
		start_position.x,
		Forest.ground_height(start_position.x, start_position.y),
		start_position.y
	)

	animal_nodes[wolf_id] = wolf
	animal_targets[wolf_id] = start_position
	animal_activities[wolf_id] = &"wandering"
	animal_species[wolf_id] = &"wolf"
	animal_states[wolf_id] = &"idle"
	animal_animations[wolf_id] = animation

func _update_deer(deer_id: String, delta: float) -> void:
	var deer: Node3D = animal_nodes[deer_id]
	var target_position: Vector2 = animal_targets[deer_id]
	var previous := Vector2(deer.position.x, deer.position.z)
	var activity: StringName = animal_activities[deer_id]

	var follow_rate := 10.0

	if activity == &"fleeing":
		follow_rate = 15.0

	var next_position := previous.lerp(
		target_position,
		1.0 - exp(-follow_rate * delta)
	)
	var movement := next_position - previous
	# Server activities describe intent. The movement check prevents a deer at
	# an escape boundary from looping its walk animation while standing still.
	var is_walking := (
		activity == &"walking" or activity == &"fleeing"
	) and movement.length_squared() > 0.000001

	var animation: AnimationPlayer = animal_animations[deer_id]
	var state: StringName = animal_states[deer_id]

	if animation:
		if activity == &"resting":
			if state != &"laydown" and state != &"rest":
				if animation.has_animation(&"laydown"):
					animation.play(&"laydown")
					animal_states[deer_id] = &"laydown"
				else:
					animation.play(&"rest")
					animal_states[deer_id] = &"rest"

			elif state == &"laydown" and _animation_has_finished(animation):
				animation.play(&"rest")
				animal_states[deer_id] = &"rest"

			animation.speed_scale = 1.0

		elif state == &"laydown" or state == &"rest":
			if animation.has_animation(&"get up"):
				animation.play(&"get up")
				animal_states[deer_id] = &"get_up"
			else:
				animal_states[deer_id] = &"graze"

		elif state == &"get_up" and not _animation_has_finished(animation):
			animation.speed_scale = 1.0

		elif is_walking:
			if state != &"walk":
				animation.play(&"walk")
				animal_states[deer_id] = &"walk"

			animation.speed_scale = 1.40 if activity == &"fleeing" else 1.0
		else:
			if state != &"graze":
				animation.play(&"graze")
				animal_states[deer_id] = &"graze"

			animation.speed_scale = 0.30
	if is_walking and movement.length_squared() > 0.000001:
		var heading := atan2(movement.x, movement.y)
		deer.rotation.y = lerp_angle(
			deer.rotation.y,
			heading,
			1.0 - exp(-7.0 * delta)
		)

	deer.position = Vector3(
		next_position.x,
		Forest.ground_height(next_position.x, next_position.y),
		next_position.y
	)


func _animation_has_finished(animation: AnimationPlayer) -> bool:
	var current := animation.current_animation
	if current.is_empty():
		return true
	var clip := animation.get_animation(current)
	return clip == null or animation.current_animation_position >= clip.length - 0.03


func _update_wolf(wolf_id: String, delta: float) -> void:
	var wolf: Node3D = animal_nodes[wolf_id]
	var target_position: Vector2 = animal_targets[wolf_id]
	var previous := Vector2(wolf.position.x, wolf.position.z)

	var next_position := previous.lerp(
		target_position,
		1.0 - exp(-18.0 * delta)
	)
	var movement := next_position - previous
	var speed := movement.length() / maxf(delta, 0.0001)

	var animation: AnimationPlayer = animal_animations[wolf_id]
	var activity: StringName = animal_activities[wolf_id]
	var state: StringName = animal_states[wolf_id]

	if animation:
		if activity == &"hunting":
			if state != &"run":
				animation.play(&"run")
				animal_states[wolf_id] = &"run"

			animation.speed_scale = clampf(speed / 0.65, 0.75, 1.35)

		elif activity == &"resting":
			if state != &"idle":
				animation.play(&"idle")
				animal_states[wolf_id] = &"idle"

			animation.speed_scale = 0.65

		elif movement.length_squared() > 0.000001:
			if state != &"walk":
				animation.play(&"walk")
				animal_states[wolf_id] = &"walk"

			animation.speed_scale = clampf(speed / 0.35, 0.55, 1.10)

		else:
			if state != &"idle":
				animation.play(&"idle")
				animal_states[wolf_id] = &"idle"

			animation.speed_scale = 0.75

	if movement.length_squared() > 0.000001:
		var heading := atan2(movement.x, movement.y)
		wolf.rotation.y = lerp_angle(
			wolf.rotation.y,
			heading,
			1.0 - exp(-10.0 * delta)
		)

	wolf.position = Vector3(
		next_position.x,
		Forest.ground_height(next_position.x, next_position.y),
		next_position.y
	)

func _read_snapshot(payload: String) -> void:
	var message: Variant = JSON.parse_string(payload)

	if message is not Dictionary or message.get("type") != "snapshot":
		return

	var cooldown: Variant = message.get("reseedCooldown", 0)

	if cooldown is int or cooldown is float:
		reseed_cooldown_ticks = int(cooldown)

	var seeds: Variant = message.get("reseedsRemaining", reseeds_remaining)

	if seeds is int or seeds is float:
		reseeds_remaining = int(seeds)

	var wolf_cooldown: Variant = message.get("wolfCallCooldown", 0)

	if wolf_cooldown is int or wolf_cooldown is float:
		wolf_call_cooldown_ticks = int(wolf_cooldown)
	
	var balance: Variant = message.get("balance", 0.0)

	if balance is int or balance is float:
		ecosystem_balance = float(balance)
	
	var balance_streak: Variant = message.get("balanceStreak", 0)

	if balance_streak is int or balance_streak is float:
		balance_streak_ticks = int(balance_streak)

	var season: Variant = message.get("season", "SPRING")

	if season is String and season != current_season:
		current_season = season
		_apply_season_visuals(current_season)

	var balanced_seasons: Variant = message.get("seasonsBalanced", 0)

	if balanced_seasons is int or balanced_seasons is float:
		seasons_balanced = int(balanced_seasons)

	var complete: Variant = message.get("goalComplete", false)

	if complete is bool:
		stewardship_complete = complete

	var food: Variant = message.get("meadowFood", [])

	if food is Array:
		meadow_food.clear()

		for amount in food:
			if amount is int or amount is float:
				meadow_food.append(clampf(float(amount), 0.0, 1.0))

	var event_name: Variant = message.get("seasonEvent", "CALM WEATHER")
	if event_name is String:
		season_event = event_name

	var event_hint: Variant = message.get("seasonHint", "conditions are stable")
	if event_hint is String:
		season_hint = event_hint

	var result: Variant = message.get("seasonResult", "")
	if result is String:
		season_result = result

	var reason: Variant = message.get("seasonReason", "")
	if reason is String:
		season_reason = reason

	var report_ticks: Variant = message.get("seasonReportTicks", 0)
	if report_ticks is int or report_ticks is float:
		season_report_ticks = int(report_ticks)

	var director: Variant = message.get("director", director_status)
	if director is String:
		director_status = director
	var tended: Variant = message.get("meadowsTended", 0)
	if tended is int or tended is float:
		meadows_tended = int(tended)

	_update_season_report()
	
	var animals: Variant = message.get("animals")

	if animals is not Array:
		return

	for animal in animals:
		if animal is not Dictionary:
			continue

		var animal_id: Variant = animal.get("id")
		var species: Variant = animal.get("species")
		var x: Variant = animal.get("x")
		var z: Variant = animal.get("z")

		if not animal_id is String or not species is String:
			continue
		if not (x is float or x is int):
			continue
		if not (z is float or z is int):
			continue
		if not is_finite(x) or not is_finite(z):
			continue

		var target_position := Vector2(x, z)
		var species_name := StringName(species)
		var activity: Variant = animal.get("activity", "wandering")

		if activity == "dead":
			_remove_animal(animal_id)
			continue

		if not animal_nodes.has(animal_id):
			if species_name == &"wolf":
				_create_wolf(animal_id, target_position)
			else:
				_create_deer(animal_id, target_position)

		if activity is String:
			animal_activities[animal_id] = StringName(activity)

		animal_targets[animal_id] = target_position

	if not receiving:
		receiving = true
		print("Receiving WildBalance Go snapshots")

	var deer_count := 0
	var wolf_count := 0
	var hunt_active := false

	for animal_id in animal_nodes:
		if animal_species[animal_id] == &"wolf":
			wolf_count += 1
			if animal_activities.get(animal_id, &"wandering") == &"hunting":
				hunt_active = true
		else:
			deer_count += 1

	var seed_status := "SEEDS %d LEFT" % reseeds_remaining
	var wolf_call_status := "WOLF CALL READY"

	if reseeds_remaining == 0:
		seed_status = "SEEDS SPENT"
	elif reseed_cooldown_ticks > 0:
		seed_status = "SEED %.1fS" % [
			reseed_cooldown_ticks / 10.0,
		]

	if wolf_call_cooldown_ticks > 0:
		wolf_call_status = "WOLF CALL %.0fS" % [
			wolf_call_cooldown_ticks / 10.0,
		]
	elif hunt_active:
		wolf_call_status = "PACK HUNT  •  PRESS Q"
	
	var balance_status := "BALANCE %.0f%%" % ecosystem_balance
	var goal_status := "TEND %d/2 MEADOWS  •  HEALTH %d/60S  •  %d/4 BALANCED" % [
		meadows_tended,
		int(balance_streak_ticks / 10.0),
		seasons_balanced,
	]

	if stewardship_complete:
		goal_status = "STEWARD GOAL COMPLETE"
		
	status.text = "SIMULATION LIVE  •  %s\n%d ACTIVE DEER  •  %d WOLF\n%s  •  %s\n%s\n%s  •  %s" % [
		current_season,
		deer_count,
		wolf_count,
		seed_status,
		wolf_call_status,
		director_status,
		balance_status,
		goal_status,
	]

	meadow_status.text = _format_meadow_health()


func _format_meadow_health() -> String:
	if meadow_food.is_empty():
		return "MEADOW HEALTH  /  WAITING FOR GO"

	var rows: Array[String] = []
	var labels: Array[String] = []

	for index in meadow_food.size():
		var blocks := clampi(roundi(meadow_food[index] * 4.0), 0, 4)
		labels.append("%d:[%s%s]" % [
			index + 1,
			"#".repeat(blocks),
			"-".repeat(4 - blocks),
		])
		if labels.size() == 4 or index == meadow_food.size() - 1:
			rows.append("   ".join(labels))
			labels.clear()

	return "SEASON EVENT  •  %s — %s\nMEADOWS  •  %s\n             %s   •   PRESS 1–8 TO RESEED" % [
		season_event,
		season_hint.to_upper(),
		rows[0],
		rows[1] if rows.size() > 1 else "",
	]


func _update_season_report() -> void:
	if stewardship_complete:
		season_report.visible = true
		season_report.text = "STEWARD GOAL COMPLETE\nFOUR SEASONS BALANCED  •  PRESS T FOR A NEW RUN"
		return

	if season_report_ticks > 0 and not season_result.is_empty():
		season_report.visible = true
		season_report.text = "%s\n%s" % [season_result, season_reason]
		return

	season_report.visible = false


func _apply_season_visuals(season: String) -> void:
	if displayed_season == season:
		return

	displayed_season = season
	var environment := atmosphere.environment
	if not environment:
		return

	var tint := Color.WHITE
	var sky_top := Color("#486b87")
	var sky_horizon := Color("#b8c5b3")
	var fog := Color("#afbaa8")
	var ambient := Color("#c1d3d5")
	var sun_color := Color("#ffe0aa")
	var sun_energy := 1.15
	var fog_density := 0.009

	match season:
		"SPRING":
			tint = Color("#c6e3ae")
			sky_top = Color("#6796ae")
			sky_horizon = Color("#d5e4bd")
			fog = Color("#c0d4b6")
			ambient = Color("#d0e5d2")
			sun_color = Color("#ffe6b5")
			sun_energy = 1.18
			fog_density = 0.010
		"SUMMER":
			tint = Color("#d5cf8e")
			sky_top = Color("#547f9c")
			sky_horizon = Color("#d9d4ad")
			fog = Color("#c7c5a2")
			ambient = Color("#e0d7ba")
			sun_color = Color("#ffd18a")
			sun_energy = 1.35
			fog_density = 0.006
		"AUTUMN":
			tint = Color("#d19d69")
			sky_top = Color("#6a7183")
			sky_horizon = Color("#d0aa83")
			fog = Color("#b89a82")
			ambient = Color("#d4b39b")
			sun_color = Color("#ffc18a")
			sun_energy = 1.08
			fog_density = 0.014
		"WINTER":
			tint = Color("#9fb9c5")
			sky_top = Color("#7f96aa")
			sky_horizon = Color("#d4dfe2")
			fog = Color("#c6d2d7")
			ambient = Color("#c4d2de")
			sun_color = Color("#d9e7f2")
			sun_energy = 0.78
			fog_density = 0.024

	environment.ambient_light_color = ambient
	environment.fog_light_color = fog
	environment.fog_density = fog_density
	sun.light_color = sun_color
	sun.light_energy = sun_energy

	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	if sky_material:
		sky_material.sky_top_color = sky_top
		sky_material.sky_horizon_color = sky_horizon
		sky_material.ground_horizon_color = sky_horizon

	if forest.has_method("set_season_tint"):
		forest.call("set_season_tint", tint)


func _remove_animal(animal_id: String) -> void:
	if animal_nodes.has(animal_id):
		var animal: Node3D = animal_nodes[animal_id]
		animal.queue_free()

	animal_nodes.erase(animal_id)
	animal_targets.erase(animal_id)
	animal_activities.erase(animal_id)
	animal_species.erase(animal_id)
	animal_states.erase(animal_id)
	animal_animations.erase(animal_id)


func get_first_deer() -> Node3D:
	for animal_id in animal_nodes:
		if animal_species.get(animal_id) == &"deer":
			return animal_nodes[animal_id] as Node3D
	return null

func _send_reseed(meadow_index: int) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	socket.send_text(JSON.stringify({
		"type": "reseed",
		"meadow": meadow_index,
	}))


func _send_wolf_call() -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	socket.send_text(JSON.stringify({"type": "scare_wolf"}))


func _send_restart() -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	socket.send_text(JSON.stringify({"type": "restart"}))


func _send_population_change(species: String, delta: int) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	socket.send_text(JSON.stringify({
		"type": "adjust_%s" % species,
		"delta": delta,
	}))


func _start_game() -> void:
	game_started = true
	start_screen.hide()
	$Lookout.call("set_controls_enabled", true)

func _unhandled_input(event: InputEvent) -> void:
	if not game_started:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
				_start_game()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_H:
				overlay.visible = not overlay.visible
			KEY_1:
				_send_reseed(0)
			KEY_2:
				_send_reseed(1)
			KEY_3:
				_send_reseed(2)
			KEY_4:
				_send_reseed(3)
			KEY_5:
				_send_reseed(4)
			KEY_6:
				_send_reseed(5)
			KEY_7:
				_send_reseed(6)
			KEY_8:
				_send_reseed(7)
			KEY_Q:
				_send_wolf_call()
			KEY_MINUS:
				_send_population_change("deer", -1)
			KEY_EQUAL:
				_send_population_change("deer", 1)
			KEY_BRACKETLEFT:
				_send_population_change("wolf", -1)
			KEY_BRACKETRIGHT:
				_send_population_change("wolf", 1)
			KEY_T:
				_send_restart()
