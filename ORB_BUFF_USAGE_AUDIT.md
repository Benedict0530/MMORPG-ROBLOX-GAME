# Orb Buff System - Complete Usage Audit

## Overview
This document provides a comprehensive audit of where orb buffs are used throughout the entire MMORPG project. The system uses **non-additive multipliers** that are stored separately from stat values and only applied during damage calculations.

---

## 📊 High-Level Architecture

```
Player Stats (in player.Stats folder)
  ├─ Attack = 100 (BASE VALUE - NEVER MODIFIED)
  ├─ Defence = 50
  └─ Dexterity = 25

Orb Multipliers (cached in server memory)
  └─ playerOrbMultipliers[userId] = { Attack = 1.5, Defence = 1.2 }
     (ONLY used in DamageManager - never touches actual stats)

Client UI Display
  └─ "Base (+AllocationBonus) [+OrbBonus]"
     Example: "100 (+10) [+50 orb]"
```

---

## 📁 Files Using Orb Buff System

### 1. **OrbSpiritHandler.lua** (Core Orb System)
**Path:** `src/ServerScriptService/Library/OrbSpiritHandler.lua`

**Purpose:** Central hub for all orb mechanics, multiplier storage, and base stat caching

**Key Tables:**
- `playerOrbMultipliers[userId]` - Stores multiplier values (ONLY for DamageManager)
- `playerBaseStats[userId]` - Caches pure base stat values (never modified by orbs)
- `playerOrbEquipped[userId]` - Tracks if orb is equipped (for UI timing)
- `isEquippingOrb[userId]` - Prevents duplicate equipping calls

**Key Functions:**

| Function | Purpose | Used By |
|----------|---------|---------|
| `storeOrbMultipliers(player, orbName)` | Stores multiplier data from OrbData module | EquipOrbFromInventory, ChangeSpiritOrb |
| `GetOrbMultipliers(player)` | Retrieves cached multipliers | DamageManager, Client UI |
| `EquipOrbFromInventory(player)` | Equips orb from inventory system | EquippedOrbChanged event |
| `ChangeSpiritOrb(player, orbName)` | Changes orb (admin/command) | Admin commands |
| `UpdateBaseStats(player)` | Captures current stats as new base | StatsManager, LevelSystem |
| `CaptureInitialBaseStats(player)` | Initial base stats capture on join | PlayerDataStore |
| `IsOrbEquipped(player)` | Checks if orb is equipped | Client UI (on first load) |

**Lines with Orb Buff References:**
- **Line 53-54:** Comment defining playerOrbMultipliers
- **Line 111-129:** storeOrbMultipliers function (stores multipliers from OrbData)
- **Line 932-937:** EquipOrbFromInventory calls storeOrbMultipliers and fires RefreshStatsUI
- **Line 1045-1050:** GetOrbMultipliers function with comments on DamageManager use

---

### 2. **DamageManager.lua** (Damage Calculation with Orb Buff)
**Path:** `src/ServerScriptService/Library/Combat/DamageManager.lua`

**Purpose:** Calculate player damage including orb multiplier application

**Function: `calculateDamage(player, weaponName, randomFactor)`**

**Damage Formula:**
```lua
1. Get Attack stat from player.Stats.Attack (base value, unmodified)
2. Apply orb multiplier: attackDamage = floor(attackDamage * orbMultiplier.Attack)
   ↓ NOTE: This is a temporary calculation variable, NOT stored back to stat
3. Calculate base damage: weaponDamage * (1 + attackDamage/100)
4. Apply critical hit multiplier if critical
5. Randomize between 40%-100% of calculated damage
```

**Key Code Section (Lines 67-75):**
```lua
-- APPLY ORB MULTIPLIER TO ATTACK FOR DAMAGE CALCULATION ONLY
-- This does NOT modify the actual stat value - only the damage calculation
local orbMultipliers = OrbSpiritHandler.GetOrbMultipliers(player)
if orbMultipliers and orbMultipliers.Attack then
    attackDamage = math.floor(attackDamage * orbMultipliers.Attack)
end
```

