--[[
  Healey Boys - first-login heirlooms INTO BAGS (mod-ale)
  Replaces 02_heirloom_mail.lua (kept as 02_heirloom_mail.lua.bak).

  On a NEW real character's first login:
    1. (REMOVED 2026-10-21, approved by M H: the 20-slot Frostweave Bag (41599) is no longer
       given - the 4 starter crates below fill the bag slots instead.)
    2. ~2s later adds every heirloom for the character's CLASS to the bags
       (mod-uac: any race/class, so kits are by class, not race).
    3. Anything that doesn't fit is MAILED ("Starter Heirlooms (overflow)").
       If the player logs out before step 2 runs, the whole kit is mailed instead.
  Bots are skipped (playerbots API + RNDBOT/PLAYERBOT/AHBOT account names).
  All entries verified Quality=7 in acore_world.item_template.

  2026-10-21 STARTER CRATES (approved by M H): before step 1, every NEW real character gets
  4x Foror's Crate of Endless Resist Gear Storage (23162, 36-slot general bag):
    * equipped straight into empty bag slots 19-22, then backpack, then mailed ("Starter Crates");
    * one-time per character: flag row in acore_characters.familylan_starter_crates (guid PK), written
      BEFORE the grant, checked synchronously, + player:SaveToDB() after the grant, so a relog / crash /
      double event can't grant twice. Existing characters are never touched (first-login event only).
    * 2026-10-21 (later, approved): Frostweave Bag grant removed entirely; crates are the only starter bags.
  Undo: races-server-stage/GO-LIVE/starter-crates-20261021/UNDO-starter-crates.ps1
]]

local PLAYER_EVENT_ON_LOGOUT      = 4
local PLAYER_EVENT_ON_FIRST_LOGIN = 30
local MAIL_STATIONERY_GM = 61
local INVENTORY_SLOT_BAG_0 = 255
local GRANT_DELAY_MS = 2000
local unpack = rawget(_G, "unpack") or table.unpack

local CRATE_ENTRY = 23162          -- Foror's Crate of Endless Resist Gear Storage (36 slots, any items)
local CRATE_COUNT = 4
local CRATE_TABLE = "familylan_starter_crates"

local INSIGNIA_ALLIANCE = 44098    -- Inherited Insignia of the Alliance
local INSIGNIA_HORDE    = 44097    -- Inherited Insignia of the Horde

-- Item IDs ---------------------------------------------------------------
local SH_PLATE_VALOR, SH_PLATE_STOCKADE, SH_PLATE_LIGHTFORGE =
  42949, 44099, 44100
local SH_MAIL_HEROD, SH_MAIL_BEASTMASTER, SH_MAIL_ELEMENTS, SH_MAIL_THUNDERS =
  42950, 44101, 42951, 44102
local SH_LEA_SHADOWCRAFT, SH_LEA_STORMSHROUD, SH_LEA_IRONFEATHER, SH_LEA_FERALHEART =
  42952, 44103, 42984, 44105
local SH_CLOTH_DREADMIST, SH_CLOTH_SUNDERSEER =
  42985, 44107
local CH_PLATE_VALOR, CH_MAIL_DEATHDEALER, CH_MAIL_ELEMENTS =
  48685, 48677, 48683
local CH_LEA_SHADOWCRAFT, CH_LEA_IRONFEATHER, CH_CLOTH_DREADMIST =
  48689, 48687, 48691
local W_2H_AXE_REAPER, W_2H_SWORD_TRUESILVER, W_2H_MACE_LAVA =
  42943, 44092, 48718
local W_1H_SWORD_DALREND, W_1H_SWORD_THRASH, W_1H_MACE_MCGOWAN =
  42945, 44096, 48716
local W_DAGGER_HEARTSEEKER, W_DAGGER_KRIS =
  42944, 44091
local W_MACE_AURASTONE, W_MACE_GRACE =
  42948, 44094
local W_STAFF_HEADMASTER, W_STAFF_JORDAN =
  42947, 44095
local W_BOW, W_GUN =
  42946, 44093
local T_SWIFT_HAND, T_DISCERNING_EYE =
  42991, 42992
local R_DREAD_PIRATE =
  50255

