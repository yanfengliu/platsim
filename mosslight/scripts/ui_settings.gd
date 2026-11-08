extends RefCounted

# Session preferences only. No user:// files or persistent schema.
const SCALE_PRESETS := [100, 125, 150, 175, 200]
var requested_percent := 100

func maximum_percent(viewport: Vector2) -> int:
	# Reserve space for the map, controls and scrollable tools at native pixels.
	if viewport.x >= 1600 and viewport.y >= 1000:
		return 200
	if viewport.x >= 1400 and viewport.y >= 900:
		return 175
	if viewport.x >= 1100 and viewport.y >= 750:
		return 150
	if viewport.x >= 850 and viewport.y >= 650:
		return 125
	return 100

func applied_percent(viewport: Vector2) -> int:
	return mini(requested_percent, maximum_percent(viewport))

func choose(percent: int) -> void:
	if percent in SCALE_PRESETS:
		requested_percent = percent

func description(viewport: Vector2) -> String:
	var applied := applied_percent(viewport)
	if applied != requested_percent:
		return "Selected %d%% · using %d%% to fit this window. Enlarge the window to use your selected size." % [requested_percent, applied]
	return "Using %d%%. This window supports up to %d%%. Larger sizes need a larger window." % [applied, maximum_percent(viewport)]
