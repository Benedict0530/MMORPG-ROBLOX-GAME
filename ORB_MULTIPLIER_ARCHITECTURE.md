# Orb Multiplier Architecture - Complete System Documentation

## Overview

The orb system uses a **non-additive multiplier architecture** where orb effects are applied ONLY during damage calculations, never to the actual stat values. This ensures:
- Clean stat separation (base values are always pure)
- No save/load corruption
- Predictable gameplay (UI displays real base stats)
- Simple math (no reverse-calculations needed)

## System Design

### 1. Data Storage

```
Player Stats (player.Stats folder)
├─ Attack: 100 (BASE VALUE - never modified by orbs)
├─ Defence: 50 (BASE VALUE - never modified by orbs)
├─ MaxHealth: 500 (BASE VALUE - never modified by orbs)
├─ MaxMana: 200 (BASE VALUE - never modified by orbs)
└─ Dexterity: 30 (BASE VALUE - never modified by orbs)

Server Memory (OrbSpiritHandler module)
├─ playerBaseStats[userId]
│  └─ Same values as player.Stats (cached for UI reads)
│
└─ playerOrbMultipliers[userId]
   ├─ Attack: 1.5 (multiplier, ONLY used in damage calc)
   ├─ Defence: 1.2 (stored for future use)
   ├─ MaxHealth: 1.1 (stored for future use)
   └─ (Other stats as needed)
```

### 2. Data Flow

#### Player Login
```
DataStore Load
    ↓
Stats Folder Created (base values from DataStore)
    ↓
CaptureInitialBaseStats() called
    ↓
playerBaseStats cache = Stats values
    ↓
EquipOrbFromInventory() called
    ↓
playerOrbMultipliers cache = Orb data (NOT applied to stats)
    ↓
Ready for gameplay
```

#### Damage Calculation (ONLY place multipliers are used)
```
DamageManager.calculateDamage()
    ↓
Get baseAttack from stats (base value)
    ↓
Get orbMultiplier from cache
    ↓
damageAttack = baseAttack * orbMultiplier
    ↓
Use damageAttack in formula (base stats remain unchanged)
```

#### Stat Increase (Level Up / Allocation / Admin)
```
StatsManager or LevelSystem updates stat
    ↓
player.Stats.Attack.Value = newValue (base increase)
    ↓
OrbSpiritHandler.UpdateBaseStats() called
    ↓
playerBaseStats cache updated = newValue
    ↓
Next damage calc uses updated base + multiplier
    ↓
Stat value in stats folder remains PURE BASE (never multiplied)
```

### 3. Critical Functions

#### OrbSpiritHandler.GetBaseStats(player)
- Returns cached base stat values
- Called by UI to display "Base (+Bonus)" format
- NEVER includes multipliers in the returned values
- Cache is always pure base values

```lua
-- Returns: { Attack=100, Defence=50, ... }
-- These are ALWAYS base values
local baseStats = OrbSpiritHandler.GetBaseStats(player)
-- UI shows: "100 (+50)" where 50 = current - base
```

#### OrbSpiritHandler.GetOrbMultipliers(player)
- Returns cached multipliers
- ONLY called by DamageManager
- Never used to modify stat values
- Can be expanded for other stat multipliers in future

```lua
-- Returns: { Attack=1.5, Defence=1.2, ... }
-- These are ONLY for calculation, never applied to stats
local mults = OrbSpiritHandler.GetOrbMultipliers(player)
local damageAttack = baseAttack * mults.Attack
```

#### DamageManager.calculateDamage(player, weaponName)
- ONLY function that uses multipliers
- Multiplies Attack for damage calculation only
- Does NOT modify player.Stats values
- Applied locally to damage formula

```lua
local attackDamage = attackStat.Value -- Get base (e.g., 100)
local orbMultipliers = OrbSpiritHandler.GetOrbMultipliers(player)
if orbMultipliers and orbMultipliers.Attack then
    attackDamage = attackDamage * orbMultipliers.Attack -- 100 * 1.5 = 150 (for calc only)
end
-- baseDamage = weaponDamage * (1 + (attackDamage / 100))
-- Final damage uses 150, but player.Stats.Attack stays 100
```

### 4. Stat Lifecycle

#### Initial Load
```
PlayerDataStore loads player data
    ├─ Attack = 100 (from DataStore)
    ├─ Defence = 50 (from DataStore)
    └─ ... (other stats)
         ↓
CaptureInitialBaseStats()
    ├─ playerBaseStats[userId].Attack = 100
    ├─ playerBaseStats[userId].Defence = 50
    └─ (cache now has base values)
         ↓
EquipOrbFromInventory()
    ├─ playerOrbMultipliers[userId].Attack = 1.5
    └─ (multipliers stored, NOT applied to stats)
```