local KITS = {
  [1] = { -- Warrior
    SH_PLATE_VALOR, SH_PLATE_STOCKADE, CH_PLATE_VALOR,
    W_2H_AXE_REAPER, W_2H_SWORD_TRUESILVER, W_1H_SWORD_DALREND, W_1H_SWORD_THRASH, W_1H_MACE_MCGOWAN,
    T_SWIFT_HAND, T_SWIFT_HAND, R_DREAD_PIRATE },
  [2] = { -- Paladin
    SH_PLATE_VALOR, SH_PLATE_STOCKADE, SH_PLATE_LIGHTFORGE, CH_PLATE_VALOR,
    W_2H_AXE_REAPER, W_2H_SWORD_TRUESILVER, W_1H_SWORD_DALREND, W_1H_MACE_MCGOWAN,
    W_MACE_AURASTONE, W_MACE_GRACE,
    T_SWIFT_HAND, T_DISCERNING_EYE, R_DREAD_PIRATE },
  [3] = { -- Hunter
    SH_MAIL_HEROD, SH_MAIL_BEASTMASTER, CH_MAIL_DEATHDEALER,
    W_BOW, W_GUN, W_2H_AXE_REAPER,
    T_SWIFT_HAND, T_SWIFT_HAND, R_DREAD_PIRATE },
  [4] = { -- Rogue
    SH_LEA_SHADOWCRAFT, SH_LEA_STORMSHROUD, CH_LEA_SHADOWCRAFT,
    W_DAGGER_HEARTSEEKER, W_DAGGER_KRIS, W_1H_SWORD_DALREND, W_1H_SWORD_THRASH, W_1H_MACE_MCGOWAN,
    T_SWIFT_HAND, T_SWIFT_HAND, R_DREAD_PIRATE },
  [5] = { -- Priest
    SH_CLOTH_DREADMIST, SH_CLOTH_SUNDERSEER, CH_CLOTH_DREADMIST,
    W_STAFF_HEADMASTER, W_STAFF_JORDAN, W_MACE_AURASTONE, W_MACE_GRACE,
    T_DISCERNING_EYE, T_DISCERNING_EYE, R_DREAD_PIRATE },
  [6] = { -- Death Knight
    SH_PLATE_VALOR, SH_PLATE_STOCKADE, CH_PLATE_VALOR,
    W_2H_AXE_REAPER, W_2H_SWORD_TRUESILVER, W_2H_MACE_LAVA, W_1H_SWORD_DALREND, W_1H_SWORD_THRASH, W_1H_MACE_MCGOWAN,
    T_SWIFT_HAND, T_SWIFT_HAND, R_DREAD_PIRATE },
  [7] = { -- Shaman (enh + ele/resto)
    SH_MAIL_HEROD, SH_MAIL_BEASTMASTER, CH_MAIL_DEATHDEALER,
    SH_MAIL_ELEMENTS, SH_MAIL_THUNDERS, CH_MAIL_ELEMENTS,
    W_2H_AXE_REAPER, W_2H_MACE_LAVA, W_1H_MACE_MCGOWAN,
    W_STAFF_HEADMASTER, W_STAFF_JORDAN, W_MACE_AURASTONE, W_MACE_GRACE,
    T_SWIFT_HAND, T_DISCERNING_EYE, R_DREAD_PIRATE },
  [8] = { -- Mage
    SH_CLOTH_DREADMIST, SH_CLOTH_SUNDERSEER, CH_CLOTH_DREADMIST,
    W_STAFF_HEADMASTER, W_STAFF_JORDAN,
    T_DISCERNING_EYE, T_DISCERNING_EYE, R_DREAD_PIRATE },
  [9] = { -- Warlock
    SH_CLOTH_DREADMIST, SH_CLOTH_SUNDERSEER, CH_CLOTH_DREADMIST,
    W_STAFF_HEADMASTER, W_STAFF_JORDAN,
    T_DISCERNING_EYE, T_DISCERNING_EYE, R_DREAD_PIRATE },
  [11] = { -- Druid (feral + balance/resto)
    SH_LEA_SHADOWCRAFT, SH_LEA_STORMSHROUD, CH_LEA_SHADOWCRAFT,
    SH_LEA_IRONFEATHER, SH_LEA_FERALHEART, CH_LEA_IRONFEATHER,
    W_2H_MACE_LAVA, W_STAFF_HEADMASTER, W_STAFF_JORDAN, W_MACE_AURASTONE, W_MACE_GRACE,
    T_SWIFT_HAND, T_DISCERNING_EYE, R_DREAD_PIRATE },
}

