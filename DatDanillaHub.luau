--[[
    datdanillashrek
    Pet Simulator 99 auto progression / rank driver
    Works on Real and Delta (no executor-specific features beyond HttpGet/writefile)
]]

if getgenv and getgenv().DATDANILLA_UNLOAD then
    local oldUnload = getgenv().DATDANILLA_UNLOAD
    task.spawn(function()
        pcall(oldUnload)
    end)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local GEN = (getgenv().DATDANILLA_GEN or 0) + 1
getgenv().DATDANILLA_GEN = GEN

-- kept so the script can queue itself before hopping worlds
local LOADER_KEY = ""

local function alive()
    return getgenv().DATDANILLA_GEN == GEN
end

local CONFIG = {
    NAME = "DatDanillaHub",
    BACKGROUND_IMAGE = "rbxassetid://7178713394",
    ICON_IMAGE = "rbxassetid://6837356597",
    VERSION = "1.0.0",
    KEY_URL = "https://raw.githubusercontent.com/DatDanilla/DatDanillaHub/main/keys.txt",
    KEY_SALT = "DatDanillaHub|v1|2026",
    -- true: keys.txt holds sha256(KEY_SALT..key) hashes, not readable keys
    HASH_KEYS = true,
    DEFAULT_KEYS = {},
    MAX_ZONE = 98,
    -- datdanillarank finishes at rank 8, datdanillarankprovip at rank 20
    RANK_TARGET = 8,
    -- datdanillarankprovip farms to the last area of world 4 instead
    PRO_VIP_MAX_ZONE = 279,
    PRO_VIP_RANK = 20,
    SCRIPT_URL = "https://raw.githubusercontent.com/DatDanilla/DatDanillaHub/main/DatDanillaHub.luau",
    FORBIDDEN_ZONES = { ["Rainbow Road"] = true, ["VIP"] = true },
    TAPS_PER_SECOND = 8,
    FARM_RADIUS = 140,
    ORB_SWEEP_EVERY = 7,
    ORB_BATCH = 30,
    ORB_RADIUS = 220,
    TNT_EVERY = 5,
    STUCK_TNT_AFTER = 180,
}

local function log(...)
    print("[" .. CONFIG.NAME .. "]", ...)
end