#### During Gameplay (Mana Change Example)
```
CurrentMana.Value changes (mana drain)
    ↓
GameGui.client.lua listener fires
    ↓
updateStatsInfoDisplay() called
    ↓
getBaseStatsFunction:InvokeServer() called
    ↓
Server calls GetBaseStats()
    ↓
Returns playerBaseStats[userId] (always base: Attack=100)
    ↓
Client displays "100 (+bonus)" where bonus = current - base
    ↓
Multipliers NOT involved in this process
```

#### On Level Up
```
LevelSystem detects experience milestone
    ↓
Stats values increase (Attack: 100 → 105)
    ↓
OrbSpiritHandler.UpdateBaseStats(player) called
    ↓
playerBaseStats cache updated (Attack: 100 → 105)
    ↓
Next damage calc: 105 * 1.5 = 157.5 (for damage only)
    ↓
Stats value remains 105 (base, pure)
```

### 5. Why This Architecture Works

**Problem Solved: Stat Corruption**
- Before: When player had orb + stats loaded, cache would reverse-calculate from combined values
- After: Cache is always properly initialized with base values from DataStore
- No reverse-calculation needed because cache is set correctly at start

**Problem Solved: Save/Load Bugs**
- Before: DataStore might contain combined values, causing bugs on reload
- After: DataStore ALWAYS contains base values (multipliers never applied to stats)
- Clean reload: Load base values, apply multipliers in damage calc only

**Problem Solved: UI Display**
- Before: Displaying "100 (+50)" required knowing if values were combined or base
- After: Values in stats folder are ALWAYS base, UI calculation is always correct

**Problem Solved: Predictable Math**
- Before: Multiple layers of buff application/removal made the system fragile
- After: Single point of application (DamageManager) makes it simple and maintainable

## Implementation Checklist

✅ **OrbSpiritHandler**
- `playerBaseStats` - Caches base values (never multiplied)
- `playerOrbMultipliers` - Caches multipliers (never applied to stats)
- `CaptureInitialBaseStats()` - Always captures from DataStore as base
- `GetBaseStats()` - Returns pure base values
- `GetOrbMultipliers()` - Returns multipliers for DamageManager only
- `UpdateBaseStats()` - Called on stat changes, captures new base value

✅ **DamageManager**
- `calculateDamage()` - ONLY function using multipliers
- Multiplies Attack for damage calculation only
- Never modifies player.Stats values

✅ **GameGui (Client)**
- `updateStatsInfoDisplay()` - Gets base stats via GetBaseStatsFunction
- Displays format: "Base (+bonus)" where bonus = current - base
- No knowledge of multipliers (UI never touches them)

✅ **DataStore**
- Always saves base values from player.Stats
- Never contains multiplied/combined values
- Clean reload: load base values → apply multipliers in damage calc

## Testing & Verification

### Test 1: Stat Display Consistency
- Load player with orb equipped
- Attack should show base value (e.g., "100 (+0)")
- Decrease mana
- Attack should remain "100 (+0)" (no corruption)
- ✅ Passes

### Test 2: Damage Calculation
- Player with base Attack=100, orb multiplier=1.5
- Weapon damage=20
- Expected damage calc: 20 * (1 + (100*1.5)/100) = 20 * 2.5 = 50
- Verify actual damage matches expectation
- ✅ Passes

### Test 3: Stat Progression
- Player starts with Attack=10
- Level up → Attack=15 (base increased)
- playerBaseStats cache = 15
- Damage calc: 15 * 1.5 = 22.5
- ✅ Passes

### Test 4: Save/Load Integrity
- Player has Attack=100 (base), orb multiplier=1.5
- Save to DataStore
- DataStore contains: Attack=100 (base, NOT 150)
- Reload player
- Attack displays as 100 (correct base)
- Damage uses 150 (100 * 1.5)
- ✅ Passes

## Future Expansion

This architecture supports expanding multipliers to other stats:
- Defence multiplier: Applied in damage reduction formula
- MaxHealth multiplier: Applied to health calculations
- Dexterity multiplier: Applied to critical chance formula

All follow the same pattern: **Store multiplier, apply only in calculation, never to stat values**

## Summary

The orb system is now clean, predictable, and maintainable:
- **Base values** are always pure and unmodified
- **Multipliers** are stored separately and applied only in DamageManager
- **UI** always displays correct base stats
- **Saves** are always clean (base values only)
- **Calculations** are simple and maintainable (one point of application)
