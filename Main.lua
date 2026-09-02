-- ============================================================
-- Pria Solo HUB - Rayfield GEN2 (Final, tanpa SetValue)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local CONFIG_FILE = "PriaSolo.json"

-- Load Rayfield GEN2
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
if not Rayfield then warn("❌ Gagal memuat Rayfield") return end
print("✅ Rayfield berhasil dimuat")

-- Load DataPetModule
local DataPetModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/DataPetModule.lua"))()
if not DataPetModule then warn("❌ Gagal memuat DataPetModule") return end
print("✅ DataPetModule berhasil dimuat")

-- Load SharkLogic
local SharkLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/okegasscript/PriaSolo/refs/heads/main/SharkLogic.lua"))()
if not SharkLogic then warn("❌ Gagal memuat SharkLogic") return end
print("✅ SharkLogic berhasil dimuat")

-- ============================================================
-- FUNGSI BANTUAN
-- ============================================================

local function formatPetLabel(pet)
    local mut = pet.mutation or "Normal"
    local name = pet.name or "Unknown"
    local weight = pet.weight or 0
    if weight <= 0 then
        local baseWeight = (pet.petData and pet.petData.BaseWeight) or 0
        local level = pet.level or 1
        weight = baseWeight + (level - 1) * 0.5599
    end
    local level = pet.level or 1
    return string.format("%s %s %.2f KG Lv.%d", mut, name, weight, level)
end

local function sortAlphabetically(a, b)
    return string.lower(a) < string.lower(b)
end

local function uniqueTable(t)
    local seen = {}
    local result = {}
    for _, v in ipairs(t) do
        if not seen[v] then
            seen[v] = true
            table.insert(result, v)
        end
    end
    return result
end

-- ============================================================
-- STATE
-- ============================================================

local state = {
    selectedMimicUUID = nil,
    selectedSharkUUID = nil,
    targetQueue = {},
    currentTargetIndex = 1,
    tumbalNames = {"Dog"},
    minLevel = 100,
    isSharkActive = false,
    isProcessing = false,
    currentTumbalUUID = nil,
    currentTargetUUID = nil,
    cycleCount = 0,
    lastActionTime = 0,
    levelingTim = {},
    levelingTargets = {},
    targetLevel = 100,
    isLevelingActive = false,
    pnpPets = {},
    pnpPickupDelay = 0.6,
    pnpPlaceDelay = 0,
    pnpActive = false,
    pnpProcessing = {},
}

local isLevelingProcessing = false
local isUnequipping = false

-- ============================================================
-- EVENT SERVICE
-- ============================================================

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PetCooldownsEvent = GameEvents:WaitForChild("PetCooldownsUpdated")
local PetsService = GameEvents:WaitForChild("PetsService")
local NotificationEvent = GameEvents:WaitForChild("Notification")

-- ============================================================
-- FUNGSI UNEQUIP SELEKTIF
-- ============================================================

