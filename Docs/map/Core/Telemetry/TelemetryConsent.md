<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/TelemetryConsent.gd` — `class_name TelemetryConsent` extends `RefCounted`

`173` lines · [back to the map](../../../CODEBASE_MAP.md)

> Explicit opt-in gate for gameplay telemetry. The player is asked once, on the first launch, whether anonymous gameplay decisions may be collected to help improv…

Sections: Enums · Constants · Public Variables · Lifecycle Methods · Public Methods · Private Methods
- L18-22 `enum Status` = UNDECIDED, GRANTED, DECLINED

Constants:
- L27 `CONSENT_VERSION: int = 1` — Bump this when the disclosure text changes so every player is asked again.
- L28 `SCHEMA_VERSION: int = 1`
- L29 `DEFAULT_PATH: String = "user://telemetry_consent.json"`
- L30 `STATUS_GRANTED: String = "granted"`
- L31 `STATUS_DECLINED: String = "declined"`

State:
- L38 `storage_path: String = DEFAULT_PATH` — Where this record reads and writes its answer. Every mutating method defaults to it, so a caller can point one instance at a throwaway file (a test) without pas…
- L39 `status: int = Status.UNDECIDED`
- L40 `consent_version: int = 0`
- L41 `decided_at_unix: float = 0.0`

Public API:
- L53-54 `is_decided() -> bool` — True once the player answered the current disclosure version.
- L58-59 `needs_prompt() -> bool` — True while the disclosure still has to be shown.
- L63-64 `is_granted() -> bool` — True only for the explicit "Agree" answer of the current version.
- L68-72 `decide(agreed: bool) -> void` — Stores the answer and persists it. Passing false keeps collection fully off.
- L76-81 `reset() -> void` — Forgets the answer (used by tests and a future "change my mind" control).
- L85-112 `load_from_path(path: String = "") -> void` — Re-reads the answer from disk (no-op when the file is missing/corrupt).
- L116-133 `save_to_path(path: String = "") -> bool` — Writes the answer to disk. Returns true when the file could be written.
- L137-138 `static load_from(path: String = DEFAULT_PATH) -> TelemetryConsent` — Convenience factory; equivalent to TelemetryConsent.new(path).

Private:
- L46-48 `_init`
- L142-147 `_status_key`
- L150-161 `_to_int`
- L164-171 `_to_float`

Uses: —
Used by: Core/Telemetry/TelemetryUploader.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/TelemetryManager.gd, Scenes/HUD/TelemetryConsentPopup.gd
Loads: —