**Important:** The multiplier is applied to a local variable only - the actual stat value in `player.Stats.Attack` is NEVER modified.

---

### 3. **GameGui.client.lua** (Client UI Display)
**Path:** `src/StarterPlayer/StarterPlayerScripts/GameGui.client.lua`

**Purpose:** Display stats with orb bonus breakdown in the player UI

**Sections Displaying Orb Bonus:**

#### A. Attack Display (Lines 200-234)
```lua
local orbMultiplier = 1.0
local getOrbMultiplierFunction = ReplicatedStorage:FindFirstChild("GetOrbMultiplierFunction")
if getOrbMultiplierFunction then
    local multipliers = getOrbMultiplierFunction:InvokeServer()
    if multipliers and multipliers.Attack then
        orbMultiplier = multipliers.Attack
    end
end

-- Calculate orb bonus: (base * multiplier) - base
local orbBonus = math.floor(baseAttack * orbMultiplier) - baseAttack

-- Format: "Base (+AllocationBonus) [+OrbBonus]"
if allocationBonus > 0 and orbBonus > 0 then
    attackValue.Text = baseAttack .. " (+" .. allocationBonus .. ") [" .. orbBonus .. " orb]"
elseif orbBonus > 0 then
    attackValue.Text = baseAttack .. " [+" .. orbBonus .. " orb]"
```

#### B. Defence Display (Lines 247-270)
Similar logic for Defence stat with Defence multiplier

#### C. Dexterity Display (Lines 273-295)
Similar logic for Dexterity stat with Dexterity multiplier

#### D. Real-Time Updates
- **Lines 714-730:** Listeners on `EquippedOrb` folder for orb changes
- **Lines 718-719:** When orb name changes, calls `updateStatsInfoDisplay()`
- **Lines 729-730:** When orb ID changes, calls `updateStatsInfoDisplay()`
- **RefreshStatsUI Event:** Listens for server signals to refresh UI

#### E. First-Load Orb Waiting (Lines 190-200)
```lua
-- Wait for orb to be equipped before displaying first time
local isOrbEquippedFunction = ReplicatedStorage:FindFirstChild("IsOrbEquippedFunction")
if isOrbEquippedFunction then
    local success = isOrbEquippedFunction:InvokeServer()  -- Wait up to 5 seconds
```

---

### 4. **StatsManager.lua** (Stat Allocation System)
**Path:** `src/ServerScriptService/Library/Player/StatsManager.lua`

**Purpose:** Handle stat point allocation and reset with cache updates

**Integration Points:**

#### A. Stat Allocation (allocateStatPoint function)
- Calls `OrbSpiritHandler.UpdateBaseStats(player)` after allocation
- Waits 0.05 seconds for cache propagation
- Fires `RefreshStatsUI` event to client for real-time display update

#### B. Stat Reset (resetStats function)
- Calls `OrbSpiritHandler.UpdateBaseStats(player)` after reset
- Fires `RefreshStatsUI` event to refresh UI

**Why This Matters:**
When stats are allocated/reset, the base stats cache must update. This ensures that the next orb bonus calculation uses the correct base value.

---

### 5. **LevelSystem.lua** (Leveling System)
**Path:** `src/ServerScriptService/Library/Player/LevelSystem.lua`

**Purpose:** Handle player level progression

**Integration Point:**
- Calls `OrbSpiritHandler.UpdateBaseStats(player)` after level up
- Ensures base stats cache reflects new level bonuses

---

### 6. **PlayerDataStore.lua** (Player Data Management)
**Path:** `src/ServerScriptService/Library/DataManagement/PlayerDataStore.lua`

**Purpose:** Load and manage player data on join/leave

**Integration Points:**

#### A. Player Initialization (Lines 330-331)
```lua
DamageManager.MarkPlayerInitializing(player)
```

#### B. Player Loaded (Line 425)
```lua
DamageManager.MarkPlayerLoaded(player)
```

