class_name XlsxReader
extends RefCounted

## Reads an .xlsx (zip of XML) into { sheet_name: Array[Array[String]] }.
## All values returned as Strings; typed conversion happens in DataBuilder.

static func read_sheets(path: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		push_error("XlsxReader: cannot open " + path)
		return {}
	var shared := _read_shared_strings(zip)
	var rels := _read_workbook_rels(zip)          # rId -> "worksheets/sheet1.xml"
	var name_to_rid := _read_workbook_sheets(zip) # sheet name -> rId
	var result := {}
	for sheet_name in name_to_rid:
		var target: String = rels.get(name_to_rid[sheet_name], "")
		if target.is_empty():
			continue
		if target.begins_with("/"):
			target = target.substr(1)
		elif not target.begins_with("xl/"):
			target = "xl/" + target
		if zip.file_exists(target):
			result[sheet_name.to_lower()] = _parse_sheet(zip, target, shared)
	zip.close()
	return result


static func _read_workbook_sheets(zip: ZIPReader) -> Dictionary:
	if not zip.file_exists("xl/workbook.xml"):
		return {}
	var p := XMLParser.new()
	p.open_buffer(zip.read_file("xl/workbook.xml"))
	var out := {}
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "sheet":
			out[p.get_named_attribute_value_safe("name")] = p.get_named_attribute_value_safe("r:id")
	return out


static func _read_workbook_rels(zip: ZIPReader) -> Dictionary:
	if not zip.file_exists("xl/_rels/workbook.xml.rels"):
		return {}
	var p := XMLParser.new()
	p.open_buffer(zip.read_file("xl/_rels/workbook.xml.rels"))
	var out := {}
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "Relationship":
			out[p.get_named_attribute_value_safe("Id")] = p.get_named_attribute_value_safe("Target")
	return out


static func _read_shared_strings(zip: ZIPReader) -> PackedStringArray:
	var strings := PackedStringArray()
	if not zip.file_exists("xl/sharedStrings.xml"):
		return strings
	var p := XMLParser.new()
	p.open_buffer(zip.read_file("xl/sharedStrings.xml"))
	var in_si := false
	var cur := ""
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				if p.get_node_name() == "si":
					in_si = true
					cur = ""
			XMLParser.NODE_TEXT:
				if in_si:
					cur += p.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if p.get_node_name() == "si":
					strings.append(cur)
					in_si = false
	return strings


static func _parse_sheet(zip: ZIPReader, target: String, shared: PackedStringArray) -> Array:
	var p := XMLParser.new()
	p.open_buffer(zip.read_file(target))
	var dense: Array = []
	var cur_row := -1
	var cells := {}
	var max_col := 0
	var col_idx := 0
	var cell_type := ""
	var in_cell := false

	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				match p.get_node_name():
					"row":
						cur_row = int(p.get_named_attribute_value_safe("r")) - 1
						cells = {}
						max_col = 0
					"c":
						in_cell = true
						cell_type = p.get_named_attribute_value_safe("t")
						var ref := p.get_named_attribute_value_safe("r")
						col_idx = 0
						for ch in ref:
							if ch.is_valid_int():
								break
							col_idx = col_idx * 26 + (ch.unicode_at(0) - 64)
						max_col = maxi(max_col, col_idx)
			XMLParser.NODE_TEXT:
				if in_cell:
					var raw := p.get_node_data()
					if cell_type == "s" and raw.is_valid_int():
						var idx := raw.to_int()
						cells[col_idx] = shared[idx] if idx < shared.size() else ""
					else:
						# numeric, bool ("1"/"0"), or inlineStr text
						cells[col_idx] = raw
			XMLParser.NODE_ELEMENT_END:
				match p.get_node_name():
					"row":
						var arr: Array = []
						for c in range(1, max_col + 1):
							arr.append(cells.get(c, ""))
						while dense.size() <= cur_row:
							dense.append([])
						dense[cur_row] = arr
						cur_row = -1
					"c":
						in_cell = false
						cell_type = ""
	return dense
