# Party-Based Loot & Experience System

## Overview
Implemented a comprehensive party-based loot and experience sharing system that allows players in the same party to share drops and experience rewards from defeating enemies.

## Key Features

### 1. Party-Based Loot Sharing
**File: `ItemDropManager.lua`**

When an enemy is defeated by a player in a party:
- The dropped items are automatically associated with all party members
- All party members can pick up the drops within the 10-second ownership window
- Solo players (not in a party) can only pick up drops they personally obtained
- After 10 seconds, drops become available to all players

**Implementation:**
- When spawning a drop, the system checks if the defeating player is in a party
- If in a party, all party members are stored as "PartyMembers" in the drop object
- This allows the pickup system to recognize party-based ownership

### 2. Party-Based Experience Sharing
**File: `EnemiesModule.lua`**

When an enemy is defeated, experience is distributed based on party membership:

#### Solo Players
- Receive experience proportional to the damage they dealt
- Formula: `(playerDamage / totalDamage) × enemyExperience`

#### Party Players
- Party's total experience is calculated based on combined party damage
- Experience is then divided **equally** among all party members who dealt damage
- Formula: `((partyTotalDamage / totalDamage) × enemyExperience) ÷ numberOfPartyMembers`

**Example:**
- Enemy gives 100 XP
- Party A deals 60% of total damage → 60 XP for the party
- Party A has 3 members who dealt damage → 20 XP each
- Solo player deals 40% of total damage → 40 XP to that player

### 3. Party Ownership Validation
**File: `ItemCollectionHandler.lua`**

The pickup system now validates both:
1. Direct ownership (the player who defeated the enemy)
2. Party membership (checking if picker is in the same party as the owner)

**Logic:**
```lua
if elapsedTime < 10 seconds then
    can_pickup = (player is owner) OR (player and owner are in same party)
else
    can_pickup = true -- Anyone can pick it up
end
```

## Configuration

### Ownership Window Duration
- **Location:** `ItemDropManager.lua` line 112
- **Value:** 10 seconds
- **Effect:** Duration that only the defeating player and party members can pick up items
- Modify `pickupRestrictionValue.Value = 10` to change

### Item Despawn Time
- **Location:** `ItemDropManager.lua` line 288
- **Value:** 30 seconds
- **Effect:** Items despawn if not collected within this time
- Modify `task.delay(30, ...)` to change

## Console Output
The system provides detailed logging for debugging:

### Loot Sharing
```
[ItemDropManager] ✅ Drop [ItemName] set for party of [PlayerName] (3 members)
[ItemDropManager] ℹ️ Drop [ItemName] set for solo player [PlayerName]
[ItemCollectionHandler] ✅ [PlayerName] can pick up party-owned drop (party leader: [LeaderName])
```

### Experience Distribution
```
[EnemiesModule] 👥 Party party_1 gets 60 XP total, divided equally = 20 each to 3 members
[EnemiesModule] Awarded 20 XP to PARTY member [PlayerName] (party: party_1)
[EnemiesModule] Awarded 40 XP to SOLO player [SoloPlayerName]
```

## Benefits

✅ **Team Cooperation** - Players in parties benefit more from fighting together
✅ **Fair Distribution** - Experience is proportional to party contribution
✅ **Shared Resources** - All party members can access the same loot
✅ **Flexible Solo Play** - Solo players still get full rewards for solo kills
✅ **Balanced Economy** - Party members get less individual XP but work together efficiently

## Edge Cases Handled

- ✅ Players leaving party mid-fight (still get their share)
- ✅ Player disconnecting after kill (party gets their exp)
- ✅ Party members out of range when picking up drops (still allowed during ownership window)
- ✅ Mixed solo/party players fighting same enemy (each gets appropriate share)
- ✅ Multiple parties fighting same enemy (each party divided equally within themselves)

## Future Enhancements

Potential improvements:
- [ ] Configurable experience sharing mode (equal vs proportional)
- [ ] Party level scaling for difficulty balance
- [ ] Loot rarity bonus for larger parties
- [ ] Shared party treasury system
