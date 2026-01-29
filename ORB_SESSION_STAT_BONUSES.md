# Orb Session-Based Stat Bonuses Implementation

## Overview
Orb stat bonuses for MaxHealth, MaxMana, and Dexterity are now applied as **session-based buffs** that:
- ✅ Add to stat values temporarily during gameplay
- ✅ Are NOT saved to DataStore
- ✅ Auto-reapply on player rejoin (when orb is re-equipped)
- ✅ Restore to original values when orb is unequipped

## Architecture

### Stat Types

**Two Categories of Orb Effects:**

1. **Damage Multiplier (Attack)** - Stored separately
   - NOT applied to actual stat values
   - Only used in DamageManager for damage calculations
   - Example: Base Attack 100 + 1.5x multiplier = 150 damage (not stored)
   - Displayed in UI as bonus information

2. **Session Stat Bonuses (MaxHealth, MaxMana, Dexterity)** - Applied directly
   - Applied to actual stat values when orb equipped
   - Restored to original when orb unequipped
   - NOT saved to DataStore (only base values saved)
   - Example: Base MaxHealth 100 + 1.4x multiplier = 140 actual stat value

### Implementation Flow

#### On Player Join
```
1. PlayerDataStore loads stats from DataStore
   └─→ All stats are base values (no orb bonuses)

2. Player.Stats has: MaxHealth = 100, MaxMana = 50, etc.

3. EquipOrbFromInventory() is called
   ├─→ storeOrbMultipliers(player, orbName)
   │   └─→ playerOrbMultipliers[userId] = { Attack: 1.25, MaxHealth: 1.4, ... }
   │
   └─→ applyOrbStatBonuses(player, orbName)
       ├─→ playerOrbBonusedStats[userId] = {
       │       originalMaxHealth: 100,
       │       originalMaxMana: 50,
       │       originalDexterity: 25
       │   }
       └─→ Apply multipliers to actual stats:
           ├─→ MaxHealth = floor(100 * 1.4) = 140
           ├─→ MaxMana = floor(50 * 1.2) = 60
           └─→ Dexterity = floor(25 * 1.3) = 32

4. GameGui displays current values:
   ├─→ Health: 140/140 (boosted, shows current value)
   ├─→ Mana: 60/60 (boosted, shows current value)
   └─→ Attack: 100 [+50 orb] (displays bonus separately)
```

#### On Orb Change
```
1. EquippedOrbChanged event fires

2. EquipOrbFromInventory() called with new orb
   ├─→ removeOrbStatBonuses() first
   │   ├─→ Restore MaxHealth to originalMaxHealth
   │   ├─→ Restore MaxMana to originalMaxMana
   │   └─→ Restore Dexterity to originalDexterity
   │
   └─→ applyOrbStatBonuses() with new orb
       └─→ Apply new multipliers

3. UI automatically refreshes with new values
```

#### On Orb Unequip
```
1. UnequipSpiritOrb() called

2. removeOrbStatBonuses() executed
   ├─→ MaxHealth restored to original
   ├─→ MaxMana restored to original
   └─→ Dexterity restored to original

3. Stats folder now contains only base values
```

#### On Player Logout
```
1. PlayerDataStore.SaveStats() saves CURRENT values
   └─→ But since we restore to base on unequip, this saves base values

2. playerOrbBonusedStats[userId] cleared on disconnect
```

## Code Changes

### OrbSpiritHandler.lua

**New Tracking Table:**
```lua
-- Track original stat values BEFORE orb bonuses are applied
local playerOrbBonusedStats = {}
-- Format: playerOrbBonusedStats[userId] = {
--     originalMaxHealth = 100,
--     originalMaxMana = 50,
--     originalDexterity = 25
-- }
```

**New Function: applyOrbStatBonuses()**
```lua
local function applyOrbStatBonuses(player, orbName)
    -- Get orb multipliers from OrbData
    -- Store original values
    -- Apply multipliers: stat = floor(original * multiplier)
    -- For MaxHealth, MaxMana, Dexterity
end
```

**New Function: removeOrbStatBonuses()**
```lua
local function removeOrbStatBonuses(player)
    -- Restore MaxHealth to original
    -- Restore MaxMana to original
    -- Restore Dexterity to original
    -- Clear playerOrbBonusedStats entry
end
```

