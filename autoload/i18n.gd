class_name I18nSystem
extends Node

signal locale_changed(new_locale: String)

const TRANSLATIONS_DIR: String = "res://translations/"
const DEFAULT_LOCALE: String = "en"

var _translations: Dictionary = {}
var _current_locale: String = DEFAULT_LOCALE


func _ready() -> void:
	_load_all_translations()
	print("[I18n] Loaded %d locales: %s" % [_translations.size(), ", ".join(_translations.keys())])


func tr_key(key: String) -> String:
	if _translations.has(_current_locale):
		var text: String = _translations[_current_locale].get(key, "")
		if not text.is_empty():
			return text
	if _current_locale != DEFAULT_LOCALE and _translations.has(DEFAULT_LOCALE):
		var text: String = _translations[DEFAULT_LOCALE].get(key, "")
		if not text.is_empty():
			return text
	return key


func set_locale(locale: String) -> void:
	if locale == _current_locale:
		return
	if _translations.has(locale):
		_current_locale = locale
		locale_changed.emit(locale)
	else:
		push_warning("[I18n] Locale '%s' not available" % locale)


func get_locale() -> String:
	return _current_locale


func get_available_locales() -> Array[String]:
	var result: Array[String] = []
	result.assign(_translations.keys())
	return result


func _load_all_translations() -> void:
	var dir: DirAccess = DirAccess.open(TRANSLATIONS_DIR)
	if not dir:
		push_warning("[I18n] Translations dir not found: " + TRANSLATIONS_DIR)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".csv"):
			_load_csv(TRANSLATIONS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_csv(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var header: String = file.get_line().strip_edges()
	var columns: PackedStringArray = header.split(",")

	for i in range(1, columns.size()):
		var locale: String = columns[i].strip_edges()
		if not _translations.has(locale):
			_translations[locale] = {}

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var fields: PackedStringArray = _parse_csv_line(line)
		if fields.size() < 2:
			continue
		var key: String = fields[0].strip_edges()
		if key.is_empty() or key == "key":
			continue
		for i in range(1, min(fields.size(), columns.size())):
			var locale: String = columns[i].strip_edges()
			var text: String = fields[i].strip_edges()
			if not text.is_empty():
				_translations[locale][key] = text

	file.close()


func _parse_csv_line(line: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var current: String = ""
	var in_quotes: bool = false
	for i in range(line.length()):
		var c: String = line[i]
		if c == "\"":
			in_quotes = not in_quotes
		elif c == "," and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += c
	result.append(current)
	return result
