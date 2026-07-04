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

	var valid: bool = catalog.load_catalog()
	print("catalog_path=default valid=%s count=%d" % [str(valid), catalog.get_all().size()])
	quit(0 if valid and catalog.get_all().size() == 21 else 1)