#### C. Player Disconnect (Lines 441-442)
```lua
DamageManager.MarkPlayerDisconnected(player)
-- Clears orb-related caches via cleanupPlayerOrbData
```

#### D. Initial Base Stats Capture
- Calls `OrbSpiritHandler.CaptureInitialBaseStats(player)` after stats setup
- Populates `playerBaseStats[userId]` with initial values

---

### 7. **OrbData.lua** (Orb Definition Database)
**Path:** `src/ReplicatedStorage/Modules/OrbData.lua`

**Purpose:** Store orb stat definitions (multipliers)

**Structure:**
```lua
OrbData.Orbs = {
    ["Dark Orb"] = {
        id = "orb_001",
        stats = { Attack = 1.5, Defence = 1.0, Dexterity = 0.8 }
    },
    ["Fire Orb"] = {
        id = "orb_002",
        stats = { Attack = 1.3, Defence = 0.9, Dexterity = 1.2 }
    },
    -- ... more orbs
}
```

**How It's Used:**
- `storeOrbMultipliers()` reads `OrbData.GetOrbData(orbName)` to get multiplier values
- These values are stored in `playerOrbMultipliers[userId]` (NOT applied to stats)

---

## 🔄 Data Flow Diagrams

### On Player Join
```
PlayerDataStore.LoadPlayerData()
    ↓
Create Stats folder (Attack, Defence, Dexterity, etc.)
    ↓
OrbSpiritHandler.CaptureInitialBaseStats(player)
    └─→ playerBaseStats[userId] = { Attack: 100, Defence: 50, ... }
    ↓
EquipOrbFromInventory(player)
    ├─→ storeOrbMultipliers(player, orbName)
    │   └─→ playerOrbMultipliers[userId] = { Attack: 1.5, ... }
    └─→ Fire RefreshStatsUI event to client
    ↓
GameGui.client - updateStatsInfoDisplay()
    ├─→ Fetch baseStats via GetBaseStatsFunction
    ├─→ Fetch orbMultipliers via GetOrbMultiplierFunction
    └─→ Display: "100 (+10) [+50 orb]"
```

### On Stat Allocation
```
Client: AllocateStatPoint RemoteEvent
    ↓
StatsManager.allocateStatPoint(player, statName)
    ├─→ Increment stat in player.Stats folder
    └─→ OrbSpiritHandler.UpdateBaseStats(player)
        └─→ playerBaseStats[userId].Attack = 110 (new base)
    ↓
    Fire RefreshStatsUI event to client
    ↓
GameGui.client - updateStatsInfoDisplay()
    └─→ Display updated stats with new base and orb bonus
```

### On Orb Change
```
Client: EquippedOrbChanged RemoteEvent
    ↓
OrbSpiritHandler.EquipOrbFromInventory(player)
    ├─→ storeOrbMultipliers(player, newOrbName)
    │   └─→ playerOrbMultipliers[userId] = newMultipliers
    └─→ Fire RefreshStatsUI event to client
    ↓
GameGui.client - updateStatsInfoDisplay()
    ├─→ Fetch new orbMultipliers via GetOrbMultiplierFunction
    └─→ Display updated orb bonus with new multiplier
```

### On Damage Calculation
```
DamageManager.calculateDamage(player, weaponName)
    ├─→ Get Attack from player.Stats.Attack (base, unmodified)
    ├─→ Get orbMultiplier from OrbSpiritHandler.GetOrbMultipliers()
    ├─→ Apply multiplier: attackDamage = floor(attackDamage * orbMultiplier.Attack)
    │   (This is a LOCAL VARIABLE calculation only)
    ├─→ Calculate baseDamage = weaponDamage * (1 + attackDamage/100)
    ├─→ Apply critical multiplier if needed
    ├─→ Randomize 40%-100%
    └─→ Return finalDamage
```

---

## 🎯 Key Design Principles

### 1. **Stats Are NEVER Modified**
- Player.Stats values are always pure base values
- Orbs never add to stat values themselves
- `playerBaseStats` cache stores exact values from `player.Stats`