-- ALE's AddItem/EquipItem return a stray number (not nil) on failure, so only a
-- real Item userdata counts as success.
local function IsItem(v) return type(v) == "userdata" end

-- Bot filter --------------------------------------------------------------
local function CallBool(player, method)
  local f = player[method]
  if type(f) ~= "function" then return false end
  local ok, r = pcall(f, player)
  return ok and r == true
end

local function IsBot(player)
  if CallBool(player, "IsPlayerbot") or CallBool(player, "IsRandomBot")
     or CallBool(player, "IsAddclassBot") then
    return true
  end
  local ok, acc = pcall(function() return player:GetAccountName() end)
  if ok and type(acc) == "string" then
    local u = string.upper(acc)
    if u:find("^RNDBOT") or u:find("PLAYERBOT") or u:find("^AHBOT") then return true end
  end
  return false
end

local function IsHorde(player)
  local ok, r = pcall(function() return player:IsHorde() end)
  if ok and type(r) == "boolean" then return r end
  local ok2, t = pcall(function() return player:GetTeam() end)
  return ok2 and t == 1
end

local function BuildKit(player)
  local base = KITS[player:GetClass()]
  if not base then return nil end
  local kit = {}
  for _, e in ipairs(base) do kit[#kit + 1] = e end
  kit[#kit + 1] = IsHorde(player) and INSIGNIA_HORDE or INSIGNIA_ALLIANCE
  return kit
end

-- Mail helper (max 12 attachments per mail) ------------------------------
local function MailItems(guidLow, subject, body, entries)
  local part, chunk = 1, {}
  for i, e in ipairs(entries) do
    chunk[#chunk + 1] = e; chunk[#chunk + 1] = 1
    if #chunk == 24 or i == #entries then
      local subj = (#entries > 12) and string.format("%s (%d)", subject, part) or subject
      SendMail(subj, body, guidLow, 0, MAIL_STATIONERY_GM, 0, 0, 0, unpack(chunk))
      part, chunk = part + 1, {}
    end
  end
end

local MAIL_BODY = table.concat({
  "Welcome to the family realm!",
  "",
  "Your bags were full, so these heirlooms came by mail.",
  "There is a mailbox (works for both factions) right near your starting area.",
}, "\n")

local pending = {}   -- guidLow -> true while the delayed grant hasn't run

-- Starter crates (one-time, persistent flag) ------------------------------
pcall(CharDBExecute, "CREATE TABLE IF NOT EXISTS " .. CRATE_TABLE .. " (" ..
  "guid INT UNSIGNED NOT NULL PRIMARY KEY, " ..
  "granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, " ..
  "equipped TINYINT UNSIGNED NOT NULL DEFAULT 0, " ..
  "in_bags TINYINT UNSIGNED NOT NULL DEFAULT 0, " ..
  "mailed TINYINT UNSIGNED NOT NULL DEFAULT 0)")

local function CratesAlreadyGranted(guid)
  local ok, q = pcall(CharDBQuery, "SELECT 1 FROM " .. CRATE_TABLE .. " WHERE guid = " .. guid)
  if not ok then return true end   -- can't verify -> fail safe (never double-grant)
  return q ~= nil
end

local function GrantCrates(player)
  local guid = player:GetGUIDLow()
  if CratesAlreadyGranted(guid) then
    print(string.format("[StarterCrates] %s (guid %d) already got crates - skipped", player:GetName(), guid))
    return
  end
  -- flag FIRST so a second event / relog can never grant again
  CharDBExecute(string.format("INSERT IGNORE INTO %s (guid) VALUES (%d)", CRATE_TABLE, guid))
  local equipped, inBags, mailed = 0, 0, 0
  for slot = 19, 22 do
    if equipped >= CRATE_COUNT then break end
    if not player:GetItemByPos(INVENTORY_SLOT_BAG_0, slot) then
      local ok, item = pcall(function() return player:EquipItem(CRATE_ENTRY, slot) end)
      if ok and IsItem(item) then equipped = equipped + 1 end
    end
  end
  local overflow = {}
  for _ = 1, CRATE_COUNT - equipped do
    local ok, item = pcall(function() return player:AddItem(CRATE_ENTRY, 1) end)
    if ok and IsItem(item) then inBags = inBags + 1 else overflow[#overflow + 1] = CRATE_ENTRY end
  end
  if #overflow > 0 then
    MailItems(guid, "Starter Crates", "Welcome to the family realm!\n\nYour bags were full, so your big crates came by mail.", overflow)
    mailed = #overflow
  end
  CharDBExecute(string.format("UPDATE %s SET equipped = %d, in_bags = %d, mailed = %d WHERE guid = %d",
    CRATE_TABLE, equipped, inBags, mailed, guid))
  pcall(function() player:SaveToDB() end)   -- persist crates + cleared first-login flag now
  print(string.format("[StarterCrates] %s (guid %d): %d equipped, %d in bags, %d mailed",
    player:GetName(), guid, equipped, inBags, mailed))
  pcall(function()
    local msg = (equipped == CRATE_COUNT) and "|cff4CFF00Four huge 36-slot crates|r are in your bag slots!"
      or "|cff4CFF00Four huge 36-slot crates|r are yours - check your bags!"
    if mailed > 0 then msg = msg .. " Some didn't fit - check the mailbox near your start area." end
    player:SendBroadcastMessage(msg)
  end)
end

local function GrantKit(player)
  local guid = player:GetGUIDLow()
  if not pending[guid] then return end
  pending[guid] = nil
  local kit = BuildKit(player)
  if not kit then return end
  local overflow, added = {}, 0
  for _, entry in ipairs(kit) do
    local ok, item = pcall(function() return player:AddItem(entry, 1) end)
    if ok and IsItem(item) then added = added + 1 else overflow[#overflow + 1] = entry end
  end
  if #overflow > 0 then
    MailItems(guid, "Starter Heirlooms (overflow)", MAIL_BODY, overflow)
  end
  print(string.format("[Heirlooms] %s (class %d, guid %d): %d in bags, %d mailed",
    player:GetName(), player:GetClass(), guid, added, #overflow))
  pcall(function()
    local msg = "|cff4CFF00Starter heirlooms|r for your class are in your bags!"
    if #overflow > 0 then msg = msg .. " Some didn't fit - check the mailbox near your start area." end
    player:SendBroadcastMessage(msg)
  end)
end

local function OnFirstLogin(event, player)
  if not player or IsBot(player) then return end
  local guid = player:GetGUIDLow()
  local okC, errC = pcall(GrantCrates, player)
  if not okC then print("[StarterCrates] grant FAILED: " .. tostring(errC)) end
  if not KITS[player:GetClass()] then
    print(string.format("[Heirlooms] no kit for class %d (%s)", player:GetClass(), player:GetName()))
    return
  end
  pending[guid] = true
  player:RegisterEvent(function(_, _, _, p)
    local ok, err = pcall(GrantKit, p)
    if not ok then print("[Heirlooms] grant FAILED: " .. tostring(err)) end
  end, GRANT_DELAY_MS, 1)
end

-- Logged out before the delayed grant ran: mail the whole kit instead.
local function OnLogout(event, player)
  local guid = player:GetGUIDLow()
  if not pending[guid] then return end
  pending[guid] = nil
  local kit = BuildKit(player)
  if kit then
    MailItems(guid, "Starter Heirlooms", MAIL_BODY, kit)
    print(string.format("[Heirlooms] %s logged out early - mailed %d heirlooms", player:GetName(), #kit))
  end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_FIRST_LOGIN, OnFirstLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, OnLogout)
print("[Heirlooms] first-login heirlooms-to-bags loaded (bots skipped, overflow mailed)")
print("[StarterCrates] first-login 4x Foror's Crate (23162) loaded (bots skipped, one-time flag, overflow mailed)")
