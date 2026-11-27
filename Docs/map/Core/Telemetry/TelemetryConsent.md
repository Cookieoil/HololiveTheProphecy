<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/TelemetryConsent.gd` — `class_name TelemetryConsent` extends `RefCounted`

`201` lines · [back to the map](../../../CODEBASE_MAP.md)

> Explicit opt-in gate for gameplay telemetry. The player is asked on every launch, before the first battle starts: nothing is collected until they press "Allow",…

Sections: Enums · Constants · Public Variables · Private Variables · Lifecycle Methods · Public Methods · Private Methods
- L19-23 `enum Status` = UNDECIDED, GRANTED, DECLINED

Constants:
- L32 `CONSENT_VERSION: int = 2` — Bump this when the disclosure text changes so the stored answer is recognisably older than the wording it was given for. v2: the window was restyled and the wor…
- L33 `SCHEMA_VERSION: int = 1`
- L34 `DEFAULT_PATH: String = "user://telemetry_consent.json"`
- L35 `STATUS_GRANTED: String = "granted"`
- L36 `STATUS_DECLINED: String = "declined"`

State:
- L43 `storage_path: String = DEFAULT_PATH` — Where this record reads and writes its answer. Every mutating method defaults to it, so a caller can point one instance at a throwaway file (a test) without pas…
- L44 `status: int = Status.UNDECIDED`
- L45 `consent_version: int = 0`
- L46 `decided_at_unix: float = 0.0`
- L54 `_answered_this_launch: bool = false` — True once the player has answered in *this* launch. A stored "granted" from an earlier session must never be enough on its own: the recorder waits for this laun…

Public API:
- L70-71 `static answered_this_launch() -> bool` — True when the player answered the disclosure during this launch. A stored "granted" from an earlier session is deliberately not enough: the recorder requires th…
- L75-76 `static reset_launch_flag() -> void` — Test seam: forgets that this launch was answered.
- L80-81 `is_decided() -> bool` — True once the player answered the current disclosure version.
- L85-86 `needs_prompt() -> bool` — True while the disclosure still has to be shown.
- L90-91 `is_granted() -> bool` — True only for the explicit "Agree" answer of the current version.
- L95-100 `decide(agreed: bool) -> void` — Stores the answer and persists it. Passing false keeps collection fully off.
- L104-109 `reset() -> void` — Forgets the answer (used by tests and a future "change my mind" control).
- L113-140 `load_from_path(path: String = "") -> void` — Re-reads the answer from disk (no-op when the file is missing/corrupt).
- L144-161 `save_to_path(path: String = "") -> bool` — Writes the answer to disk. Returns true when the file could be written.
- L165-166 `static load_from(path: String = DEFAULT_PATH) -> TelemetryConsent` — Convenience factory; equivalent to TelemetryConsent.new(path).

Private:
- L59-61 `_init`
- L170-175 `_status_key`
- L178-189 `_to_int`
- L192-199 `_to_float`

Uses: —
Used by: GDTest/TelemetryConsentTest.gd, GDTest/TelemetryTest.gd, Managers/TelemetryManager.gd, Managers/TelemetryUploader.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/TelemetryConsentPopup.gd
Loads: —