-- SHA-256 so keys.txt can hold hashes instead of readable keys
local function sha256(message)
    local band, bor, bxor, bnot, rshift, lshift, ror =
        bit32.band, bit32.bor, bit32.bxor, bit32.bnot, bit32.rshift, bit32.lshift, bit32.rrotate
    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }
    local H = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    local bytes = {}
    for i = 1, #message do
        bytes[i] = string.byte(message, i)
    end
    local bitlen = #bytes * 8
    table.insert(bytes, 0x80)
    while (#bytes % 64) ~= 56 do
        table.insert(bytes, 0)
    end
    local hi = math.floor(bitlen / 4294967296)
    local lo = bitlen % 4294967296
    for i = 3, 0, -1 do
        table.insert(bytes, band(rshift(hi, i * 8), 0xff))
    end
    for i = 3, 0, -1 do
        table.insert(bytes, band(rshift(lo, i * 8), 0xff))
    end
    for chunk = 1, #bytes, 64 do
        local w = {}
        for i = 0, 15 do
            local a, b, c, d = bytes[chunk + i * 4], bytes[chunk + i * 4 + 1], bytes[chunk + i * 4 + 2], bytes[chunk + i * 4 + 3]
            w[i] = bor(lshift(a, 24), lshift(b, 16), lshift(c, 8), d)
        end
        for i = 16, 63 do
            local s0 = bxor(bxor(ror(w[i - 15], 7), ror(w[i - 15], 18)), rshift(w[i - 15], 3))
            local s1 = bxor(bxor(ror(w[i - 2], 17), ror(w[i - 2], 19)), rshift(w[i - 2], 10))
            w[i] = band(w[i - 16] + s0 + w[i - 7] + s1, 0xffffffff)
        end
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        for i = 0, 63 do
            local S1 = bxor(bxor(ror(e, 6), ror(e, 11)), ror(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local t1 = band(h + S1 + ch + K[i + 1] + w[i], 0xffffffff)
            local S0 = bxor(bxor(ror(a, 2), ror(a, 13)), ror(a, 22))
            local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
            local t2 = band(S0 + maj, 0xffffffff)
            h = g
            g = f
            f = e
            e = band(d + t1, 0xffffffff)
            d = c
            c = b
            b = a
            a = band(t1 + t2, 0xffffffff)
        end
        H[1] = band(H[1] + a, 0xffffffff)
        H[2] = band(H[2] + b, 0xffffffff)
        H[3] = band(H[3] + c, 0xffffffff)
        H[4] = band(H[4] + d, 0xffffffff)
        H[5] = band(H[5] + e, 0xffffffff)
        H[6] = band(H[6] + f, 0xffffffff)
        H[7] = band(H[7] + g, 0xffffffff)
        H[8] = band(H[8] + h, 0xffffffff)
    end
    local out = {}
    for i = 1, 8 do
        out[i] = string.format("%08x", H[i])
    end
    return table.concat(out)
end

local function hashKey(key)
    return sha256(CONFIG.KEY_SALT .. string.lower(key))
end

-- dynamic key list (filled by key gate)
local ACTIVE_KEYS = {}

local function fetchKeys()
    local list = {}
    -- HttpGet can hang forever on a dead host; give it 10s and move on
    local body = nil
    local finished = false
    task.spawn(function()
        local ok, res = pcall(function()
            return game:HttpGet(CONFIG.KEY_URL .. "?t=" .. tostring(os.time()))
        end)
        if ok and type(res) == "string" then
            body = res
        end
        finished = true
    end)
    local started = os.clock()
    while not finished and os.clock() - started < 10 do
        task.wait(0.1)
    end
    if body and #body > 0 then
        for line in string.gmatch(body, "[^\r\n]+") do
            line = string.match(line, "^%s*(.-)%s*$") or ""
            -- keys are simple words; this also drops 404 pages/HTML bodies
            if
                #line >= 3
                and #line <= 64
                and string.sub(line, 1, 1) ~= "#"
                and string.match(line, "^[%w_%-%.]+$")
            then
                list[#list + 1] = string.lower(line)
            end
        end
    end
    for _, k in ipairs(CONFIG.DEFAULT_KEYS) do
        list[#list + 1] = string.lower(k)
    end
    return list
end

local function isKeyValid(key)
    key = string.lower(string.match(tostring(key or ""), "^%s*(.-)%s*$") or "")
    if #key == 0 then
        return false
    end
    local wanted = CONFIG.HASH_KEYS and hashKey(key) or key
    for _, k in ipairs(ACTIVE_KEYS) do
        if k == wanted then
            return true
        end
    end
    return false
end

local function readSavedKey()
    if not (writefile and readfile and isfile) then
        return nil
    end
    local path = "datdanillashrek_key.txt"
    if isfile(path) then
        local ok, data = pcall(readfile, path)
        if ok then
            return data
        end
    end
    return nil
end

local function saveKey(key)
    if writefile then
        pcall(writefile, "datdanillashrek_key.txt", key)
    end
end

---------------------------------------------------------------------
-- Game bindings
---------------------------------------------------------------------

local Library = ReplicatedStorage:WaitForChild("Library", 30)
if not Library then
    return log("Pet Simulator 99 not detected (Library missing).")
end

-- Right after a rejoin the Library's children can still be streaming, so every
-- module is fetched with a wait instead of a raw index.
local function req(parent, name)
    local child = parent:FindFirstChild(name) or parent:WaitForChild(name, 30)
    if not child then
        error("DatDanillaHub: missing " .. tostring(name), 0)
    end
    return require(child)
end

local C = Library:FindFirstChild("Client") or Library:WaitForChild("Client", 30)
if not C then
    return log("Pet Simulator 99 not detected (Client missing).")
end
local Directory = req(Library, "Directory")
local Util = Library:FindFirstChild("Util") or Library:WaitForChild("Util", 30)
if not Util then
    return log("Pet Simulator 99 not detected (Util missing).")
end
local ZonesUtil = req(Util, "ZonesUtil")

local Save = req(C, "Save")
local Network = req(C, "Network")
local MapCmds = req(C, "MapCmds")
local ZoneCmds = req(C, "ZoneCmds")
local EggCmds = req(C, "EggCmds")
local PetEquipCmds = req(C, "PetEquipCmds")
local EnchantCmds = req(C, "EnchantCmds")
local PotionCmds = req(C, "PotionCmds")
local FruitCmds = req(C, "FruitCmds")
local BuffCmds = req(C, "BuffCmds")
local ConsumableCmds = req(C, "ConsumableCmds")
local UltimateCmds = req(C, "UltimateCmds")
local RebirthCmds = req(C, "RebirthCmds")
local SettingsCmds = req(C, "SettingsCmds")
local MachineCmds = req(C, "MachineCmds")
local TeleportCmds = req(C, "TeleportMapCmds")
local FlexibleFlagCmds = req(C, "FlexibleFlagCmds")
local RandomEventCmds = req(C, "RandomEventCmds")
local LootboxCmds = req(C, "LootboxCmds")
local PresentCmds = req(C, "PresentCmds")
local ForeverPackCmds = req(C, "ForeverPackCmds")
local RankCmds = req(C, "RankCmds")
local CurrencyCmds = req(C, "CurrencyCmds")
local UpgradeCmds = req(C, "UpgradeCmds")
local BreakableCmds = req(C, "BreakableCmds")
local InventoryCmds = req(C, "InventoryCmds")

-- Boss chest ids are read once: the directory loader throws on unknown ids, so
-- looking them up per breakable spams the console
local BOSS_CHESTS = {}
pcall(function()
    for id, chest in pairs(Directory.Chests or {}) do
        if chest and chest.IsBoss == true then
            BOSS_CHESTS[id] = true
        end
    end
end)

local Types = Library:FindFirstChild("Types") or Library:WaitForChild("Types", 30)
if not Types then
    return log("Pet Simulator 99 not detected (Types missing).")
end
local Quests = req(Types, "Quests")
local GOAL = Quests.Goals

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

local State = {
    on = false,
    phase = 1,
    -- datdanillarankprovip: farm to the end of world 4, then push rank 20
    -- 98 until rank 8 is done, then the run continues to the end of world 4
    zoneLimit = 98,
    rankTarget = 8,
    lastWorldHop = 0,
    status = "Idle",
    quest = "",
    zone = nil,
    busy = false,
    farmList = {},
    farmZone = nil,
    farmIndex = 1,
    taps = 0,
    lastTapAt = 0,
    lastTnt = 0,
    lastOrb = 0,
    lastClaim = 0,
    lastSlot = 0,
    lastEggSlot = 0,
    lastGift = 0,
    lastSpeed = 0,
    lastAnim = 0,
    lastFarmFix = 0,
    lastDiamondFlag = 0,
    lastUpgrade = 0,
    upgradeCursor = 1,
    -- true while upgrade trips are still finding tiers to buy; shortens the
    -- gap between trips until the cheap ones are gone
    upgFast = true,
    lastEnchant = 0,
    lastEnchantCheck = 0,
    actionBusy = false,
    actionStarted = 0,
    actionRank = nil,
    actionSafeForOrbs = false,
    preempt = false,
    manual = false,
    stairwayBusy = false,
    tapRate = CONFIG.TAPS_PER_SECOND,
    orbsEnabled = true,
    activeKey = nil,
    activeProgress = nil,
    activeSince = 0,
    lastBuff = 0,
    lastPotion = 0,
    lastFruit = 0,
    lastUlt = 0,
    lastBuy = 0,
    lastRebirth = 0,
    lastScan = 0,    lastProgress = os.clock(),
    lastHatchZone = nil,
    lastHatchCount = 0,
    hatchZone = nil,
    hatchDone = 0,
    -- egg plan is tracked per area so switching areas never re-buys a bundle
    hatchByZone = {},
    lastHatchAttempt = 0,
    startedAt = os.clock(),
    goalFails = {},
    flagBlocked = {},
    upgSkip = {},
}

local UI = {
    ready = false,
    window = nil,
    toggle = nil,
    status = nil,
    quest = nil,
    phase = nil,
}

local pendingUI = { status = nil, quest = nil, phase = nil }

local function applyStatus(text)
    if not (UI.ready and UI.status) then
        pendingUI.status = text
        return
    end
    local ok = pcall(function() UI.status:SetDesc(text) end)
    if not ok then
        pendingUI.status = text
    end
end

local function applyQuest(text)
    if not (UI.ready and UI.quest) then
        pendingUI.quest = text
        return
    end
    local ok = pcall(function() UI.quest:SetDesc(text) end)
    if not ok then
        pendingUI.quest = text
    end
end

local function applyPhase(text)
    if not (UI.ready and UI.phase) then
        pendingUI.phase = text
        return
    end
    local ok = pcall(function() UI.phase:SetDesc(text) end)
    if not ok then
        pendingUI.phase = text
    end
end

local function setStatus(text)
    State.status = text
    applyStatus(text)
end

local function setQuest(text)
    State.quest = text
    applyQuest(text)
end

local function setPhase(text)
    applyPhase(text)
end

local function flushUI()
    if pendingUI.status then
        local text = pendingUI.status
        pendingUI.status = nil
        if UI.ready and UI.status then
            pcall(function() UI.status:SetDesc(text) end)
        end
    end
    if pendingUI.quest then
        local text = pendingUI.quest
        pendingUI.quest = nil
        if UI.ready and UI.quest then
            pcall(function() UI.quest:SetDesc(text) end)
        end
    end
    if pendingUI.phase then
        local text = pendingUI.phase
        pendingUI.phase = nil
        if UI.ready and UI.phase then
            pcall(function() UI.phase:SetDesc(text) end)
        end
    end
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function getSave()
    local ok, s = pcall(Save.Get)
    if ok then
        return s
    end
    return nil
end

-- each world pays in its own currency (Coins / TechCoins / VoidCoins /
-- FantasyCoins), so affordability checks follow the current world
local function money(kind)
    if not kind then
        local ok, zone = pcall(MapCmds.GetCurrentZone)
        local w = 1
        if ok and type(zone) == "string" and Directory.Zones[zone] then
            w = Directory.Zones[zone].WorldNumber or 1
        end
        local entry = Directory.Worlds and Directory.Worlds["World " .. tostring(w)]
        kind = (entry and entry.WorldCurrency) or "Coins"
    end
    local ok, v = pcall(CurrencyCmds.Get, kind)
    if ok and type(v) == "number" then
        return v
    end
    return 0
end

local function char()
    return LocalPlayer.Character
end

local function hrp()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function teleport(cf, anchor)
    local h = hrp()
    if not h or not cf then
        return false
    end
    for _, d in ipairs(h:GetDescendants()) do
        if d:IsA("AlignPosition") or d:IsA("AlignOrientation") then
            d.Enabled = false
        end
    end
    if anchor == false then
        h.AssemblyLinearVelocity = Vector3.zero
        h.CFrame = cf
        return true
    end
    h.Anchored = true
    h.CFrame = cf
    task.spawn(function()
        task.wait(0.75)
        if h.Parent then
            pcall(function()
                h.Anchored = false
            end)
        end
    end)
    return true
end

local function zoneNumber(name)
    local z = name and Directory.Zones[name]
    return z and z.ZoneNumber or nil
end

-- one table instead of five locals: the chunk is already close to Luau's
-- register limit
local WorldUtil = {}

function WorldUtil.of(name)
    local z = name and Directory.Zones[name]
    return z and z.WorldNumber or nil
end

function WorldUtil.placeId(worldNumber)
    local w = Directory.Worlds and Directory.Worlds["World " .. tostring(worldNumber)]
    return w and w.PlaceId or nil
end

-- last zone of a world, e.g. world 4 ends at Hollow Veil Castle
function WorldUtil.lastZone(worldNumber)
    local best, bestNum = nil, -1
    for name, z in pairs(Directory.Zones or {}) do
        if (z.WorldNumber or 1) == worldNumber and (z.ZoneNumber or 0) > bestNum then
            best, bestNum = name, z.ZoneNumber or 0
        end
    end
    return best
end

local function forbiddenZone(name)
    if not name then
        return true
    end
    if CONFIG.FORBIDDEN_ZONES[name] then
        -- Rainbow Road is the gateway into world 2 and opens after rank 8
        if not (name == "Rainbow Road" and (State.zoneLimit or 0) > CONFIG.MAX_ZONE) then
            return true
        end
    end
    local n = zoneNumber(name)
    if n == nil then
        return false
    end
    -- 98 until rank 8, then 279 so the run reaches the end of world 4
    return n > (State.zoneLimit or CONFIG.MAX_ZONE)
end

local function bestZone()
    local ok, name = pcall(ZoneCmds.GetMaxOwnedZone)
    if ok and type(name) == "string" and not forbiddenZone(name) then
        return name
    end
    return "Spawn"
end

-- Next area to buy, skipping the blacklisted ones (Rainbow Road / VIP). In
-- pro vip mode this carries the run past zone 98 into the next worlds instead
-- of stalling on Rainbow Road forever.
local function nextBuyableZone()
    local ok, base = pcall(ZoneCmds.GetMaxOwnedZone)
    local cur = 0
    if ok and type(base) == "string" then
        cur = zoneNumber(base) or 0
    end
    local save = getSave()
    local owned = (save and save.UnlockedZones) or {}
    local best, bestNum = nil, math.huge
    for name, z in pairs(Directory.Zones or {}) do
        local n = z.ZoneNumber or 0
        if n > cur and not owned[name] and not forbiddenZone(name) and n < bestNum then
            best, bestNum = name, n
        end
    end
    return best
end

local function nextZone()
    local ok, name = pcall(ZoneCmds.GetNextZone)
    if ok and type(name) == "string" then
        return name
    end
    return nil
end

local function currentZone()
    local ok, z = pcall(MapCmds.GetCurrentZone)
    if ok then
        return z
    end
    return nil
end

local function ownsZone(name)
    local ok, v = pcall(ZoneCmds.Owns, name)
    return ok and v == true
end

-- A zone can hold several break zones: one normal farm area plus boss chest
-- arenas, which look identical apart from the loot inside. The normal one is
-- picked by counting ordinary breakables around each candidate, so the
-- character can never be sent to a boss chest.
local breakZoneCache = {}

-- a chest that is much bigger than a mini-chest is a boss chest even when the
-- directory has not loaded its entry yet
local function bossSizedChest(m, id)
    if not string.find(string.lower(id), "chest", 1, true) then
        return false
    end
    local ok, size = pcall(function()
        return m:GetExtentsSize()
    end)
    return ok and size ~= nil and (size.X > 16 or size.Z > 16)
end

local function isBossBreakable(m)
    local id = tostring(m:GetAttribute("BreakableID"))
    local cls = string.lower(tostring(m:GetAttribute("BreakableClass")))
    -- boss chests are named after their map (SandcastleChest, HellChest, ...),
    -- so the directory flag is the only reliable marker
    return m:GetAttribute("isBossChest") == true
        or BOSS_CHESTS[id] == true
        or string.find(string.lower(id), "boss", 1, true) ~= nil
        or string.find(cls, "boss", 1, true) ~= nil
        or bossSizedChest(m, id)
end

local function countNormalBreakables(zone, pos)
    local n = 0
    for _, folder in ipairs({ workspace.__THINGS.Breakables, workspace.__THINGS.AnimatedBreakables }) do
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m:GetAttribute("ParentID") == zone and not isBossBreakable(m) then
                local id = string.lower(tostring(m:GetAttribute("BreakableID")))
                if not string.find(id, "vip", 1, true) then
                    local ok, p = pcall(function()
                        return m:GetPivot().Position
                    end)
                    if ok and (p - pos).Magnitude <= 140 then
                        n = n + 1
                    end
                end
            end
        end
    end
    return n
end

local function breakZonePart(name)
    local cached = breakZoneCache[name]
    if cached and os.clock() - cached.at < 45 then
        if cached.part and cached.part.Parent then
            return cached.part
        end
    end
    local ok, model = pcall(ZonesUtil.GetBreakableZones, name)
    if not ok or not model then
        return nil
    end
    local candidates = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "BREAK_ZONE" then
            candidates[#candidates + 1] = d
        end
    end
    if #candidates == 0 then
        return nil
    end

    local pick, bestScore = nil, -math.huge
    for _, d in ipairs(candidates) do
        local score
        if d:GetAttribute("isBossChest") == true then
            score = -1000
        elseif #candidates == 1 then
            score = 0
        else
            score = countNormalBreakables(name, d.Position)
        end
        if score > bestScore then
            pick, bestScore = d, score
        end
    end
    breakZoneCache[name] = { part = pick, at = os.clock() }
    return pick
end

local function bossChestPos(name)
    local ok, model = pcall(ZonesUtil.GetBreakableZones, name)
    if not ok or not model then
        return nil
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "BREAK_ZONE" and d:GetAttribute("isBossChest") == true then
            return d.Position
        end
    end
    return nil
end

local function tpToZone(name)
    local part = breakZonePart(name)
    local target = nil
    if part then
        target = CFrame.new(part.Position + Vector3.new(0, 4, 0))
    else
        local ok, cf = pcall(ZonesUtil.GetTeleportPartLocation, name)
        if ok and cf then
            target = cf + Vector3.new(0, 4, 0)
        end
    end

    -- short hops are cheap and instant; only long distances need the game's
    -- own zone teleport (streaming and position checks)
    local h = hrp()
    if target and h and (h.Position - target.Position).Magnitude < 600 then
        teleport(target)
        task.wait(1)
        return true
    end

    local sent = pcall(function()
        return TeleportCmds.TeleportZones(name)
    end)
    if sent then
        task.wait(2.5)
        if hrp() then
            return true
        end
    end
    if not target then
        return false
    end
    teleport(target)
    task.wait(1)
    return true
end

-- Worlds are separate places, so moving up a world is a real teleport. The
-- script queues itself first so it keeps running after the hop when the
-- executor supports it.
function WorldUtil.travel(worldNumber)
    local line = string.format(
        'script_key = "%s"; loadstring(game:HttpGet("%s?t=%d"))()',
        LOADER_KEY,
        CONFIG.SCRIPT_URL,
        os.time()
    )
    pcall(function()
        if queue_on_teleport then
            queue_on_teleport(line)
        elseif syn and syn.queue_on_teleport then
            syn.queue_on_teleport(line)
        end
    end)
    setStatus("Travelling to World " .. tostring(worldNumber))

    -- the game's own portal remote lands on the ground at the new world spawn,
    -- which is where the world chest sits
    local viaRemote = pcall(function()
        return Network.Invoke("World" .. tostring(worldNumber) .. "Teleport")
    end)

    -- module fallback (also the unlock gate)
    local ok, can = pcall(function()
        return TeleportCmds.CanTeleportToWorld(worldNumber)
    end)
    if ok and can then
        local sent = pcall(function()
            TeleportCmds.TeleportWorlds(worldNumber)
        end)
        if sent then
            return true
        end
    end
    if viaRemote then
        return true
    end

    -- fallback: go straight to the world's place
    local placeId = WorldUtil.placeId(worldNumber)
    if not placeId then
        return false
    end
    return pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
end

function WorldUtil.hopNeeded()
    local hereW = WorldUtil.of(currentZone()) or 1
    -- a fully unlocked account already owns areas in a later world, so go
    -- where the best area actually is
    local best = bestZone()
    local bestW = best and WorldUtil.of(best) or nil
    if bestW and bestW > hereW then
        return bestW
    end
    local nxt = nextBuyableZone()
    if not nxt then
        return nil
    end
    local there = WorldUtil.of(nxt)
    if there and there > hereW then
        return there
    end
    return nil
end

-- Worlds 2-4 have a supercomputer at spawn that runs every machine remotely, so
-- the character never has to walk to Gold/Rainbow/enchant/fruit/potion machines
-- there. World 1 has no computer and still needs the walk.
function WorldUtil.directMachines()
    local w = WorldUtil.of(currentZone())
    return w ~= nil and w >= 2
end

local MACHINE_ZONES = {
    GoldMachine = "Desert Pyramids",
    RainbowMachine = "Hot Springs",
    UpgradePotionsMachine = "Dark Forest",
    UpgradeEnchantsMachine = "Crimson Forest",
    EggSlotsMachine = "Backyard",
    EquipSlotsMachine = "Green Forest",
    FuseMachine = "Shanty Town",
    HugeMachine = "Castle",
    RebirthShrine = "Fire Dojo",
    MagicMachine = "Haunted Mansion",
}

-- Map folders are named like "79 | Dungeon"; returns "Dungeon"
local function zoneOfModel(model)
    local node = model
    for _ = 1, 6 do
        if not node then
            return nil
        end
        local name = node.Name
        local bar = string.find(name, " | ", 1, true)
        if bar then
            return string.sub(name, bar + 3)
        end
        node = node.Parent
    end
    return nil
end

local function machinePosition(name)
    local list = MachineCmds.GetAll(name)
    local m = list and list[1]
    if m then
        local part = m.InteractPart
        if part and part:IsA("BasePart") then
            return part.Position
        end
        if m.Pad and m.Pad.pad then
            local ok, p = pcall(function()
                return m.Pad.pad:GetPivot().Position
            end)
            if ok and p then
                return p
            end
        end
        if m.Model and m.Model.PrimaryPart then
            return m.Model.PrimaryPart.Position
        end
    end
    for _, inst in ipairs(workspace.Map:GetDescendants()) do
        if inst:IsA("Model") and inst.Name == name and inst.PrimaryPart then
            return inst.PrimaryPart.Position
        end
    end
    return nil
end

local function tpToMachine(name)
    local pos = machinePosition(name)
    if not pos then
        local zone = MACHINE_ZONES[name]
        -- never travel to a zone the player has not unlocked, and never hop
        -- back to a world-1 zone while standing in another world
        if zone and ownsZone(zone) and (WorldUtil.of(zone) or 1) == (WorldUtil.of(currentZone()) or 1) then
            tpToZone(zone)
            task.wait(2)
            pos = machinePosition(name)
        end
    end
    if not pos then
        return false
    end
    -- the machine may be replicated from the next (locked) zone
    local list = MachineCmds.GetAll(name)
    local m = list and list[1]
    local mzone = m and m.Model and zoneOfModel(m.Model)
    if mzone and not ownsZone(mzone) then
        return false
    end
    teleport(CFrame.new(pos + Vector3.new(0, 6, 0)))
    task.wait(1)
    return true
end

-- keeps the character inside the zone's dotted break box. Drifting to the
-- border between two zones breaks TNT, flags and most breakable spawns.
local function ensureFarmSpot(zone)
    if not zone then
        return false
    end
    local now = os.clock()
    if now - (State.lastFarmFix or 0) < 5 then
        return false
    end
    local h = hrp()
    if not h then
        return false
    end
    local part = breakZonePart(zone)
    if not part then
        return false
    end
    local dist = (h.Position - part.Position).Magnitude
    local dotted = false
    pcall(function()
        dotted = MapCmds.IsInDottedBox()
    end)
    State.dotFix = State.dotFix or {}
    -- teleporting is only worth it when the box is far away. Checking the
    -- dotted flag every few seconds and hopping on it is what made the
    -- character bounce in place without ever farming.
    if dist > 25 then
        State.lastFarmFix = now
        teleport(CFrame.new(part.Position + Vector3.new(0, 6, 0)))
        task.wait(1)
        return true
    end
    if not dotted and dist > 8 and not State.dotFix[zone] then
        State.lastFarmFix = now
        teleport(CFrame.new(part.Position + Vector3.new(0, 6, 0)))
        task.wait(1)
        local again = false
        pcall(function()
            again = MapCmds.IsInDottedBox()
        end)
        -- some zones never report the box; stop retrying them
        if not again then
            State.dotFix[zone] = true
        end
        return true
    end
    return false
end

local function distanceTo(pos)
    local h = hrp()
    if not h then
        return math.huge
    end
    return (h.Position - pos).Magnitude
end

---------------------------------------------------------------------
-- Breakables
---------------------------------------------------------------------

local function scanBreakables(zone)
    local list = {}
    if not zone then
        return list
    end
    local boss = bossChestPos(zone)
    for _, folder in ipairs({ workspace.__THINGS.Breakables, workspace.__THINGS.AnimatedBreakables }) do
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m:GetAttribute("ParentID") == zone then
                local uid = m:GetAttribute("BreakableUID")
                local cls = tostring(m:GetAttribute("BreakableClass"))
                local bid = tostring(m:GetAttribute("BreakableID"))
                local ok, pos = pcall(function()
                    return m:GetPivot().Position
                end)
                pos = ok and pos or Vector3.zero
                -- boss chests are never farmed, and neither is anything that
                -- spawns inside their arena
                local bossish = isBossBreakable(m)
                    or string.find(string.lower(bid), "vip", 1, true) ~= nil
                    or (boss ~= nil and (pos - boss).Magnitude < 140)
                if uid and not bossish then
                    list[#list + 1] = {
                        model = m,
                        uid = uid,
                        class = cls,
                        id = bid,
                        pos = pos,
                    }
                end
            end
        end
    end
    return list
end

local function refreshFarm(force)
    local zone = currentZone()
    local now = os.clock()
    if force or zone ~= State.farmZone or now - State.lastScan > 2.5 then
        State.lastScan = now
        State.farmZone = zone
        State.farmList = scanBreakables(zone)
        State.farmIndex = 1
    end
end

local function nearestBreakables(n)
    local h = hrp()
    if not h then
        return {}
    end
    local p = h.Position
    local scored = {}
    for _, b in ipairs(State.farmList) do
        local d = (b.pos - p).Magnitude
        if d <= CONFIG.FARM_RADIUS then
            -- special breakables (crates, presents, chests) are worth more, so
            -- they are taken first, closest of that kind first
            local special = (b.class ~= "Normal" and b.class ~= "") and 0 or 1
            scored[#scored + 1] = { b = b, d = d, special = special }
        end
    end
    if #scored == 0 then
        for _, b in ipairs(State.farmList) do
            scored[#scored + 1] = { b = b, d = (b.pos - p).Magnitude, special = 1 }
        end
    end
    table.sort(scored, function(a, b)
        if a.special ~= b.special then
            return a.special < b.special
        end
        return a.d < b.d
    end)
    local out = {}
    for i = 1, math.min(n, #scored) do
        out[i] = scored[i].b
    end
    return out
end

local function tapUid(uid)
    if uid then
        State.taps = (State.taps or 0) + 1
        State.lastTapAt = os.clock()
        Network.UnreliableFire("Breakables_PlayerDealDamage", uid)
    end
end

---------------------------------------------------------------------
-- Orbs
---------------------------------------------------------------------

local function activeOrbs()
    local out = {}
    local folder = workspace.__THINGS:FindFirstChild("Orbs")
    if not folder then
        return out
    end
    local h = hrp()
    if not h then
        return out
    end
    local p = h.Position
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part.Position.Y > -3000 then
            local d = (part.Position - p).Magnitude
            if d < 70 then
                out[#out + 1] = { part = part, d = d }
            end
        end
    end
    table.sort(out, function(a, b)
        return a.d < b.d
    end)
    return out
end

local function magnetPower()
    local ok, v = pcall(UpgradeCmds.GetPower, "Magnet")
    return ok and type(v) == "number" and v or 0
end

-- Sweep every orb/coin/gem drop in the area by touching each one. The game
-- collects an orb when the character is within pickup range, and the server
-- validates that range, so teleporting onto the drop is the only reliable way.
local function collectOrbs(maxCount)
    local h = hrp()
    if not h then
        return
    end
    local reach = 2.5 + magnetPower()
    local here = h.Position
    -- stay inside the current zone's break box: orbs from the neighbouring
    -- area sit past the gate, and chasing them drags the character back there
    local zone = currentZone()
    local box = breakZonePart(zone)
    local function insideBox(p)
        if not box then
            return true
        end
        local rel = box.CFrame:PointToObjectSpace(p)
        return math.abs(rel.X) <= box.Size.X / 2 + 8 and math.abs(rel.Z) <= box.Size.Z / 2 + 8
    end
    local list = {}
    for _, part in ipairs(workspace.__THINGS:FindFirstChild("Orbs"):GetChildren()) do
        if part:IsA("BasePart") and part.Position.Y > -3000 and insideBox(part.Position) then
            local d = (part.Position - here).Magnitude
            if d <= CONFIG.ORB_RADIUS and d > reach then
                list[#list + 1] = { part = part, d = d }
            end
        end
    end
    if #list == 0 then
        return
    end
    table.sort(list, function(a, b)
        return a.d < b.d
    end)
    local anchor = h.CFrame
    maxCount = maxCount or CONFIG.ORB_BATCH
    for i = 1, math.min(maxCount, #list) do
        local p = list[i].part
        if p.Parent and p.Position.Y > -3000 then
            teleport(CFrame.new(p.Position), false)
            task.wait(0.06)
        end
    end
    -- return to the middle of the break box instead of wherever we drifted to
    local part = breakZonePart(currentZone())
    if part then
        teleport(CFrame.new(part.Position + Vector3.new(0, 4, 0)), false)
    else
        teleport(anchor + Vector3.new(0, 0.5, 0), false)
    end
end

---------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------

local function invItems(category)
    local s = getSave()
    if not s or not s.Inventory then
        return {}
    end
    return s.Inventory[category] or {}
end

local function findItem(category, id)
    for uid, item in pairs(invItems(category)) do
        if item.id == id then
            return uid, item
        end
    end
    return nil, nil
end

local function itemCount(category, id)
    local _, item = findItem(category, id)
    return item and (item._am or 1) or 0
end

---------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------

local function bestEggFor(zoneName)
    local z = Directory.Zones[zoneName]
    if not z then
        return nil
    end
    local zn = z.ZoneNumber
    local best, bestNum = nil, -1
    for name, egg in pairs(Directory.Eggs) do
        if egg.zoneNumber == zn and (egg.eggNumber or 0) > bestNum then
            best, bestNum = name, egg.eggNumber or 0
        end
    end
    if best then
        return best
    end
    -- some areas reuse the egg of an earlier area, so take the newest egg that
    -- is not above this area instead of giving up
    local fallback, fbNum = nil, -1
    for name, egg in pairs(Directory.Eggs) do
        local en = egg.zoneNumber or 0
        if en <= zn and en > fbNum then
            fallback, fbNum = name, en
        end
    end
    return fallback
end

local function hatchEggs(eggName, count, maxTime)
    if not eggName or count <= 0 then
        return 0
    end
    local left = count
    local done = 0
    local guard = 0
    local started = os.clock()
    while left > 0 and guard < 40 do
        guard = guard + 1
        if not State.on or (State.preempt and State.actionBusy) then
            break
        end
        -- keep one action short enough that the loop never starts a second one
        if maxTime and os.clock() - started > maxTime then
            break
        end
        local per = math.max(1, EggCmds.GetMaxHatch())
        local n = math.min(per, left)
        -- full bundles only: if the whole bundle is unaffordable, buy nothing
        -- and keep saving instead of trickling eggs in one by one
        local ok, res = pcall(EggCmds.RequestPurchase, eggName, n)
        if not ok or not res then
            break
        end
        left = left - n
        done = done + n
        task.wait(math.max(0.6, EggCmds.ComputeDebounce() + 0.15))
    end
    return done
end

local function hatchForZone(zoneName, force)
    local egg = bestEggFor(zoneName)
    if not egg then
        setStatus("Eggs: no egg known for " .. tostring(zoneName))
        return false
    end
    if State.hatchZone ~= zoneName then
        State.hatchZone = zoneName
    end
    -- two bundles in world 1, one bundle from world 2 onward
    local bundles = (WorldUtil.of(zoneName) or 1) > 1 and 1 or 2
    local want = bundles * math.max(1, EggCmds.GetMaxHatch())
    local done = State.hatchByZone[zoneName] or 0
    State.hatchDone = done
    if done >= want then
        return false
    end
    if not force and os.clock() - State.lastHatchAttempt < 15 then
        return false
    end
    State.lastHatchAttempt = os.clock()
    setStatus("Hatching " .. tostring(want - done) .. "x " .. egg)
    local got = hatchEggs(egg, want - done, 14)
    State.hatchByZone[zoneName] = done + got
    State.hatchDone = State.hatchByZone[zoneName]
    State.lastHatchZone = zoneName
    State.lastHatchCount = State.hatchDone
    if got == 0 then
        -- the full bundle is not affordable yet, so it keeps farming and
        -- retries; nothing is bought until a whole bundle can be paid for
        setStatus("Eggs: saving up (" .. tostring(State.hatchDone) .. "/" .. tostring(want) .. ")")
    end
    return got > 0
end

---------------------------------------------------------------------
-- Enchants
---------------------------------------------------------------------

local function bestEnchantsById(id, limit)
    local list = {}
    for uid, item in pairs(invItems("Enchant")) do
        if item.id == id then
            list[#list + 1] = { uid = uid, tier = item.tn or 1, amount = item._am or 1 }
        end
    end
    table.sort(list, function(a, b)
        return a.tier > b.tier
    end)
    local out = {}
    for i = 1, math.min(limit, #list) do
        out[i] = list[i]
    end
    return out
end

local function ensureEnchantLoadout(wanted)
    local s = getSave()
    if not s then
        return
    end
    local cap = math.max(1, s.MaxEnchantsEquipped or 1)
    local equipped = EnchantCmds.GetEquipped() or {}
    -- the game keys slots by string ("1", "2"), so normalise to numbers and
    -- keep the original key for unequip calls
    local current = {}
    local slotKey = {}
    for key, uid in pairs(equipped) do
        local n = tonumber(key)
        if n then
            current[n] = invItems("Enchant")[uid]
            slotKey[n] = key
        end
    end

    -- a wanted entry is either a plain id, or { id = ..., tier = ... } when the
    -- farm loadout asks for the strongest tier it owns
    local function wantId(w)
        return type(w) == "table" and w.id or w
    end

    local need = {}
    for slot = 1, cap do
        local want = wanted[slot]
        if want then
            local id = wantId(want)
            local tier = type(want) == "table" and want.tier or nil
            local cur = current[slot]
            local good = cur ~= nil and cur.id == id and (tier == nil or (cur.tn or 1) >= tier)
            if not good then
                need[#need + 1] = { slot = slot, id = id, tier = tier }
            end
        end
    end
    if #need == 0 then
        return
    end

    local label = {}
    for _, w in ipairs(wanted) do
        label[#label + 1] = wantId(w)
    end
    setStatus("Enchant loadout -> " .. table.concat(label, ", "))
    for _, req in ipairs(need) do
        local candidates = bestEnchantsById(req.id, 3)
        if getgenv().DD_DEBUG_ENCH then
            local desc = {}
            for _, c in ipairs(candidates) do
                desc[#desc + 1] = tostring(c.uid):sub(1, 6) .. "/t" .. tostring(c.tier) .. "x" .. tostring(c.amount)
            end
            print("[ench] slot", req.slot, "want", req.id, "tier", tostring(req.tier), "cands", table.concat(desc, " "))
        end
        if #candidates > 0 then
            -- how many copies of each uid are already in other slots; a stack of
            -- 3 tier-4 enchants can fill three slots
            local usedCount = {}
            for key, uid in pairs(EnchantCmds.GetEquipped() or {}) do
                if tonumber(key) ~= req.slot then
                    usedCount[uid] = (usedCount[uid] or 0) + 1
                end
            end
            -- the server needs a beat between unequip and equip, otherwise the
            -- equip is refused and the slot stays empty
            if equipped[slotKey[req.slot]] then
                pcall(EnchantCmds.Unequip, slotKey[req.slot])
                task.wait(0.4)
                pcall(EnchantCmds.Unequip, tonumber(req.slot) or req.slot)
                task.wait(0.8)
                if getgenv().DD_DEBUG_ENCH then
                    local g = EnchantCmds.GetEquipped() or {}
                    print("[ench]   unequip slot", req.slot, "now", tostring(g[slotKey[req.slot]] or g[req.slot] or g[tostring(req.slot)]))
                end
            end
            local placed = false
            -- pass 1: prefer a uid not used in any other slot, so five slots
            -- take five different stacks instead of retrying the same one
            for pass = 1, 2 do
                if not placed then
                    for _, cand in ipairs(candidates) do
                        local have = usedCount[cand.uid] or 0
                        local okToUse = (pass == 1) and (have == 0) or (have < (cand.amount or 1))
                        if not placed and okToUse then
                            for _ = 1, 2 do
                                local eok, eres = pcall(EnchantCmds.Equip, cand.uid)
                                task.wait(0.6)
                                local got = EnchantCmds.GetEquipped() or {}
                                local item = invItems("Enchant")[got[req.slot] or got[tostring(req.slot)]]
                                if getgenv().DD_DEBUG_ENCH then
                                    print("[ench]   equip", tostring(cand.uid):sub(1, 6), "ok", tostring(eok), tostring(eres), "->", tostring(item and item.id), "t" .. tostring(item and item.tn))
                                end
                                if item and item.id == req.id then
                                    placed = true
                                    usedCount[cand.uid] = have + 1
                                    break
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.2)
        end
    end
end

---------------------------------------------------------------------
-- Potions / fruits / buffs
---------------------------------------------------------------------

local POTION_PRIORITY = { "Coins", "Diamonds", "Damage", "Lucky", "Treasure Hunter", "Huge", "Walkspeed" }

local function activePotion(name)
    local ok, v = pcall(PotionCmds.Has, name)
    return ok and v == true
end

local function useBestPotion(name)
    local best, bestTier = nil, -1
    for uid, item in pairs(invItems("Potion")) do
        if item.id == name and (item.tn or 1) > bestTier then
            best, bestTier = uid, item.tn or 1
        end
    end
    if best then
        pcall(PotionCmds.Consume, best, 1)
        return true
    end
    return false
end

local function autoPotions()
    for _, name in ipairs(POTION_PRIORITY) do
        if not activePotion(name) then
            if useBestPotion(name) then
                setStatus("Potion: " .. name)
                return
            end
        end
    end
end

local function activeFruit(name)
    local ok, v = pcall(FruitCmds.Has, name)
    return ok and v == true
end

local function fruitRoom(uid)
    local ok, room = pcall(FruitCmds.GetMaxConsume, uid)
    if ok and type(room) == "number" then
        return room
    end
    return 0
end

local function autoFruits()
    for name, _ in pairs(Directory.Fruits) do
        if not activeFruit(name) then
            local uid = findItem("Fruit", name)
            if uid and fruitRoom(uid) > 0 then
                pcall(FruitCmds.Consume, uid, 1)
                setStatus("Fruit: " .. name)
                return
            end
        end
    end
end

local BUFF_REMOTES = {
    ["Squeaky Toy"] = "SqueakyToy_Consume",
    ["Toy Ball"] = "ToyBall_Consume",
    ["Toy Bone"] = "ToyBone_Consume",
    ["Christmas Cookie"] = "ChristmasCookie_Consume",
    ["Hot Cocoa"] = "HotCocoa_Consume",
    ["Glitched Drive"] = "GlitchedDrive_Consume",
    ["Nightmare Fuel"] = "NightmareFuel_Consume",
}

local function autoBuffs()
    for buffName, buff in pairs(Directory.Buffs) do
        if not BuffCmds.IsActive(buffName) then
            local itemId = buff.AssociatedItemID
            local remote = itemId and BUFF_REMOTES[itemId]
            if remote then
                local uid = findItem("Misc", itemId)
                if uid then
                    pcall(Network.Invoke, remote)
                    setStatus("Buff: " .. tostring(itemId))
                    return
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- Ultimate
---------------------------------------------------------------------

local function autoUltimate()
    if not UltimateCmds.UltimatesUnlocked() then
        return
    end
    local item = nil
    pcall(function()
        item = UltimateCmds.GetEquippedItem()
    end)
    if not item then
        -- nothing equipped: put one in so the ability can actually fire
        for _, it in pairs(invItems("Ultimate")) do
            if it.id then
                pcall(UltimateCmds.Equip, it.id)
                return
            end
        end
        return
    end
    -- the save stores the inventory uid, but the commands take the type id
    local id = item._data and (item._data.id or item._data._id) or nil
    if not id then
        return
    end
    local ok, charged = pcall(function()
        return UltimateCmds.IsCharged(id)
    end)
    if ok and charged and not UltimateCmds.IsActive() then
        -- only fire from the middle of the cluster: average the breakables so
        -- the spot is inside the area and not on its edge
        local part = breakZonePart(currentZone())
        local center = nil
        if part then
            local sum, n = Vector3.zero, 0
            for _, b in ipairs(State.farmList or {}) do
                if n < 14 and (b.pos - part.Position).Magnitude <= 140 then
                    sum = sum + b.pos
                    n = n + 1
                end
            end
            center = n > 0 and (sum / n) or part.Position
        end
        local h = hrp()
        local prevPause = State.pauseTaps
        State.pauseTaps = true
        if center and h and (h.Position - center).Magnitude > 10 then
            teleport(CFrame.new(center + Vector3.new(0, 5, 0)))
            task.wait(0.8)
        end
        h = hrp()
        if not center or (h and (h.Position - center).Magnitude <= 15) then
            pcall(UltimateCmds.Activate, id)
            task.wait(1)
        end
        State.pauseTaps = prevPause
    end
end

---------------------------------------------------------------------
-- Claims
---------------------------------------------------------------------

local function claimAll()
    pcall(Network.Invoke, "Mailbox: Claim All")
    pcall(Network.Invoke, "Redeem Free Gift")
    pcall(Network.Invoke, "ForeverPacks: Claim Free")
    pcall(Network.Fire, "Ranks_ClaimAll")
    pcall(Network.Invoke, "Login Streaks: Claim")
    pcall(Network.Invoke, "DailyRewards_Redeem")
end

local function openGiftBags()
    -- every item in the "Gifts" inventory tab opens with GiftBag_Open(id, n),
    -- verified in game on Toy Bundle / bundles
    for _, item in pairs(invItems("Misc")) do
        local id = tostring(item.id or "")
        local tags = nil
        pcall(function()
            local dir = Directory.MiscItems[id]
            tags = dir and dir.InventoryTags or nil
        end)
        local isGift = type(tags) == "table" and table.find(tags, "Gifts") ~= nil
        if isGift and (item._am or 0) > 0 then
            pcall(Network.Invoke, "GiftBag_Open", id, item._am or 1)
            task.wait(0.35)
        end
    end
end

local function openLootboxes()
    for _, item in pairs(invItems("Misc")) do
        local id = tostring(item.id or "")
        local isLootbox = false
        pcall(function()
            isLootbox = Directory.Lootboxes[id] ~= nil
        end)
        if not isLootbox then
            pcall(function()
                local dir = Directory.MiscItems[id]
                isLootbox = dir ~= nil and dir.Lootbox == true
            end)
        end
        if isLootbox then
            pcall(function()
                LootboxCmds.Open(item, item._am or 1)
            end)
            task.wait(0.3)
        end
    end
end

---------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------

local function buyUpgrade(upgradeId)
    local list = UpgradeCmds.All()
    if type(list) ~= "table" then
        return false
    end
    local bought = false
    for _, stand in pairs(list) do
        if stand.UpgradeID == upgradeId and stand.ZoneID then
            for _ = 1, 8 do
                local ok, res = pcall(UpgradeCmds.Purchase, upgradeId, stand.ZoneID)
                if not ok or not res then
                    break
                end
                bought = true
                task.wait(0.15)
            end
        end
    end
    return bought
end

local function buyPetSpeed()
    buyUpgrade("Pet Speed")
    buyUpgrade("Magnet")
end

-- The stand only accepts a buy while the character is physically on its pad,
-- and the movement controller drags the character away the moment it is free.
-- So hold the character still for the whole buy loop.
-- A stand only sells while the character is standing on its pad. Anchoring a
-- few studs above the pad lands outside the check the server runs, which is
-- why purchases were being refused, so the exact pad position is used and the
-- character is released to settle before each buy.
local function padPosition(model)
    if not model then
        return nil
    end
    for _, name in ipairs({ "Pad", "Upgrade", "Inside" }) do
        local part = model:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            return part.Position
        end
    end
    local ok, pivot = pcall(function()
        return model:GetPivot()
    end)
    return ok and pivot and pivot.Position or nil
end

local function buyAtPad(model, upgradeId, zone, maxTiers)
    local pos = padPosition(model)
    local h = hrp()
    if not pos or not h then
        return 0
    end
    for _, d in ipairs(h:GetDescendants()) do
        if d:IsA("AlignPosition") or d:IsA("AlignOrientation") then
            d.Enabled = false
        end
    end
    local got = 0
    for _ = 1, (maxTiers or 8) do
        -- keep the trip marked busy: the main loop would otherwise start
        -- teleporting back to the farm zone partway through and the character
        -- ends up parked between two maps doing nothing
        State.actionStarted = os.clock()
        h.Anchored = true
        h.CFrame = CFrame.new(pos)
        task.wait(0.4)
        h.Anchored = false
        task.wait(0.35)
        local ok, res = pcall(UpgradeCmds.Purchase, upgradeId, zone)
        if not ok or not res then
            task.wait(0.4)
            ok, res = pcall(UpgradeCmds.Purchase, upgradeId, zone)
        end
        if not ok or not res then
            break
        end
        got = got + 1
        task.wait(0.25)
    end
    return got
end

-- Upgrade stands only sell while the player is standing next to them, so this
-- walks to each loaded, unowned stand of one upgrade and buys every tier.
-- Locked zones are never visited.
local function buyUpgradeAtStands(upgradeId)
    local list = UpgradeCmds.All()
    if type(list) ~= "table" then
        return false
    end
    local bought = false
    for _, stand in pairs(list) do
        if stand.UpgradeID == upgradeId and stand.ZoneID and ownsZone(stand.ZoneID) then
            local owned = false
            pcall(function()
                owned = UpgradeCmds.Owns(upgradeId, stand.ZoneID) == true
            end)
            if not owned then
                if currentZone() ~= stand.ZoneID then
                    tpToZone(stand.ZoneID)
                    task.wait(1.2)
                end
                local pos = nil
                pcall(function()
                    pos = stand.Model:GetPivot().Position
                end)
                if pos then
                    if buyAtPad(stand.Model, upgradeId, stand.ZoneID, 8) > 0 then
                        bought = true
                    end
                end
            end
        end
    end
    return bought
end

-- Buys every unowned upgrade stand in one zone. Stands are matched by zone id
-- instead of by distance, because a distance guess misses whole clusters, and
-- each tier is confirmed with Owns() instead of trusting the return value.
local function buyAllUpgradesHere(zone)
    local list = UpgradeCmds.All()
    if type(list) ~= "table" then
        return false, 0
    end
    zone = zone or currentZone()
    if not zone then
        return false, 0
    end
    local bought = false
    local seen = 0
    for _, stand in pairs(list) do
        if stand.UpgradeID and stand.ZoneID == zone and ownsZone(zone) then
            local owned = false
            pcall(function()
                owned = UpgradeCmds.Owns(stand.UpgradeID, stand.ZoneID) == true
            end)
            if not owned and stand.Model and stand.Model.Parent then
                seen = seen + 1
                local got = buyAtPad(stand.Model, stand.UpgradeID, stand.ZoneID, 12)
                if got > 0 then
                    bought = true
                end
            end
        end
    end
    return bought, seen
end

local function buySlots()
    local s = getSave()
    if not s then
        return
    end
    local capPet = RankCmds.GetMaxPurchasableEquipSlots()
    if s.PetSlotsPurchased < capPet then
        pcall(Network.Invoke, "EquipSlotsMachine_RequestPurchase", s.PetSlotsPurchased + 1)
    end
end

local function buyEggSlots()
    local s = getSave()
    if not s then
        return
    end
    local cap = RankCmds.GetMaxPurchasableEggSlots()
    if s.EggSlotsPurchased >= cap then
        return
    end
    -- the purchase remote works from anywhere (verified through the world 2
    -- supercomputer, far from the Backyard machine), so no trip is needed
    setStatus("Buying egg slots")
    for _ = 1, 4 do
        s = getSave()
        if not s or s.EggSlotsPurchased >= cap then
            break
        end
        local bundle = RankCmds.GetEggBundle(s.EggSlotsPurchased + 1)
        if not bundle then
            break
        end
        local ok, res = pcall(Network.Invoke, "EggHatchSlotsMachine_RequestPurchase", bundle)
        if not ok or not res then
            break
        end
        setStatus("Bought egg bundle slot")
        task.wait(0.7)
    end
end

---------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------

local function tryRebirth()
    local ok, nxt = pcall(RebirthCmds.GetNextRebirth)
    if not ok or type(nxt) ~= "table" then
        return false
    end
    local req = tonumber(nxt.ZoneNumberRequired)
    local limit = State.zoneLimit or CONFIG.MAX_ZONE
    if not req or req > limit then
        return false
    end
    local zone = nil
    for name, z in pairs(Directory.Zones) do
        if z.ZoneNumber == req then
            zone = name
            break
        end
    end
    if not zone or not ownsZone(zone) then
        return false
    end
    if not MachineCmds.CanUse("RebirthShrine") then
        if not tpToMachine("RebirthShrine") then
            return false
        end
        task.wait(1.3)
    end
    setStatus("Rebirthing...")
    local okR = pcall(RebirthCmds.Rebirth, tostring(nxt.RebirthNumber))
    task.wait(3)
    return okR
end

---------------------------------------------------------------------
-- TNT / stairway
---------------------------------------------------------------------

local function useTnt(crate)
    if crate then
        local uid = findItem("Misc", "TNT Crate")
        if uid then
            pcall(Network.Invoke, "TNT_Crate_Consume", uid)
            return true
        end
        return false
    end
    local ok, res = pcall(Network.Invoke, "TNT_Consume")
    return ok and res
end

local function stairLeavePart()
    local things = workspace.__THINGS
    local inst = things:FindFirstChild("Instances")
    local stair = inst and inst:FindFirstChild("StairwayToHeaven")
    local teleports = stair and stair:FindFirstChild("Teleports")
    if not teleports then
        return nil
    end
    local part = teleports:FindFirstChild("Leave") or teleports:FindFirstChild("LeavePart")
    if part and part:IsA("BasePart") then
        return part
    end
    return nil
end

local function inStairway()
    local part = stairLeavePart()
    local h = hrp()
    if not part or not h then
        return false
    end
    local dx = part.Position.X - h.Position.X
    local dz = part.Position.Z - h.Position.Z
    return math.sqrt(dx * dx + dz * dz) < 220
end

local function leaveStairway()
    for _ = 1, 3 do
        local part = stairLeavePart()
        if not part then
            return false
        end
        setStatus("Leaving Stairway to Heaven")
        teleport(CFrame.new(part.Position + Vector3.new(0, 2.5, 0)), false)
        task.wait(2)
        if not inStairway() then
            return true
        end
        task.wait(0.4)
    end
    tpToZone(bestZone())
    task.wait(1.5)
    return not inStairway()
end

---------------------------------------------------------------------
-- Quest engine (phase 2)
---------------------------------------------------------------------

-- Strict top-to-bottom order from the spec.
--   1-10 = priority quests, 20 = normal, 30 = side.
local GOAL_PRIORITY = {
    [GOAL.USE_POTION] = 1,
    [GOAL.USE_FRUIT] = 2,
    [GOAL.USE_FLAG] = 3,
    [GOAL.UPGRADE_ENCHANT] = 4,
    [GOAL.UPGRADE_POTION] = 5,
    -- spawnable event quests come before pet crafting and egg hatching
    [GOAL.BEST_COMET] = 6,
    [GOAL.COMET] = 6,
    [GOAL.BEST_PINATA] = 7,
    [GOAL.PINATA] = 7,
    [GOAL.BEST_LUCKYBLOCK] = 7,
    [GOAL.LUCKYBLOCK] = 7,
    [GOAL.GOLD_PET] = 90,
    [GOAL.BEST_GOLD_PET] = 90,
    [GOAL.RAINBOW_PET] = 90,
    [GOAL.BEST_RAINBOW_PET] = 90,
    [GOAL.BEST_COIN_JAR] = 10,
    [GOAL.COIN_JAR] = 10,
    [GOAL.EGG] = 11,
    [GOAL.BEST_EGG] = 11,
    -- hatching pets is the same objective as hatching eggs
    [GOAL.PET] = 11,
    -- normal
    [GOAL.BREAKABLE] = 20,
    [GOAL.CURRENT_BREAKABLE] = 20,
    [GOAL.DIAMOND_BREAKABLE] = 20,
    [GOAL.CURRENCY] = 20,
    [GOAL.OBTAIN_CURRENCY] = 20,
    -- mini-chests spawn on their own schedule, so they wait behind the plain
    -- breakable count instead of jumping ahead of it
    -- side quests: they finish on their own while doing everything else
    [GOAL.MINI_CHEST] = 90,
    [GOAL.BEST_MINI_CHEST] = 90,
    [GOAL.SUPERIOR_MINI_CHEST] = 90,
    [GOAL.BEST_SUPERIOR_MINI_CHEST] = 90,
    [GOAL.COLLECT_ENCHANT] = 90,
    [GOAL.COLLECT_POTION] = 90,
}

-- quest actions that never move the character, so the orb sweep can run
-- underneath them
local ORB_SAFE_GOALS = {
    [GOAL.EGG] = true,
    [GOAL.BEST_EGG] = true,
    [GOAL.USE_POTION] = true,
    [GOAL.USE_FRUIT] = true,
    [GOAL.COMET] = true,
    [GOAL.BEST_COMET] = true,
    [GOAL.COIN_JAR] = true,
    [GOAL.BEST_COIN_JAR] = true,
    [GOAL.PINATA] = true,
    [GOAL.BEST_PINATA] = true,
    [GOAL.LUCKYBLOCK] = true,
    [GOAL.BEST_LUCKYBLOCK] = true,
}

local GOAL_SKIP = {
    [GOAL.HATCH_RARE_PET] = true,
    [GOAL.ZONE] = true,
    [GOAL.SPECIFIC_ZONE] = true,
    [GOAL.MAP_UPGRADE] = true,
    -- never do these: separate minigames and a rarity gamble
    [GOAL.FISHING] = true,
    [GOAL.ADVANCED_FISHING] = true,
    [GOAL.DIGSITE] = true,
    [GOAL.ADVANCED_DIGSITE] = true,
}

local GOAL_TEXT = {
    [GOAL.BREAKABLE] = "Break breakables",
    [GOAL.CURRENT_BREAKABLE] = "Break breakables",
    [GOAL.DIAMOND_BREAKABLE] = "Break diamond breakables",
    [GOAL.EGG] = "Hatch eggs",
    [GOAL.BEST_EGG] = "Hatch best eggs",
    [GOAL.PET] = "Hatch pets",
    [GOAL.GOLD_PET] = "Make golden pets",
    [GOAL.BEST_GOLD_PET] = "Make golden pets",
    [GOAL.RAINBOW_PET] = "Make rainbow pets",
    [GOAL.BEST_RAINBOW_PET] = "Make rainbow pets",
    [GOAL.COMET] = "Break comets",
    [GOAL.BEST_COMET] = "Break comets",
    [GOAL.COIN_JAR] = "Break coin jars",
    [GOAL.BEST_COIN_JAR] = "Break coin jars",
    [GOAL.PINATA] = "Break pinatas",
    [GOAL.BEST_PINATA] = "Break pinatas",
    [GOAL.LUCKYBLOCK] = "Break lucky blocks",
    [GOAL.BEST_LUCKYBLOCK] = "Break lucky blocks",
    [GOAL.MINI_CHEST] = "Break mini-chests",
    [GOAL.BEST_MINI_CHEST] = "Break mini-chests",
    [GOAL.SUPERIOR_MINI_CHEST] = "Break mini-chests",
    [GOAL.BEST_SUPERIOR_MINI_CHEST] = "Break mini-chests",
    [GOAL.COLLECT_ENCHANT] = "Collect enchants",
    [GOAL.COLLECT_POTION] = "Collect potions",
    [GOAL.USE_FLAG] = "Use flags",
    [GOAL.USE_POTION] = "Use potions",
    [GOAL.USE_FRUIT] = "Use fruits",
    [GOAL.UPGRADE_ENCHANT] = "Upgrade enchants",
    [GOAL.UPGRADE_POTION] = "Upgrade potions",
    [GOAL.CURRENCY] = "Earn diamonds",
    [GOAL.ZONE] = "Unlock area",
    [GOAL.SPECIFIC_ZONE] = "Unlock area",
    [GOAL.HATCH_RARE_PET] = "Hatch legendary+",
}

local function goalLabel(typeId)
    return GOAL_TEXT[typeId] or ("Goal " .. tostring(typeId))
end

local function readGoals()
    local s = getSave()
    local list = {}
    if not s or not s.Goals then
        return list
    end
    for key, g in pairs(s.Goals) do
        if type(g) == "table" then
            list[#list + 1] = {
                key = key,
                type = g.Type,
                amount = g.Amount or 0,
                progress = g.Progress or 0,
                stars = g.Stars or 0,
                tier = g.PotionTier,
                potionTier = g.PotionTier,
                enchantTier = g.EnchantTier,
                tierTarget = g.Tier,
                breakable = g.BreakableType,
                uid = g.UID,
            }
        end
    end
    table.sort(list, function(a, b)
        local pa = GOAL_PRIORITY[a.type] or 50
        local pb = GOAL_PRIORITY[b.type] or 50
        if pa ~= pb then
            return pa < pb
        end
        return (b.stars or 0) < (a.stars or 0)
    end)
    return list
end

-- Pinatas and lucky blocks are not quests: they are random events that sit in
-- the area until someone breaks them, and while one is up nothing else can be
-- summoned there. So they are cleared before any quest work starts.
local function blockingEvent(zone)
    local ok, events = pcall(RandomEventCmds.GetActive)
    if not ok or type(events) ~= "table" then
        return nil
    end
    zone = zone or currentZone()
    for _, e in pairs(events) do
        local id = string.lower(tostring(e.id or ""))
        if e.parentID == zone and e.origin
            and (string.find(id, "pinata", 1, true) or string.find(id, "lucky", 1, true)) then
            return e
        end
    end
    return nil
end

-- Which breakable belongs to which spawned event. The nearest breakable is
-- usually a present or a crate sitting next to the spawn point, so the event
-- type is matched by name instead.
local EVENT_KEY = {
    Comet = "comet",
    CoinJar = "jar",
    Pinata = "pinata",
    LuckyBlock = "lucky",
}

local function eventBreakable(origin, eventId, radius)
    local key = EVENT_KEY[eventId] or string.lower(tostring(eventId))
    local best, bd, fallback, fd = nil, math.huge, nil, math.huge
    for _, folder in ipairs({ workspace.__THINGS.Breakables, workspace.__THINGS.AnimatedBreakables }) do
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                local uid = m:GetAttribute("BreakableUID")
                local bid = tostring(m:GetAttribute("BreakableID"))
                if uid then
                    local ok, p = pcall(function()
                        return m:GetPivot().Position
                    end)
                    if ok then
                        local d = (p - origin).Magnitude
                        if d <= (radius or 60) then
                            if string.find(string.lower(bid), key, 1, true) then
                                if d < bd then
                                    best, bd = { uid = uid, pos = p, id = bid }, d
                                end
                            elseif d < fd then
                                fallback, fd = { uid = uid, pos = p, id = bid }, d
                            end
                        end
                    end
                end
            end
        end
    end
    return best or fallback
end

-- Spawning a comet (or jar/pinata/lucky block) does not finish the quest: the
-- thing itself has to be destroyed. So walk onto it and keep tapping while the
-- pets hit it, until the event is gone or the goal progress moves.
-- Which event type each goal cares about, so a pinata sitting in the area is
-- never mistaken for the comet the quest wants broken.
local GOAL_EVENT_KEY = {
    [GOAL.COMET] = "comet",
    [GOAL.BEST_COMET] = "comet",
    [GOAL.COIN_JAR] = "jar",
    [GOAL.BEST_COIN_JAR] = "jar",
    [GOAL.PINATA] = "pinata",
    [GOAL.BEST_PINATA] = "pinata",
    [GOAL.LUCKYBLOCK] = "lucky",
    [GOAL.BEST_LUCKYBLOCK] = "lucky",
}

local function eventByKey(zone, key)
    local ok, events = pcall(RandomEventCmds.GetActive)
    if not ok or type(events) ~= "table" then
        return nil
    end
    for _, e in pairs(events) do
        if e.parentID == zone and e.origin then
            if not key or string.find(string.lower(tostring(e.id or "")), key, 1, true) then
                return e
            end
        end
    end
    return nil
end

local function breakActiveEvent(goal, ev)
    local zone = currentZone()
    local e = ev
    if not e then
        e = eventByKey(zone, GOAL_EVENT_KEY[goal and goal.type])
    end
    if not e then
        return false
    end
    local h = hrp()
    if not h then
        return false
    end
    local target = eventBreakable(e.origin, e.id, 70)
    local aim = target and target.pos or e.origin
    if (h.Position - aim).Magnitude > 12 then
        teleport(CFrame.new(aim + Vector3.new(0, 5, 0)))
        task.wait(1)
    end
    local startProgress = goal.progress or 0
    local stopAt = os.clock() + 16
    local uid = target and target.uid or nil
    while os.clock() < stopAt do
        if not uid then
            local again = eventBreakable(e.origin, e.id, 80)
            uid = again and again.uid or nil
        end
        if uid then
            tapUid(uid)
        end
        task.wait(0.18)
        if not eventByKey(zone, GOAL_EVENT_KEY[goal and goal.type]) then
            return true
        end
        if (goal.progress or 0) ~= startProgress then
            return true
        end
    end
    return true
end

local function spawnEventItem(itemId, remote)
    local uid = findItem("Misc", itemId)
    if not uid then
        return false
    end
    local ok, res = pcall(Network.Invoke, remote, uid)
    return ok and res == true
end

local function ownedZonesDesc()
    local list = {}
    local s = getSave()
    if not s or not s.UnlockedZones then
        return list
    end
    for name, owned in pairs(s.UnlockedZones) do
        if owned and not forbiddenZone(name) then
            list[#list + 1] = { name = name, num = zoneNumber(name) or 0 }
        end
    end
    table.sort(list, function(a, b)
        return a.num > b.num
    end)
    return list
end

-- Buys upgrade stands in owned zones. The zone list comes from the save file,
-- not from what happens to be streamed, so a zone whose stands have not loaded
-- yet is still visited instead of being silently skipped. A zone that has
-- nothing left to buy is put on a short cooldown so it is not revisited.
local function crawlUpgrades(zoneBudget)
    local targets = {}
    local now = os.clock()
    for _, z in ipairs(ownedZonesDesc()) do
        local name = z.name
        local until_ = State.upgSkip[name]
        if not until_ or until_ < now then
            targets[#targets + 1] = name
        end
    end
    if #targets == 0 then
        State.upgSkip = {}
        return false
    end

    local bought = false
    local started = os.clock()
    local limit = math.min(zoneBudget or #targets, #targets)
    for i = 1, limit do
        -- a trip must not eat the whole farm window; banks the rest for later
        if os.clock() - started > 45 then
            break
        end
        local zone = targets[i]
        State.actionStarted = os.clock()
        -- land on the zone's normal spawn: stands sit near it, not near the
        -- break box the farm loop uses
        local ok, cf = pcall(ZonesUtil.GetTeleportPartLocation, zone)
        if ok and cf then
            teleport(cf + Vector3.new(0, 6, 0))
            -- stands take a moment to stream in after the teleport
            task.wait(2.2)
        end
        local got, seen = buyAllUpgradesHere(zone)
        if getgenv().DD_DEBUG_UPG then
            print("[upg]", zone, "now", tostring(currentZone()), "seen", seen, "bought", tostring(got))
        end
        if got then
            bought = true
        end
        if not got then
            -- nothing to buy here: park the zone for a few minutes when every
            -- stand was already owned, but only briefly when nothing had
            -- streamed in yet, so a slow load cannot hide a zone for long
            State.upgSkip[zone] = os.clock() + (seen == 0 and 90 or 600)
        else
            State.upgSkip[zone] = nil
        end
    end
    return bought
end

local function flagsBlockedUntil(zone)
    local t = State.flagBlocked[zone]
    if t and t > os.clock() then
        return true
    end
    return false
end

local function markFlagsBlocked(zone)
    State.flagBlocked[zone] = os.clock() + 300
end

-- A zone holds one flag TYPE, but any number of that same type
-- (up to GetMaxPlaceAutomaticContext). GetMaxPlaceAutomaticContext already
-- returns 0 for a different active type, so it is the only check needed.
local function tryPlaceFlagHere(flagName, uid, owned, need)
    if not MapCmds.IsInDottedBox() then
        return false
    end
    local maxPlace = 0
    pcall(function()
        maxPlace = FlexibleFlagCmds.GetMaxPlaceAutomaticContext(flagName)
    end)
    if not maxPlace or maxPlace <= 0 then
        return false
    end
    local amount = math.min(maxPlace, owned or 1, math.max(1, need), 10)
    if amount <= 0 then
        return false
    end
    local ok, res = pcall(FlexibleFlagCmds.Consume, flagName, uid, amount)
    return ok and res == true
end

local function useFlagOnBestArea(goal)
    local flagName = "Diamonds Flag"
    local uid, item = findItem("Misc", flagName)
    if not uid then
        flagName = "Coins Flag"
        uid, item = findItem("Misc", flagName)
    end
    if not uid then
        for name in pairs(Directory.ZoneFlags) do
            local u2, it2 = findItem("Misc", name)
            if u2 then
                flagName, uid, item = name, u2, it2
                break
            end
        end
    end
    if not uid then
        return false
    end
    local owned = item and (item._am or 1) or 1
    local need = 1
    if goal and goal.amount and goal.progress then
        need = math.max(1, goal.amount - goal.progress)
    end

    -- try where we stand first
    if MapCmds.IsInDottedBox() then
        local zone = currentZone()
        if not zone or not flagsBlockedUntil(zone) then
            if tryPlaceFlagHere(flagName, uid, owned, need) then
                return true
            end
            if zone then
                markFlagsBlocked(zone)
            end
        end
    end

    -- then walk the best owned zones until one accepts
    local zones = ownedZonesDesc()
    for i = 1, math.min(6, #zones) do
        local z = zones[i].name
        if not flagsBlockedUntil(z) then
            tpToZone(z)
            task.wait(1.1)
            if tryPlaceFlagHere(flagName, uid, owned, need) then
                State.flagBlocked[z] = nil
                return true
            end
            markFlagsBlocked(z)
        end
    end
    return false
end

local DIAMOND_GOALS = {
    [GOAL.DIAMOND_BREAKABLE] = true,
    [GOAL.CURRENCY] = true,
    [GOAL.OBTAIN_CURRENCY] = true,
}

local function hasDiamondQuest(goals)
    for _, g in ipairs(goals) do
        if DIAMOND_GOALS[g.type] then
            local done = (g.amount or 0) > 0 and (g.progress or 0) >= (g.amount or 0)
            if not done then
                return true
            end
        end
    end
    return false
end

-- while a diamond breakable / earn diamonds quest is open, keep a Diamonds
-- Flag down in the best zone (only one type of flag can exist per zone)
local function ensureDiamondFlag()
    local uid = findItem("Misc", "Diamonds Flag")
    if not uid then
        return false
    end
    local active = false
    pcall(function()
        active = FlexibleFlagCmds.PlayerHasActiveFlag("Diamonds Flag")
    end)
    if active then
        return false
    end
    if not MapCmds.IsInDottedBox() then
        return false
    end
    local room = 0
    pcall(function()
        room = FlexibleFlagCmds.GetMaxPlaceAutomaticContext("Diamonds Flag")
    end)
    if room <= 0 then
        return false
    end
    local ok, res = pcall(FlexibleFlagCmds.Consume, "Diamonds Flag", uid, 1)
    return ok and res == true
end

local function usePotionForGoal(goal)
    local wantTier = tonumber(goal.tier)
    local best, bestScore = nil, math.huge
    for uid, item in pairs(invItems("Potion")) do
        local tn = item.tn or 1
        if (not wantTier) or tn == wantTier then
            if tn < bestScore then
                best, bestScore = uid, tn
            end
        end
    end
    if not best then
        return false
    end
    pcall(PotionCmds.Consume, best, 1)
    return true
end

-- Fruits cap at 20 active of the same type. Pick the type with the most room
-- (least active) so the quest is spread across all fruit types instead of
-- dumping everything into one, and only consume as many as the quest needs.
local function useFruitForGoal(goal)
    local remaining = (goal and goal.amount or 1) - (goal and goal.progress or 0)
    if remaining <= 0 then
        return false
    end
    local best = nil
    for uid, item in pairs(invItems("Fruit")) do
        local amount = item._am or 1
        if amount > 0 then
            local room = fruitRoom(uid)
            if room > 0 and (not best or room > best.room) then
                best = { uid = uid, room = room, amount = amount, name = item.id }
            end
        end
    end
    if not best then
        return false
    end
    -- one per pass: the next pass picks whichever type now has the most room,
    -- which keeps the types balanced and stops at the quest amount
    pcall(FruitCmds.Consume, best.uid, 1)
    return true
end

-- Farm phase keeps a coin buff running at all times: a potion gives a flat
-- multiplier and bananas stack on top of it, which is free income every second
-- the character is breaking something.
local function keepCoinBuffs()
    local activePotions = {}
    local ok, potions = pcall(PotionCmds.GetActivePotions)
    if ok and type(potions) == "table" then
        for id in pairs(potions) do
            activePotions[tostring(id)] = true
        end
    end
    for _, want in ipairs({ "The Cocktail", "Coins" }) do
        if not activePotions[want] then
            local uid = findItem("Potion", want)
            if uid then
                pcall(PotionCmds.Consume, uid, 1)
                task.wait(0.4)
                return true
            end
        end
    end

    local activeFruits = {}
    ok, activeFruits = pcall(FruitCmds.GetActiveFruits)
    activeFruits = ok and activeFruits or {}
    for _, want in ipairs({ "Rainbow", "Banana" }) do
        local uid = findItem("Fruit", want)
        if uid then
            local entry = activeFruits[want]
            local count = 0
            if type(entry) == "table" then
                count = entry.count or entry.amount or entry.Amount or 1
            elseif type(entry) == "number" then
                count = entry
            end
            if count < 20 then
                pcall(FruitCmds.Consume, uid, 1)
                return true
            end
            break
        end
    end
    return false
end


-- Farm loadout: every slot takes the strongest Coins / Strong Pets enchant
-- owned, highest tier first, Coins winning ties (same product, bigger number).
-- Tap Power is never used: with a full pet team the tap share is negligible.
local function farmEnchants()
    local save = getSave()
    local cap = math.max(1, (save and save.MaxEnchantsEquipped) or 1)
    local flat = {}
    for _, item in pairs(invItems("Enchant")) do
        if item.id == "Coins" or item.id == "Strong Pets" then
            for _ = 1, math.max(1, item._am or 1) do
                flat[#flat + 1] = { id = item.id, tier = item.tn or 1 }
            end
        end
    end
    table.sort(flat, function(a, b)
        if a.tier ~= b.tier then
            return a.tier > b.tier
        end
        return a.id == "Coins" and b.id ~= "Coins"
    end)
    local list = {}
    for i = 1, cap do
        if flat[i] then
            list[i] = { id = flat[i].id, tier = flat[i].tier }
        else
            list[i] = flat[1] and { id = flat[1].id, tier = 0 } or "Coins"
        end
    end
    return list
end

-- Upgrades raw items until one reaches targetTier.
-- Tier N needs 3 items of tier N-1, so lower tiers are climbed one step at a time.
local function upgradeToTier(machineName, remote, targetTier)
    if not WorldUtil.directMachines() then
        if not tpToMachine(machineName) then
            return false
        end
        task.wait(0.8)
        if not MachineCmds.CanUse(machineName) then
            return false
        end
    end
    local category = machineName:find("Enchant") and "Enchant" or "Potion"
    targetTier = tonumber(targetTier)
    if not targetTier or targetTier < 2 then
        local lowest = nil
        for _, item in pairs(invItems(category)) do
            local tier = item.tn or 1
            if (item._am or 1) >= 3 and tier < 5 and (not lowest or tier < lowest) then
                lowest = tier
            end
        end
        targetTier = (lowest or 1) + 1
    end

    for _ = 1, 15 do
        if not State.on or (State.preempt and State.actionBusy) then
            return false
        end
        local items = invItems(category)
        local ready = nil       -- a stack of exactly target-1
        local climb = nil       -- lowest stack below target-1
        for uid, item in pairs(items) do
            local tier = item.tn or 1
            local amount = item._am or 1
            if tier < targetTier and amount >= 3 then
                if tier == targetTier - 1 then
                    if not ready or amount > ready.amount then
                        ready = { uid = uid, tier = tier, amount = amount }
                    end
                end
                if not climb or tier < climb.tier then
                    climb = { uid = uid, tier = tier, amount = amount }
                end
            end
        end

        local pick = ready or climb
        if not pick then
            return false
        end
        local ok, res = pcall(Network.Invoke, remote, pick.uid, 1)
        if not ok or res ~= true then
            return false
        end
        task.wait(0.55)
        if ready then
            return true
        end
    end
    return false
end

-- how many pets of `variant` we can turn into the next variant right now
-- (10 pets of one stack = 1 result)
local function petCapacity(variant)
    local n = 0
    for _, item in pairs(invItems("Pet")) do
        if (item.pt or 0) == variant then
            n = n + math.floor((item._am or 1) / 10)
        end
    end
    return n
end

-- Stay in the best area and hatch until `check()` is satisfied.
-- No machine trip happens here, so the bot stops bouncing back and forth.
local function hatchUntil(check)
    local zone = bestZone()
    if currentZone() ~= zone then
        tpToZone(zone)
        task.wait(1.2)
    end
    local egg = bestEggFor(zone)
    if not egg then
        return false
    end
    local hatched = false
    for _ = 1, 8 do
        if State.preempt and State.actionBusy then
            break
        end
        if check() then
            break
        end
        if hatchEggs(egg, 25) <= 0 then
            break
        end
        hatched = true
    end
    return hatched
end

local function largestStack(variant)
    local uid, amount = nil, 0
    for u, item in pairs(invItems("Pet")) do
        if (item.pt or 0) == variant and (item._am or 1) > amount then
            uid, amount = u, item._am or 1
        end
    end
    return uid, amount
end

local function craftAtMachine(machine, remote, wantedVariant, count)
    if not WorldUtil.directMachines() then
        if not tpToMachine(machine) then
            return false
        end
        task.wait(0.8)
        if not MachineCmds.CanUse(machine) then
            return false
        end
    end
    local candidates = {}
    for uid, item in pairs(invItems("Pet")) do
        local n = item._am or 1
        if (item.pt or 0) == wantedVariant and n >= 10 then
            candidates[#candidates + 1] = { uid = uid, amount = n }
        end
    end
    table.sort(candidates, function(a, b)
        return a.amount > b.amount
    end)
    local crafted = false
    for i = 1, math.min(20, #candidates) do
        if State.preempt and State.actionBusy then
            break
        end
        if count <= 0 then
            break
        end
        local c = candidates[i]
        local results = math.min(math.floor(c.amount / 10), count)
        if results >= 1 then
            local ok, res = pcall(Network.Invoke, remote, c.uid, results)
            if ok and res == true then
                crafted = true
                count = count - results
                task.wait(0.45)
            end
        end
    end
    return crafted
end

local function doGoldPets(goal)
    local remaining = math.max(1, (goal.amount or 1) - (goal.progress or 0))
    if petCapacity(0) < remaining then
        -- stay in the best area and hatch until enough pets exist
        return hatchUntil(function()
            return petCapacity(0) >= remaining
        end)
    end
    -- everything needed is already in the inventory: one trip, craft it all
    return craftAtMachine("GoldMachine", "GoldMachine_Activate", 0, remaining)
end

local function doRainbowPets(goal)
    local remaining = math.max(1, (goal.amount or 1) - (goal.progress or 0))
    if petCapacity(1) >= remaining then
        return craftAtMachine("RainbowMachine", "RainbowMachine_Activate", 1, remaining)
    end

    -- a rainbow needs 10 golden pets of the SAME species, so we need one
    -- normal stack of 100 to produce a full 10 golden stack
    if (select(2, largestStack(0)) or 0) < 100 then
        return hatchUntil(function()
            return (select(2, largestStack(0)) or 0) >= 100
        end)
    end

    if not tpToMachine("GoldMachine") then
        return false
    end
    task.wait(0.8)
    if not MachineCmds.CanUse("GoldMachine") then
        return false
    end
    local uid, amount = largestStack(0)
    if not uid then
        return false
    end
    local missing = remaining - petCapacity(1)
    local results = math.min(missing * 10, math.floor(amount / 10))
    if results < 10 then
        return false
    end
    local ok, res = pcall(Network.Invoke, "GoldMachine_Activate", uid, results)
    return ok and res == true
end

local function runGoal(goal)
    local t = goal.type
    if t == GOAL.USE_POTION then
        return usePotionForGoal(goal)
    elseif t == GOAL.USE_FRUIT then
        return useFruitForGoal(goal)
    elseif t == GOAL.USE_FLAG then
        return useFlagOnBestArea(goal)
    elseif t == GOAL.UPGRADE_ENCHANT then
        local target = goal.enchantTier or goal.EnchantTier or goal.tierTarget
        return upgradeToTier("UpgradeEnchantsMachine", "UpgradeEnchantsMachine_Activate", target)
    elseif t == GOAL.UPGRADE_POTION then
        local target = goal.potionTier or goal.PotionTier or goal.tierTarget
        return upgradeToTier("UpgradePotionsMachine", "UpgradePotionsMachine_Activate", target)
    elseif t == GOAL.EGG or t == GOAL.BEST_EGG then
        local zone = bestZone()
        if currentZone() ~= zone then
            tpToZone(zone)
            task.wait(1.2)
        end
        local remain = (goal.amount or 0) - (goal.progress or 0)
        return hatchEggs(bestEggFor(zone), math.min(math.max(remain, 1), math.max(1, EggCmds.GetMaxHatch()))) > 0
    elseif t == GOAL.GOLD_PET or t == GOAL.BEST_GOLD_PET then
        return doGoldPets(goal)
    elseif t == GOAL.RAINBOW_PET or t == GOAL.BEST_RAINBOW_PET then
        return doRainbowPets(goal)
    elseif t == GOAL.COMET or t == GOAL.BEST_COMET then
        if breakActiveEvent(goal) then
            return true
        end
        return spawnEventItem("Comet", "Comet_Spawn")
    elseif t == GOAL.COIN_JAR or t == GOAL.BEST_COIN_JAR then
        if breakActiveEvent(goal) then
            return true
        end
        local ok = spawnEventItem("Basic Coin Jar", "CoinJar_Spawn")
        if not ok then
            ok = spawnEventItem("Giant Coin Jar", "CoinJar_Spawn")
        end
        return ok
    elseif t == GOAL.PINATA or t == GOAL.BEST_PINATA then
        if breakActiveEvent(goal) then
            return true
        end
        return spawnEventItem("Mini Pinata", "MiniPinata_Consume")
    elseif t == GOAL.LUCKYBLOCK or t == GOAL.BEST_LUCKYBLOCK then
        if breakActiveEvent(goal) then
            return true
        end
        return spawnEventItem("Mini Lucky Block", "MiniLuckyBlock_Consume")
    elseif t == GOAL.BREAKABLE
        or t == GOAL.CURRENT_BREAKABLE
        or t == GOAL.DIAMOND_BREAKABLE
        or t == GOAL.MINI_CHEST
        or t == GOAL.BEST_MINI_CHEST
        or t == GOAL.SUPERIOR_MINI_CHEST
        or t == GOAL.BEST_SUPERIOR_MINI_CHEST
        or t == GOAL.COLLECT_ENCHANT
        or t == GOAL.COLLECT_POTION
        or t == GOAL.CURRENCY
        or t == GOAL.OBTAIN_CURRENCY
        or t == GOAL.PET
    then
        return true
    else
        return false
    end
end

---------------------------------------------------------------------
-- Phase loops
---------------------------------------------------------------------

local function actionBusy()
    return State.actionBusy and (os.clock() - State.actionStarted) < 30
end

local function runAction(fn, label, force, rank, safeForOrbs)
    if not force and actionBusy() then
        return false
    end
    State.actionBusy = true
    State.actionStarted = os.clock()
    State.actionRank = rank
    State.actionSafeForOrbs = safeForOrbs == true
    State.preempt = false
    if label then
        setStatus(label)
    end
    task.spawn(function()
        local ok, err = pcall(fn)
        State.actionBusy = false
        State.actionRank = nil
        State.actionSafeForOrbs = false
        State.preempt = false
        if not ok then
            setStatus("Action error: " .. tostring(err))
        end
    end)
    return true
end

local function phaseOneStep()
    local best = bestZone()
    local nxt = nextBuyableZone()

    -- the best area is in another world: hop place first, and never fall
    -- through to a zone teleport that cannot work from here
    local hop = WorldUtil.hopNeeded()
    if hop and os.clock() - State.lastWorldHop > 30 then
        runAction(function()
            State.lastWorldHop = os.clock()
            WorldUtil.travel(hop)
        end, "World hop")
        return
    end

    local zone = currentZone()
    if zone ~= best then
        setStatus("Travelling to " .. best)
        tpToZone(best)
        task.wait(1.2)
        return
    end

    if ensureFarmSpot(best) then
        return
    end

    -- pinatas and lucky blocks block summons, so they are cleared first
    local blocker = blockingEvent(best)
    if blocker and os.clock() - (State.lastEventClear or 0) > 15 then
        if
            runAction(function()
                breakActiveEvent({ progress = 0 }, blocker)
            end, "Clearing event")
        then
            State.lastEventClear = os.clock()
            return
        end
    end

    -- stamp the timer only when the action actually started; otherwise a busy
    -- loop would keep skipping this for another full minute
    if os.clock() - State.lastEnchantCheck > 60 then
        if
            runAction(function()
                ensureEnchantLoadout(farmEnchants())
            end)
        then
            State.lastEnchantCheck = os.clock()
            return
        end
    end

    -- keep a coin potion / banana running: the multiplier is free while farming
    if os.clock() - (State.lastBuff or 0) > 60 then
        if runAction(keepCoinBuffs) then
            State.lastBuff = os.clock()
            return
        end
    end

    -- 1) eggs for the newest area only: two full hatch bundles. Buying eggs is
    -- a remote call, not a teleport, so a short retry costs nothing and the
    -- bundle lands as soon as the coins are there.
    local wantEggs = ((WorldUtil.of(best) or 1) > 1 and 1 or 2) * math.max(1, EggCmds.GetMaxHatch())
    local doneEggs = State.hatchByZone[best] or 0
    State.hatchDone = doneEggs
    if best == bestZone() and doneEggs < wantEggs and os.clock() - State.lastHatchAttempt > 20 then
        runAction(function()
            hatchForZone(best, false)
        end, nil, false, nil, true)
        return
    end

    -- 2) only once those eggs are bought, save for and buy the next area.
    -- The retry is short: waiting longer only delays the purchase after the
    -- coins are already there.
    if nxt and not forbiddenZone(nxt) and not ownsZone(nxt) and os.clock() - State.lastBuy > 2 then
        State.lastBuy = os.clock()
        runAction(function()
            local ok, res = pcall(Network.Invoke, "Zones_RequestPurchase", nxt)
            if ok and res then
                setStatus("Bought " .. nxt)
                task.wait(0.8)
                tpToZone(nxt)
                task.wait(1.5)
                hatchForZone(nxt, true)
            else
                -- nothing bought: allow the next check almost immediately
                State.lastBuy = os.clock() - 1
            end
        end, "Buying " .. tostring(nxt))
        return
    end

    -- 3) upgrades are the farm rate. Trips stay quick while a trip is still
    -- buying tiers (three minutes), and back off to ten minutes once the
    -- affordable tiers are gone so the character farms instead of walking.
    local interval = State.upgFast and 180 or 600
    local budget = State.upgFast and 5 or 3
    if os.clock() - State.lastUpgrade > interval then
        if
            runAction(function()
                -- stop tapping while walking the map: taps in a lower zone are
                -- wasted work and make it look like it farms the wrong area
                State.pauseTaps = true
                local ok, bought = pcall(crawlUpgrades, budget)
                -- come straight back: never leave the character parked in a
                -- lower zone where the tap loop would keep hitting breakables
                local home = bestZone()
                if currentZone() ~= home then
                    tpToZone(home)
                    task.wait(1)
                end
                State.pauseTaps = false
                State.upgFast = ok and bought or false
            end, "Upgrade trip")
        then
            State.lastUpgrade = os.clock()
        end
        return
    end

    if os.clock() - State.lastEggSlot > 300 then
        State.lastEggSlot = os.clock()
        local s = getSave()
        if s and s.EggSlotsPurchased < RankCmds.GetMaxPurchasableEggSlots() then
            runAction(buyEggSlots)
            return
        end
    end

    if os.clock() - State.lastRebirth > 120 then
        State.lastRebirth = os.clock()
        runAction(function()
            tryRebirth()
        end)
        return
    end

    setStatus("Farming " .. tostring(zone))
    if (State.zoneLimit or 0) > CONFIG.MAX_ZONE then
        setPhase("Phase 1 - FARM TO WORLD 4")
    else
        setPhase("Phase 1 - FARM TO AREA 98")
    end
end

local function phaseTwoStep()
    local s = getSave()
    if not s then
        return
    end

    -- rank quests happen in the best area too: if that area lives in another
    -- world, hop there first
    local hop = WorldUtil.hopNeeded()
    if hop and os.clock() - State.lastWorldHop > 30 then
        runAction(function()
            State.lastWorldHop = os.clock()
            WorldUtil.travel(hop)
        end, "World hop")
        return
    end
    -- a reached rank target only ends the stage here; the main loop decides
    -- whether the run is actually over (rank 20 + world 4 finished)
    if (s.Rank or 0) >= (State.rankTarget or 8) then
        return
    end

    local best = bestZone()
    if currentZone() ~= best and not inStairway() and not actionBusy() then
        setStatus("Travelling to " .. best)
        tpToZone(best)
        task.wait(1.2)
        return
    end

    if ensureFarmSpot(best) then
        return
    end

    local blocker = blockingEvent(best)
    if blocker and os.clock() - (State.lastEventClear or 0) > 15 then
        State.lastEventClear = os.clock()
        setStatus("Clearing " .. tostring(blocker.name or blocker.id))
        runAction(function()
            breakActiveEvent({ progress = 0 }, blocker)
        end, "Clearing event")
        return
    end

    if os.clock() - State.lastEggSlot > 300 then
        State.lastEggSlot = os.clock()
        local sv = getSave()
        if sv and sv.EggSlotsPurchased < RankCmds.GetMaxPurchasableEggSlots() then
            runAction(buyEggSlots)
            return
        end
    end

    local goals = readGoals()

    if hasDiamondQuest(goals) and os.clock() - State.lastDiamondFlag > 15 then
        State.lastDiamondFlag = os.clock()
        if ensureDiamondFlag() then
            setStatus("Placed Diamonds Flag")
        end
    end

    local active = nil
    local now = os.clock()

    -- gold / rainbow pet work is sticky: once started it is finished before
    -- any other goal is taken, and it is never put on the failure cooldown
    local function isCraftGoal(t)
        return t == GOAL.GOLD_PET or t == GOAL.BEST_GOLD_PET
            or t == GOAL.RAINBOW_PET or t == GOAL.BEST_RAINBOW_PET
    end
    if State.stickyCraft then
        for _, g in ipairs(goals) do
            local done = (g.amount or 0) > 0 and (g.progress or 0) >= (g.amount or 0)
            if g.key == State.stickyCraft and not done then
                active = g
                break
            end
        end
        if not active then
            State.stickyCraft = nil
        end
    end

    if not active then
        for _, g in ipairs(goals) do
            local done = (g.amount or 0) > 0 and (g.progress or 0) >= (g.amount or 0)
            if not GOAL_SKIP[g.type] and not done then
                local fail = State.goalFails[g.key]
                if not fail or fail.expire < now then
                    active = g
                    break
                end
            end
        end
    end

    if active and isCraftGoal(active.type) then
        State.stickyCraft = active.key
        State.goalFails[active.key] = nil
    end

    if not active then
        setQuest("Waiting on quests - farming")
        setStatus("Farming " .. tostring(best))
        return
    end

    setQuest(goalLabel(active.type) .. "  " .. tostring(active.progress) .. "/" .. tostring(active.amount))
    setPhase("RANK " .. tostring(s.Rank or 0) .. "  |  " .. (#goals) .. " quests")
    setStatus("Rank quest: " .. goalLabel(active.type))

    local stallLimit = 180
    if active.type == GOAL.COIN_JAR or active.type == GOAL.BEST_COIN_JAR then
        stallLimit = 300
    elseif active.type == GOAL.GOLD_PET or active.type == GOAL.BEST_GOLD_PET
        or active.type == GOAL.RAINBOW_PET or active.type == GOAL.BEST_RAINBOW_PET then
        -- pet crafting can sit idle while the bag fills up; never abandon it
        stallLimit = 3600
    elseif active.type == GOAL.BREAKABLE
        or active.type == GOAL.CURRENT_BREAKABLE
        or active.type == GOAL.DIAMOND_BREAKABLE
        or active.type == GOAL.CURRENCY
        or active.type == GOAL.COLLECT_ENCHANT
        or active.type == GOAL.COLLECT_POTION
    then
        stallLimit = 120
    end

    if State.activeKey ~= active.key or State.activeProgress ~= active.progress then
        State.activeKey = active.key
        State.activeProgress = active.progress
        State.activeSince = now
    elseif now - State.activeSince > stallLimit then
        State.goalFails[active.key] = { count = 0, expire = now + 150 }
        State.activeKey = nil
        return
    end

    if os.clock() - State.lastEnchant > 60 then
        if
            runAction(function()
                -- rank phase uses the best Treasure Hunter tiers owned, in
                -- every slot the account has (4 of them from rank 8)
                local cap = math.max(1, (getSave() or {}).MaxEnchantsEquipped or 1)
                local tiers = {}
                for _, item in pairs(invItems("Enchant")) do
                    if item.id == "Treasure Hunter" then
                        for _ = 1, math.max(1, item._am or 1) do
                            tiers[#tiers + 1] = item.tn or 1
                        end
                    end
                end
                table.sort(tiers, function(a, b)
                    return a > b
                end)
                local wanted = {}
                for i = 1, cap do
                    wanted[i] = { id = "Treasure Hunter", tier = tiers[i] or 0 }
                end
                ensureEnchantLoadout(wanted)
            end)
        then
            State.lastEnchant = os.clock()
            return
        end
    end

    runAction(function()
        local ok = runGoal(active)
        if State.preempt then
            return
        end
        if not ok then
            -- never park a pet-crafting goal on cooldown: it just means the bag
            -- is not full enough yet
            local craft = active.type == GOAL.GOLD_PET or active.type == GOAL.BEST_GOLD_PET
                or active.type == GOAL.RAINBOW_PET or active.type == GOAL.BEST_RAINBOW_PET
            if not craft then
                local fail = State.goalFails[active.key]
                if not fail then
                    fail = { count = 0, expire = 0 }
                    State.goalFails[active.key] = fail
                end
                fail.count = fail.count + 1
                if fail.count >= 3 then
                    fail.count = 0
                    fail.expire = os.clock() + 90
                end
            end
        else
            State.goalFails[active.key] = nil
        end
    end, nil, false, GOAL_PRIORITY[active.type] or 50, ORB_SAFE_GOALS[active.type] == true)
end

---------------------------------------------------------------------
-- Background actions
---------------------------------------------------------------------

local function killEggAnimation()
    -- the client reads this workspace attribute when EggOpeningFrontend plays;
    -- true makes the hatch instant and skips the "Click to open!" prompt
    pcall(function()
        if workspace:GetAttribute("GlobalInstantHatch") ~= true then
            workspace:SetAttribute("GlobalInstantHatch", true)
        end
    end)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local anim = pg and pg:FindFirstChild("EggOpenAnimation")
    if anim then
        pcall(function()
            anim:Destroy()
        end)
    end
end

local function backgroundTick()
    if not State.on then
        return
    end
    local now = os.clock()
    if now - State.lastClaim > 25 then
        State.lastClaim = now
        claimAll()
    end
    if now - State.lastGift > 45 then
        State.lastGift = now
        openGiftBags()
        openLootboxes()
    end

    if now - State.lastSpeed > 180 then
        State.lastSpeed = now
        buyPetSpeed()
    end
    if now - State.lastSlot > 40 then
        State.lastSlot = now
        buySlots()
    end

    if now - State.lastPotion > 6 then
        State.lastPotion = now
        autoPotions()
    end
    if now - State.lastFruit > 9 then
        State.lastFruit = now
        autoFruits()
    end
    if now - State.lastBuff > 11 then
        State.lastBuff = now
        autoBuffs()
    end
    if now - State.lastUlt > 2 then
        State.lastUlt = now
        autoUltimate()
    end
    if now - State.lastTnt > CONFIG.TNT_EVERY then
        State.lastTnt = now
        useTnt(false)
    end

    -- egg quests run alongside whatever else is happening: hatching is a
    -- remote, so it never pulls the character off the farm spot
    if now - (State.lastQuestHatch or 0) > 20 then
        State.lastQuestHatch = now
        local save = getSave()
        local eggName = bestEggFor(bestZone())
        if save and eggName then
            for _, g in pairs(save.Goals or {}) do
                local t = g.Type
                if (t == GOAL.EGG or t == GOAL.BEST_EGG or t == GOAL.PET)
                    and (g.Progress or 0) < (g.Amount or 0) then
                    local remain = (g.Amount or 0) - (g.Progress or 0)
                    -- always hatch a full bundle (max hatch), not a trickle
                    hatchEggs(eggName, math.min(remain, math.max(1, EggCmds.GetMaxHatch())), 12)
                    break
                end
            end
        end
    end

    -- gold / rainbow pet quests also run in the background: hatch to build the
    -- pet stock, then craft at the machine (remote in worlds 2-4)
    if now - (State.lastCraft or 0) > 25 then
        State.lastCraft = now
        local save = getSave()
        local eggName = bestEggFor(bestZone())
        if save then
            for _, g in pairs(save.Goals or {}) do
                local t = g.Type
                if (t == GOAL.GOLD_PET or t == GOAL.BEST_GOLD_PET
                    or t == GOAL.RAINBOW_PET or t == GOAL.BEST_RAINBOW_PET)
                    and (g.Progress or 0) < (g.Amount or 0) then
                    local remaining = (g.Amount or 0) - (g.Progress or 0)
                    local variant = (t == GOAL.RAINBOW_PET or t == GOAL.BEST_RAINBOW_PET) and 1 or 0
                    if petCapacity(variant) >= 1 then
                        craftAtMachine(
                            variant == 1 and "RainbowMachine" or "GoldMachine",
                            variant == 1 and "RainbowMachine_Activate" or "GoldMachine_Activate",
                            variant,
                            math.min(remaining, 20)
                        )
                    elseif eggName then
                        hatchEggs(eggName, math.max(1, EggCmds.GetMaxHatch()), 12)
                    end
                    break
                end
            end
        end
    end
end

local function farmTick()
    refreshFarm(false)
    local targets = nearestBreakables(6)
    if #targets == 0 then
        State.lastProgress = os.clock()
        return
    end
    for _, b in ipairs(targets) do
        if b.model.Parent then
            tapUid(b.uid)
            State.lastProgress = os.clock()
        end
    end
end

local function rankFinished()
    local s = getSave()
    if not s then
        return false
    end
    local last = WorldUtil.lastZone(4)
    return (s.Rank or 0) >= 20 and last ~= nil and ownsZone(last)
end

local function autoStopForRank()
    State.on = false
    setStatus("Finished - world 4 and rank 20 reached")
    setQuest("")
    if UI.toggle then
        -- defer: when this runs from the toggle callback the Set(true) is still
        -- being applied and would overwrite a nested Set(false)
        task.defer(function()
            pcall(function()
                UI.toggle:Set(false)
            end)
        end)
    end
end

-- the four world places; anything else is a minigame/trial instance
WorldUtil.places = {
    [8737899170] = 1,
    [16498369169] = 2,
    [17503543197] = 3,
    [140403681187145] = 4,
}

local function mainLoop()
    while alive() do
        State.lastLoop = os.clock()
        flushUI()
        local ok, err = pcall(function()
            if not State.on then
                return
            end

            if rankFinished() then
                autoStopForRank()
                return
            end

            -- never get stuck in a minigame / time trial instance
            if not WorldUtil.places[game.PlaceId] then
                if os.clock() - (State.lastGameEscape or 0) > 20 then
                    State.lastGameEscape = os.clock()
                    setStatus("Leaving minigame")
                    local home = WorldUtil.of(bestZone()) or 1
                    WorldUtil.travel(home)
                end
                return
            end

            local zone = currentZone()
            State.zone = zone

            if inStairway() then
                if not State.stairwayBusy then
                    State.stairwayBusy = true
                    task.spawn(function()
                        pcall(leaveStairway)
                        State.stairwayBusy = false
                    end)
                end
                return
            end

            local s = getSave()
            local lastW4 = WorldUtil.lastZone(4)
            local ownsW4 = lastW4 ~= nil and s ~= nil and ownsZone(lastW4)
            local rank = (s and s.Rank) or 0

            -- the run: farm to 98, rank 8, open 99, farm to world 4, rank 20.
            -- If the account is already in a later world, allow that world so
            -- it is never stranded below the area limit.
            local limit = CONFIG.MAX_ZONE
            if rank >= 8 and s and ownsZone("Colorful Clouds") then
                limit = CONFIG.PRO_VIP_MAX_ZONE
            else
                local w = WorldUtil.of(currentZone())
                if w and w > 1 then
                    limit = zoneNumber(WorldUtil.lastZone(w)) or CONFIG.MAX_ZONE
                end
            end
            State.zoneLimit = limit

            if ownsW4 and rank >= 20 then
                autoStopForRank()
                return
            end

            if State.forcePhase then
                State.phase = State.forcePhase
            elseif not (s and ownsZone("Colorful Clouds")) then
                State.phase = 1
                State.rankTarget = 8
            elseif rank < 8 then
                State.phase = 2
                State.rankTarget = 8
            elseif not ownsW4 then
                State.phase = 1
                State.rankTarget = 20
            else
                State.phase = 2
                State.rankTarget = 20
            end

            if os.clock() - State.lastAnim > 20 then
                State.lastAnim = os.clock()
                killEggAnimation()
            end

            if State.manual then
                return
            end

            if actionBusy() then
                if State.phase == 2 and State.actionRank then
                    local now2 = os.clock()
                    for _, g in ipairs(readGoals()) do
                        local done = (g.amount or 0) > 0 and (g.progress or 0) >= (g.amount or 0)
                        if not GOAL_SKIP[g.type] and not done then
                            local fail = State.goalFails[g.key]
                            if not fail or fail.expire < now2 then
                                local rank = GOAL_PRIORITY[g.type] or 50
                                if rank < State.actionRank then
                                    State.preempt = true
                                end
                                break
                            end
                        end
                    end
                end
                return
            end

            if State.phase == 2 then
                phaseTwoStep()
            else
                phaseOneStep()
            end

            if os.clock() - State.lastProgress > CONFIG.STUCK_TNT_AFTER then
                setStatus("Stuck - TNT crate")
                useTnt(true)
                State.lastProgress = os.clock()
            end
        end)
        if not ok then
            setStatus("Error: " .. tostring(err))
        end
        task.wait(0.35)
    end
end

local function orbLoop()
    while alive() do
        task.wait(1)
        if State.on and State.orbsEnabled then
            if os.clock() - State.lastOrb > CONFIG.ORB_SWEEP_EVERY then
                -- skip only while an action is busy doing its own teleports
                -- (machines/flags/summons); egg hatching is marked safe
                local busyTeleporting = actionBusy() and not State.actionSafeForOrbs
                if not busyTeleporting then
                    State.lastOrb = os.clock()
                    pcall(collectOrbs, CONFIG.ORB_BATCH)
                end
            end
        end
    end
end

local function backgroundLoop()
    while alive() do
        local ok, err = pcall(backgroundTick)
        if not ok then
            setStatus("Background error: " .. tostring(err))
        end
        task.wait(1)
    end
end

local tapTargets = {}
local tapTargetsAt = 0
local tapFocus = nil

local function refreshTapTargets()
    local now = os.clock()
    if now - tapTargetsAt < 0.4 then
        return
    end
    tapTargetsAt = now
    tapTargets = nearestBreakables(8)
end

local function targetAlive(b)
    return b ~= nil and b.uid ~= nil and b.model ~= nil and b.model.Parent ~= nil
end

-- Taps go all into one breakable until it pops, then the next nearest one.
-- Spread over the whole area it just chips eight things at once and takes
-- longer to break anything.
local function liveTapTarget()
    if targetAlive(tapFocus) then
        return tapFocus
    end
    tapFocus = nil
    tapTargetsAt = 0
    refreshTapTargets()
    for _, b in ipairs(tapTargets) do
        if targetAlive(b) then
            tapFocus = b
            return b
        end
    end
    return nil
end

local function tapLoop()
    local accum = 0
    local last = os.clock()
    while alive() do
        task.wait(0.05)
        -- use the real elapsed time, not just the wait: the scan work above
        -- would otherwise be invisible and the rate would come out too low
        local now = os.clock()
        local dt = now - last
        last = now
        if State.on and not State.pauseTaps then
            refreshFarm(false)
            refreshTapTargets()
            -- pets pick the breakable closest to them, so the character parks
            -- right on the tap focus: then it is the nearest target for the
            -- whole pack and they all chew the same one until it pops
            local h = hrp()
            if tapFocus and targetAlive(tapFocus) and h
                and (h.Position - tapFocus.pos).Magnitude > 5
                and now - (State.lastPetNudge or 0) > 0.5 then
                State.lastPetNudge = now
                -- anchor-free hop: this can fire once per breakable and
                -- anchoring each time would stack up
                teleport(CFrame.new(tapFocus.pos + Vector3.new(0, 2, 0)), false)
            end
            if #tapTargets > 0 then
                accum = accum + dt
                local interval = 1 / math.max(1, State.tapRate or CONFIG.TAPS_PER_SECOND)
                while accum >= interval do
                    accum = accum - interval
                    State.tapTries = (State.tapTries or 0) + 1
                    local b = liveTapTarget()
                    if not b then
                        -- every cached model died; rescan right now and retry
                        State.tapSkips = (State.tapSkips or 0) + 1
                        tapTargetsAt = 0
                        refreshTapTargets()
                        b = liveTapTarget()
                    end
                    if b then
                        tapUid(b.uid)
                    end
                end
            end
        else
            accum = 0
        end
    end
end
---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------

local function enforceSettings()
    local want = {
        EggPotatoMode = "On",
        -- PotatoMode stays as the player set it: it culls pet models, which
        -- makes it look like nothing is equipped
        ReduceOrbs = "On",
    }
    for key, value in pairs(want) do
        local ok, current = pcall(SettingsCmds.Get, key)
        if ok and current and current ~= value then
            pcall(Network.Invoke, "Toggle Setting", key)
            task.wait(0.25)
        end
    end
    killEggAnimation()
end

local function startEngine()
    if rankFinished() then
        autoStopForRank()
        return
    end
    State.on = true
    State.lastProgress = os.clock()
    setStatus("Starting...")
    runAction(enforceSettings)
end

local function stopEngine()
    State.on = false
    if rankFinished() then
        setStatus("Rank 8 reached - finished")
    else
        setStatus("Off")
    end
    setQuest("")
end

local function makeOpenButton(Window)
    local parent
    if gethui then
        local ok, hidden = pcall(gethui)
        if ok and hidden then
            parent = hidden
        end
    end
    if not parent then
        local ok, core = pcall(function()
            return game:GetService("CoreGui")
        end)
        if ok then
            parent = core
        end
    end
    if not parent then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    local sg = Instance.new("ScreenGui")
    sg.Name = "datdanillashrek_button"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 2147483647
    sg.Parent = parent

    local btn = Instance.new("ImageButton")
    btn.Name = "Toggle"
    btn.Size = UDim2.fromOffset(52, 52)
    btn.Position = UDim2.new(1, -66, 0, 8)
    btn.BackgroundTransparency = 1
    btn.Image = CONFIG.ICON_IMAGE
    btn.ImageTransparency = 0
    btn.ScaleType = Enum.ScaleType.Fit
    btn.AutoButtonColor = true
    btn.BorderSizePixel = 0
    btn.Parent = sg

    btn.MouseButton1Click:Connect(function()
        if Window.Closed then
            pcall(function() Window:Open() end)
        else
            pcall(function() Window:Close() end)
        end
        task.delay(0.06, function()
            if UI.applyBackground then
                pcall(UI.applyBackground)
            end
        end)
    end)

    UI.openButton = sg
    return sg
end

local function createMainWindow(WindUI)
    local ok, Window = pcall(WindUI.CreateWindow, WindUI, {
        Title = CONFIG.NAME,
        Icon = "shapes",
        Folder = CONFIG.NAME,
        Size = UDim2.fromOffset(430, 270),
        Theme = "Dark",
        HideSearchBar = true,
        CanResize = false,
        Transparent = false,
        Acrylic = false,
        SideBarWidth = 96,
    })
    if not ok or not Window then
        log("CreateWindow failed: " .. tostring(Window))
        return nil
    end
    UI.window = Window
    pcall(function() Window:SetBackgroundImage(CONFIG.BACKGROUND_IMAGE) end)
    pcall(function() Window:SetBackgroundImageTransparency(0.72) end)
    pcall(function() makeOpenButton(Window) end)
    pcall(function() Window:DisableTopbarButtons(true) end)
    pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)
    return Window
end

local function hideStaleWindows()
    local el = UI.quest and UI.quest.ElementFrame
    if not el then
        return
    end
    local node = el
    local folder = nil
    while node do
        local parent = node.Parent
        if parent and parent.Name == "Window" and parent.ClassName == "Folder" then
            folder = parent
            break
        end
        node = parent
    end
    if not folder or not node then
        return
    end
    for _, frame in ipairs(folder:GetChildren()) do
        if frame ~= node then
            pcall(function()
                frame.Visible = false
            end)
        end
    end
end

local function findWindowFrame()
    local el = UI.quest and UI.quest.ElementFrame
    if not el then
        return nil
    end
    local node = el
    while node do
        local parent = node.Parent
        if parent and parent.Name == "Window" and parent.ClassName == "Folder" then
            return node
        end
        node = parent
    end
    return nil
end

local function applyWindowBackground()
    local bg = UI.bgLabel
    if not (bg and bg.Parent) then
        local frame = findWindowFrame()
        if not frame then
            return
        end
        local main = frame:FindFirstChild("Main")
        local content
        if main then
            for _, child in ipairs(main:GetChildren()) do
                if child:IsA("Frame") and child:FindFirstChild("Background") then
                    content = child
                    break
                end
            end
        end
        bg = content and content:FindFirstChild("Background")
        UI.bgLabel = bg
        local scrim = frame:FindFirstChild("__dd_scrim")
        if scrim then
            scrim:Destroy()
        end
    end
    if bg and bg:IsA("ImageLabel") and bg.Image ~= CONFIG.BACKGROUND_IMAGE then
        bg.Image = CONFIG.BACKGROUND_IMAGE
        bg.ScaleType = Enum.ScaleType.Crop
        bg.ImageTransparency = 0.25
        bg.ImageColor3 = Color3.fromRGB(110, 110, 110)
    end
end

-- WindUI re-renders the panel background (tab switch, close/open, theme tick)
-- and drops our picture, so keep re-applying it.
local function uiLoop()
    while alive() do
        task.wait(0.1)
        pcall(applyWindowBackground)
    end
end

local function buildMainTab(Window)
    local Tab = Window:Tab({ Title = "Main", Icon = "home" })

    Tab:Section({ Title = "Rank" })

    -- one switch drives the whole run: 98 -> rank 8 -> world 4 -> rank 20
    local toggle = Tab:Toggle({
        Title = "datdanillarank",
        Value = false,
        Callback = function(v)
            if State.syncUi then
                return
            end
            if v then
                startEngine()
            else
                stopEngine()
            end
        end,
    })

    local quest = Tab:Paragraph({ Title = "Quest", Desc = "-" })
    local phase = Tab:Paragraph({ Title = "Phase", Desc = "-" })
    local status = Tab:Paragraph({ Title = "Status", Desc = "Off" })

    UI.toggle = toggle
    UI.quest = quest
    UI.phase = phase
    UI.status = status
    UI.ready = true

    pcall(function() Window:SetSize(UDim2.fromOffset(430, 420)) end)
    pcall(function() Tab:Select() end)
    pcall(hideStaleWindows)
    pcall(applyWindowBackground)
    UI.applyBackground = applyWindowBackground
    return Tab
end

-- The key comes from the loader line:
--   script_key = "the-key-i-gave-you";
--   loadstring(game:HttpGet("...DatDanillaHub.luau"))()
local function readLoaderKey()
    local key
    if getgenv then
        key = getgenv().script_key
    end
    if (not key or key == "") and type(_G) == "table" then
        key = _G.script_key
    end
    if not key or key == "" then
        local ok, value = pcall(function()
            return script_key
        end)
        if ok then
            key = value
        end
    end
    return tostring(key or "")
end

local function showKeyError(message)
    local parent
    if gethui then
        local ok, hidden = pcall(gethui)
        if ok and hidden then
            parent = hidden
        end
    end
    if not parent then
        parent = game:GetService("CoreGui")
    end
    local sg = Instance.new("ScreenGui")
    sg.Name = "DatDanillaHub_key"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 2147483647
    sg.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(430, 96)
    frame.Position = UDim2.new(0.5, -215, 0, 88)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 1.5
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 0, 28)
    title.Position = UDim2.fromOffset(12, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "DatDanillaHub"
    title.Parent = frame

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -24, 0, 44)
    body.Position = UDim2.fromOffset(12, 38)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.Gotham
    body.TextSize = 13
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextColor3 = Color3.fromRGB(220, 220, 225)
    body.Text = message
    body.Parent = frame

    task.delay(12, function()
        pcall(function()
            sg:Destroy()
        end)
    end)
end

local function retireOldWindUI()
    local core = game:GetService("CoreGui")
    local robloxGui = core and core:FindFirstChild("RobloxGui")
    if not robloxGui then
        return
    end
    local index = 0
    for _, child in ipairs(robloxGui:GetChildren()) do
        if child.Name == "WindUI" or string.find(child.Name, "WindUI_old", 1, true) then
            index = index + 1
            pcall(function()
                child.Enabled = false
                child.Name = "WindUI_old_" .. index
            end)
        end
    end
end

local function buildFallbackUI()
    local parent
    if gethui then
        local ok, hidden = pcall(gethui)
        if ok and hidden then
            parent = hidden
        end
    end
    if not parent then
        parent = game:GetService("CoreGui")
    end

    local existing = parent:FindFirstChild("datdanillashrek_fallback")
    if existing then
        existing:Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "datdanillashrek_fallback"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 2147483646
    sg.Parent = parent

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(300, 170)
    panel.Position = UDim2.new(0.5, -150, 0.5, -85)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.fromOffset(10, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = CONFIG.NAME
    title.Parent = panel

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -20, 0, 40)
    toggleBtn.Position = UDim2.fromOffset(10, 40)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.Text = "datdanillarank: OFF"
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = panel

    local function label(y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 22)
        l.Position = UDim2.fromOffset(10, y)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Color3.fromRGB(190, 190, 200)
        l.Text = "-"
        l.Parent = panel
        return l
    end

    local questL = label(88)
    local phaseL = label(110)
    local statusL = label(132)

    local toggleObj = { Value = false }
    function toggleObj:Set(value)
        self.Value = value and true or false
        toggleBtn.Text = "datdanillarank: " .. (self.Value and "ON" or "OFF")
        toggleBtn.BackgroundColor3 = self.Value and Color3.fromRGB(30, 120, 70) or Color3.fromRGB(34, 34, 40)
        if self.Value then
            startEngine()
        else
            stopEngine()
        end
    end

    toggleBtn.MouseButton1Click:Connect(function()
        toggleObj:Set(not toggleObj.Value)
    end)

    local openBtn = Instance.new("ImageButton")
    openBtn.Size = UDim2.fromOffset(52, 52)
    openBtn.Position = UDim2.new(1, -66, 0, 8)
    openBtn.BackgroundTransparency = 1
    openBtn.Image = CONFIG.ICON_IMAGE
    openBtn.ScaleType = Enum.ScaleType.Fit
    openBtn.BorderSizePixel = 0
    openBtn.Parent = sg
    openBtn.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
    end)

    UI.fallback = sg
    UI.toggle = toggleObj
    UI.quest = { SetDesc = function(_, t) questL.Text = tostring(t) end }
    UI.phase = { SetDesc = function(_, t) phaseL.Text = tostring(t) end }
    UI.status = { SetDesc = function(_, t) statusL.Text = tostring(t) end }
    UI.ready = true
end

local function boot()
    retireOldWindUI()
    local ok, WindUI = pcall(function()
        local src = game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
        return loadstring(src)()
    end)
    if ok and type(WindUI) == "table" then
        getgenv().DATDANILLA_WINDUI = WindUI
    end
    ACTIVE_KEYS = fetchKeys()
    if #ACTIVE_KEYS == 0 then
        log("blocked: keys.txt could not be loaded")
        showKeyError("The key list could not be loaded. Check that keys.txt exists at the CONFIG.KEY_URL.")
        return
    end

    local providedKey = readLoaderKey()
    if not isKeyValid(providedKey) then
        log("blocked: missing or invalid script_key")
        showKeyError(
            providedKey == ""
                and 'No key found. Use the loader and put your key inside the quotes: script_key = "your-key"'
                or 'This key is invalid or was removed. Put the new key in your loader line.'
        )
        return
    end
    LOADER_KEY = providedKey

    local Window = nil
    if ok and type(WindUI) == "table" then
        if WindUI.ScreenGui then
            WindUI.ScreenGui.Enabled = true
        end
        Window = createMainWindow(WindUI)
    end

    if Window then
        buildMainTab(Window)
    else
        log("WindUI unavailable, fallback UI")
        buildFallbackUI()
    end

    pcall(function()
        Network.Fired("Breakables_Destroyed"):Connect(function()
            State.lastProgress = os.clock()
        end)
    end)
    pcall(function()
        Network.Fired("Zones_PurchaseComplete"):Connect(function()
            -- the egg counter is per area, so a new area starts at zero on its
            -- own; nothing to reset here
        end)
    end)

    -- Roblox disconnects a client that shows no input for a while, and this
    -- game turns that into a full rejoin. A quiet virtual click every minute
    -- keeps the session alive without moving the character.
    local function antiAfkLoop()
        local vu = nil
        pcall(function()
            vu = game:GetService("VirtualUser")
        end)

        local function nudge()
            if vu then
                pcall(function()
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new(1, 1))
                end)
            end
            pcall(function()
                if mousemoverel then
                    mousemoverel(3, 1)
                end
            end)
            -- a real key event is what Roblox's own idle timer looks at. use a
            -- key the UI does not bind: RightShift is WindUI's window toggle,
            -- which is why the panel kept opening and closing by itself.
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.RightAlt, false, game)
                vim:SendKeyEvent(false, Enum.KeyCode.RightAlt, false, game)
            end)
        end

        pcall(function()
            LocalPlayer.Idled:Connect(nudge)
        end)
        while alive() do
            task.wait(45)
            nudge()
        end
    end

    task.spawn(tapLoop)
    task.spawn(backgroundLoop)
    task.spawn(orbLoop)
    task.spawn(uiLoop)
    task.spawn(antiAfkLoop)

    -- the mode comes up enabled; it turns itself off once world 4 and rank 20
    -- are both done
    State.syncUi = true
    pcall(function()
        if UI.toggle then
            UI.toggle:Set(true)
        end
    end)
    State.syncUi = false
    startEngine()

    log("loaded v" .. CONFIG.VERSION)
    mainLoop()
end

local function unload()
    if getgenv().DATDANILLA_GEN == GEN then
        getgenv().DATDANILLA_GEN = GEN + 1
    end
    State.on = false
    UI.ready = false
    local win, keyWin = UI.window, UI.keyWindow
    local openButton = UI.openButton
    local fallback = UI.fallback
    UI.fallback = nil
    if fallback then
        pcall(function() fallback:Destroy() end)
    end
    UI.window = nil
    UI.keyWindow = nil
    UI.openButton = nil
    task.spawn(function()
        if openButton then
            pcall(function() openButton:Destroy() end)
        end
        if keyWin then
            pcall(function() keyWin:Destroy() end)
        end
        if win then
            pcall(function() win:Destroy() end)
        end
    end)
end

getgenv().DATDANILLA_STATE = State
getgenv().DATDANILLA_UI = UI
getgenv().DATDANILLA_DEBUG = {
    readGoals = readGoals,
    runGoal = runGoal,
    tpToZone = tpToZone,
    hatchEggs = hatchEggs,
    bestEggFor = bestEggFor,
    bestZone = bestZone,
    ensureEnchantLoadout = ensureEnchantLoadout,
    setStatus = setStatus,
    setQuest = setQuest,
    setPhase = setPhase,
    collectOrbs = collectOrbs,
    crawlUpgrades = crawlUpgrades,
    buyAllUpgradesHere = buyAllUpgradesHere,
}
getgenv().DATDANILLA_UNLOAD = unload

if STATE and type(STATE) == "table" and type(STATE.onCleanup) == "function" then
    STATE.onCleanup(unload)
end

boot()
