<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/TelemetryConsent.gd` — `class_name TelemetryConsent` extends `RefCounted`

`176` lines · [back to the map](../../../CODEBASE_MAP.md)

> Explicit opt-in gate for gameplay telemetry. The player is asked once, on the first launch, whether anonymous gameplay decisions may be collected to help improv…

Sections: Enums · Constants · Public Variables · Lifecycle Methods · Public Methods · Private Methods
- L18-22 `enum Status` = UNDECIDED, GRANTED, DECLINED

Constants:
- L30 `CONSENT_VERSION: int = 2` — Bump this when the disclosure text changes so every player is asked again. v2: the window was restyled and the wording became "Data Consent / We need your conse…
- L31 `SCHEMA_VERSION: int = 1`
- L32 `DEFAULT_PATH: String = "user://telemetry_consent.json"`
- L33 `STATUS_GRANTED: String = "granted"`
- L34 `STATUS_DECLINED: String = "declined"`

State:
- L41 `storage_path: String = DEFAULT_PATH` — Where this record reads and writes its answer. Every mutating method defaults to it, so a caller can point one instance at a throwaway file (a test) without pas…
- L42 `status: int = Status.UNDECIDED`
- L43 `consent_version: int = 0`
- L44 `decided_at_unix: float = 0.0`

Public API:
- L56-57 `is_decided() -> bool` — True once the player answered the current disclosure version.
- L61-62 `needs_prompt() -> bool` — True while the disclosure still has to be shown.
- L66-67 `is_granted() -> bool` — True only for the explicit "Agree" answer of the current version.
- L71-75 `decide(agreed: bool) -> void` — Stores the answer and persists it. Passing false keeps collection fully off.
- L79-84 `reset() -> void` — Forgets the answer (used by tests and a future "change my mind" control).
- L88-115 `load_from_path(path: String = "") -> void` — Re-reads the answer from disk (no-op when the file is missing/corrupt).
- L119-136 `save_to_path(path: String = "") -> bool` — Writes the answer to disk. Returns true when the file could be written.
- L140-141 `static load_from(path: String = DEFAULT_PATH) -> TelemetryConsent` — Convenience factory; equivalent to TelemetryConsent.new(path).

Private:
- L49-51 `_init`
- L145-150 `_status_key`
- L153-164 `_to_int`
- L167-174 `_to_float`

Uses: —
Used by: Core/Telemetry/TelemetryUploader.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/TelemetryManager.gd, Scenes/HUD/TelemetryConsentPopup.gd
Loads: —

