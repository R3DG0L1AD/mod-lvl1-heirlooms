# mod-lvl1-heirlooms

AzerothCore 3.3.5a **Eluna/ALE** script. On a **new real character's first login**, grants a class kit of **heirloom** shoulders, chests, weapons, trinkets, and Dread Pirate Ring.

Overflow is mailed. Bots (`IsBot`, RNDBOT/RAIDBOT/AHBOT) are skipped. One-time per character (first-login event only).

## Install

Copy `lua_scripts/lvl1_heirlooms.lua` into the worldserver Lua folder and `.reload ale`.

Heirlooms must exist in `item_template` (stock WotLK heirlooms, Quality 7). No client DBC patch.

## Config

Edit `KITS[classId]` at the top of the script.
