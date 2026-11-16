class_name XlsxReader
extends RefCounted
## Reads an .xlsx workbook (a zip of XML parts) into
## { sheet_name: Array[Array[String]] }.
##
## Every cell is returned as a String; DataBuilder performs the typed
## conversion into JSON values. This is authoring-only tooling and is never
## used by the running game.
##
## @author TheGreatJellyfish
## @version 11/16/2026

#region Constants
const WORKBOOK_PATH: String = "xl/workbook.xml"
const WORKBOOK_RELS_PATH: String = "xl/_rels/workbook.xml.rels"
const SHARED_STRINGS_PATH: String = "xl/sharedStrings.xml"
## ASCII code of 'A' minus one, so "A" resolves to column 1.
const LETTER_OFFSET: int = 64
const ALPHABET_SIZE: int = 26
#endregion

#region Public Methods
## Reads every worksheet in the workbook.
## @param path - absolute or res:// path to the .xlsx file
## @return Dictionary - lower-case sheet name -> Array of rows, each row an
##         Array of Strings ordered from column A onwards
static func read_sheets(path: String) -> Dictionary:
	var sheets: Dictionary = {}
	var zip: ZIPReader = ZIPReader.new()
	if zip.open(path) != OK:
		push_error("XlsxReader: cannot open " + path)
		return sheets
	var shared: PackedStringArray = _read_shared_strings(zip)
	var relations: Dictionary = _read_workbook_rels(zip)
	var sheet_rels: Dictionary = _read_workbook_sheets(zip)
	for sheet_name: String in sheet_rels:
		var relationship_id: String = str(sheet_rels[sheet_name])
		var target: String = str(relations.get(relationship_id, ""))
		if target.is_empty():
			continue
		if target.begins_with("/"):
			target = target.substr(1)
		elif not target.begins_with("xl/"):
			target = "xl/" + target
		if not zip.file_exists(target):
			continue
		sheets[sheet_name.to_lower()] = _parse_sheet(zip, target, shared)
	zip.close()
	return sheets
#endregion

#region Private Methods
## Maps sheet name -> relationship id.
static func _read_workbook_sheets(zip: ZIPReader) -> Dictionary:
	var sheet_rels: Dictionary = {}
	if not zip.file_exists(WORKBOOK_PATH):
		return sheet_rels
	var parser: XMLParser = XMLParser.new()
	parser.open_buffer(zip.read_file(WORKBOOK_PATH))
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "sheet":
			continue
		var name: String = parser.get_named_attribute_value_safe("name")
		var relationship_id: String = parser.get_named_attribute_value_safe("r:id")
		sheet_rels[name] = relationship_id
	return sheet_rels


## Maps relationship id -> worksheet part path (e.g. "worksheets/sheet1.xml").
static func _read_workbook_rels(zip: ZIPReader) -> Dictionary:
	var relations: Dictionary = {}
	if not zip.file_exists(WORKBOOK_RELS_PATH):
		return relations
	var parser: XMLParser = XMLParser.new()
	parser.open_buffer(zip.read_file(WORKBOOK_RELS_PATH))
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "Relationship":
			continue
		var relationship_id: String = parser.get_named_attribute_value_safe("Id")
		var target: String = parser.get_named_attribute_value_safe("Target")
		relations[relationship_id] = target
	return relations
## Reads the shared string table (cell type "s" points into this table).
static func _read_shared_strings(zip: ZIPReader) -> PackedStringArray:
	var strings: PackedStringArray = PackedStringArray()
	if not zip.file_exists(SHARED_STRINGS_PATH):
		return strings
	var parser: XMLParser = XMLParser.new()
	parser.open_buffer(zip.read_file(SHARED_STRINGS_PATH))
	var inside_entry: bool = false
	var current: String = ""
	while parser.read() == OK:
		var node_type: int = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "si":
				inside_entry = true
				current = ""
		elif node_type == XMLParser.NODE_TEXT:
			if inside_entry:
				current += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "si":
				strings.append(current)
				inside_entry = false
	return strings


## Parses one worksheet into a dense grid of Strings.
static func _parse_sheet(zip: ZIPReader, target: String, shared: PackedStringArray) -> Array:
	var rows: Array = []
	var parser: XMLParser = XMLParser.new()
	parser.open_buffer(zip.read_file(target))
	var current_row: int = -1
	var cells: Dictionary = {}
	var max_column: int = 0
	var column_index: int = 0
	var cell_type: String = ""
	var inside_cell: bool = false
	while parser.read() == OK:
		var node_type: int = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var element_name: String = parser.get_node_name()
			if element_name == "row":
				current_row = int(parser.get_named_attribute_value_safe("r")) - 1
				cells = {}
				max_column = 0
			elif element_name == "c":
				inside_cell = true
				cell_type = parser.get_named_attribute_value_safe("t")
				column_index = _column_from_reference(parser.get_named_attribute_value_safe("r"))
				max_column = maxi(max_column, column_index)
		elif node_type == XMLParser.NODE_TEXT:
			if inside_cell:
				var raw_text: String = parser.get_node_data()
				if cell_type == "s" and raw_text.is_valid_int():
					var shared_index: int = raw_text.to_int()
					if shared_index >= 0 and shared_index < shared.size():
						cells[column_index] = shared[shared_index]
					else:
						cells[column_index] = ""
				else:
					# Numeric, boolean ("1"/"0") or inline string text.
					cells[column_index] = raw_text
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var closing_name: String = parser.get_node_name()
			if closing_name == "row":
				_commit_row(rows, current_row, cells, max_column)
				current_row = -1
			elif closing_name == "c":
				inside_cell = false
				cell_type = ""
	return rows


## Converts a cell reference ("B7") into a one-based column index (2).
static func _column_from_reference(reference: String) -> int:
	if reference.is_empty():
		return 0
	var index: int = 0
	for character: String in reference:
		if character.is_valid_int():
			break
		index = index * ALPHABET_SIZE + (character.unicode_at(0) - LETTER_OFFSET)
	return index


## Writes one parsed row into the dense grid, padding missing cells.
static func _commit_row(rows: Array, row_index: int, cells: Dictionary, max_column: int) -> void:
	if row_index < 0:
		return
	var row_values: Array = []
	for column: int in range(1, max_column + 1):
		row_values.append(str(cells.get(column, "")))
	while rows.size() <= row_index:
		rows.append([])
	rows[row_index] = row_values
#endregion