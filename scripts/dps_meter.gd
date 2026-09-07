extends Control

var total_damage: float = 0.0
var recent_hits: Array[Dictionary] = [] # [{time: float, dmg: float}]
var current_dps: float = 0.0
var peak_dps: float = 0.0
var combat_active: bool = false
var combat_time: float = 0.0
var idle_time: float = 0.0

@onready var lbl_current_dps: Label = $VBox/HBoxDPS/ValDPS
@onready var lbl_peak_dps: Label = $VBox/HBoxPeak/ValPeak
@onready var lbl_total_damage: Label = $VBox/HBoxTotal/ValTotal
@onready var lbl_combat_time: Label = $VBox/HBoxTime/ValTime
@onready var btn_reset: Button = $VBox/BtnReset

func _ready() -> void:
	if btn_reset:
		btn_reset.pressed.connect(reset_stats)

func record_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	combat_active = true
	idle_time = 0.0
	total_damage += amount

	var now = Time.get_ticks_msec() * 0.001
	recent_hits.append({"time": now, "dmg": amount})

func _process(delta: float) -> void:
	var now = Time.get_ticks_msec() * 0.001

	# Prune damage older than 1.0s
	var i = 0
	var sum_dmg = 0.0
	while i < recent_hits.size():
		if (now - recent_hits[i].time) > 1.0:
			recent_hits.remove_at(i)
		else:
			sum_dmg += recent_hits[i].dmg
			i += 1

	current_dps = sum_dmg
	if current_dps > peak_dps:
		peak_dps = current_dps

	if combat_active:
		combat_time += delta
		if sum_dmg <= 0.0:
			idle_time += delta
			if idle_time >= 4.5:
				combat_active = false
		else:
			idle_time = 0.0

	_update_labels()

func reset_stats() -> void:
	total_damage = 0.0
	recent_hits.clear()
	current_dps = 0.0
	peak_dps = 0.0
	combat_active = false
	combat_time = 0.0
	idle_time = 0.0
	_update_labels()

	# Also reset target dummies if present
	var dummies = get_tree().get_nodes_in_group("target_dummies")
	for d in dummies:
		if is_instance_valid(d) and d.has_method("reset_stats"):
			d.reset_stats()

func _update_labels() -> void:
	if lbl_current_dps:
		lbl_current_dps.text = "%d" % int(current_dps)
	if lbl_peak_dps:
		lbl_peak_dps.text = "%d" % int(peak_dps)
	if lbl_total_damage:
		lbl_total_damage.text = _format_val(total_damage)
	if lbl_combat_time:
		var mins = int(combat_time) / 60
		var secs = int(combat_time) % 60
		lbl_combat_time.text = "%02d:%02d" % [mins, secs]

func _format_val(val: float) -> String:
	if val >= 1000000.0:
		return "%.2fM" % (val / 1000000.0)
	elif val >= 1000.0:
		return "%.1fK" % (val / 1000.0)
	return "%d" % int(val)
