extends Node

# === MAP & WORLD (GDD §3) ===
const GRID_SIZE := Vector2i(200, 200)
const TILE_SIZE := Vector2(2.0, 2.0)
const DROP_ZONE_COUNT := 8
const CENTER_THRONE_HOLD_TIME := 60.0         # seconds for 50 coin bonus
const CENTER_BEAST_DESPAWN_TIME := 600.0      # minute 10 (600s)
const VENDOR_NEUTRAL_RADIUS := 3              # tiles
const BLACK_MARKET_NEUTRAL_RADIUS := 5        # tiles
const BLACK_MARKET_SPAWN_INTERVAL := 480.0    # every 8 minutes (480s)
const BLACK_MARKET_WARNING_TIME := 60.0       # 60s before spawn
const BLACK_MARKET_DURATION := 180.0          # 3 minutes active
const SHIPMENT_CRATE_INTERVAL := 600.0        # every 10 minutes (600s)
const ZONE_SHRINK_START := 1020.0             # minute 17 (1020s)
const ZONE_SHRINK_RATE := 30.0                # 1 tile per 30 seconds
const ZONE_SHRINK_DAMAGE := 2.0               # 2 HP/s inside shrink zone
const LATE_ARRIVAL_BUFF_DURATION := 30.0      # 30s Adrenaline buff
const LATE_ARRIVAL_SPEED_BUFF := 0.10         # +10% speed
const LATE_ARRIVAL_DAMAGE_BUFF := 0.10        # +10% damage

# === ROLES & ARCHETYPES (GDD §4) ===
const KING_RESPAWN_TIME := 30.0               # seconds
const DEFAULT_RESPAWN_TIME := 15.0            # seconds
const QUEEN_COIN_RATE := 20.0                 # 1 coin per 20 seconds
const QUEEN_COIN_RATE_MINT := 10.0            # 1 coin per 10 seconds with Mint
const QUEEN_EMERGENCY_RATE_MULTIPLIER := 0.25 # 75% reduction on capture
const QUEEN_SECRET_STASH := 10                # 10 coins emergency stash

# Archetype Ability Values
const WARLORD_RALLY_SPEED_BUFF := 0.20
const WARLORD_RALLY_DAMAGE_BUFF := 0.20
const WARLORD_RALLY_DURATION := 8.0
const WARLORD_RALLY_RADIUS := 10.0
const WARLORD_RALLY_COOLDOWN := 45.0
const WARLORD_BANNER_DAMAGE_BUFF := 0.15
const WARLORD_BANNER_RADIUS := 8.0

const REGENT_TAX_EDICT_BUFF := 0.50
const REGENT_TAX_EDICT_DURATION := 20.0
const REGENT_TAX_EDICT_COOLDOWN := 90.0
const REGENT_STOCKPILE_BONUS := 0.50

const BEASTLORD_BEAST_STAT_BUFF := 0.30
const BEASTLORD_PACK_LEADER_SPEED_BUFF := 0.15

const ENGINEER_OVERCLOCK_TIME_MULT := 0.50
const ENGINEER_OVERCLOCK_DURATION := 15.0
const ENGINEER_OVERCLOCK_COOLDOWN := 60.0
const ENGINEER_TRAP_DAMAGE_BUFF := 0.40

const WITCH_HEX_SPEED_DEBUFF := -0.30
const WITCH_HEX_DAMAGE_DEBUFF := -0.20
const WITCH_HEX_DURATION := 10.0
const WITCH_HEX_COOLDOWN := 30.0

const HERBALIST_POTION_HEAL := 35.0
const HERBALIST_MEND_REGEN_RATE := 2.0         # +2 HP/s within 5 tiles of base

const GUARDIAN_SHIELD_BLOCK_REDUCTION := 0.60
const GUARDIAN_TAUNT_INTERVAL := 40.0
const GUARDIAN_TAUNT_DURATION := 5.0

const BERSERKER_FRENZY_DURATION := 6.0
const BERSERKER_FRENZY_COOLDOWN := 120.0
const BERSERKER_BLOODLUST_PER_KILL := 0.05
const BERSERKER_BLOODLUST_MAX := 0.40

