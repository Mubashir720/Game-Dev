extends Node

# --- World & Map ---
signal resource_harvested(resource_type: Constants.ResourceType, amount: int, position: Vector3)
signal zone_entered(player, zone_type: Constants.ZoneType)
signal day_phase_changed(phase: Constants.DayPhase)

# --- Combat & Health ---
signal player_damaged(attacker, target, damage: float)
signal player_downed(player)
signal player_killed(player, killer)
signal player_respawned(player)
signal teamkiller_marked(player)
signal justice_served(killer, traitor)

# --- Capture & Prison ---
signal player_handcuffed(captor, captive)
signal player_imprisoned(captor, captive, cage)
signal prisoner_escaped(prisoner, method: String)
signal ransom_posted(captor_squad, prisoner, amount: int)
signal ransom_paid(payer_squad, prisoner, amount: int)
signal ransom_outbid(bidder_squad, prisoner, amount: int)
signal ransom_counter_offered(prisoner_squad, counter_amount: int)
signal prisoner_executed(executor, prisoner)
signal forced_labor_started(captor_squad, prisoner, resource_type: Constants.ResourceType)

# --- Economy & Treasury ---
signal coins_earned(squad, amount: int, source: String)
signal coins_spent(squad, amount: int, target: String)
signal treasury_destroyed(squad, scatter_amount: int)
signal treasury_stolen(thief, squad, amount: int)
signal treasury_locked(squad, duration: float)

# --- Traitor System ---
signal traitor_activated(player)
signal traitor_revealed(player)
signal traitor_defected(player, new_squad)
signal rogue_squad_formed(rogue_squad)
signal vote_to_exile_started(squad, target_player)
signal vote_to_exile_completed(squad, target_player, exiled: bool)

# --- Beasts ---
signal beast_tamed(player, beast)
signal beast_died(beast, cause: String)
signal beast_sacrifice(beast, saved_player)
signal beast_evolved(beast, new_tier: String)
signal beast_duel_started(beast1, beast2)
signal beast_duel_ended(winner_beast, loser_beast)
signal mutation_wave_started(wave_number: int)

# --- Curse System ---
signal forest_curse_triggered(squad, trigger_type: int)
signal forest_curse_ended(squad)

# --- Moments Engine ---
signal legendary_moment(moment_type: String, involved_players: Array)

# --- Progression & XP ---
signal xp_awarded(player, amount: int, reason: String)
signal level_up(player, new_level: int)

# --- Match Timeline ---
signal match_tick(time_seconds: float)
signal match_started()
signal match_ended(winning_squad)
signal black_market_warning()
signal black_market_spawned(position: Vector3)
signal black_market_despawned()
signal shipment_crate_dropped(position: Vector3)
signal zone_shrink_started()
signal zone_shrink_tick(new_boundary_radius: float)
