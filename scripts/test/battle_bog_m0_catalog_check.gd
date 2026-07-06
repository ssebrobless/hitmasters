extends SceneTree

func _initialize() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null:
		push_error("CreatureCatalog autoload missing.")
		quit(1)
		return

	var path := ""
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--catalog-path="):
			path = argument.trim_prefix("--catalog-path=")

	if not path.is_empty():
		var valid: bool = catalog.load_catalog(path)
		print("catalog_path=%s valid=%s count=%d" % [path, str(valid), catalog.get_all().size()])
		quit(0 if not valid else 1)
		return

	var invalid_region_rejected := _check_invalid_region_rejected(catalog)
	var valid: bool = catalog.load_catalog()
	print("catalog_path=default valid=%s count=%d invalid_region_rejected=%s" % [str(valid), catalog.get_all().size(), str(invalid_region_rejected)])
	quit(0 if valid and catalog.get_all().size() == 21 and invalid_region_rejected else 1)

func _check_invalid_region_rejected(catalog: Node) -> bool:
	var temp_path := "user://invalid_hurtbox_region_roster.json"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not create invalid hurtbox region roster fixture.")
		return false
	file.store_string(JSON.stringify({
		"creatures": [
			{
				"id": "invalid_region_probe",
				"name": "Invalid Region Probe",
				"family": "test",
				"movement": ["ground_walker"],
				"role": ["test"],
				"diet": "omnivore",
				"footprint": {"shape": "circle", "radius_units": 1.0},
				"hurtbox_regions": [
					{"name": "needle", "offset_units": [0.0, 0.0], "radius_units": 0.2, "mult": 2.0, "open_when": "always"}
				],
				"stats": {"health": 1, "speed": 1.0}
			}
		]
	}))
	file.close()
	return not catalog.load_catalog(temp_path)