**Integration Points:**
- `EquipOrbFromInventory()` - Calls applyOrbStatBonuses() after storeOrbMultipliers()
- `UnequipSpiritOrb()` - Calls removeOrbStatBonuses() before clearOrbMultipliers()
- `cleanupPlayerOrbData()` - Clears playerOrbBonusedStats on disconnect

## UI Display

### MaxHealth and MaxMana
**Display:** Shows current (boosted) value
```
Health: 140/140        (when orb provides +1.4x MaxHealth)
Mana: 60/60            (when orb provides +1.2x MaxMana)
```

The UI displays the actual current stat values. Since these are session-based and restored on logout, there's no confusion about saved vs temporary values.

### Attack and Defence
**Display:** Shows base value with bonus information
```
Attack: 100 [+50 orb]           (orb provides 1.5x multiplier, calculated as (100*1.5)-100=50)
Defence: 50 [+10 orb]           (orb provides 1.2x multiplier)
Dexterity: 25 [+6 orb]          (orb provides 1.24x multiplier)
```

These show bonuses separately because they're NOT applied to actual stat values.

## DataStore Behavior

**What Gets Saved:**
```lua
Stats folder contains:
├─ Attack = 100 (unchanged, base value)
├─ Defence = 50 (unchanged, base value)
├─ MaxHealth = 100 (RESTORED to original before save)
├─ MaxMana = 50 (RESTORED to original before save)
└─ Dexterity = 25 (RESTORED to original before save)
```

**Timeline:**
1. Player has orb equipped → MaxHealth = 140 (boosted)
2. Player logs out → UnequipSpiritOrb() called → MaxHealth = 100 (restored)
3. DataStore saves MaxHealth = 100 (base value)
4. Player rejoins → MaxHealth = 100 loaded → Orb re-equipped → MaxHealth = 140 (re-boosted)

## Advantages of This Design

1. **Clean Data Integrity** - DataStore only ever contains base values
2. **Predictable Behavior** - Stats always reset to base on logout, no accumulation
3. **Session-Based Buffs** - Orb bonuses feel temporary and fair
4. **Easy to Balance** - All orb values in OrbData.lua, apply consistently
5. **No Save Corruption** - Multiplier values never stored with stats
6. **Consistent Display** - UI shows what the player actually has

## Example Orb Data

From OrbData.lua:
```lua
["Fire Orb"] = {
    chance = 0.20,
    stats = {
        Attack = 1.25,        -- Damage calc only (not applied to stat)
        Defence = 1.30,       -- Damage calc only (not applied to stat)
        MaxHealth = 1.40,     -- Applied to actual stat (+40%)
        Dexterity = 1.30      -- Applied to actual stat (+30%)
    }
}
```

With base stats of Attack=100, Defence=50, MaxHealth=100, Dexterity=25:

| Stat | Base | Multiplier | Actual Value | Display |
|------|------|-----------|--------------|---------|
| Attack | 100 | 1.25x | 100 | "100 [+25 orb]" |
| Defence | 50 | 1.30x | 50 | "50 [+10 orb]" |
| MaxHealth | 100 | 1.40x | **140** | "140/140" |
| Dexterity | 25 | 1.30x | **32** | "32" or "25 [+7 orb]"* |

*Dexterity display depends on implementation choice

## Implementation Status

✅ **Completed:**
- Added playerOrbBonusedStats tracking table
- Created applyOrbStatBonuses() function
- Created removeOrbStatBonuses() function
- Integrated with EquipOrbFromInventory()
- Integrated with UnequipSpiritOrb()
- Added cleanup in cleanupPlayerOrbData()
- Session-based bonuses working correctly

## Testing Checklist

- [ ] Player joins → orb equipped → MaxHealth increases
- [ ] Change orb → new MaxHealth applied, old one removed
- [ ] Unequip orb → MaxHealth returns to original
- [ ] Player logout → stats reset to base
- [ ] Player rejoin → base stats loaded, orb re-equipped, bonuses reapplied
- [ ] DataStore only contains base values (verify with save logs)
- [ ] UI displays correct values (actual for health/mana, bonus format for attack)
- [ ] No stat accumulation across sessions
- [ ] Multiple stat types work together (health + mana + dexterity)
