# DatDanillaHub

Pet Simulator 99 — auto progression + rank driver.

## Load

```lua
script_key = "THE-KEY-I-GAVE-YOU";

loadstring(game:HttpGet("https://raw.githubusercontent.com/DatDanilla/DatDanillaHub/main/DatDanillaHub.luau"))()
```

The key must be inside the quotes. No key window pops up - a wrong, missing or
removed key just shows a short error and the script stops.

## Repo layout

```
DatDanillaHub.luau   main script (this is the file the loader pulls)
keys.txt             hashed key list, one hash per line
keygen.luau          run this to turn a key into a hash for keys.txt
README.md            this file
```

## Keys

`keys.txt` does **not** contain readable keys. Each line is:

```
sha256("DatDanillaHub|v1|2026" .. key)
```

so someone reading the file cannot copy a key out of it.

Adding a key:
1. open `keygen.luau`, put the plain key in `KEYS = { "shrek" }`
2. run it in any executor (Roblox does not need to be in a game)
3. copy the printed hash into `keys.txt`, one hash per line
4. upload `keys.txt`

Deleting a key: delete its line and upload. That person's loader stops working
on their next launch. Changing the key means they need a new loader line.

`DEFAULT_KEYS` is empty, so `keys.txt` is the only source of valid keys.

## UI

- Icon button (top right): closes / reopens the menu.
- `datdanillarank` toggle: starts / stops the engine.
- Quest line under the toggle shows the rank quest currently being worked on.

## Behaviour

Phase 1 (FARM) runs until you own zone 98 (Colorful Clouds):
rebirth, buy next area, enchant Coins/Coins/Coins, hatch MaxEquipped x best egg,
TNT every 5s, TNT crate when stuck, farm breakables + orbs/coins/gems, all universal claims.

Phase 2 (RANK) starts automatically once zone 98 is owned and runs until rank 8:
Treasure Hunter/Treasure Hunter/Coins enchants, priority quest handling
(potions, fruits, flags, enchant/potion upgrades, eggs, gold/rainbow pets,
comets, coin jars, pinatas, lucky blocks), then normal and side quests.

At rank 8 the script turns itself off, and refuses to start again until you rebirth.

Hard stops: never buys zone 99 (Rainbow Road) and never enters VIP.

## Note on hiding

A client-side Luau script is always downloadable by the executor that runs it, so the
code cannot be made truly unreadable. The key list is protected by hashing. If you want
the code itself harder to read, run `DatDanillaHub.luau` through an obfuscator before
uploading (the raw file is still the one to keep for editing).
