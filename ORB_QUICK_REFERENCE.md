# Orb Multiplier Architecture - Quick Reference

## The System in 30 Seconds

**Stats = ALWAYS base values (never multiplied)**
```lua
player.Stats.Attack.Value = 100  -- Always base, never 150 (even with 1.5x orb)
```

**Multipliers = Stored separately (only for damage calc)**
```lua
playerOrbMultipliers[userId] = { Attack = 1.5 }  -- Stored, never applied to stats
```

**Damage calc = Only place multipliers are used**
```lua
-- In DamageManager:
local baseDamage = player.Stats.Attack.Value  -- 100
local multiplied = baseDamage * orbMultiplier  -- 150 (for damage only)
-- Final damage uses 150, but player.Stats.Attack stays 100
```

---

## Function Reference

### Get Base Stats (UI Display)
```lua
local baseStats = OrbSpiritHandler.GetBaseStats(player)
-- Returns: { Attack=100, Defence=50, ... }
-- These are ALWAYS base, never multiplied
```

### Get Multipliers (Damage Calculation Only)
```lua
local mults = OrbSpiritHandler.GetOrbMultipliers(player)
-- Returns: { Attack=1.5, Defence=1.2, ... }
-- ONLY used in DamageManager.calculateDamage()
```

### Calculate Damage (DamageManager)
```lua
local damage, isCritical, baseDmg, dex = DamageManager.calculateDamage(player, weaponName)
-- This is the ONLY function that uses multipliers
-- Multiplies Attack for calculation, never modifies stat values
```

### Update Base Stats
```lua
OrbSpiritHandler.UpdateBaseStats(player)
-- Called when stats change (level up, allocation, admin command)
-- Caches new base value
```

---

## Key Rules

### DO ✅
- Store multipliers in `playerOrbMultipliers`
- Use multipliers in DamageManager only
- Cache base stats in `playerBaseStats`
- Display base stats to UI
- Save base stats to DataStore

### DON'T ❌
- Apply multipliers to `player.Stats` values
- Use multipliers outside DamageManager
- Modify stat values with orb data
- Save combined values to DataStore
- Display multiplied stats to UI

---

## Data Locations

### Server Memory (OrbSpiritHandler)
```lua
playerBaseStats[userId] = {
  Attack = 100,           -- Base value, cached from stats
  Defence = 50,           -- Base value, cached from stats
  MaxHealth = 500,        -- Base value, cached from stats
  MaxMana = 200,          -- Base value, cached from stats
  Dexterity = 30          -- Base value, cached from stats
}

playerOrbMultipliers[userId] = {
  Attack = 1.5,           -- Multiplier, ONLY for DamageManager
  Defence = 1.2,          -- Multiplier, for future use
  MaxHealth = 1.1         -- Multiplier, for future use
}
```

### Client Memory (GameGui)
```lua
cachedBaseStats = {       -- Cached from GetBaseStatsFunction:InvokeServer()
  Attack = 100,           -- Base value from server
  Defence = 50,           -- Base value from server
  -- ... etc
}
-- Used for UI display: "Base (+Bonus)" format
```

### Player Instance (player.Stats folder)
```lua
player.Stats.Attack = IntValue(100)        -- Base value, never multiplied
player.Stats.Defence = IntValue(50)        -- Base value, never multiplied
player.Stats.MaxHealth = IntValue(500)     -- Base value, never multiplied
player.Stats.MaxMana = IntValue(200)       -- Base value, never multiplied
player.Stats.Dexterity = IntValue(30)      -- Base value, never multiplied
```

### DataStore
```lua
"Player_12345" = {
  Attack = 100,           -- Base value from stats folder
  Defence = 50,           -- Base value from stats folder
  MaxHealth = 500,        -- Base value from stats folder
  MaxMana = 200,          -- Base value from stats folder
  Dexterity = 30,         -- Base value from stats folder
  EquippedOrb = { name = "Dark Orb", id = "123" }
}
-- Never contains multiplied/combined values
```

---

## Stat Changes Flow

### When Stats Change
```
Stat value modified (e.g., Attack: 100 → 105)
         ↓
OrbSpiritHandler.UpdateBaseStats(player) called
         ↓
playerBaseStats[userId].Attack = 105
         ↓
Next damage calc: 105 * 1.5 = 157.5
```

### Mana Decrease Flow
```
CurrentMana.Value decreases
         ↓
UI listener fires
         ↓
getBaseStatsFunction:InvokeServer()
         ↓
Server returns GetBaseStats() (always base)
         ↓
UI displays "100 (+0)" (base + bonus)
         ↓
Multipliers NOT involved
```

---

## Common Questions

**Q: Do orbs affect stat display?**
A: No. Base stats are always displayed. Multipliers only affect damage calculations.

**Q: Where are multipliers used?**
A: Only in DamageManager.calculateDamage(). Nowhere else.

**Q: Can stats be saved with multipliers?**
A: No. DataStore always saves base values only.

**Q: What if cache is nil?**
A: CaptureInitialBaseStats runs at login, so cache should never be nil. Fallback reverse-calculation only for edge cases.

**Q: Can I add other stat multipliers?**
A: Yes. Store in playerOrbMultipliers and apply in relevant calc functions (e.g., Defence in damage reduction).

---

## Files Changed This Update

1. **OrbSpiritHandler.lua**
   - Added architectural header (30 lines)
   - Improved table comments (8 lines)
   - Updated GetBaseStats comments (8 lines)
   - Updated GetOrbMultipliers comments (6 lines)
   - Enhanced debug logging (4 lines)

2. **DamageManager.lua**
   - Updated calculateDamage comments (15 lines)
   - Clarified multiplier application (5 lines)

3. **Documentation**
   - ORB_MULTIPLIER_ARCHITECTURE.md (200+ lines)
   - ORB_SYSTEM_VERIFICATION.md (150+ lines)
   - This quick reference (this file)

---

## Status

✅ Architecture: Clean (Non-Additive)
✅ Code: Verified
✅ Bugs: Fixed (Stat Corruption)
✅ Documentation: Complete
✅ Ready: For testing/production
