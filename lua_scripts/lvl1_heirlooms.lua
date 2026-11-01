--[[
  Family LAN - first-login STARTER KIT (mod-ale)
  REWORK 2026-10-30:
    OUT:  4x Foror's Crate + full per-class heirloom login dump (REMOVED)
    IN:   exactly ONE mid-tier bag (Netherweave 21841) equipped into bag slot 19,
          Flightmaster Whistle (70000), Hearthstone (6948, only if missing),
          15 gold (only if the char has less).
  Heirlooms now come from the SeasonPass Dream/Hero Paths (mod-seasonpass rewards) — earned,
  not dumped. Bots are skipped. One-time per character via the EXISTING
  familylan_starter_crates flag table (same table as the old crates grant, so characters that
  already fired first-login are unaffected and new ones can never double-claim).
  Undo: restore this file from .bak-20261030-starterkit.
]]

local PLAYER_EVENT_ON_FIRST_LOGIN = 30
local INVENTORY_SLOT_BAG_0 = 255
local BAG_ENTRY = 21841            -- Netherweave Bag (16 slots)
local WHISTLE_ENTRY = 70000        -- Flightmaster Whistle
local HEARTHSTONE_ENTRY = 6948
local STARTER_GOLD_COPPER = 150000 -- 15g
local GRANT_DELAY_MS = 2000
local unpack = rawget(_G, "unpack") or table.unpack

local FLAG_TABLE = "familylan_starter_crates"
local KIT_SUBJECT = "Starter Kit"
local MAIL_STATIONERY_GM = 61

local function IsItem(v) return type(v) == "userdata" end

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
    if u:find("^RNDBOT") or u:find("^RAIDBOT") or u:find("PLAYERBOT") or u:find("^AHBOT") then return true end
  end
  return false
end

pcall(CharDBExecute, "CREATE TABLE IF NOT EXISTS " .. FLAG_TABLE .. " (" ..
  "guid INT UNSIGNED NOT NULL PRIMARY KEY, " ..
  "granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, " ..
  "equipped TINYINT UNSIGNED NOT NULL DEFAULT 0, " ..
  "in_bags TINYINT UNSIGNED NOT NULL DEFAULT 0, " ..
  "mailed TINYINT UNSIGNED NOT NULL DEFAULT 0)")

local function AlreadyGranted(guid)
  local ok, q = pcall(CharDBQuery, "SELECT 1 FROM " .. FLAG_TABLE .. " WHERE guid = " .. guid)
  if not ok then return true end   -- can't verify -> fail safe (never double-grant)
  return q ~= nil
end

local function HasItem(player, entry)
  local ok, count = pcall(function() return player:GetItemCount(entry) end)
  return ok and type(count) == "number" and count > 0
end

local function GrantKit(player)
  local guid = player:GetGUIDLow()
  if AlreadyGranted(guid) then
    print(string.format("[StarterKit] %s (guid %d) already got starter kit - skipped", player:GetName(), guid))
    return
  end
  -- flag FIRST so a second event / relog can never grant again
  CharDBExecute(string.format("INSERT IGNORE INTO %s (guid) VALUES (%d)", FLAG_TABLE, guid))

  local equipped, inBags, mailed = 0, 0, 0
  local overflow = {}

  -- 1) exactly ONE bag, pre-equipped into the first empty bag slot
  for slot = 19, 22 do
    if equipped == 0 and not player:GetItemByPos(INVENTORY_SLOT_BAG_0, slot) then
      local ok, item = pcall(function() return player:EquipItem(BAG_ENTRY, slot) end)
      if ok and IsItem(item) then equipped = 1 end
    end
  end
  if equipped == 0 then
    local ok, item = pcall(function() return player:AddItem(BAG_ENTRY, 1) end)
    if ok and IsItem(item) then inBags = 1 else overflow[#overflow + 1] = BAG_ENTRY end
  end

  -- 2) Flightmaster Whistle
  if not HasItem(player, WHISTLE_ENTRY) then
    local ok, item = pcall(function() return player:AddItem(WHISTLE_ENTRY, 1) end)
    if ok and IsItem(item) then inBags = inBags + 1 else overflow[#overflow + 1] = WHISTLE_ENTRY end
  end

  -- 3) Hearthstone (only if missing)
  if not HasItem(player, HEARTHSTONE_ENTRY) then
    local ok, item = pcall(function() return player:AddItem(HEARTHSTONE_ENTRY, 1) end)
    if ok and IsItem(item) then inBags = inBags + 1 else overflow[#overflow + 1] = HEARTHSTONE_ENTRY end
  end

  -- 4) 15 gold (only if the char has less)
  local okMoney, money = pcall(function() return player:GetMoney() end)
  if okMoney and type(money) == "number" and money < STARTER_GOLD_COPPER then
    pcall(function() player:ModifyMoney(STARTER_GOLD_COPPER - money) end)
  end

  if #overflow > 0 then
    local chunk = {}
    for _, e in ipairs(overflow) do
      chunk[#chunk + 1] = e; chunk[#chunk + 1] = 1
    end
    SendMail(KIT_SUBJECT, "Welcome to the family realm!\n\nYour bags were full, so your starter items came by mail.",
      guid, 0, MAIL_STATIONERY_GM, 0, 0, 0, unpack(chunk))
    mailed = #overflow
  end

  CharDBExecute(string.format("UPDATE %s SET equipped = %d, in_bags = %d, mailed = %d WHERE guid = %d",
    FLAG_TABLE, equipped, inBags, mailed, guid))
  pcall(function() player:SaveToDB() end)
  print(string.format("[StarterKit] %s (guid %d): %d bag equipped, %d items in bags, %d mailed, 15g",
    player:GetName(), guid, equipped, inBags, mailed))
  pcall(function()
    player:SendBroadcastMessage("|cff4CFF00Starter kit:|r a 16-slot bag, your Flightmaster Whistle, Hearthstone and 15 gold. Earn heirlooms and more on the Season Pass!")
  end)
end

local function OnFirstLogin(event, player)
  if not player or IsBot(player) then return end
  player:RegisterEvent(function(_, _, _, p)
    local ok, err = pcall(GrantKit, p)
    if not ok then print("[StarterKit] grant FAILED: " .. tostring(err)) end
  end, GRANT_DELAY_MS, 1)
end

RegisterPlayerEvent(PLAYER_EVENT_ON_FIRST_LOGIN, OnFirstLogin)
print("[StarterKit] first-login starter kit loaded (1 bag + whistle + HS + 15g, bots skipped, one-time flag)")
