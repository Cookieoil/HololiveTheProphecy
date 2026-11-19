<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/xlsx_reader.gd` — `class_name XlsxReader` extends `RefCounted`

`181` lines · [back to the map](../../CODEBASE_MAP.md)

> Reads an .xlsx workbook (a zip of XML parts) into { sheet_name: Array[Array[String]] }. Every cell is returned as a String; DataBuilder performs the typed conve…

Sections: Constants · Public Methods · Private Methods

Constants:
- L14 `WORKBOOK_PATH: String = "xl/workbook.xml"`
- L15 `WORKBOOK_RELS_PATH: String = "xl/_rels/workbook.xml.rels"`
- L16 `SHARED_STRINGS_PATH: String = "xl/sharedStrings.xml"`
- L18 `LETTER_OFFSET: int = 64` — ASCII code of 'A' minus one, so "A" resolves to column 1.
- L19 `ALPHABET_SIZE: int = 26`

Public API:
- L27-49 `static read_sheets(path: String) -> Dictionary` — Reads every worksheet in the workbook. Array of Strings ordered from column A onwards

Private:
- L54-68 `_read_workbook_sheets`
- L72-86 `_read_workbook_rels`
- L88-109 `_read_shared_strings`
- L113-156 `_parse_sheet`
- L160-168 `_column_from_reference`
- L172-180 `_commit_row`

Uses: DataBuilder
Used by: Tools/dataBuilder.gd, Tools/validate_gameData.gd
Loads: res

