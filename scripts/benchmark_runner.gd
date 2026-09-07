extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var main_instance: Node2D = null
var player: CharacterBody2D = null
var swarm_mgr: Node2D = null
var part_mgr: Node2D = null

var frame_times: Array[float] = []
var benchmark_duration: float = 15.0 # 15 seconds stress test
var elapsed: float = 0.0
var started: bool = false
var spawn_target: int = 4500

func _init() -> void:
	print("========================================")
	print("🏁 STARTING ISOMETRIC SWARM BENCHMARK 🏁")
	print("========================================")

func _process(delta: float) -> bool:
	if not started:
		_setup_benchmark()
		started = true
		return false

	elapsed += delta
	frame_times.append(delta)

	# Ensure player stays alive during stress test
	if is_instance_valid(player):
		player.is_invulnerable = true
		player.invuln_timer = 999.0
		player.current_health = player.max_health

	# Keep swarm populated up to spawn_target
	if is_instance_valid(swarm_mgr) and is_instance_valid(player):
		var deficit = spawn_target - swarm_mgr.active_count
		if deficit > 0:
			var batch = min(deficit, 250)
			for i in range(batch):
				var ang = randf() * TAU
				var dist = randf_range(200.0, 900.0)
				var pos = player.global_position + Vector2(cos(ang) * dist, sin(ang) * dist * 0.7)
				swarm_mgr.spawn_enemy(pos, randi() % 5)

	if elapsed >= benchmark_duration:
		_finish_benchmark()
		quit(0)
		return true

	return false

func _setup_benchmark() -> void:
	main_instance = MainScene.instantiate()
	root.add_child(main_instance)

	player = main_instance.get_node_or_null("Entities/Player")
	swarm_mgr = main_instance.get_node_or_null("SwarmManager")
	part_mgr = main_instance.get_node_or_null("ParticleManager")

	if not player or not swarm_mgr:
		printerr("Failed to locate Player or SwarmManager!")
		quit(1)
		return

	# Equip all 7 weapons and evolutions
	var weps = ["railgun", "flame", "shockwave", "missile", "blade", "tesla", "mortar"]
	for w in weps:
		for lvl in range(5):
			player.apply_upgrade(w)
		player.apply_upgrade(w + "_evo")

	# Equip all 5 passives maxed
	var passives = ["energy_core", "nano_armor", "thrusters", "magnet", "amp"]
	for p in passives:
		for lvl in range(5):
			player.apply_upgrade(p)

	player.is_invulnerable = true
	player.invuln_timer = 9999.0
	player.max_health = 99999.0
	player.current_health = 99999.0

	# Pre-spawn 4,500 enemies across all 5 types
	for i in range(spawn_target):
		var ang = randf() * TAU
		var dist = randf_range(150.0, 1200.0)
		var p_pos = player.global_position + Vector2(cos(ang) * dist, sin(ang) * dist * 0.7)
		swarm_mgr.spawn_enemy(p_pos, randi() % 5)

	print("Benchmark configured: 7 Evolved Weapons, 5 Passives, 4,500 Swarm Entities.")
	print("Simulating intense late-game combat for %d seconds..." % int(benchmark_duration))

func _finish_benchmark() -> void:
	if frame_times.is_empty():
		print("No frames recorded!")
		return

	var total_time = 0.0
	var max_dt = 0.0
	for dt in frame_times:
		total_time += dt
		if dt > max_dt:
			max_dt = dt

	var frame_count = frame_times.size()
	var avg_fps = float(frame_count) / max(0.001, total_time)
	var min_fps = 1.0 / max(0.001, max_dt)

	# Calculate 1% Low FPS
	var sorted_dts = frame_times.duplicate()
	sorted_dts.sort()
	var low_1_pct_idx = int(float(frame_count) * 0.99)
	var low_1_pct_dt = sorted_dts[clamp(low_1_pct_idx, 0, frame_count - 1)]
	var low_1_pct_fps = 1.0 / max(0.001, low_1_pct_dt)

	print("========================================")
	print("📊 BENCHMARK RESULTS 📊")
	print("Total Frames:       %d" % frame_count)
	print("Total Duration:     %.2f s" % total_time)
	print("Average FPS:        %.1f FPS" % avg_fps)
	print("1%% Low FPS:        %.1f FPS" % low_1_pct_fps)
	print("Minimum Instant FPS: %.1f FPS" % min_fps)
	if is_instance_valid(swarm_mgr):
		print("Active Enemies:     %d" % swarm_mgr.active_count)
	if is_instance_valid(part_mgr):
		print("Active Particles:   %d" % part_mgr.active_count)
	print("========================================")