local function unequipAllGardenPets(keepUUIDs, timeout)
    timeout = timeout or 0.5
    if isUnequipping then return end
    isUnequipping = true

    keepUUIDs = keepUUIDs or {}
    local keepMap = {}
    for _, uuid in ipairs(keepUUIDs) do
        keepMap[uuid] = true
    end

    local data = DataPetModule.getAllPets()
    if not data then
        isUnequipping = false
        return
    end
    local equipped = data.PetsData and data.PetsData.EquippedPets
    if not equipped or type(equipped) ~= "table" then
        isUnequipping = false
        return
    end

    equipped = uniqueTable(equipped)
    local toUnequip = {}
    for _, uuid in ipairs(equipped) do
        if not keepMap[uuid] then
            table.insert(toUnequip, uuid)
        end
    end

    if #toUnequip > 0 then
        print("🔄 Unequip " .. #toUnequip .. " pet (timeout " .. timeout .. "s)")
        local startTime = os.clock()
        for i, uuid in ipairs(toUnequip) do
            if os.clock() - startTime > timeout then
                print("⏹️ Unequip dihentikan (timeout) - sisa " .. (#toUnequip - i + 1) .. " pet")
                break
            end
            SharkLogic.unequipPet(PetsService, uuid)
            task.wait(0.05)
        end
    else
        print("✅ Tidak ada pet yang perlu diunequip")
    end

    isUnequipping = false
end

-- ============================================================
-- FUNGSI LOGIKA AUTO SHARK
-- ============================================================

local function unequipTargetAndEquipShark()
    if state.isSharkActive == false then return end
    if state.currentTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentTargetUUID)
        state.currentTargetUUID = nil
        task.wait(0.05)
    end
    if state.currentTumbalUUID then
        SharkLogic.unequipPet(PetsService, state.currentTumbalUUID)
        state.currentTumbalUUID = nil
        task.wait(0.05)
    end
    if state.selectedSharkUUID then
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        task.wait(0.05)
    end
    state.isProcessing = false
end

local function getNextTarget()
    if #state.targetQueue == 0 then return nil end
    local target = state.targetQueue[state.currentTargetIndex]
    state.currentTargetIndex = state.currentTargetIndex + 1
    if state.currentTargetIndex > #state.targetQueue then
        state.currentTargetIndex = 1
    end
    return target
end

local function unequipSharkAndEquipTumbalTarget()
    if not state.selectedSharkUUID then
        print("⚠️ Shark belum dipilih")
        return
    end
    local targetUUID = getNextTarget()
    if not targetUUID then
        print("⚠️ Tidak ada target tersedia")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
        return
    end

    local tumbalUUID = SharkLogic.findTumbal(
        DataPetModule,
        state.tumbalNames,
        {state.selectedMimicUUID, state.selectedSharkUUID},
        state.minLevel or 0
    )

    if tumbalUUID and targetUUID then
        SharkLogic.unequipPet(PetsService, state.selectedSharkUUID)
        task.wait(0.05)
        SharkLogic.equipPet(PetsService, tumbalUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTumbalUUID = tumbalUUID
        task.wait(0.05)
        SharkLogic.equipPet(PetsService, targetUUID, SharkLogic.defaultConfig.slotCFrame)
        state.currentTargetUUID = targetUUID
        state.isProcessing = true
        print("✅ Equip tumbal & target (target #" .. state.currentTargetIndex .. "/" .. #state.targetQueue .. ")")
    else
        print("⚠️ Tumbal atau target tidak ditemukan")
        SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
        state.isProcessing = false
    end
end

-- ============================================================
-- FUNGSI LOGIKA AUTO LEVELING & PNP
-- ============================================================

local function getPetLevel(uuid)
    local data = DataPetModule.getAllPets()
    if not data then return 0 end
    local pet = data[uuid]
    if pet and pet.PetData then
        return pet.PetData.Level or pet.PetData.Lvl or 0
    end
    return 0
end

local function unequipLevelingTarget()
    if state.currentLevelingTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentLevelingTargetUUID)
        state.currentLevelingTargetUUID = nil
        task.wait(0.05)
    end
end

local function equipLevelingTim()
    for _, uuid in ipairs(state.levelingTim) do
        SharkLogic.equipPet(PetsService, uuid, SharkLogic.defaultConfig.slotCFrame)
        task.wait(0.05)
    end
end

local function processLeveling()
    if not state.isLevelingActive or isLevelingProcessing then return end
    isLevelingProcessing = true

    while state.isLevelingActive do
        if #state.levelingTargets == 0 then
            print("✅ Semua target selesai")
            state.isLevelingActive = false
            break
        end

        local targetUUID = state.levelingTargets[state.currentLevelingTargetIndex]
        if not targetUUID then
            state.currentLevelingTargetIndex = 1
            targetUUID = state.levelingTargets[1]
        end

        local currentLevel = getPetLevel(targetUUID)
        if currentLevel >= state.targetLevel then
            print("✅ Target sudah mencapai level", state.targetLevel, "- lewati")
            unequipLevelingTarget()
            state.currentLevelingTargetIndex = state.currentLevelingTargetIndex + 1
            if state.currentLevelingTargetIndex > #state.levelingTargets then
                state.currentLevelingTargetIndex = 1
            end
            continue
        end

        if state.currentLevelingTargetUUID ~= targetUUID then
            unequipLevelingTarget()
            SharkLogic.equipPet(PetsService, targetUUID, SharkLogic.defaultConfig.slotCFrame)
            state.currentLevelingTargetUUID = targetUUID
            print("📈 Equip target leveling:", targetUUID, "Level:", currentLevel, "/", state.targetLevel)
        end

        for _ = 1, 2 do
            if not state.isLevelingActive then break end
            task.wait(1)
        end
    end

    isLevelingProcessing = false
end

local function startLeveling()
    if isLevelingProcessing then
        state.isLevelingActive = false
        task.wait(0.2)
    end

    if #state.levelingTim == 0 then
        print("⚠️ Tim leveling kosong!")
        return
    end
    if #state.levelingTargets == 0 then
        print("⚠️ Target leveling kosong!")
        return
    end

    unequipAllGardenPets(state.levelingTim, 1.0)
    task.wait(0.2)

    equipLevelingTim()
    print("✅ Tim leveling di-equip")

    state.currentLevelingTargetIndex = 1
    state.isLevelingActive = true
    print("▶️ Auto Leveling dimulai")
    task.spawn(processLeveling)
end

local function stopLeveling()
    state.isLevelingActive = false
    while isLevelingProcessing do task.wait(0.1) end

    if state.currentLevelingTargetUUID then
        SharkLogic.unequipPet(PetsService, state.currentLevelingTargetUUID)
        state.currentLevelingTargetUUID = nil
        task.wait(0.05)
    end

    for _, uuid in ipairs(state.levelingTim) do
        SharkLogic.unequipPet(PetsService, uuid)
        task.wait(0.05)
    end

    unequipAllGardenPets({}, 1.0)
    print("⏹️ Auto Leveling dihentikan, semua pet diunequip.")
end

local function pnpProcessPet(uuid)
    if state.pnpProcessing[uuid] then return end
    state.pnpProcessing[uuid] = true

    local pickupDelay = state.pnpPickupDelay or 0.6
    local placeDelay = state.pnpPlaceDelay or 0

    task.wait(pickupDelay)
    SharkLogic.unequipPet(PetsService, uuid)

    task.wait(placeDelay)
    SharkLogic.equipPet(PetsService, uuid, SharkLogic.defaultConfig.slotCFrame)

    state.pnpProcessing[uuid] = false
end

-- ============================================================
-- EVENT LISTENER (Cooldown)
-- ============================================================

local isHandlingCooldownEvent = false

PetCooldownsEvent.OnClientEvent:Connect(function(petId, dataArray)
    if state.pnpActive and petId and state.pnpPets and type(state.pnpPets) == "table" then
        for _, uuid in ipairs(state.pnpPets) do
            if petId == uuid then
                local time = nil
                for _, entry in ipairs(dataArray) do
                    if entry.Time then time = entry.Time break end
                end
                if time == nil then return end
                if time <= 0.1 and not state.pnpProcessing[uuid] then
                    task.spawn(function()
                        pnpProcessPet(uuid)
                    end)
                end
                break
            end
        end
    end

    if state.isSharkActive and petId == state.selectedMimicUUID and not isHandlingCooldownEvent then
        local time = nil
        for _, entry in ipairs(dataArray) do
            if entry.Time then time = entry.Time break end
        end
        if time == nil then return end

        if state.isProcessing and time > 0.1 then
            isHandlingCooldownEvent = true
            pcall(unequipTargetAndEquipShark)
            isHandlingCooldownEvent = false
        end

        if not state.isProcessing and time <= 0.1 then
            local now = os.clock()
            if now - state.lastActionTime < 0.5 then return end
            state.lastActionTime = now
            isHandlingCooldownEvent = true
            task.spawn(function()
                task.wait(0.6)
                pcall(unequipSharkAndEquipTumbalTarget)
                isHandlingCooldownEvent = false
            end)
        end
    end
end)

NotificationEvent.OnClientEvent:Connect(function(message)
    if state.isSharkActive and state.isProcessing and type(message) == "string" and string.find(message, "Mimic Octopus") then
        if string.find(message, "spat its Blossoming mutation onto") or string.find(message, "mutation failed to transfer") then
            unequipTargetAndEquipShark()
        end
    end
end)

-- ============================================================
-- FUNGSI UNTUK MENGAMBIL DATA DROPDOWN
-- ============================================================

local function getOptionsFor(type, filter)
    filter = filter or ""
    local hasil = {}
    if type == "mimic" then
        hasil = DataPetModule.findPets({ name = "Mimic", isFavorite = true })
    elseif type == "shark" then
        hasil = DataPetModule.findPets({ name = "Shark", isFavorite = true })
    elseif type == "target" then
        hasil = DataPetModule.findPets({
            type = "Mimic Octopus",
            isFavorite = false,
            mutation = "Normal",
            excludeUUIDs = {state.selectedMimicUUID, state.selectedSharkUUID}
        })
    elseif type == "tim" then
        hasil = DataPetModule.findPets({ isFavorite = true })
    elseif type == "targetlevel" then
        hasil = DataPetModule.findPets({ isFavorite = false })
    elseif type == "pnp" then
        hasil = DataPetModule.findPets({ isFavorite = true })
    end
    local options = {}
    local map = {}
    for _, pet in ipairs(hasil) do
        local label = formatPetLabel(pet)
        if string.lower(label):find(string.lower(filter)) then
            if map[label] then
                label = label .. " [" .. string.sub(pet.uuid, 1, 4) .. "]"
            end
            table.insert(options, label)
            map[label] = pet.uuid
        end
    end
    table.sort(options, sortAlphabetically)
    if #options == 0 then
        options = {"❌ Tidak ada data"}
    end
    return options, map
end

-- ============================================================
-- UI (RAYFIELD GEN2)
-- ============================================================

local Window = Rayfield:CreateWindow({
    name = "Pria Solo HUB",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "Settings",
        customFolder = "PriaSolo",
    },
    key = Enum.KeyCode.K,
})

-- Variabel untuk dropdown dan toggle
local MimicDropdown, SharkDropdown, TargetDropdown
local TimDropdown, TargetLevelDropdown, PnpDropdown
local SharkToggle, LevelingToggle, PnpToggle
local TumbalInput, MinLevelSlider, TargetLevelSlider

-- ============================================================
-- UPDATE UI (hanya refresh options dropdown, tidak set value)
-- ============================================================

local function updateAllUI()
    if MimicDropdown then
        MimicDropdown:Refresh(getOptionsFor("mimic"))
    end
    if SharkDropdown then
        SharkDropdown:Refresh(getOptionsFor("shark"))
    end
    if TargetDropdown then
        TargetDropdown:Refresh(getOptionsFor("target"))
    end
    if TimDropdown then
        TimDropdown:Refresh(getOptionsFor("tim"))
    end
    if TargetLevelDropdown then
        TargetLevelDropdown:Refresh(getOptionsFor("targetlevel"))
    end
    if PnpDropdown then
        PnpDropdown:Refresh(getOptionsFor("pnp"))
    end
end

-- ============================================================
-- TAB 1: AUTO SHARK
-- ============================================================

local sharkTab = Window:CreateTab({ name = "Auto Shark", icon = "shark" })

sharkTab:CreateInput({
    name = "🔍 Cari Mimic",
    placeholder = "Filter...",
    value = "",
    flag = "mimicFilter",
    callback = function(v)
        if MimicDropdown then
            local opts, map = getOptionsFor("mimic", v)
            MimicDropdown:Refresh(opts)
            _G._mimicMap = map
        end
    end
})

MimicDropdown = sharkTab:CreateDropdown({
    name = "Pilih Mimic",
    options = getOptionsFor("mimic"),
    value = "",
    multiSelect = false,
    flag = "mimicDropdown",
    callback = function(val)
        local map = _G._mimicMap or {}
        local uuid = map[val]
        if uuid then
            state.selectedMimicUUID = uuid
            print("✅ Mimic:", val, "UUID:", uuid)
            saveConfig()
        end
    end
})

sharkTab:CreateInput({
    name = "🔍 Cari Shark",
    placeholder = "Filter...",
    value = "",
    flag = "sharkFilter",
    callback = function(v)
        if SharkDropdown then
            local opts, map = getOptionsFor("shark", v)
            SharkDropdown:Refresh(opts)
            _G._sharkMap = map
        end
    end
})

SharkDropdown = sharkTab:CreateDropdown({
    name = "Pilih Shark",
    options = getOptionsFor("shark"),
    value = "",
    multiSelect = false,
    flag = "sharkDropdown",
    callback = function(val)
        local map = _G._sharkMap or {}
        local uuid = map[val]
        if uuid then
            state.selectedSharkUUID = uuid
            print("✅ Shark:", val, "UUID:", uuid)
            saveConfig()
        end
    end
})

sharkTab:CreateInput({
    name = "🔍 Cari Target",
    placeholder = "Filter...",
    value = "",
    flag = "targetFilter",
    callback = function(v)
        if TargetDropdown then
            local opts, map = getOptionsFor("target", v)
            TargetDropdown:Refresh(opts)
            _G._targetMap = map
        end
    end
})

TargetDropdown = sharkTab:CreateDropdown({
    name = "Pilih Target (Multiple, Non-Fav, Normal)",
    options = getOptionsFor("target"),
    value = {},
    multiSelect = true,
    flag = "targetDropdown",
    callback = function(vals)
        local map = _G._targetMap or {}
        state.targetQueue = {}
        for _, label in ipairs(vals) do
            local uuid = map[label]
            if uuid then table.insert(state.targetQueue, uuid) end
        end
        state.currentTargetIndex = 1
        print("✅ Target dipilih:", #state.targetQueue)
        saveConfig()
    end
})

TumbalInput = sharkTab:CreateInput({
    name = "Nama Tumbal (pisah koma)",
    placeholder = "Dog, Cat, Bunny",
    value = table.concat(state.tumbalNames, ", "),
    flag = "tumbalInput",
    callback = function(v)
        local names = {}
        for token in string.gmatch(v, "[^,]+") do
            local trimmed = token:match("^%s*(.-)%s*$")
            if trimmed ~= "" then table.insert(names, trimmed) end
        end
        if #names > 0 then
            state.tumbalNames = names
            print("✅ Tumbal:", table.concat(names, ", "))
            saveConfig()
        end
    end
})

MinLevelSlider = sharkTab:CreateSlider({
    name = "Min Level Tumbal",
    min = 0,
    max = 500,
    increment = 1,
    value = state.minLevel,
    flag = "minLevelSlider",
    callback = function(v)
        state.minLevel = v
        print("📊 Min Level:", v)
        saveConfig()
    end
})

SharkToggle = sharkTab:CreateToggle({
    name = "▶️ Start / Stop Shark",
    value = state.isSharkActive,
    flag = "sharkToggle",
    callback = function(v)
        state.isSharkActive = v
        if v then
            print("▶️ Shark ON")
            unequipAllGardenPets({state.selectedMimicUUID, state.selectedSharkUUID}, 1.0)
            task.wait(0.2)
            if state.selectedMimicUUID then
                SharkLogic.equipPet(PetsService, state.selectedMimicUUID, SharkLogic.defaultConfig.slotCFrame)
            end
            if state.selectedSharkUUID then
                SharkLogic.equipPet(PetsService, state.selectedSharkUUID, SharkLogic.defaultConfig.slotCFrame)
            end
            state.isProcessing = false
            state.cycleCount = 0
        else
            print("⏹️ Shark OFF")
            state.isSharkActive = false
            unequipTargetAndEquipShark()
            unequipAllGardenPets({}, 1.0)
        end
        saveConfig()
    end
})

-- ============================================================
-- TAB 2: AUTO LEVELING
-- ============================================================

local levelingTab = Window:CreateTab({ name = "Auto Leveling", icon = "rocket" })

levelingTab:CreateInput({
    name = "🔍 Cari Tim",
    placeholder = "Filter...",
    value = "",
    flag = "timFilter",
    callback = function(v)
        if TimDropdown then
            local opts, map = getOptionsFor("tim", v)
            TimDropdown:Refresh(opts)
            _G._timMap = map
        end
    end
})

TimDropdown = levelingTab:CreateDropdown({
    name = "Tim Leveling (Max 7)",
    options = getOptionsFor("tim"),
    value = {},
    multiSelect = true,
    flag = "timDropdown",
    callback = function(vals)
        local map = _G._timMap or {}
        state.levelingTim = {}
        for _, label in ipairs(vals) do
            local uuid = map[label]
            if uuid then table.insert(state.levelingTim, uuid) end
        end
        if #state.levelingTim > 7 then
            print("⚠️ Maksimal 7 pet! Ambil 7 pertama.")
            table.move(state.levelingTim, 1, 7, 1, {})
        end
        print("✅ Tim Leveling:", #state.levelingTim)
        saveConfig()
    end
})

levelingTab:CreateInput({
    name = "🔍 Cari Target Leveling",
    placeholder = "Filter...",
    value = "",
    flag = "targetLevelFilter",
    callback = function(v)
        if TargetLevelDropdown then
            local opts, map = getOptionsFor("targetlevel", v)
            TargetLevelDropdown:Refresh(opts)
            _G._targetLevelMap = map
        end
    end
})

TargetLevelDropdown = levelingTab:CreateDropdown({
    name = "Target Leveling",
    options = getOptionsFor("targetlevel"),
    value = {},
    multiSelect = true,
    flag = "targetLevelDropdown",
    callback = function(vals)
        local map = _G._targetLevelMap or {}
        state.levelingTargets = {}
        for _, label in ipairs(vals) do
            local uuid = map[label]
            if uuid then table.insert(state.levelingTargets, uuid) end
        end
        print("✅ Target Leveling:", #state.levelingTargets)
        saveConfig()
    end
})

TargetLevelSlider = levelingTab:CreateSlider({
    name = "Target Level",
    min = 0,
    max = 500,
    increment = 1,
    value = state.targetLevel,
    flag = "targetLevelSlider",
    callback = function(v)
        state.targetLevel = v
        print("🎯 Target Level:", v)
        saveConfig()
    end
})

LevelingToggle = levelingTab:CreateToggle({
    name = "▶️ Start / Stop Leveling",
    value = state.isLevelingActive,
    flag = "levelingToggle",
    callback = function(v)
        if v then
            if state.isSharkActive then
                print("⚠️ Auto Shark sedang aktif! Matikan dulu.")
                -- tidak ada SetValue di sini, biarkan toggle tetap ON atau OFF sesuai logika
                -- tapi kita harus set toggle kembali ke false jika error
                -- cara: kita set state.isLevelingActive = false dan return
                state.isLevelingActive = false
                -- kita tidak bisa set toggle manual, biarkan flag yang handle
                return
            end
            if #state.levelingTim == 0 then
                print("⚠️ Pilih Tim Leveling dulu!")
                state.isLevelingActive = false
                return
            end
            if #state.levelingTargets == 0 then
                print("⚠️ Pilih Target Leveling dulu!")
                state.isLevelingActive = false
                return
            end
            startLeveling()
        else
            stopLeveling()
            state.isLevelingActive = false
        end
        saveConfig()
    end
})

-- ============================================================
-- TAB 3: PNP
-- ============================================================

local pnpTab = Window:CreateTab({ name = "PNP", icon = "bolt" })

pnpTab:CreateInput({
    name = "🔍 Cari Pet",
    placeholder = "Filter...",
    value = "",
    flag = "pnpFilter",
    callback = function(v)
        if PnpDropdown then
            local opts, map = getOptionsFor("pnp", v)
            PnpDropdown:Refresh(opts)
            _G._pnpMap = map
        end
    end
})

PnpDropdown = pnpTab:CreateDropdown({
    name = "Pilih Pet untuk PNP",
    options = getOptionsFor("pnp"),
    value = {},
    multiSelect = true,
    flag = "pnpDropdown",
    callback = function(vals)
        local map = _G._pnpMap or {}
        state.pnpPets = {}
        for _, label in ipairs(vals) do
            local uuid = map[label]
            if uuid then table.insert(state.pnpPets, uuid) end
        end
        print("✅ PNP Pets:", #state.pnpPets)
        saveConfig()
    end
})

pnpTab:CreateInput({
    name = "Pickup Delay (detik)",
    placeholder = "0.6",
    value = tostring(state.pnpPickupDelay),
    flag = "pickupDelay",
    callback = function(v)
        local num = tonumber(v)
        if num and num >= 0 then state.pnpPickupDelay = num end
        print("📦 Pickup Delay:", state.pnpPickupDelay)
        saveConfig()
    end
})

pnpTab:CreateInput({
    name = "Place Delay (detik)",
    placeholder = "0",
    value = tostring(state.pnpPlaceDelay),
    flag = "placeDelay",
    callback = function(v)
        local num = tonumber(v)
        if num and num >= 0 then state.pnpPlaceDelay = num end
        print("📦 Place Delay:", state.pnpPlaceDelay)
        saveConfig()
    end
})

PnpToggle = pnpTab:CreateToggle({
    name = "▶️ Start / Stop PNP",
    value = state.pnpActive,
    flag = "pnpToggle",
    callback = function(v)
        state.pnpActive = v
        print(v and "▶️ PNP ON" or "⏹️ PNP OFF")
        saveConfig()
    end
})

-- ============================================================
-- INISIALISASI AKHIR
-- ============================================================

loadConfig()
updateAllUI()

print("✅ Pria Solo HUB siap. Tekan K untuk membuka UI.")