const SAPPER_DEMOLISH_TIME := 3.0
const SAPPER_DEMOLISH_COOLDOWN := 20.0

const SCOUT_FLARE_RADIUS := 20.0
const SCOUT_FLARE_DURATION := 30.0

const ARCHER_EAGLE_EYE_RANGE_THRESHOLD := 6.0
const ARCHER_EAGLE_EYE_DAMAGE_BUFF := 0.50
const ARCHER_VOLLEY_COOLDOWN := 4.0

const BUILDER_SPEED_MULT := 3.0
const BUILDER_BLUEPRINT_COST_MULT := 0.50

# === SURVIVAL STATS & CONSUMABLES (GDD §8) ===
const MAX_HP := 100.0
const MAX_HUNGER := 100.0
const MAX_THIRST := 100.0
const HUNGER_DECAY_RATE := 0.125               # -1 per 8 seconds
const THIRST_DECAY_RATE := 0.125               # -1 per 8 seconds
const HUNGER_ZERO_HP_DRAIN := 0.333            # -1 HP per 3 seconds
const THIRST_ZERO_HP_DRAIN := 0.500            # -1 HP per 2 seconds

const RAW_FOOD_HUNGER := 20.0
const COOKED_FOOD_HUNGER := 40.0
const COOKED_FOOD_SPEED_DURATION := 30.0
const WATER_THIRST := 40.0
const WATER_SKIN_VENDOR_THIRST := 60.0
const BANDAGE_HEAL := 25.0
const POTION_HEAL := 50.0

# === COMBAT & HP STATES (GDD §9) ===
const FRIENDLY_FIRE_DAMAGE_MODIFIER := 0.50   # 50% reduced damage to teammates
const TEAMKILLER_ICON_DURATION := 60.0
const JUSTICE_SERVED_COIN_REWARD := 10

const WOUNDED_HP_THRESHOLD := 40.0             # 40 HP or below = Wounded (-20% speed)
const CRITICAL_HP_THRESHOLD := 10.0            # 10 HP or below = Critical (-40% speed)
const DOWNED_BLEED_RATE := 0.333               # 1 HP per 3 seconds
const DOWNED_BLEED_TIME := 30.0                # 30 seconds to bleed out completely
const DOWNED_CRAWL_SPEED := 1.2                # m/s while downed (GDD §9 ~20px/s → a slow drag in world units)
const IMPRISON_ESCAPE_TIME := 18.0             # seconds a caged prisoner takes to break free (stands in for the lock-pick mini-game)

const HANDCUFF_HOLD_TIME := 2.0                # 2 seconds to handcuff downed player
const CARRY_SPEED_PENALTY := 0.60              # speed drops to 60%

const BASIC_SWORD_DAMAGE := 15.0
const UPGRADED_SWORD_DAMAGE := 22.0
const BASIC_BOW_DAMAGE := 8.0
const BASIC_BOW_RANGE := 8.0
const ADVANCED_BOW_DAMAGE := 13.0
const ADVANCED_BOW_RANGE := 12.0
const CHARGE_ATTACK_DAMAGE := 25.0
const CHARGE_ATTACK_COOLDOWN := 6.0
const BEAR_TRAP_DAMAGE := 20.0
const BEAR_TRAP_FREEZE_DURATION := 5.0

# === PRISON, RANSOM & CHAIN GANG (GDD §10) ===
const RANSOM_WINDOW_DURATION := 90.0           # 90 seconds public broadcast
const RANSOM_OUTBID_COST_RATIO := 0.50         # 50% of listed price
const RANSOM_EXTENSION_COST := 5               # 5 coins for 60s extension
const RANSOM_EXTENSION_TIME := 60.0
const BLACK_MARKET_PRISONER_SALE_PRICE := 15   # 15 coins flat
const CHAIN_GANG_RADIUS := 5.0                 # 5 tiles leash radius
const CHAIN_GANG_GATHER_RATE := 0.25           # 25% normal gathering speed
const CHAIN_GANG_DEFAULT_DURATION := 180.0     # 3 minutes
const CHAIN_GANG_EXTENDED_DURATION := 300.0    # 5 minutes if no rescue
const CHAIN_GANG_BROKEN_GATHER_RATE := 0.40   # 40% after 2 interrogations
const CHAIN_HP := 15.0                         # 15 HP for squad rescue attack
const LOCKPICK_COOLDOWN := 45.0                # try lockpick every 45s

