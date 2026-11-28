class_name SkillContextFactory
extends RefCounted
## Builds the SkillContext a skill resolves against, with the async callables injected:
## the player's prompts go to the UI and are timed for telemetry, while the enemy's are
## answered automatically - and seeded - so a run still replays from its seed.
##
## Extracted from Managers/GameManager.gd, which now hands it the board per call (the same
## shape as Managers/DebugCommandRunner.gd), so the turn machine reads as a turn machine
## and these closures read as closures. Pure logic: no node, no state of its own.
##
## @author TheGreatJellyfish
## @version 11/28/2026


#region Public Methods
## The context for a player-cast skill. A turn-wide bonus from a merged Buff lands on the
## card value here and is spent by doing so, so the next card of the turn starts clean.
static func build_ally_context(
	ally: Unit,
	card: Card,
	state: GameState,
	ui: GameUI,
	telemetry: TelemetryManager
) -> SkillContext:
	var ctx: SkillContext = SkillContext.new(ally, card, state)

	# Apply turn-wide bonus from Buff Skill 2 merged
	if state.next_skill_bonus > 0:
		ctx.card_value += state.next_skill_bonus
		var bonus_str: String = ColorUtils.colorize("+" + str(state.next_skill_bonus), ColorUtils.COLOR_CARD)
		ui.show_message("  %s bonus value from Buff!" % bonus_str)
		state.next_skill_bonus = 0

	# Pick_n_target:
	ctx.pick_n_target = func(count: int, filter: Callable) -> Array[Unit]:
		var candidates: Array[Unit] = []
		for u: Unit in state.allies:
			if filter.call(u):
				candidates.append(u)
		for u: Unit in state.enemies:
			if filter.call(u):
				candidates.append(u)
		if candidates.is_empty():
			return []
		var started_ms: int = Time.get_ticks_msec()
		var picked: Array[Unit] = await ui.ask_pick_targets(candidates, count)
		telemetry.note_pick_target(candidates, count, picked, Time.get_ticks_msec() - started_ms)
		return picked

	# Pick_n_card:
	ctx.pick_n_card = func(count: int, filter: Callable) -> Array[Card]:
		var candidates: Array[Card] = []
		for c: Card in state.hand:
			if filter.call(c):
				candidates.append(c)
		if candidates.is_empty():
			return []
		var started_ms: int = Time.get_ticks_msec()
		var picked: Array[Card] = await ui.ask_pick_cards(candidates, count)
		telemetry.note_pick_card(candidates, count, picked, Time.get_ticks_msec() - started_ms)
		return picked

	# Flash_cards: reveal cards the game picked automatically (no prompt shown).
	ctx.flash_cards = func(cards: Array[Card]) -> void:
		if cards.is_empty():
			return
		await ui.flash_auto_selected_cards(cards)

	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)

	return ctx


## The context for one enemy's action: its roll is the card value and the merged flag
## comes from the intent's condition. Enemies get no prompt - targeting is silent (and
## seeded) and every card change flashes red, because an enemy caused it.
## `state` is read through, so this takes no telemetry recorder: an enemy picks nothing.
static func build_enemy_context(
	enemy: Unit,
	intent: EnemyIntent,
	state: GameState,
	ui: GameUI
) -> SkillContext:
	var ctx: SkillContext = SkillContext.new(enemy, null, state)
	ctx.card_value = intent.effective_value
	ctx.is_merged = intent.condition_met

	# Enemy targeting is random — inject auto-target callables
	ctx.pick_n_target = func(count: int, _filter: Callable) -> Array[Unit]:
		var target: Array[Unit] = state.get_living_allies()
		# Seeded, so the same run seed always targets the same ally.
		state.shuffle_units(target)
		var result: Array[Unit] = []
		for i: int in mini(count, target.size()):
			result.append(target[i])
		if not result.is_empty():
			var names: Array = result.map(func(t: Unit) -> String: return t.data.display_name)
			var joined: String = ", ".join(PackedStringArray(names))
			var colored: String = ColorUtils.colorize(joined, ColorUtils.COLOR_ALLY)
			ui.show_message(" Targets: %s" % colored)
		return result

	ctx.pick_n_card = func(count: int, _filter: Callable) -> Array[Card]:
		# Enemies never get a hand prompt, so auto-pick the top cards and reveal
		# them with the hostile (red) flash, since an enemy caused the change.
		var auto_cards: Array[Card] = state.get_top_n_cards(count)
		if not auto_cards.is_empty():
			await ui.flash_auto_selected_cards(auto_cards, true)
		return auto_cards

	# Flash_cards: reveal cards the game picked automatically (no prompt shown).
	# Enemy-caused changes flash red (hostile) so the player sees the hit.
	ctx.flash_cards = func(cards: Array[Card]) -> void:
		if cards.is_empty():
			return
		await ui.flash_auto_selected_cards(cards, true)

	ctx.log_message = func(msg: String) -> void:
		ui.show_message("  " + msg)

	return ctx
#endregion