### 2. **Multipliers Are Stored Separately**
- Multiplier values cached in `playerOrbMultipliers`
- These are ONLY retrieved when needed (damage calc, UI display)
- Never stored back to stat values

### 3. **Orb Buff Applied at Calculation Time**
- In **DamageManager:** Multiplier applied to temporary calculation variable
- In **GameGui:** Orb bonus calculated for display (not stored)
- Formula: `bonusValue = floor(baseValue * multiplier) - baseValue`

### 4. **Real-Time Updates via Events**
- `RefreshStatsUI` event signals when to refresh display
- `EquippedOrbChanged` event triggers on orb swap
- `GetOrbMultiplierFunction` RemoteFunction fetches current multipliers

### 5. **Proper Initialization Sequence**
1. Stats folder created (base values)
2. `CaptureInitialBaseStats()` called to cache base values
3. Orb equipped and multipliers stored
4. UI waits for orb completion before first display
5. Client refreshes with both base and orb bonus

---

## 🔍 Audit Summary

| Component | Status | Key File | Lines |
|-----------|--------|----------|-------|
| Multiplier Storage | ✅ Clean | OrbSpiritHandler.lua | 53-54, 127 |
| Multiplier Retrieval | ✅ DamageManager only | DamageManager.lua | 67-75 |
| Base Stats Caching | ✅ Implemented | OrbSpiritHandler.lua | 62-75, 980-995 |
| UI Display Format | ✅ "Base (+Alloc) [+Orb]" | GameGui.client.lua | 228, 234 |
| Real-Time Updates | ✅ Event-driven | GameGui.client.lua | 718-730 |
| Stat Allocation Integration | ✅ Calls UpdateBaseStats | StatsManager.lua | - |
| Leveling Integration | ✅ Calls UpdateBaseStats | LevelSystem.lua | - |
| Orb Change Updates | ✅ Fires RefreshStatsUI | OrbSpiritHandler.lua | 934-938 |

---

## ✅ Verification Checklist

- [x] Orb multipliers stored in `playerOrbMultipliers` (server memory only)
- [x] Actual stat values in `player.Stats` never modified by orbs
- [x] Base stats cached in `playerBaseStats` immediately after capture
- [x] DamageManager uses multiplier only in damage calculation (not stored)
- [x] UI displays format: "Base (+AllocationBonus) [+OrbBonus]"
- [x] Orb change triggers UI refresh via RefreshStatsUI event
- [x] Stat allocation triggers UpdateBaseStats and UI refresh
- [x] Level up triggers UpdateBaseStats
- [x] Player join waits for orb equipment before first display
- [x] Admin commands properly integrated with UpdateBaseStats

---

## 📝 Remote Functions/Events Used

| Name | Type | Purpose | Caller | Callee |
|------|------|---------|--------|--------|
| `GetBaseStatsFunction` | RemoteFunction | Client fetches base stats for UI | GameGui | OrbSpiritHandler |
| `GetOrbMultiplierFunction` | RemoteFunction | Client fetches multipliers for display bonus | GameGui | OrbSpiritHandler |
| `IsOrbEquippedFunction` | RemoteFunction | Client checks if orb is equipped | GameGui | OrbSpiritHandler |
| `RefreshStatsUI` | RemoteEvent | Server signals client to refresh stats display | OrbSpiritHandler, StatsManager | GameGui |
| `EquippedOrbChanged` | RemoteEvent | Client signals server when orb changes | Client Inventory | OrbSpiritHandler |
| `AllocateStatPoint` | RemoteEvent | Client requests stat allocation | GameGui | StatsManager |

---

## 🚀 Conclusion

The orb buff system is cleanly architected with:
- **Separation of Concerns:** Stats, multipliers, and calculations in separate systems
- **No Stat Modification:** Orbs never touch actual stat values
- **Proper Caching:** Base stats and multipliers cached separately
- **Real-Time Updates:** Event-driven system ensures UI stays current
- **Single Point of Application:** DamageManager is the only place multipliers affect gameplay

All references to orb buffs are accounted for and properly integrated.