const CURSE_EXECUTION_BASE_DURATION := 90.0    # 1st execution = 90s, 2nd = 120s, 3rd = 150s
const VENGEANCE_BUFF_DAMAGE := 0.15
const VENGEANCE_BUFF_DURATION := 120.0
const BLOOD_DEBT_BOUNTY_COINS := 10

# === TRAITOR TOKEN SYSTEM (GDD §11 System 1) ===
const TOTAL_TRAITOR_TOKENS := 6                # 6 traitors distributed across 8 squads (2 clean)
const TRAITOR_ACTIVATION_UNLOCK_TIME := 480.0  # Minute 8:00
const TRAITOR_DISGUISE_DURATION := 30.0        # 30 seconds disguised rogue state
const POST_BETRAYAL_RALLY_DURATION := 60.0
const POST_BETRAYAL_RALLY_DAMAGE := 0.20
const POST_BETRAYAL_RALLY_SPEED := 0.10
const POST_BETRAYAL_RALLY_RESPAWN_MULT := 0.50
const STOLEN_TREASURE_CARRY_SPEED := 0.70      # 70% speed while carrying gold sack
const DEFECTION_SECOND_TOKEN_CHANCE := 0.15    # 15% hidden chance on defection
const ROGUE_SQUAD_MAX_MEMBERS := 3
const ROGUE_SQUAD_DAMAGE_BUFF := 0.15          # "Nothing Left to Lose"
const ROGUE_SQUAD_SPEED_BUFF := 0.10

# === BEAST COMPANIONS (GDD §11 System 7) ===
const BEAST_HUNGER_DECAY_RATE := 0.05          # -1 per 20 seconds
const BEAST_EVOLUTION_XP := 30
const BEAST_WOLF_DAMAGE := 12.0                # companion bite damage (GDD §11)
const BEAST_ATTACK_COOLDOWN := 1.1             # seconds between bites
const BEAST_DIRE_WOLF_HP_BONUS := 20.0
const BEAST_DIRE_WOLF_DAMAGE_BONUS := 5.0
const BEAST_RAVEN_SCOUT_RANGE := 30.0
const BEAST_RAVEN_SCOUT_RADIUS := 5.0
const BEAST_RAVEN_STORM_RADIUS := 8.0
const BEAST_RAVEN_SCOUT_COOLDOWN := 45.0
const BEAST_STAG_RESOURCE_BONUS := 20
const BEAST_STAG_GREAT_RESOURCE_BONUS := 35
const BEAST_DUEL_WINNER_STAT_BUFF := 0.10

# === DAY / NIGHT CYCLE ===
const DAY_DURATION := 480.0                    # 8 minutes
const NIGHT_DURATION := 240.0                  # 4 minutes
const FULL_DAY_NIGHT_CYCLE := 720.0            # 12 minutes total

# === MATCH TIMELINE (GDD §12) ===
const MATCH_DURATION := 1500.0                 # 25 minutes total match length

enum ZoneType { DROP_ZONE, DENSE_FOREST, OPEN_CLEARING, RIVERBED, ROCKY_HIGHLANDS, SWAMP, CURSED_THRONE }
enum ResourceType { WOOD, STONE, FOOD, WATER, METAL, HERBS }
enum DayPhase { DAWN, DAY, DUSK, NIGHT }
enum Role { KING, QUEEN, SOLDIER_A, SOLDIER_B }
enum GameState { LOADING, LOBBY, PLAYING, POST_MATCH }
enum PrisonOption { RANSOM, FORCED_LABOR, INTERROGATE, EXECUTE, SELL }
enum TraitorPath { LONE_WOLF, DEFECT, ROGUE_SQUAD }
