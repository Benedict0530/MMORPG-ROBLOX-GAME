# Stat Corruption Bug - Root Cause Analysis & Fix

## Problem
When CurrentMana decreased, the base stats cache would become corrupted with reverse-calculated values.
- Example: Attack displayed as "1 (+35)" would change to "22 (+14)" when mana dropped by 2
- Suggests base stats were being recalculated instead of retrieved from cache

## Root Cause
**CaptureInitialBaseStats() had conditional logic that skipped cache initialization when an orb was already equipped**

Flow when player with equipped orb logs in:
1. Stats loaded from DataStore (base stats)
2. CaptureInitialBaseStats() checks if orb is equipped
3. IF orb equipped → SKIPS cache initialization with message "will be handled by EquipOrbFromInventory"
4. EquipOrbFromInventory() runs but cache is nil
5. Reverse-calculation triggers: `base = current / multiplier`
6. Cache corrupted with wrong values for entire session

## Why This Caused Mana-Related Corruption
When mana decreased:
1. CurrentMana.Changed event fired in GameGui
2. updateStatsInfoDisplay() called getBaseStatsFunction:InvokeServer()
3. Server returned corrupted cache values
4. UI showed wrong base stat with wrong bonus calculation

This only happened during runtime reads of the cache, which occurred when UI updated on stat changes.

## The Fix
**CaptureInitialBaseStats() now ALWAYS initializes the cache from DataStore values**

Key insight: DataStore values should ALWAYS be base stats because:
- Stats only modified by: stat allocation, level-up, admin commands
- Never modified by orb multipliers (multipliers applied only in DamageManager for damage calc)
- No other system modifies stat values

Changed logic:
```lua
-- BEFORE: Skip if orb equipped
if not hasOrb then
    -- capture
else
    -- skip, will be handled later
end

-- AFTER: Always capture
-- ALWAYS capture current stat values as base - DataStore should never contain combined values
playerBaseStats[userId] = {
    Attack = stats.Attack.Value,
    Defence = stats.Defence.Value,
    ... etc
}
```

## Why This Fix Works
1. Cache is properly initialized at login (before EquipOrbFromInventory)
2. Reverse-calculation never triggers (cache never nil on initial setup)
3. Cache contains correct base values throughout session
4. UI always displays correct base stat + bonus calculation
5. Mana changes no longer trigger stat corruption

## Code Changes
- **OrbSpiritHandler.lua line 926**: Modified CaptureInitialBaseStats() to always capture stats
- **OrbSpiritHandler.lua line 857**: Added fallback handling + improved logging
- **OrbSpiritHandler.lua line 961**: Added GetBaseStats() logging to track cache state
- **OrbSpiritHandler.lua line 923**: Added CaptureInitialBaseStats() logging

## Testing
After fix, verify:
1. Player logs in with orb equipped → Attack should show correct base stat
2. Mana decreases → Attack display unchanged (no corruption)
3. Server logs should show "Captured base stats" with correct Attack value
4. No WARNING logs about reverse-calculation on initial load
