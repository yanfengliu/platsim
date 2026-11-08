extends SceneTree

const UISettings = preload("res://scripts/ui_settings.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _init() -> void:
	var settings := UISettings.new()
	check(settings.requested_percent == 100, "Fresh sessions start at100%")
	for viewport in [Vector2(320, 640), Vector2(720, 560), Vector2(420, 640), Vector2(421, 640), Vector2(480, 640), Vector2(481, 640), Vector2(560, 640), Vector2(561, 640)]:
		check(settings.maximum_percent(viewport) == 100, "Compact cap preserves controls at" + str(viewport))
	check(settings.maximum_percent(Vector2(1280, 800)) > 100, "Normal Windows window permits meaningful scaling")
	check(settings.maximum_percent(Vector2(1920, 1080)) == UISettings.SCALE_PRESETS.back(), "Large Windows window permits largest offered size")
	settings.choose(200)
	check(settings.applied_percent(Vector2(320, 640)) == 100, "Requested large scale adapts safely on small windows")
	check(settings.requested_percent == 200, "Resizing does not erase preference")
	check(settings.description(Vector2(320, 640)).contains("Selected 200% · using 100%"), "Cap is explained visibly")
	check(settings.applied_percent(Vector2(1920, 1080)) == 200, "Returning to large window restores chosen scale")
	settings.choose(133)
	check(settings.requested_percent == 200, "Invalid presets leave preference intact")
	settings.choose(100)
	check(settings.applied_percent(Vector2(320, 640)) == 100 and settings.requested_percent == 100, "Reset works at smallest supported width")
	settings.choose(200)
	var previous_limit := 0
	for index in range(20):
		var viewport := Vector2(300 + index * 90, 400 + index * 40)
		var limit: int = settings.maximum_percent(viewport)
		var applied: int = settings.applied_percent(viewport)
		check(limit >= previous_limit and limit in UISettings.SCALE_PRESETS, "Growing windows never shrink the safe size range")
		check(applied > 0 and applied <= limit and applied <= settings.requested_percent, "Applied metrics are bounded positive preferences")
		check(settings.requested_percent == 200, "Repeated layout queries preserve the session choice")
		previous_limit = limit
	print("Mosslight UI settings: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
